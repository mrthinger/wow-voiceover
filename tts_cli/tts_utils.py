import requests
import os
import pandas as pd
from tqdm import tqdm
import hashlib
from concurrent.futures import ThreadPoolExecutor
import re
from tts_cli.env_vars import ELEVENLABS_API_KEY

from tts_cli.length_table import write_sound_length_table_lua

OUTPUT_FOLDER = "generated/sounds"
voice_map = {'orc-male': None, 'orc-female': None,
             'troll-male': None, 'troll-female': None,
             'goblin-male': None, 'goblin-female': None,
             'tauren-male': None, 'tauren-female': None}

race_dict = {2: 'orc', 8: 'troll', 9: 'goblin', 6: 'tauren'}
gender_dict = {0: 'male', 1: 'female'}

replace_dict = {'$b': '\n', '$B': '\n', '$n': 'Adventurer', '$N': 'Adventurer',
                '$C': 'adventurer', '$c': 'adventurer', '$R': 'person', '$r': 'person'}


def get_voices():
    url = "https://api.elevenlabs.io/v1/voices"

    headers = {
        "xi-api-key": ELEVENLABS_API_KEY
    }

    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        response = response.json()
    else:
        print("Error: unable to fetch data.")
    for voice in response["voices"]:
        if voice["name"] in voice_map:
            voice_map[voice["name"]] = voice["voice_id"]


def tts(text: str, voice: str, outputName: str, output_subfolder: str, forceGen: bool = False):
    result = ""
    outpath = os.path.join(OUTPUT_FOLDER, output_subfolder, outputName)
    if os.path.isfile(outpath) and forceGen is not True:
        result = "duplicate generation, skipping"
        return

    voice_id = voice_map[voice]
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
        result = "Error: unable to save audio file."
    return result


def get_hash(text):
    hash_object = hashlib.md5(text.encode())
    return hash_object.hexdigest()


def preprocess_dataframe(df):
    df['race'] = df['DisplayRaceID'].map(race_dict)
    df['gender'] = df['DisplaySexID'].map(gender_dict)

    df['templateText_race_gender'] = df['text'] + df['race'] + df['gender']
    df['templateText_race_gender_hash'] = df['templateText_race_gender'].apply(
        get_hash)

    for k, v in replace_dict.items():
        df['text'] = df['text'].str.replace(k, v, regex=False)

    df['text'] = df['text'].str.replace(r'<.*?>\s', '', regex=True)

    return df


def process_quest_row(row_tuple):
    row = pd.Series(row_tuple[1:], index=row_tuple._fields[1:])
    custom_message = ""
    if "$" in row["text"] or "<" in row["text"] or ">" in row["text"]:
        custom_message = f'skipping due to invalid chars: {row["id"]}-{row["source"]}'
    elif row['source'] == "progress":
        custom_message = f'skipping progress text: {row["id"]}-{row["source"]}'
    else:
        tts(row["text"], f'{row["race"]}-{row["gender"]}',
            f'{row["quest"]}-{row["source"]}.mp3', 'quests')
    return custom_message


def process_gossip_row(row_tuple):
    row = pd.Series(row_tuple[1:], index=row_tuple._fields[1:])
    custom_message = ""
    if "$" in row["text"] or "<" in row["text"] or ">" in row["text"]:
        custom_message = f'skipping due to invalid chars: {row["id"]}'
    else:
        tts(row["text"], f'{row["race"]}-{row["gender"]}',
            f'{row["templateText_race_gender_hash"]}.mp3', 'gossip')
    return custom_message


def process_rows_in_parallel(df, row_proccesing_fn, max_workers=5):
    total_rows = len(df)
    bar_format = '{desc}: {l_bar}{bar}| {n_fmt}/{total_fmt} [{elapsed}<{remaining}, {rate_fmt}] {postfix}'

    with tqdm(total=total_rows, unit='rows', ncols=100, desc='Processing DataFrame', ascii=False, bar_format=bar_format, dynamic_ncols=True) as pbar:
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            for row, custom_message in zip(df.iterrows(), executor.map(row_proccesing_fn, df.itertuples())):
                pbar.set_postfix_str(custom_message)
                pbar.update(1)


def write_gossip_file_lookups_table(df):
    gossip_table = {}
    for i, row in tqdm(df.iterrows()):
        cleaned_text = re.sub(r'\W+', '', row['text'])

        if row['id'] not in gossip_table:
            gossip_table[row['id']] = {}

        gossip_table[row['id']][cleaned_text] = row['templateText_race_gender_hash']

    output_file = "generated/gossip_file_lookups.lua"

    with open(output_file, "w") as f:
        f.write("NPCToTextToTemplateHash = {\n")
        for id_key, sub_dict in gossip_table.items():
            f.write(f"    [{id_key}] = {{\n")
            for text_key, hash_value in sub_dict.items():
                f.write(f"        [\"{text_key}\"] = \"{hash_value}\",\n")
            f.write("    },\n")
        f.write("}\n")


def process_quest_data(df):
    df = preprocess_dataframe(df)
    get_voices()
    process_rows_in_parallel(df, process_quest_row, max_workers=6)
    write_sound_length_table_lua(OUTPUT_FOLDER)


def process_gossip_data(df):
    df = preprocess_dataframe(df)
    get_voices()
    process_rows_in_parallel(df, process_gossip_row, max_workers=20)
    write_gossip_file_lookups_table(df)
    write_sound_length_table_lua(OUTPUT_FOLDER)
