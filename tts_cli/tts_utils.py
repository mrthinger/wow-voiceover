from slpp import slpp as lua
from tts_cli.utils import get_first_n_words, get_last_n_words, replace_dollar_bs_with_space
from tts_cli.length_table import write_sound_length_table_lua
from tts_cli.consts import RACE_DICT, GENDER_DICT
from tts_cli.env_vars import ELEVENLABS_API_KEY
import os
import pandas as pd
from tqdm import tqdm
import hashlib
from concurrent.futures import ThreadPoolExecutor
import re
import torch.multiprocessing as mp

from tts_cli.tts_ai import Converter
mp.set_start_method('spawn', force=True)


# TODO: make module name a cli arg when we do other expansions
MODULE_NAME = 'AI_VoiceOverData_Vanilla'

STATIC_MAX_WORKERS = 2

INPUT_FOLDER = 'translator/assets/wow-classic-en/AI_VoiceOverData_Vanilla/generated'
OUTPUT_FOLDER = 'translator/assets/wow-classic-fr/AI_VoiceOverData_Vanilla/generated'
DEFAULT_VOICE = 'translator/assets/sounds/default/medivh.mp3'

SOUND_INPUT_FOLDER = INPUT_FOLDER + '/sounds'
SOUND_OUTPUT_FOLDER = OUTPUT_FOLDER + '/sounds'
DATAMODULE_TABLE_GUARD_CLAUSE = 'if not VoiceOver or not VoiceOver.DataModules then return end'
REPLACE_DICT = {'$b': '\n', '$B': '\n', '$n': 'aventurier', '$N': 'Aventurier',
                '$C': 'Aventurier', '$c': 'aventurier', '$R': 'Voyageur', '$r': 'voyageur'}


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
                pruned_table[source_key][title_key] = single_quest_id(
                    title_value)
            else:
                pruned_table[source_key][title_key] = {}
                for npc_key, npc_value in title_value.items():
                    if is_single_quest_id(npc_value):
                        pruned_table[source_key][title_key][npc_key] = single_quest_id(
                            npc_value)
                    else:
                        pruned_table[source_key][title_key][npc_key] = npc_value

    return pruned_table


class TTSProcessor:
    def get_voice_map(self):
        return self.voice_map

    def tts(self, text: str, inputName: str, outputName: str, output_subfolder: str, language: str, forceGen: bool = False):
        result = ""
        outpath = os.path.join(SOUND_OUTPUT_FOLDER,
                               output_subfolder, outputName)
        inpath = os.path.join(SOUND_INPUT_FOLDER, output_subfolder, inputName)

        if os.path.isfile(outpath) and forceGen is not True:
            result = "duplicate generation, skipping"
            return

        if os.path.isfile(inpath) is False:
            inpath = DEFAULT_VOICE
            return

        Converter().convert(text=text, input_sound_path=inpath,
                            language=language, output_sound_path=outpath)

        result = f"Audio file saved successfully!: {outpath}"

        return result

    def handle_gender_options(self, text):
        pattern = re.compile(r'\$[Gg]\s*([^:;]+?)\s*:\s*([^:;]+?)\s*;')

        male_text = pattern.sub(r'\1', text)
        female_text = pattern.sub(r'\2', text)

        return male_text, female_text

    def preprocess_dataframe(self, df):
        df = df.copy()  # prevent mutation on original df for safety
        df['race'] = df['DisplayRaceID'].map(RACE_DICT)
        df['gender'] = df['DisplaySexID'].map(GENDER_DICT)

        df['templateText_race_gender'] = df['original_text'] + \
            df['race'] + df['gender']
        df['templateText_race_gender_hash'] = df['templateText_race_gender'].apply(
            get_hash)

        df['cleanedText'] = df['text'].copy()

        for k, v in REPLACE_DICT.items():
            df['cleanedText'] = df['cleanedText'].str.replace(
                k, v, regex=False)

        df['cleanedText'] = df['cleanedText'].str.replace(
            r'\$g([^:]+):([^;]+);', r'\1', regex=True)
        df['cleanedText'] = df['cleanedText'].str.replace(
            r'<.*?>\s', '', regex=True)

        df['player_gender'] = None
        rows = []
        for _, row in df.iterrows():
            if re.search(r'\$[Gg]', row['cleanedText']):
                male_text, female_text = self.handle_gender_options(
                    row['cleanedText'])

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
        custom_message = ""
        if "$" in row["cleanedText"] or "<" in row["cleanedText"] or ">" in row["cleanedText"]:
            custom_message = f'skipping due to invalid chars: {row["cleanedText"]}'
        # skip progress text (progress text is usually better left unread since its always played before quest completion)
        elif row['source'] == "progress":
            custom_message = f'skipping progress text: {row["quest"]}-{row["source"]}'
        else:
            self.tts_row(row)
        return custom_message

    def tts_row(self, row):
        tts_text = row['cleanedText']
        file_name = f'{row["quest"]}-{row["source"]}' if row['quest'] else f'{row["templateText_race_gender_hash"]}'
        if row['player_gender'] is not None:
            file_name = row['player_gender'] + '-' + file_name
        file_name = file_name + '.mp3'
        subfolder = 'quests' if row['quest'] else 'gossip'

        input_file_name = file_name
        output_file_name = file_name

        self.tts(tts_text, input_file_name, output_file_name, subfolder, 'ru')

    def create_output_dirs(self):
        create_output_subdirs('')
        create_output_subdirs('quests')
        create_output_subdirs('gossip')

    def process_rows_in_parallel(self, df, row_proccesing_fn, max_workers=STATIC_MAX_WORKERS):
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            Converter().process_dataframe(
                df=df,
                num_processes=max_workers,
                executor=executor,
                row_proccesing_fn=row_proccesing_fn
            )

    def write_gossip_file_lookups_table(self, df, module_name, type, table, filename):
        output_file = OUTPUT_FOLDER + f"/{filename}.lua"
        gossip_table = {}

        accept_df = df[(df['quest'] == '') & (df['type'] == type)]

        for i, row in tqdm(accept_df.iterrows()):
            if row['id'] not in gossip_table:
                gossip_table[row['id']] = {}

            escapedText = row['text'].replace(
                '"', '\'').replace('\r', ' ').replace('\n', ' ')

            gossip_table[row['id']
                         ][escapedText] = row['templateText_race_gender_hash']

        with open(output_file, "w", encoding="UTF-8") as f:
            f.write(DATAMODULE_TABLE_GUARD_CLAUSE + "\n")
            f.write(f"{module_name}.{table} = ")
            f.write(lua.encode(gossip_table))
            f.write("\n")

        print(f"Finished writing {filename}.lua")

    def write_questlog_npc_lookups_table(self, df, module_name, type, table, filename):
        output_file = OUTPUT_FOLDER + f"/{filename}.lua"
        questlog_table = {}

        accept_df = df[(df['source'] == 'accept') & (df['type'] == type)]

        for i, row in tqdm(accept_df.iterrows()):
            questlog_table[int(row['quest'])] = row['id']

        with open(output_file, "w", encoding="UTF-8") as f:
            f.write(DATAMODULE_TABLE_GUARD_CLAUSE + "\n")
            f.write(f"{module_name}.{table} = ")
            f.write(lua.encode(questlog_table))
            f.write("\n")

        print(f"Finished writing {filename}.lua")

    def write_npc_name_lookup_table(self, df, module_name, type, table, filename):
        output_file = OUTPUT_FOLDER + f"/{filename}.lua"
        npc_name_table = {}

        accept_df = df[df['type'] == type]

        for i, row in tqdm(accept_df.iterrows()):
            npc_name_table[row['id']] = row['name']

        with open(output_file, "w", encoding="UTF-8") as f:
            f.write(DATAMODULE_TABLE_GUARD_CLAUSE + "\n")
            f.write(f"{module_name}.{table} = ")
            f.write(lua.encode(npc_name_table))
            f.write("\n")

        print(f"Finished writing {filename}.lua")

    def write_quest_id_lookup(self, df, module_name):
        output_file = OUTPUT_FOLDER + "/quest_id_lookups.lua"
        quest_id_table = {}

        quest_df = df[df['quest'] != '']

        for i, row in tqdm(quest_df.iterrows()):
            quest_source = row['source']
            if quest_source == 'progress':  # skipping progress text for now
                continue

            quest_id = int(row['quest'])
            quest_title = row['quest_title']
            quest_text = get_first_n_words(
                row['text'], 15) + ' ' + get_last_n_words(row['text'], 15)
            escaped_quest_text = replace_dollar_bs_with_space(
                quest_text.replace('"', '\'').replace('\r', ' ').replace('\n', ' '))
            escaped_quest_title = quest_title.replace(
                '"', '\'').replace('\r', ' ').replace('\n', ' ')
            npc_name = row['name']
            escaped_npc_name = npc_name.replace(
                '"', '\'').replace('\r', ' ').replace('\n', ' ')

            # table[source][title][npcName][text]
            if quest_source not in quest_id_table:
                quest_id_table[quest_source] = {}

            if escaped_quest_title not in quest_id_table[quest_source]:
                quest_id_table[quest_source][escaped_quest_title] = {}

            if escaped_npc_name not in quest_id_table[quest_source][escaped_quest_title]:
                quest_id_table[quest_source][escaped_quest_title][escaped_npc_name] = {
                }

            if quest_text not in quest_id_table[quest_source][escaped_quest_title][escaped_npc_name]:
                quest_id_table[quest_source][escaped_quest_title][escaped_npc_name][escaped_quest_text] = quest_id

        pruned_quest_id_table = prune_quest_id_table(quest_id_table)

        # UTF-8 Encoding is important for other languages!
        with open(output_file, "w", encoding="utf-8") as f:
            f.write(DATAMODULE_TABLE_GUARD_CLAUSE + "\n")
            f.write(f"{module_name}.QuestIDLookup = ")
            f.write(lua.encode(pruned_quest_id_table))
            f.write("\n")

    def write_npc_name_gossip_file_lookups_table(self, df, module_name, type, table, filename):
        output_file = OUTPUT_FOLDER + f"/{filename}.lua"
        gossip_table = {}

        accept_df = df[(df['quest'] == '') & (df['type'] == type)]

        for i, row in tqdm(accept_df.iterrows()):
            npc_name = row['name']
            escaped_npc_name = npc_name.replace(
                '"', '\'').replace('\r', ' ').replace('\n', ' ')

            if escaped_npc_name not in gossip_table:
                gossip_table[escaped_npc_name] = {}

            escapedText = row['text'].replace(
                '"', '\'').replace('\r', ' ').replace('\n', ' ')

            gossip_table[escaped_npc_name][escapedText] = row['templateText_race_gender_hash']

        with open(output_file, "w", encoding="UTF-8") as f:
            f.write(DATAMODULE_TABLE_GUARD_CLAUSE + "\n")
            f.write(f"{module_name}.{table} = ")
            f.write(lua.encode(gossip_table))
            f.write("\n")

        print(f"Finished writing {filename}.lua")

    def tts_dataframe(self, df):
        self.create_output_dirs()
        self.process_rows_in_parallel(
            df, self.process_row, max_workers=STATIC_MAX_WORKERS)
        print("Audio finished generating.")

    def generate_lookup_tables(self, df):
        self.create_output_dirs()
        self.write_gossip_file_lookups_table(
            df, MODULE_NAME, 'creature', 'GossipLookupByNPCID', 'npc_gossip_file_lookups')
        self.write_gossip_file_lookups_table(
            df, MODULE_NAME, 'gameobject', 'GossipLookupByObjectID', 'object_gossip_file_lookups')

        self.write_quest_id_lookup(df, MODULE_NAME)
        print("Finished writing quest_id_lookups.lua")

        self.write_npc_name_gossip_file_lookups_table(
            df, MODULE_NAME, 'creature', 'GossipLookupByNPCName', 'npc_name_gossip_file_lookups')
        self.write_npc_name_gossip_file_lookups_table(
            df, MODULE_NAME, 'gameobject', 'GossipLookupByObjectName', 'object_name_gossip_file_lookups')

        self.write_questlog_npc_lookups_table(
            df, MODULE_NAME, 'creature', 'NPCIDLookupByQuestID', 'questlog_npc_lookups')
        self.write_questlog_npc_lookups_table(
            df, MODULE_NAME, 'gameobject', 'ObjectIDLookupByQuestID', 'questlog_object_lookups')
        self.write_questlog_npc_lookups_table(
            df, MODULE_NAME, 'item', 'ItemIDLookupByQuestID', 'questlog_item_lookups')

        self.write_npc_name_lookup_table(
            df, MODULE_NAME, 'creature', 'NPCNameLookupByNPCID', 'npc_name_lookups')
        self.write_npc_name_lookup_table(
            df, MODULE_NAME, 'gameobject', 'ObjectNameLookupByObjectID', 'object_name_lookups')
        self.write_npc_name_lookup_table(
            df, MODULE_NAME, 'item', 'ItemNameLookupByItemID', 'item_name_lookups')

        write_sound_length_table_lua(
            MODULE_NAME, SOUND_OUTPUT_FOLDER, OUTPUT_FOLDER)
        print("Updated sound_length_table.lua")


def run():
    mp.freeze_support()
    print('loop')


if __name__ == '__main__':
    run()
