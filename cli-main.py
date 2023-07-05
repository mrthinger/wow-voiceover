import argparse
from prompt_toolkit.shortcuts import checkboxlist_dialog, radiolist_dialog, yes_no_dialog
from tts_cli.sql_queries import query_dataframe_for_all_quests_and_gossip, query_dataframe_for_area
from tts_cli.tts_utils import TTSProcessor
from tts_cli.init_db import download_and_extract_latest_db_dump, import_sql_files_to_database
from tts_cli.consts import RACE_DICT_INV, GENDER_DICT_INV, race_gender_tuple_to_strings
from tts_cli.zone_selector import KalimdorZoneSelector, EasternKingdomsZoneSelector
from tts_cli import utils


def prompt_user(tts_processor):

    #map
    map_choices = [
        (-1, "All (includes dungeons)"),
        (0, "Eastern Kingdoms"),
        (1, "Kalimdor"),
    ]
    map_id = radiolist_dialog(
        title="Select a map",
        text="Choose a map:",
        values=map_choices,
    ).run()

    if map_id >= 0:
        if map_id == 0:
            zone_selector = EasternKingdomsZoneSelector()
        else:
            zone_selector = KalimdorZoneSelector()

        #area
        (xrange, yrange) = zone_selector.select_zone()

        df = query_dataframe_for_area(xrange, yrange, map_id)
    else:
        (xrange, yrange) = 'all', 'all'
        df = query_dataframe_for_all_quests_and_gossip()
    
    # Get unique race-gender combinations
    unique_race_gender_combos = df[[
        'DisplayRaceID', 'DisplaySexID']].drop_duplicates().values
    # Convert the unique race-gender combinations to a tuple
    race_gender_tuple = tuple(map(tuple, unique_race_gender_combos))


    #voices
    voice_map = tts_processor.get_voice_map()
    required_voices_for_zone_complete = race_gender_tuple_to_strings(
        race_gender_tuple)

    available_voices = set(voice_map.keys())
    required_voices = set(required_voices_for_zone_complete)
    missing_voices = required_voices - available_voices
    selectable_voices = required_voices.intersection(available_voices)


    voice_choices = [(voice_name, f"{voice_name} (found)")
                     for voice_name in selectable_voices]
    voice_choices.sort()

    if missing_voices:
        missing_choices = [(voice_name, f"{voice_name} (missing)")
                          for voice_name in missing_voices]
        missing_choices.sort()
        voice_choices += missing_choices

    all_found_option = 'all-found'
    voice_choices.insert(0, (all_found_option, all_found_option))

    selected_voices = checkboxlist_dialog(
        title="Choose Voices",
        text=f"Select the voices you want to use. These are all of the voices needed to generate text in the selected area. Selecting a missing voice does nothing.",
        values=voice_choices,
    ).run()

    if all_found_option in selected_voices:
        selected_voices = selectable_voices
    else:
        # Filter out the missing voices from the selected_voices list
        selected_voices = [
            voice for voice in selected_voices if voice not in missing_voices]

    selected_race_gender = []
    for voice in selected_voices:
        race, gender = voice.split('-')
        selected_race_gender.append(
            (RACE_DICT_INV[race], GENDER_DICT_INV[gender]))

    selected_voice_names = race_gender_tuple_to_strings(selected_race_gender)


    #text estimate
    # Calculate the total amount of characters of non-progress and unique text
    estimate_df = tts_processor.preprocess_dataframe(df)
    estimate_df = estimate_df.loc[estimate_df['voice_name'].isin(selected_voice_names)]
    estimate_df = estimate_df.loc[~estimate_df['source'].str.contains('progress')]
    estimate_df = estimate_df[['text', 'DisplayRaceID',
                       'DisplaySexID']].drop_duplicates()
    total_characters = estimate_df['text'].str.len().sum()


    confirmed = yes_no_dialog(
        title="Summary",
        text=f"Selected Map: {map_choices[map_id][1]}\n"
             f"Coordinate Range: x={xrange}, y={yrange}\n"
             f"Selected Voices: {', '.join(selected_voice_names)}\n"
             f"Approximate Text Characters: {total_characters}",
        yes_text='Generate',
        no_text='Cancel'
    ).run()

    if not confirmed:
        exit(0)

    return df, selected_voice_names


parser = argparse.ArgumentParser(
    description="Text-to-Speech CLI for WoW dialog")

subparsers = parser.add_subparsers(dest="mode", help="Available modes")
subparsers.add_parser("init-db", help="Initialize the database")
subparsers.add_parser("interactive", help="Interactive mode")
subparsers.add_parser("gen_lookup_tables", help="Generate the lookup tables for all quests and gossip in the game. Also recomputes the sound length table.") \
          .add_argument("--lang", default="enUS")

args = parser.parse_args()

def interactive_mode():
    tts_processor = TTSProcessor()
    df, selected_voice_names = prompt_user(tts_processor)
    df = tts_processor.preprocess_dataframe(df)
    tts_processor.tts_dataframe(df, selected_voice_names)


if args.mode == "init-db":
    download_and_extract_latest_db_dump()
    import_sql_files_to_database()
    print("Database initialized successfully.")
elif args.mode == "interactive":
    interactive_mode()
elif args.mode == "gen_lookup_tables":
    tts_processor = TTSProcessor()

    language_code = args.lang
    language_number = utils.language_code_to_language_number(language_code)
    print(f"Selected language: {language_code}")

    df = query_dataframe_for_all_quests_and_gossip(language_number)
    df = tts_processor.preprocess_dataframe(df)
    tts_processor.generate_lookup_tables(df)
else:
    interactive_mode()
