import os
import mutagen.mp3

DATAMODULE_TABLE_GUARD_CLAUSE = 'if not VoiceOver or not VoiceOver.DataModules then return end'

def write_sound_length_table_lua(module_name: str, sound_folder_path: str, output_folder_path: str):

    mp3_files = []

    for root, dirs, files in os.walk(sound_folder_path):
        for f in files:
            if f.endswith(".mp3"):
                mp3_files.append(os.path.join(root, f))

    # Create a Lua table mapping the name of the sound to its length in seconds
    soundDict = {}
    for mp3_file in mp3_files:
        audio = mutagen.mp3.MP3(mp3_file)
        length = audio.info.length
        soundDict[os.path.splitext(os.path.basename(mp3_file))[0]] = length

    # Write the dictionary to the output file in Lua table format
    with open(output_folder_path + '/sound_length_table.lua', "w") as f:
        f.write(DATAMODULE_TABLE_GUARD_CLAUSE + "\n")
        f.write(f"{module_name}.SoundLengthLookupByFileName = {{\n")
        for key, value in soundDict.items():
            f.write(f"    [\"{key}\"] = {value},\n")
        f.write("}\n")
