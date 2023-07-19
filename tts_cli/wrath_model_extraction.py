import pandas as pd
from tts_cli.sql_queries import make_connection
from tts_cli.consts import RACE_DICT

def write_model_data():
    db = make_connection()
    query = '''
    with data112 as (
        with normalized_models(entry, display_id, name) as (
            select entry, display_id1, name from mangos.creature_template where display_id1
            union distinct
            select entry, display_id2, name from mangos.creature_template where display_id2
            union distinct
            select entry, display_id3, name from mangos.creature_template where display_id3
            union distinct
            select entry, display_id4, name from mangos.creature_template where display_id4
        )
        select distinct modelname, entry, name from (
            select id from mangos.creature_questrelation
            union distinct
            select id from mangos.creature_involvedrelation
            union distinct
            select entry from mangos.creature_template where gossip_menu_id
        ) sources
        left join normalized_models nm on nm.entry=sources.id
        left join mangos.db_CreatureDisplayInfo cdi on cdi.ID=nm.display_id
        left join mangos.db_CreatureModelData cmd on cmd.ID=cdi.ModelID -- 112_CreatureModelData.sql
    ),
    data335 as (
        with normalized_models(entry, display_id, name) as (
            select entry, modelid1, Name from mangos_wrath.creature_template where modelid1
            union distinct
            select entry, modelid2, Name from mangos_wrath.creature_template where modelid2
            union distinct
            select entry, modelid3, Name from mangos_wrath.creature_template where modelid3
            union distinct
            select entry, modelid4, Name from mangos_wrath.creature_template where modelid4
        )
        select distinct modelname, entry, name  from (
            select id from mangos_wrath.creature_questrelation
            union distinct
            select id from mangos_wrath.creature_involvedrelation
            union distinct
            select entry from mangos_wrath.creature_template where GossipMenuId
        ) sources
        left join normalized_models nm on nm.entry=sources.id
        left join mangos_wrath.db_CreatureDisplayInfo cdi on cdi.ID=nm.display_id -- 335_CreatureDisplayInfo.sql
        left join mangos_wrath.db_CreatureModelData cmd on cmd.ID=cdi.ModelID -- 335_CreatureModelData.sql
    )
    select entry, modelname, name from (
        select * from data112
        union distinct
        select * from data335
    ) combined
    order by entry
    '''
    with db.cursor() as cursor:
        cursor.execute(query)
        data = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]

    db.close()
    df = pd.DataFrame(data, columns=columns)


    def extract_info(modelname):
        race_id = -1
        gender = -1
        if not modelname:
            return race_id, gender, -1
        
        unique_voice_name = modelname.split("\\")[-1].split(".")[0]

        for key, value in RACE_DICT.items():
            if value.lower() in modelname.lower():
                race_id = key
                break

        if "female" in modelname.lower():
            gender = 1
        elif "male" in modelname.lower():
            gender = 0

        return race_id, gender, unique_voice_name


    # Create new columns 'race_id', 'gender', and 'unique_voice_name'
    df[['race_id', 'gender', 'unique_voice_name']] = df['modelname'].apply(
        lambda x: pd.Series(extract_info(x)))

    # Write the updated DataFrame to a new CSV file
    df.to_csv("generated/warcraft-display-metadata.csv", index=False)
