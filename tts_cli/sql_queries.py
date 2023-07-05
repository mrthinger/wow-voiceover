import pymysql
import pandas as pd
from tts_cli.env_vars import MYSQL_HOST, MYSQL_PORT, MYSQL_PASSWORD, MYSQL_USER, MYSQL_DATABASE


def make_connection():
    return pymysql.connect(
        host=MYSQL_HOST,
        port=MYSQL_PORT,
        user=MYSQL_USER,
        password=MYSQL_PASSWORD,
        database=MYSQL_DATABASE
    )


def query_dataframe_for_area(x_range, y_range, map_id):
    db = make_connection()
    sql_query = '''
WITH RECURSIVE
filtered_creatures AS (
    SELECT *
    FROM creature
    WHERE
        map = %s
        AND position_x >= %s AND position_x <= %s
        AND position_y >= %s AND position_y <= %s
),
quest_relations AS (
    SELECT 'accept' as source, qr.quest, fc.id as creature_id, fc.position_x, fc.position_y, fc.map
    FROM filtered_creatures fc
    JOIN creature_questrelation qr ON qr.id = fc.id
        UNION ALL
    SELECT 'complete' as source, qr.quest, fc.id as creature_id, fc.position_x, fc.position_y, fc.map
    FROM filtered_creatures fc
    JOIN creature_involvedrelation qr ON qr.id = fc.id
        UNION ALL
    SELECT 'progress' as source, qr.quest, fc.id as creature_id, fc.position_x, fc.position_y, fc.map
    FROM filtered_creatures fc
    JOIN creature_involvedrelation qr ON qr.id = fc.id
),
collected_gossip_menus (base_menu_id, menu_id, text_id, action_menu_id) AS (
    WITH gossip_menu_and_options AS (
        SELECT gm.entry, gm.text_id, NULL as action_menu_id
            FROM gossip_menu gm
        UNION DISTINCT
        SELECT gm.entry, gm.text_id, gmo.action_menu_id
            FROM gossip_menu gm
            LEFT JOIN gossip_menu_option gmo on gmo.menu_id = gm.entry
    )
    SELECT gm.entry as base_menu_id, gm.entry, gm.text_id, gm.action_menu_id
        FROM gossip_menu_and_options gm
    UNION DISTINCT
    SELECT cgm.base_menu_id, gm.entry, gm.text_id, gm.action_menu_id
        FROM gossip_menu_and_options gm
        INNER JOIN collected_gossip_menus cgm ON cgm.action_menu_id = gm.entry
),
creature_data AS (
    SELECT
        filtered_creatures.id,
        ct.name,
        cgm.text_id,
        cdie.DisplaySexID,
        cdie.DisplayRaceID
    FROM filtered_creatures
        JOIN creature_template ct ON filtered_creatures.id = ct.entry
        JOIN db_CreatureDisplayInfo cdi ON ct.display_id1 = cdi.ID
        JOIN db_CreatureDisplayInfoExtra cdie ON cdi.ExtendedDisplayInfoID = cdie.ID
        LEFT JOIN collected_gossip_menus cgm ON cgm.base_menu_id = ct.gossip_menu_id
),
numbers AS (
    SELECT 0 AS n
    UNION ALL SELECT 1
    UNION ALL SELECT 2
    UNION ALL SELECT 3
    UNION ALL SELECT 4
    UNION ALL SELECT 5
    UNION ALL SELECT 6
    UNION ALL SELECT 7
)
SELECT
    distinct
    qr.source,
    qr.quest,
    qt.Title as quest_title,
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
WHERE
    (
        (qr.source = 'accept' AND qt.Details IS NOT NULL AND qt.Details != '')
        OR (qr.source = 'progress' AND qt.RequestItemsText IS NOT NULL AND qt.RequestItemsText != '')
        OR (qr.source = 'complete' AND qt.OfferRewardText IS NOT NULL AND qt.OfferRewardText != '')
    )

UNION ALL

SELECT
    distinct
    'gossip' as source,
    '' as quest,
    '' as quest_title,
    IF(creature_data.DisplaySexID = 0, bt.male_text, bt.female_text) AS text,
    creature_data.DisplayRaceID,
    creature_data.DisplaySexID,
    creature_data.name,
    creature_data.id
FROM creature_data
    CROSS JOIN numbers
    JOIN npc_text nt ON nt.ID = creature_data.text_id
    JOIN broadcast_text bt ON
        CASE numbers.n
            WHEN 0 THEN nt.BroadcastTextID0
            WHEN 1 THEN nt.BroadcastTextID1
            WHEN 2 THEN nt.BroadcastTextID2
            WHEN 3 THEN nt.BroadcastTextID3
            WHEN 4 THEN nt.BroadcastTextID4
            WHEN 5 THEN nt.BroadcastTextID5
            WHEN 6 THEN nt.BroadcastTextID6
            WHEN 7 THEN nt.BroadcastTextID7
        END = bt.entry
WHERE
    (DisplaySexID = 0 AND bt.male_text IS NOT NULL AND bt.male_text != '')
    OR (DisplaySexID = 1 AND bt.female_text IS NOT NULL AND bt.female_text != '')
;
    '''

    with db.cursor() as cursor:
        cursor.execute(
            sql_query, (map_id, x_range[0], x_range[1], y_range[0], y_range[1]))
        data = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]

    db.close()
    df = pd.DataFrame(data, columns=columns)

    return df


def query_dataframe_for_all_quests_and_gossip(lang: int = 0):
    db = make_connection()
    sql_query = '''
WITH RECURSIVE
creature_quest_relations AS (
    SELECT 'accept' as source, qr.quest, ct.entry as creature_id
    FROM creature_template ct
    JOIN creature_questrelation qr ON qr.id = ct.entry
        UNION ALL
    SELECT 'complete' as source, qr.quest, ct.entry as creature_id
    FROM creature_template ct
    JOIN creature_involvedrelation qr ON qr.id = ct.entry
        UNION ALL
    SELECT 'progress' as source, qr.quest, ct.entry as creature_id
    FROM creature_template ct
    JOIN creature_involvedrelation qr ON qr.id = ct.entry
),
gameobject_quest_relations AS (
    SELECT 'accept' as source, qr.quest, gt.entry as gameobject_id
    FROM gameobject_template gt
    JOIN gameobject_questrelation qr ON qr.id = gt.entry
        UNION ALL
    SELECT 'complete' as source, qr.quest, gt.entry as gameobject_id
    FROM gameobject_template gt
    JOIN gameobject_involvedrelation qr ON qr.id = gt.entry
        UNION ALL
    SELECT 'progress' as source, qr.quest, gt.entry as gameobject_id
    FROM gameobject_template gt
    JOIN gameobject_involvedrelation qr ON qr.id = gt.entry
),
item_quest_relations AS (
    SELECT 'accept' as source, it.start_quest as quest, it.entry as item_id
    FROM item_template it
    WHERE it.start_quest
),
collected_gossip_menus (base_menu_id, menu_id, text_id, action_menu_id) AS (
    WITH gossip_menu_and_options AS (
        SELECT gm.entry, gm.text_id, NULL as action_menu_id
            FROM gossip_menu gm
        UNION DISTINCT
        SELECT gm.entry, gm.text_id, gmo.action_menu_id
            FROM gossip_menu gm
            LEFT JOIN gossip_menu_option gmo on gmo.menu_id = gm.entry
    )
    SELECT gm.entry as base_menu_id, gm.entry, gm.text_id, gm.action_menu_id
        FROM gossip_menu_and_options gm
    UNION DISTINCT
    SELECT cgm.base_menu_id, gm.entry, gm.text_id, gm.action_menu_id
        FROM gossip_menu_and_options gm
        INNER JOIN collected_gossip_menus cgm ON cgm.action_menu_id = gm.entry
),
creature_data AS (
    SELECT
        ct.entry as id,
        ct.name,
        cgm.text_id,
        cdie.DisplaySexID,
        cdie.DisplayRaceID
    FROM creature_template ct
        JOIN db_CreatureDisplayInfo cdi ON ct.display_id1 = cdi.ID
        JOIN db_CreatureDisplayInfoExtra cdie ON cdi.ExtendedDisplayInfoID = cdie.ID
        LEFT JOIN collected_gossip_menus cgm ON cgm.base_menu_id = ct.gossip_menu_id
),
gameobject_data AS (
    SELECT
        gt.entry as id,
        gt.name,
        cgm.text_id
    FROM gameobject_template gt
        LEFT JOIN collected_gossip_menus cgm ON cgm.base_menu_id =
            CASE gt.type
                WHEN 2  THEN data3  -- GAMEOBJECT_TYPE_QUESTGIVER (type 2) has property "gossipID" in data3 field
                WHEN 8  THEN data10 -- GAMEOBJECT_TYPE_SPELL_FOCUS (type 8) has property "gossipID" in data10 field
                WHEN 10 THEN data19 -- GAMEOBJECT_TYPE_GOOBER (type 10) has property "gossipID" in data19 field
            END
    WHERE gt.type IN (2, 10)
),
numbers AS (
    SELECT 0 AS n
    UNION ALL SELECT 1
    UNION ALL SELECT 2
    UNION ALL SELECT 3
    UNION ALL SELECT 4
    UNION ALL SELECT 5
    UNION ALL SELECT 6
    UNION ALL SELECT 7
),
ALL_DATA AS (

-- Creature QuestGivers

SELECT
    distinct
    qr.source,
    qr.quest,
    qt.Title as quest_title,
    CASE
        WHEN qr.source = 'accept' THEN qt.Details
        WHEN qr.source = 'progress' THEN qt.RequestItemsText
        ELSE qt.OfferRewardText
    END as "text",
    0 as broadcast_text_id,
    cdie.DisplayRaceID,
    cdie.DisplaySexID,
    ct.name,
    'creature' as type,
    qr.creature_id as id
FROM
    creature_quest_relations qr
JOIN quest_template qt ON qr.quest = qt.entry
JOIN creature_template ct ON qr.creature_id = ct.entry
JOIN db_CreatureDisplayInfo cdi ON ct.display_id1 = cdi.ID
JOIN db_CreatureDisplayInfoExtra cdie ON cdi.ExtendedDisplayInfoID = cdie.ID
WHERE
    (
        (qr.source = 'accept' AND qt.Details IS NOT NULL AND qt.Details != '')
        OR (qr.source = 'progress' AND qt.RequestItemsText IS NOT NULL AND qt.RequestItemsText != '')
        OR (qr.source = 'complete' AND qt.OfferRewardText IS NOT NULL AND qt.OfferRewardText != '')
    )

-- GameObject QuestGivers

UNION ALL
SELECT
    distinct
    qr.source,
    qr.quest,
    qt.Title as quest_title,
    CASE
        WHEN qr.source = 'accept' THEN qt.Details
        WHEN qr.source = 'progress' THEN qt.RequestItemsText
        ELSE qt.OfferRewardText
    END as "text",
    0 as broadcast_text_id,
    -1 as DisplayRaceID,
    0 as DisplaySexID,
    gt.name,
    'gameobject' as type,
    qr.gameobject_id as id
FROM
    gameobject_quest_relations qr
JOIN quest_template qt ON qr.quest = qt.entry
JOIN gameobject_template gt ON qr.gameobject_id = gt.entry
WHERE
    (
        (qr.source = 'accept' AND qt.Details IS NOT NULL AND qt.Details != '')
        OR (qr.source = 'progress' AND qt.RequestItemsText IS NOT NULL AND qt.RequestItemsText != '')
        OR (qr.source = 'complete' AND qt.OfferRewardText IS NOT NULL AND qt.OfferRewardText != '')
    )

-- Item QuestGivers

UNION ALL
SELECT
    distinct
    qr.source,
    qr.quest,
    qt.Title as quest_title,
    qt.Details as "text",
    0 as broadcast_text_id,
    -1 as DisplayRaceID,
    0 as DisplaySexID,
    it.name,
    'item' as type,
    qr.item_id as id
FROM
    item_quest_relations qr
JOIN quest_template qt ON qr.quest = qt.entry
JOIN item_template it ON qr.item_id = it.entry
WHERE
    (
        (qr.source = 'accept' AND qt.Details IS NOT NULL AND qt.Details != '')
    )

-- Creature Gossip

UNION ALL
SELECT
    distinct
    'gossip' as source,
    '' as quest,
    '' as quest_title,
    IF(creature_data.DisplaySexID = 0, bt.male_text, bt.female_text) AS text,
    bt.entry as broadcast_text_id,
    creature_data.DisplayRaceID,
    creature_data.DisplaySexID,
    creature_data.name,
    'creature' as type,
    creature_data.id
FROM creature_data
    CROSS JOIN numbers
    JOIN npc_text nt ON nt.ID = creature_data.text_id
    JOIN broadcast_text bt ON
        CASE numbers.n
            WHEN 0 THEN nt.BroadcastTextID0
            WHEN 1 THEN nt.BroadcastTextID1
            WHEN 2 THEN nt.BroadcastTextID2
            WHEN 3 THEN nt.BroadcastTextID3
            WHEN 4 THEN nt.BroadcastTextID4
            WHEN 5 THEN nt.BroadcastTextID5
            WHEN 6 THEN nt.BroadcastTextID6
            WHEN 7 THEN nt.BroadcastTextID7
        END = bt.entry
WHERE
    (DisplaySexID = 0 AND bt.male_text IS NOT NULL AND bt.male_text != '')
    OR (DisplaySexID = 1 AND bt.female_text IS NOT NULL AND bt.female_text != '')

-- GameObject Gossip

UNION ALL
SELECT
    distinct
    'gossip' as source,
    '' as quest,
    '' as quest_title,
    IF(bt.male_text IS NOT NULL AND bt.male_text != '', bt.male_text, bt.female_text) AS text,
    bt.entry as broadcast_text_id,
    -1 as DisplayRaceID,
    0 as DisplaySexID,
    gameobject_data.name,
    'gameobject' as type,
    gameobject_data.id
FROM gameobject_data
    CROSS JOIN numbers
    JOIN npc_text nt ON nt.ID = gameobject_data.text_id
    JOIN broadcast_text bt ON
        CASE numbers.n
            WHEN 0 THEN nt.BroadcastTextID0
            WHEN 1 THEN nt.BroadcastTextID1
            WHEN 2 THEN nt.BroadcastTextID2
            WHEN 3 THEN nt.BroadcastTextID3
            WHEN 4 THEN nt.BroadcastTextID4
            WHEN 5 THEN nt.BroadcastTextID5
            WHEN 6 THEN nt.BroadcastTextID6
            WHEN 7 THEN nt.BroadcastTextID7
        END = bt.entry
WHERE
    bt.male_text IS NOT NULL AND bt.male_text != '' OR
    bt.female_text IS NOT NULL AND bt.female_text != ''

-- Creature QuestGreetings

UNION ALL
SELECT
    distinct
    'gossip' as source,
    '' as quest,
    '' as quest_title,
    qg.content_default AS text,
    0 as broadcast_text_id,
    creature_data.DisplayRaceID,
    creature_data.DisplaySexID,
    creature_data.name,
    'creature' as type,
    creature_data.id
FROM creature_data
    JOIN quest_greeting qg ON qg.entry=creature_data.id AND type=0

-- GameObject QuestGreetings

UNION ALL
SELECT
    distinct
    'gossip' as source,
    '' as quest,
    '' as quest_title,
    qg.content_default AS text,
    0 as broadcast_text_id,
    -1 AS DisplayRaceID,
    0 AS DisplaySexID,
    gameobject_data.name,
    'gameobject' as type,
    gameobject_data.id
FROM gameobject_data
    JOIN quest_greeting qg ON qg.entry=gameobject_data.id AND type=1

)
    '''

    if lang == 0:
        sql_query += '''
SELECT
    source,
    quest,
    quest_title,
    text,
    DisplayRaceID,
    DisplaySexID,
    name,
    type,
    id,
    text as original_text
FROM ALL_DATA
        '''
    else:
        sql_query += f'''
SELECT
    source,
    quest,
    IFNULL(NULLIF(lq.title_loc{lang}, ''), quest_title) as quest_title,
    IFNULL(NULLIF(CASE source
        WHEN 'gossip' THEN (CASE
            WHEN broadcast_text_id = 0 THEN qg.content_loc{lang}
            WHEN ALL_DATA.type = 'creature' THEN IF(DisplaySexID = 0, lbt.male_text_loc{lang}, lbt.female_text_loc{lang})
            ELSE IFNULL(NULLIF(lbt.male_text_loc{lang}, ''), lbt.female_text_loc{lang})
        END)
        WHEN 'accept'   THEN lq.Details_loc{lang}
        WHEN 'progress' THEN lq.RequestItemsText_loc{lang}
        WHEN 'complete' THEN lq.OfferRewardText_loc{lang}
        ELSE NULL
    END, ''), text) as text,
    DisplayRaceID,
    DisplaySexID,
    IFNULL(NULLIF(CASE ALL_DATA.type
        WHEN 'creature'   THEN lc.name_loc{lang}
        WHEN 'gameobject' THEN lg.name_loc{lang}
        WHEN 'item'       THEN li.name_loc{lang}
        ELSE NULL
    END, ''), name) as name,
    ALL_DATA.type,
    id,
    text as original_text
FROM ALL_DATA
    LEFT JOIN mangos.locales_quest          lq  ON lq .entry = quest
    LEFT JOIN mangos.locales_broadcast_text lbt ON lbt.entry = broadcast_text_id
    LEFT JOIN mangos.locales_creature       lc  ON lc .entry = id AND type = 'creature'
    LEFT JOIN mangos.locales_gameobject     lg  ON lg .entry = id AND type = 'gameobject'
    LEFT JOIN mangos.locales_item           li  ON li .entry = id AND type = 'item'
    LEFT JOIN mangos.quest_greeting         qg  ON qg .entry = id AND qg.type = (CASE ALL_DATA.type WHEN 'creature' THEN 0 WHEN 'gameobject' THEN 1 ELSE -1 END)
        '''

    with db.cursor() as cursor:
        cursor.execute(sql_query)
        data = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]

    db.close()
    df = pd.DataFrame(data, columns=columns)

    return df
