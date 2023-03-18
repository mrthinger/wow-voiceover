import argparse
from tts_cli.sql_queries import get_gossip_dataframe, get_quest_dataframe
from tts_cli.tts_utils import process_quest_data, process_gossip_data
from tts_cli.init_db import download_and_extract_latest_db_dump, import_sql_files_to_database


parser = argparse.ArgumentParser(
    description="Text-to-Speech CLI for WoW dialog")

subparsers = parser.add_subparsers(dest="mode", help="Available modes")
subparsers.add_parser("init-db", help="Initialize the database")
subparsers.add_parser("quests", help="Process quests")
subparsers.add_parser("gossip", help="Process gossip")

args = parser.parse_args()

if args.mode == "quests":
    quest_df = get_quest_dataframe()
    print(quest_df.head())
    process_quest_data(quest_df)
elif args.mode == "gossip":
    gossip_df = get_gossip_dataframe()
    print(gossip_df.head())
    process_gossip_data(gossip_df)
elif args.mode == "init-db":
    download_and_extract_latest_db_dump()
    import_sql_files_to_database()
    print("Database initialized successfully.")
