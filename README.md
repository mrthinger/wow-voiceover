# VoiceOver for World of Warcraft Quests and Gossip
This project contains a CLI (Command Line Interface) tool that generates Text-to-Speech (TTS) audio files for World of Warcraft quests and gossip texts. The tool uses data fetched from a local MySQL database and the ElevenLabs TTS API to generate the audio files. It also contains an addon for playing and queuing the text in game.

## Development Discord: https://discord.gg/VdhUmA8ZCt

## Features
- Initialize quest and gossip text database
- Fetch quest and gossip texts from a local MySQL database.
- Generate TTS audio files using the ElevenLabs TTS API.
- Supports multiple races and genders.
- Generates lookup tables for use in addon.
- Parallel processing for faster generation.

## Requirements
- python 3.9+
- docker (for the database)

## Installation
1. Make a python virtual enviornment. (make sure to source it after creating)
```bash
python -m venv .venv
```
2. Install the required packages.
```bash
pip install -r requirements.txt
```
3. Copy the .env.example file to .env and fill in your ElevenLabs API Key and database credentials. The included database values are fine if you're going to use the docker-compose file.
```bash
cp .env.example .env
```
4. Start the MySQL DB
```bash
docker compose up -d
```
5. Seed the MySQL DB
```bash
python cli-main.py init-db
```

## Voice Setup
The generation scripts assume you have voices created in Elevenlabs named in the format `race-gender`. For the exact races the script checks your elevenlabs account for, refer to `tts_cli\consts.py`. Gender will always either be `male` or `female`. ex: `orc-male`. You will need to create your own voice clones. A good place to get samples is @ https://www.wowhead.com/sounds/npc-greetings/name:orc 
## Usage
To use the interactive CLI tool, run the following command:

```bash
python cli-main.py
```
## Output
The generated TTS audio files will be saved in the sounds folder, with separate subfolders for quests and gossip. Lookup tables and sound length tables will also be generated for use in the addon. 

## Addon Install
Copy over the `generated` folder to the VoiceOver folder, then the VoiceOver folder to `World of Warcraft/_classic_era_/Interface/AddOns`
## Contributing
If you want to contribute to this project, please feel free to open an issue or submit a pull request.
