import pymysql
import pandas as pd
from tts_cli.env_vars import MYSQL_HOST, MYSQL_PASSWORD, MYSQL_USER, MYSQL_DATABASE

def make_connection():
    return pymysql.connect(
        host=MYSQL_HOST,
        user=MYSQL_USER,
        password=MYSQL_PASSWORD,
        database=MYSQL_DATABASE
    )

def get_gossip_dataframe():
    db = make_connection()
    sql_query = '''
SELECT DISTINCT
    cdie.DisplayRaceID,
    cdie.DisplaySexID,
    creature.id,
    ct.name,
    IF(cdie.DisplaySexID = 0, bt.male_text, bt.female_text) AS text
FROM creature
    JOIN creature_template ct ON creature.id = ct.entry
    JOIN gossip_menu gm ON ct.gossip_menu_id = gm.entry
    JOIN npc_text nt ON gm.text_id = nt.ID
    JOIN broadcast_text bt ON nt.BroadcastTextID0 = bt.entry
    JOIN db_CreatureDisplayInfo cdi ON ct.display_id1 = cdi.ID
    JOIN db_CreatureDisplayInfoExtra cdie ON cdi.ExtendedDisplayInfoID = cdie.ID
WHERE
    creature.map = 1
    AND (cdie.DisplayRaceID = 2 OR cdie.DisplayRaceID = 8 OR cdie.DisplayRaceID = 6 OR cdie.DisplayRaceID = 9)
    AND creature.position_x > -1000 AND creature.position_x < 2000
    AND creature.position_y > -5500 AND creature.position_y < -1000
    AND (
        (cdie.DisplaySexID = 0 AND bt.male_text IS NOT NULL AND bt.male_text != '')
        OR (cdie.DisplaySexID = 1 AND bt.female_text IS NOT NULL AND bt.female_text != '')
    );
    '''

    gossip_df = pd.read_sql_query(sql_query, db)
    db.close()

    return gossip_df


def get_quest_dataframe():
    db = make_connection()

    sql_query = '''
WITH quest_relations AS (
    SELECT 'accept' as source, qr.quest, creature.id as creature_id, creature.position_x, creature.position_y, creature.map
    FROM creature
    JOIN creature_questrelation qr ON qr.id = creature.id
        UNION ALL
    SELECT 'complete' as source, qr.quest, creature.id as creature_id, creature.position_x, creature.position_y, creature.map
    FROM creature
    JOIN creature_involvedrelation qr ON qr.id = creature.id
        UNION ALL
    SELECT 'progress' as source, qr.quest, creature.id as creature_id, creature.position_x, creature.position_y, creature.map
    FROM creature
    JOIN creature_involvedrelation qr ON qr.id = creature.id
)
SELECT
    distinct
    qr.source,
    qr.quest,
    CASE
        WHEN qr.source = 'accept' THEN qt.Details
        WHEN qr.source = 'progress' THEN qt.RequestItemsText
        ELSE qt.OfferRewardText
    END as "text",
    cdie.DisplayRaceID,
    cdie.DisplaySexID,
    ct.name,
    qr.creature_id as id
FROM
    quest_relations qr
JOIN quest_template qt ON qr.quest = qt.entry
JOIN creature_template ct ON qr.creature_id = ct.entry
JOIN db_CreatureDisplayInfo cdi ON ct.display_id1 = cdi.ID
JOIN db_CreatureDisplayInfoExtra cdie ON cdi.ExtendedDisplayInfoID = cdie.ID
where
    qr.map = 1
  AND (cdie.DisplayRaceID = 2 OR cdie.DisplayRaceID = 8 OR cdie.DisplayRaceID = 6 OR cdie.DisplayRaceID = 9)
  and qr.position_x > -1000 and qr.position_x < 2000
  and qr.position_y > -5500 and qr.position_y < -1000
  AND (
        (qr.source = 'accept' AND qt.Details IS NOT NULL AND qt.Details != '')
        OR (qr.source = 'progress' AND qt.RequestItemsText IS NOT NULL AND qt.RequestItemsText != '')
        OR (qr.source = 'complete' AND qt.OfferRewardText IS NOT NULL AND qt.OfferRewardText != '')
    );
    '''

    quest_df = pd.read_sql_query(sql_query, db)
    db.close()

    return quest_df
