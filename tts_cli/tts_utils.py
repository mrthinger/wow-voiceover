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
from slpp import slpp as lua

OUTPUT_FOLDER = 'generated'
SOUND_OUTPUT_FOLDER = OUTPUT_FOLDER + "/sounds"

replace_dict = {'$b': '\n', '$B': '\n', '$n': 'Adventurer', '$N': 'Adventurer',
                '$C': 'adventurer', '$c': 'adventurer', '$R': 'person', '$r': 'person'}

race_substitutions = [ "human", "orc", "dwarf", "night elf", "undead", "tauren", "gnome", "troll", "goblin", "blood elf", "draenei", "worgen", "pandaren", "nightborne", "void elf", "zandalari", "kul tiran", "mechagnome", "dracthyr" ]
class_substitutions = [ "warrior", "paladin", "hunter", "rogue", "priest", "death knight", "shaman", "mage", "warlock", "monk", "druid", "demon hunter", "evoker" ]

def get_hash(text):
    hash_object = hashlib.md5(text.encode())
    return hash_object.hexdigest()

def create_output_subdirs(subdir: str):
    output_subdir = os.path.join(SOUND_OUTPUT_FOLDER, subdir)
    if not os.path.exists(output_subdir):
        os.makedirs(output_subdir)

class TTSProcessor:
    def __init__(self):
        self.voice_map = self.fetch_voice_map()
        self.preprocessed = False

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


    def preprocess_dataframe(self, df):
        if self.preprocessed:
            print("ALREADY PREPROCESSED A DATAFRAME. RUNNING THIS TWICE ON THE SAME DF CAUSES HASHING ISSUES. SKIPPING THIS CALL")
            return

        df['race'] = df['DisplayRaceID'].map(RACE_DICT)
        df['gender'] = df['DisplaySexID'].map(GENDER_DICT)
        df['voice_name'] =  df['race'] + '-' + df['gender']

        df['templateText_race_gender'] = df['text'] + df['race'] + df['gender']
        df['templateText_race_gender_hash'] = df['templateText_race_gender'].apply(
            get_hash)

        df['originalText'] = df['text']
        for k, v in replace_dict.items():
            df['text'] = df['text'].str.replace(k, v, regex=False)

        df['text'] = df['text'].str.replace(r'<.*?>\s', '', regex=True)

        self.preprocessed = True
        return df


    def process_row(self, row_tuple):
        row = pd.Series(row_tuple[1:], index=row_tuple._fields[1:])
        voice_name = f'{row["race"]}-{row["gender"]}'
        custom_message = ""
        if "$" in row["text"] or "<" in row["text"] or ">" in row["text"]:
            custom_message = f'skipping due to invalid chars: {row["text"]}'
        elif voice_name not in self.selected_voice_names:
            custom_message = f'skipping due to voice being unselected or unavailable: {voice_name}'
        elif row['source'] == "progress": # skip progress text (progress text is usually better left unread since its always played before quest completion)
            custom_message = f'skipping progress text: {row["quest"]}-{row["source"]}'
        elif not row['quest']: # if quest is missing its a gossip row
            self.tts(row["text"], voice_name,
                f'{row["templateText_race_gender_hash"]}.mp3', 'gossip')
        else:
            self.tts(row["text"], voice_name,
                f'{row["quest"]}-{row["source"]}.mp3', 'quests')
        return custom_message

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

            cleaned_text = re.sub(r'\W+', '', row['text'])

            if row['id'] not in gossip_table:
                gossip_table[row['id']] = {}

            gossip_table[row['id']][cleaned_text] = row['templateText_race_gender_hash']

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


    def read_quest_id_lookups_table(self, file_path):
        quest_id_table = {}

        if not os.path.exists(file_path):
            return quest_id_table

        with open(file_path, "r") as f:
            contents = f.read()
            try:
                # Remove the assignment part of the Lua table and parse the table
                contents = contents.replace("if WOW_PROJECT_ID or select(4, GetBuildInfo()) >= 40000 then return end\n", "")
                contents = contents.replace("select(2, ...).QuestTextHashToQuestID = ", "")
                quest_id_table = lua.decode(contents)
            except Exception as e:
                print(f"Error while reading quest_id_lookups.lua: {e}")
                return {}

        return quest_id_table

    def write_quest_id_lookups_table(self, df):
        output_file = OUTPUT_FOLDER + "/quest_id_lookups.lua"
        quest_id_table = self.read_quest_id_lookups_table(output_file)

        accept_df = df[(df['source'] == 'accept') | (df['source'] == 'progress') | (df['source'] == 'complete')]

        log = None
        #log = [] # Uncomment to write a log file with sanitized texts

        for i, row in tqdm(accept_df.iterrows()):
            title = row['Title'].lower()
            text = row['originalText']
            quest = int(row['quest'])
            npc = int(row['id'])

            # Hash male and female text versions separately
            texts = []
            if "$g" in text or "$G" in text:
                texts.append(re.sub(r'\$[Gg]\s*(.*?)\s*:\s*(.*?)\s*;', r'\1', text))
                texts.append(re.sub(r'\$[Gg]\s*(.*?)\s*:\s*(.*?)\s*;', r'\2', text))
            else:
                texts.append(text)

            text_male = None
            for text in texts:
                # Replace newline substitutions with a space
                text = re.sub(r'\$[Bb]', ' ', text)
                # Remove all Capitalized words between 2 and 12 characters in length - to client any of those words
                # could potentially be the substituted player's name, if the name is a common english word
                text = re.sub(r'\b[A-Z][a-z]{1,11}\b', '', text)
                # From this point on we can work with lowercase text
                text = text.lower()
                # Remove all name/race/class substitutions (pvp title ($t) not supported)
                text = re.sub(r'\$[nrc]', '', text)
                # Remove all possible race/class occurrences in strings (client cannot distinguish them from $r/$c after formatting)
                text = re.sub(fr'\b({"|".join(race_substitutions)}|{"|".join(class_substitutions)})\b', '', text)
                # Remove all worldstate substitutions
                text = re.sub(r'\$\d+[wedk]', '', text)
                # Remove all characters except latin letters
                text = re.sub(r'[^a-z]', '', text)

                # Skip storing the hash twice if both the male and female sanitized texts end up being the same
                if text_male is None:
                    text_male = text
                else:
                    if text_male == text:
                        continue

                # Map MD5("title@text") to quest ID
                hash = get_hash(f"{title}@{text}")
                if hash in quest_id_table and quest_id_table[hash] != quest:
                    quest_id_table[f"{hash}:{npc}"] = quest # If there are multiple quests with the same text - discriminate them by the quest npc id
                else:
                    quest_id_table[hash] = quest

                if not log is None:
                    log.append(f"{hash} = {quest} = {title}@{text}")

        if not log is None:
            with open(output_file + ".log", "w") as f:
                f.write("\n".join(log))

        with open(output_file, "w") as f:
            f.write("if WOW_PROJECT_ID or select(4, GetBuildInfo()) >= 40000 then return end\n")
            f.write("select(2, ...).QuestTextHashToQuestID = ")
            f.write(lua.encode(quest_id_table))
            f.write("\n")


    def tts_dataframe(self, df, selected_voices):
        self.create_output_dirs()
        self.process_rows_in_parallel(df, self.process_row, selected_voices, max_workers=5)
        print("Audio finished generating.")
        self.generate_lookup_tables(df)

    def generate_lookup_tables(self, df):
        self.write_gossip_file_lookups_table(df)
        print("Added new entries to gossip_file_lookups.lua")

     
        self.write_questlog_npc_lookups_table(df)
        print("Added new entries to questlog_npc_lookups.lua")
        self.write_quest_id_lookups_table(df)
        print("Added new entries to quest_id_lookups.lua")
        write_sound_length_table_lua(SOUND_OUTPUT_FOLDER, OUTPUT_FOLDER)
        print("Updated sound_length_table.lua")
