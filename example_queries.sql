--- Quests
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
  and (cdie.DisplayRaceID = 2 or cdie.DisplayRaceID = 8)
  and qr.position_x > -1000 and qr.position_x < 2000
  and qr.position_y > -5500 and qr.position_y < -2000
  AND (
        (qr.source = 'accept' AND qt.Details IS NOT NULL AND qt.Details != '')
        OR (qr.source = 'progress' AND qt.RequestItemsText IS NOT NULL AND qt.RequestItemsText != '')
        OR (qr.source = 'complete' AND qt.OfferRewardText IS NOT NULL AND qt.OfferRewardText != '')
    );

--- gossip
select distinct
        cdie.DisplayRaceID,
       cdie.DisplaySexID,
       creature.id,
       ct.name,
       IF(cdie.DisplaySexID = 0, bt.male_text, bt.female_text) AS text
from creature
         join creature_template ct on creature.id = ct.entry
         join gossip_menu gm on ct.gossip_menu_id = gm.entry
         join npc_text nt on gm.text_id = nt.ID
         join broadcast_text bt on nt.BroadcastTextID0 = bt.entry
         JOIN db_CreatureDisplayInfo cdi ON ct.display_id1 = cdi.ID
         JOIN db_CreatureDisplayInfoExtra cdie ON cdi.ExtendedDisplayInfoID = cdie.ID
where
    creature.map = 1
  and (cdie.DisplayRaceID = 2 or cdie.DisplayRaceID = 8)
  and creature.position_x > -1000 and creature.position_x < 2000
  and creature.position_y > -5500 and creature.position_y < -2000
   AND (
        (cdie.DisplaySexID = 0 AND bt.male_text IS NOT NULL AND bt.male_text != '')
        OR (cdie.DisplaySexID = 1 AND bt.female_text IS NOT NULL AND bt.female_text != '')
    );

--- get number of characters in quest text
WITH quest_relations AS (
    SELECT 'accept' as source, qr.quest, creature.id as creature_id, creature.position_x, creature.position_y, creature.map
    FROM creature
    JOIN creature_questrelation qr ON qr.id = creature.id
        UNION ALL
    SELECT 'complete' as source, qr.quest, creature.id as creature_id, creature.position_x, creature.position_y, creature.map
    FROM creature
    JOIN creature_involvedrelation qr ON qr.id = creature.id
)
SELECT
    sum(CHAR_LENGTH(text)) as total_characters
FROM
    (
        SELECT
            distinct

            CASE
                WHEN qr.source = 'accept' THEN qt.Details
                WHEN qr.source = 'progress' THEN qt.RequestItemsText
                ELSE qt.OfferRewardText
            END as "text"

        FROM
            quest_relations qr
        JOIN quest_template qt ON qr.quest = qt.entry
        JOIN creature_template ct ON qr.creature_id = ct.entry
        JOIN db_CreatureDisplayInfo cdi ON ct.display_id1 = cdi.ID
        JOIN db_CreatureDisplayInfoExtra cdie ON cdi.ExtendedDisplayInfoID = cdie.ID
        where
        (
                (qr.source = 'accept' AND qt.Details IS NOT NULL AND qt.Details != '')
                OR (qr.source = 'progress' AND qt.RequestItemsText IS NOT NULL AND qt.RequestItemsText != '')
                OR (qr.source = 'complete' AND qt.OfferRewardText IS NOT NULL AND qt.OfferRewardText != '')
        )
    ) as subquery;

--- get number of characters in gossip text