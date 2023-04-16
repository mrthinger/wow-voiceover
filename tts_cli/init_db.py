from tts_cli.env_vars import MYSQL_HOST, MYSQL_PORT, MYSQL_PASSWORD, MYSQL_USER, MYSQL_DATABASE
import pymysql
import io
import zipfile
import requests
import os
from tqdm import tqdm


VMANGOS_DB_DUMP_URL = "https://api.github.com/repos/vmangos/core/releases/tags/db_latest"
EXPORTED_FILES = ['assets/sql/exported/CreatureDisplayInfo.sql',
                  'assets/sql/exported/CreatureDisplayInfoExtra.sql']


def download_and_extract_latest_db_dump():
    print("Retrieving latest version")
    check_version = requests.get(VMANGOS_DB_DUMP_URL)
    get_latest = check_version.json()['assets'][0]['browser_download_url']
    print("Processing")
    response = requests.get(get_latest)
    if response.status_code == 200:
        z = zipfile.ZipFile(io.BytesIO(response.content))
        z.extractall("assets/sql")
    else:
        print("Error: Unable to download the database dump.")
        exit(1)


def count_total_chunks(files, delimiter):
    total_chunks = 0
    for file in files:
        with open(file, "rb") as f:
            buffer = f.read()
            total_chunks += buffer.count(delimiter)
    return total_chunks


def count_commands_from_file(filename):
    fd = open(filename, 'r')
    sqlFile = fd.read()
    fd.close()

    sqlCommands = sqlFile.split(';')
    return len(sqlCommands)


def execute_scripts_from_file(cursor, filename, progress_update_fn):
    fd = open(filename, 'r')
    sqlFile = fd.read()
    fd.close()

    sqlCommands = sqlFile.split(';')

    for command in sqlCommands:
        try:
            cursor.execute(command)
        except pymysql.Error as e:
            pass
        progress_update_fn()


def import_sql_files_to_database():
    db = pymysql.connect(
        host=MYSQL_HOST,
        port=MYSQL_PORT,
        user=MYSQL_USER,
        password=MYSQL_PASSWORD
    )
    cursor = db.cursor()
    cursor.execute(f"CREATE DATABASE IF NOT EXISTS {MYSQL_DATABASE};")
    cursor.execute(f"USE {MYSQL_DATABASE};")

    sql_files = []
    for dirpath, _, filenames in os.walk("assets/sql/db_dump"):
        for filename in filenames:
            if filename.endswith(".sql"):
                sql_files.append(os.path.join(dirpath, filename))

    chunk_size = 1024 * 1024  # 1MB
    delimiter = b";\n"
    total_chunks = count_total_chunks(
        sql_files, delimiter) + sum(map(count_commands_from_file, EXPORTED_FILES))

    with tqdm(total=total_chunks, unit='chunks', desc='Importing SQL files', ncols=100) as pbar:
        for file in sql_files:
            with open(file, "rb") as f:
                buffer = bytearray()
                while chunk := f.read(chunk_size):
                    buffer.extend(chunk)
                    while delimiter in buffer:
                        pos = buffer.index(delimiter)
                        try:
                            sql_command = buffer[:pos].decode('utf-8')
                            cursor.execute(sql_command)
                            db.commit()
                        except pymysql.Error as e:
                            print(f"Error importing {file}: {e}")
                            exit(1)
                        buffer = buffer[pos+len(delimiter):]
                        pbar.update(1)  # Update progress bar for each chunk
                # Execute any remaining SQL commands
                if buffer:
                    try:
                        sql_command = buffer.decode('utf-8')
                        cursor.execute(sql_command)
                        db.commit()
                    except pymysql.Error as e:
                        print(f"Error importing {file}: {e}")
                        exit(1)

        for file in EXPORTED_FILES:
            execute_scripts_from_file(cursor, file, progress_update_fn=lambda: pbar.update(1))

    db.commit()
    cursor.close()
    db.close()


if __name__ == "__main__":
    download_and_extract_latest_db_dump()
    import_sql_files_to_database()
    
    print("Database initialized successfully.")
