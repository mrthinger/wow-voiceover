import argparse
from prompt_toolkit.shortcuts import checkboxlist_dialog, radiolist_dialog, yes_no_dialog
from tts_cli.sql_queries import query_dataframe_for_all_quests_and_gossip, query_dataframe_for_area
from tts_cli.tts_utils import TTSProcessor
from tts_cli.init_db import download_and_extract_latest_db_dump, import_sql_files_to_database
from tts_cli.consts import RACE_DICT_INV, GENDER_DICT_INV, race_gender_tuple_to_strings
from tts_cli.wrath_model_extraction import write_model_data
from tts_cli.zone_selector import KalimdorZoneSelector, EasternKingdomsZoneSelector
from tts_cli import utils


def prompt_user(tts_processor):

    # map
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

        # area
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

    # text estimate
    # Calculate the total amount of characters of non-progress and unique text
    # TODO: International: Include language parsing here
    language_code = 'frFR'
    language_number = utils.language_code_to_language_number(language_code)
    print(f"Selected language: {language_code}")

    df = query_dataframe_for_all_quests_and_gossip(language_number)

    estimate_df = tts_processor.preprocess_dataframe(df)
    estimate_df = estimate_df.loc[~estimate_df['source'].str.contains(
        'progress')]
    estimate_df = estimate_df[['text', 'DisplayRaceID',
                               'DisplaySexID']].drop_duplicates()
    total_characters = estimate_df['text'].str.len().sum()

    confirmed = yes_no_dialog(
        title="Summary",
        text=f"Selected Map: {map_choices[map_id][1]}\n"
             f"Coordinate Range: x={xrange}, y={yrange}\n"
             f"Approximate Text Characters: {total_characters}",
        yes_text='Generate',
        no_text='Cancel'
    ).run()

    if not confirmed:
        exit(0)

    return df


def prepare_generator():

    # map
    df = query_dataframe_for_all_quests_and_gossip()

    language_code = 'frFR'
    language_number = utils.language_code_to_language_number(language_code)
    print(f"Selected language: {language_code}")

    df = query_dataframe_for_all_quests_and_gossip(language_number)

    return df


parser = argparse.ArgumentParser(
    description="Text-to-Speech CLI for WoW dialog")

subparsers = parser.add_subparsers(dest="mode", help="Available modes")
subparsers.add_parser("init-db", help="Initialize the database")
subparsers.add_parser("interactive", help="Interactive mode")
subparsers.add_parser("generator", help="Generator mode")
subparsers.add_parser("extract_model_data",
                      help="Generate info about which NPC entry uses which model.")
subparsers.add_parser("gen_lookup_tables", help="Generate the lookup tables for all quests and gossip in the game. Also recomputes the sound length table.") \
          .add_argument("--lang", default="frFR")

args = parser.parse_args()


def interactive_mode():
    tts_processor = TTSProcessor()
    df = prompt_user(tts_processor)
    df = tts_processor.preprocess_dataframe(df)
    tts_processor.tts_dataframe(df)


def generator_mode():
    tts_processor = TTSProcessor()
    df = prepare_generator()
    df = tts_processor.preprocess_dataframe(df)
    tts_processor.tts_dataframe(df)


if args.mode == "init-db":
    download_and_extract_latest_db_dump()
    import_sql_files_to_database()
    print("Database initialized successfully.")
elif args.mode == "interactive":
    interactive_mode()
elif args.mode == "generator":
    generator_mode()
elif args.mode == "gen_lookup_tables":
    tts_processor = TTSProcessor()

    language_code = args.lang
    language_number = utils.language_code_to_language_number(language_code)
    print(f"Selected language: {language_code}")

    df = query_dataframe_for_all_quests_and_gossip(language_number)
    df = tts_processor.preprocess_dataframe(df)
    tts_processor.generate_lookup_tables(df)
elif args.mode == "extract_model_data":
    write_model_data()
else:
    interactive_mode()
