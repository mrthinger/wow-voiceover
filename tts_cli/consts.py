# https://wowpedia.fandom.com/wiki/RaceId
RACE_DICT = {
    -1: 'narrator',
    1: 'human',
    2: 'orc',
    3: 'dwarf',
    4: 'nightelf',
    5: 'scourge',
    6: 'tauren',
    7: 'gnome',
    8: 'troll',
    9: 'goblin',
    10: 'bloodelf',
    11: 'draenei',
    12: 'felorc',
    13: 'naga',
    14: 'broken',
    15: 'skeleton',
    16: 'vrykul',
    17: 'tuskarr',
    18: 'foresttroll',
    19: 'taunka',
    20: 'northrendskeleton',
    21: 'icetroll',
    22: 'worgen',
    23: 'human',
    24: 'pandaren',
    25: 'pandaren',
    26: 'pandaren',
    27: 'nightborne',
    28: 'highmountaintauren',
    29: 'voidelf',
    30: 'lightforgeddraenei',
    31: 'zandalari',
    32: 'kultiran',
    33: 'thinhuman',
    34: 'darkirondwarf',
    35: 'vulpera',
    36: 'magharorc',
    37: 'mechagnome',
    52: 'dracthyr',
    70: 'dracthyr'
}




GENDER_DICT = {0: 'male', 1: 'female'}

RACE_DICT_INV = {v: k for k, v in RACE_DICT.items()}
GENDER_DICT_INV = {v: k for k, v in GENDER_DICT.items()}

def race_gender_tuple_to_strings(race_gender_tuple):
    race_gender_strings = []
    
    for race_id, gender_id in race_gender_tuple:
        race = RACE_DICT.get(race_id, 'unknown')
        gender = GENDER_DICT.get(gender_id, 'unknown')
        race_gender_strings.append(f"{race}-{gender}")
    
    return race_gender_strings