import requests
import os
import pandas as pd
from tqdm import tqdm
import hashlib
from concurrent.futures import ThreadPoolExecutor
import re
from tts_cli.env_vars import ELEVENLABS_API_KEY
from tts_cli.consts import RACE_DICT, GENDER_DICT
from tts_cli.length_table import write_sound_length_table_lua
from tts_cli.utils import get_first_n_words, get_last_n_words, replace_dollar_bs_with_space
from slpp import slpp as lua


OUTPUT_FOLDER = 'generated'
SOUND_OUTPUT_FOLDER = OUTPUT_FOLDER + "/sounds"

replace_dict = {'$b': '\n', '$B': '\n', '$n': 'adventurer', '$N': 'Adventurer',
                '$C': 'Adventurer', '$c': 'adventurer', '$R': 'Traveler', '$r': 'traveler'}

def get_hash(text):
    hash_object = hashlib.md5(text.encode())
    return hash_object.hexdigest()

def create_output_subdirs(subdir: str):
    output_subdir = os.path.join(SOUND_OUTPUT_FOLDER, subdir)
    if not os.path.exists(output_subdir):
        os.makedirs(output_subdir)

def prune_quest_id_table(quest_id_table):
    def is_single_quest_id(nested_dict):
        if isinstance(nested_dict, dict):
            if len(nested_dict) == 1:
                return is_single_quest_id(next(iter(nested_dict.values())))
            else:
                return False
        else:
            return True

    def single_quest_id(nested_dict):
        if isinstance(nested_dict, dict):
            return single_quest_id(next(iter(nested_dict.values())))
        else:
            return nested_dict

    pruned_table = {}
    for source_key, source_value in quest_id_table.items():
        pruned_table[source_key] = {}
        for title_key, title_value in source_value.items():
            if is_single_quest_id(title_value):
                pruned_table[source_key][title_key] = single_quest_id(title_value)
            else:
                pruned_table[source_key][title_key] = {}
                for npc_key, npc_value in title_value.items():
                    if is_single_quest_id(npc_value):
                        pruned_table[source_key][title_key][npc_key] = single_quest_id(npc_value)
                    else:
                        pruned_table[source_key][title_key][npc_key] = npc_value

    return pruned_table

class TTSProcessor:
    def __init__(self):
        self.voice_map = self.fetch_voice_map()

    def get_voice_map(self):
        return self.voice_map

    def fetch_voice_map(self):
        url = "https://api.elevenlabs.io/v1/voices"
        headers = {
            "xi-api-key": ELEVENLABS_API_KEY
        }

        response = requests.get(url, headers=headers)
        if response.status_code != 200:
            print("Error: unable to fetch data.")
            return {}

        response = response.json()
        voice_map = {}

        for voice in response["voices"]:
            name_parts = voice["name"].split('-')
            if len(name_parts) == 2:
                race, gender = name_parts
                if race in RACE_DICT.values() and (gender == 'male' or gender == 'female'):
                    voice_map[voice["name"]] = voice["voice_id"]

        return voice_map

    def tts(self, text: str, voice: str, outputName: str, output_subfolder: str, forceGen: bool = False):
        result = ""
        outpath = os.path.join(SOUND_OUTPUT_FOLDER, output_subfolder, outputName)
        if os.path.isfile(outpath) and forceGen is not True:
            result = "duplicate generation, skipping"
            return

        voice_id = self.voice_map[voice]
        url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
        payload = {
            "text": text,
            "voice_settings": {
                "stability": 0.28,
                "similarity_boost": .992
            }
        }
        headers = {
            "xi-api-key": ELEVENLABS_API_KEY
        }

        response = requests.post(url, json=payload, headers=headers)

        if response.status_code == 200 and response.headers["Content-Type"] == "audio/mpeg":
            with open(outpath, "wb") as f:
                f.write(response.content)
                result = f"Audio file saved successfully!: {outpath}"
                print(result)
        else:
            result = f"Error: unable to save audio file {response}"
            print(result)
        return result



    def handle_gender_options(self, text):
        pattern = re.compile(r'\$[Gg]\s*([^:;]+?)\s*:\s*([^:;]+?)\s*;')

        male_text = pattern.sub(r'\1', text)
        female_text = pattern.sub(r'\2', text)

        return male_text, female_text

    def preprocess_dataframe(self, df):
        df = df.copy() # prevent mutation on original df for safety
        df['race'] = df['DisplayRaceID'].map(RACE_DICT)
        df['gender'] = df['DisplaySexID'].map(GENDER_DICT)
        df['voice_name'] = df['race'] + '-' + df['gender']

        df['templateText_race_gender'] = df['text'] + df['race'] + df['gender']
        df['templateText_race_gender_hash'] = df['templateText_race_gender'].apply(get_hash)

        df['cleanedText'] = df['text'].copy()

        for k, v in replace_dict.items():
            df['cleanedText'] = df['cleanedText'].str.replace(k, v, regex=False)

        df['cleanedText'] = df['cleanedText'].str.replace(r'<.*?>\s', '', regex=True)

        df['player_gender'] = None
        rows = []
        for _, row in df.iterrows():
            if re.search(r'\$[Gg]', row['cleanedText']):
                male_text, female_text = self.handle_gender_options(row['cleanedText'])

                row_male = row.copy()
                row_male['cleanedText'] = male_text
                row_male['player_gender'] = 'm'

                row_female = row.copy()
                row_female['cleanedText'] = female_text
                row_female['player_gender'] = 'f'

                rows.extend([row_male, row_female])
            else:
                rows.append(row)

        new_df = pd.DataFrame(rows)
        new_df.reset_index(drop=True, inplace=True)

        return new_df


    def process_row(self, row_tuple):
        row = pd.Series(row_tuple[1:], index=row_tuple._fields[1:])
        voice_name = f'{row["race"]}-{row["gender"]}'
        custom_message = ""
        if "$" in row["cleanedText"] or "<" in row["cleanedText"] or ">" in row["cleanedText"]:
            custom_message = f'skipping due to invalid chars: {row["cleanedText"]}'
        elif voice_name not in self.selected_voice_names:
            custom_message = f'skipping due to voice being unselected or unavailable: {voice_name}'
        elif row['source'] == "progress": # skip progress text (progress text is usually better left unread since its always played before quest completion)
            custom_message = f'skipping progress text: {row["quest"]}-{row["source"]}'
        else:
            self.tts_row(row, voice_name)
        return custom_message

    def tts_row(self, row, voice_name):
        tts_text = row['cleanedText']
        file_name =  f'{row["quest"]}-{row["source"]}' if row['quest'] else f'{row["templateText_race_gender_hash"]}'
        if row['player_gender'] is not None:
            file_name = row['player_gender'] + '-'+ file_name
        file_name = file_name + '.mp3'
        subfolder = 'quests' if row['quest'] else 'gossip'
        self.tts(tts_text, voice_name, file_name, subfolder)

    def create_output_dirs(self):
        create_output_subdirs('')
        create_output_subdirs('quests')
        create_output_subdirs('gossip')

    def process_rows_in_parallel(self, df, row_proccesing_fn, selected_voice_names: list[str], max_workers=5):

        total_rows = len(df)
        bar_format = '{l_bar}{bar}| {n_fmt}/{total_fmt} [{elapsed}<{remaining}, {rate_fmt}] {postfix}'
        self.selected_voice_names = set(selected_voice_names)

        with tqdm(total=total_rows, unit='rows', ncols=100, desc='Generating Audio', ascii=False, bar_format=bar_format, dynamic_ncols=True) as pbar:
            with ThreadPoolExecutor(max_workers=max_workers) as executor:
                for row, custom_message in zip(df.iterrows(), executor.map(row_proccesing_fn, df.itertuples())):
                    pbar.set_postfix_str(custom_message)
                    pbar.update(1)


    def read_gossip_file_lookups_table(self, file_path):
        gossip_table = {}
        
        if not os.path.exists(file_path):
            return gossip_table

        with open(file_path, "r") as f:
            contents = f.read()
            try:
                # Remove the assignment part of the Lua table and parse the table
                contents = contents.replace("NPCToTextToTemplateHash = ", "")
                contents = contents.replace("select(2, ...).", "")
                gossip_table = lua.decode(contents)
            except Exception as e:
                print(f"Error while reading gossip_file_lookups.lua: {e}")
                return {}
        
        return gossip_table
    def write_gossip_file_lookups_table(self, df):
        output_file = OUTPUT_FOLDER + "/gossip_file_lookups.lua"
        gossip_table = self.read_gossip_file_lookups_table(output_file)

        for i, row in tqdm(df.iterrows()):
            if row['quest']:
                continue

            if row['id'] not in gossip_table:
                gossip_table[row['id']] = {}

            escapedText = row['text'].replace('"', '\'').replace('\n','')
            
            gossip_table[row['id']][escapedText] = row['templateText_race_gender_hash']

        with open(output_file, "w") as f:
            f.write("select(2, ...).NPCToTextToTemplateHash = ")
            f.write(lua.encode(gossip_table))
            f.write("\n")


    def read_questlog_npc_lookups_table(self, file_path):
        questlog_table = {}

        if not os.path.exists(file_path):
            return questlog_table

        with open(file_path, "r") as f:
            contents = f.read()
            try:
                # Remove the assignment part of the Lua table and parse the table
                contents = contents.replace("QuestlogNpcGuidTable = ", "")
                contents = contents.replace("select(2, ...).", "")
                questlog_table = lua.decode(contents)
            except Exception as e:
                print(f"Error while reading questlog_npc_lookups.lua: {e}")
                return {}

        return questlog_table

    def write_questlog_npc_lookups_table(self, df):
        output_file = OUTPUT_FOLDER + "/questlog_npc_lookups.lua"
        questlog_table = self.read_questlog_npc_lookups_table(output_file)

        accept_df = df[df['source'] == 'accept']

        for i, row in tqdm(accept_df.iterrows()):
            questlog_table[int(row['quest'])] = row['id']

        with open(output_file, "w") as f:
            f.write("select(2, ...).QuestlogNpcGuidTable = ")
            f.write(lua.encode(questlog_table))
            f.write("\n")

    def read_quest_id_lookup(self, file_path):
        quest_id_table = {}

        if not os.path.exists(file_path):
            return quest_id_table

        with open(file_path, "r") as f:
            contents = f.read()
            try:
                # Remove the assignment part of the Lua table and parse the table
                contents = contents.replace("VoiceOver_QuestIDLookup = ", "")
                quest_id_table = lua.decode(contents)
            except Exception as e:
                print(f"Error while reading quest_id_lookups.lua: {e}")
                return {}

        return quest_id_table

    def write_quest_id_lookup(self, df):
        output_file = OUTPUT_FOLDER + "/quest_id_lookups.lua"
        quest_id_table = self.read_quest_id_lookup(output_file)

        quest_df = df[df['quest'] != '']

        for i, row in tqdm(quest_df.iterrows()):
            quest_source = row['source']
            if quest_source == 'progress': # skipping progress text for now
                continue

            quest_id = int(row['quest'])
            quest_title = row['quest_title']
            quest_text = get_first_n_words(row['text'], 15) + ' ' +  get_last_n_words(row['text'], 15)
            escaped_quest_text = replace_dollar_bs_with_space(quest_text.replace('"', '\'').replace('\n',''))
            escaped_quest_title = quest_title.replace('"', '\'').replace('\n','')
            npc_name = row['name']
            escaped_npc_name = npc_name.replace('"', '\'').replace('\n','')

            # table[source][title][npcName][text]
            if quest_source not in quest_id_table:
                quest_id_table[quest_source] = {}

            if escaped_quest_title not in quest_id_table[quest_source]:
                quest_id_table[quest_source][escaped_quest_title] = {}

            if escaped_npc_name not in quest_id_table[quest_source][escaped_quest_title]:
                quest_id_table[quest_source][escaped_quest_title][escaped_npc_name] = {}

            if quest_text not in quest_id_table[quest_source][escaped_quest_title][escaped_npc_name]:
                quest_id_table[quest_source][escaped_quest_title][escaped_npc_name][escaped_quest_text] = quest_id

        pruned_quest_id_table = prune_quest_id_table(quest_id_table)

        with open(output_file, "w") as f:
            f.write("VoiceOver_QuestIDLookup = ")
            f.write(lua.encode(pruned_quest_id_table))
            f.write("\n")

    def read_npc_name_gossip_file_lookups_table(self, file_path):
        gossip_table = {}
        
        if not os.path.exists(file_path):
            return gossip_table

        with open(file_path, "r") as f:
            contents = f.read()
            try:
                # Remove the assignment part of the Lua table and parse the table
                contents = contents.replace("VoiceOver_GossipLookup = ", "")
                contents = contents.replace("select(2, ...).", "")
                gossip_table = lua.decode(contents)
            except Exception as e:
                print(f"Error while reading npc_name_gossip_file_lookups.lua: {e}")
                return {}
        
        return gossip_table

    def write_npc_name_gossip_file_lookups_table(self, df):
        output_file = OUTPUT_FOLDER + "/npc_name_gossip_file_lookups.lua"
        gossip_table = self.read_npc_name_gossip_file_lookups_table(output_file)

        for i, row in tqdm(df.iterrows()):
            if row['quest']:
                continue
            npc_name = row['name']

            if npc_name not in gossip_table:
                gossip_table[npc_name] = {}

            escapedText = row['text'].replace('"', '\'').replace('\n','')
            
            gossip_table[npc_name][escapedText] = row['templateText_race_gender_hash']

        with open(output_file, "w") as f:
            f.write("VoiceOver_GossipLookup = ")
            f.write(lua.encode(gossip_table))
            f.write("\n")



    def tts_dataframe(self, df, selected_voices):
        self.create_output_dirs()
        self.process_rows_in_parallel(df, self.process_row, selected_voices, max_workers=5)
        print("Audio finished generating.")
        self.generate_lookup_tables(df)

    def generate_lookup_tables(self, df):
        self.write_gossip_file_lookups_table(df)
        print("Added new entries to gossip_file_lookups.lua")

        self.write_quest_id_lookup(df)
        print("Added new entries to quest_id_lookups.lua")

        self.write_npc_name_gossip_file_lookups_table(df)
        print("Added new entries to npc_name_gossip_file_lookups.lua")

        self.write_questlog_npc_lookups_table(df)
        print("Added new entries to questlog_npc_lookups.lua")
        
        write_sound_length_table_lua(SOUND_OUTPUT_FOLDER, OUTPUT_FOLDER)
        print("Updated sound_length_table.lua")
