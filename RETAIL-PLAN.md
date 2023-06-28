## WoW Voiceover Porting Plan

### Overview

The primary goal of this plan is to port the World of Warcraft addon, WoW Voiceover, from Classic WoW Vanilla to Retail WoW. The plan involves two main components:

1. Crowdsourcing voice models for each race in World of Warcraft
2. Collecting quest/gossip text data to provide the necessary information for both voice generation and correct integration into the addon

### Part 1: Crowdsourcing Voice Models (ALREADY IN PROGRESS)

Develop a user-friendly website to facilitate the crowdsourcing of voice models for all races in World of Warcraft. The website should include the following features:

- User registration and authentication to enable contributors to sign up and submit voice samples
- Clear instructions and guidelines on how to provide high-quality voice samples, including preferred recording setup, script examples, and ideal pronunciation
- A submission system for users to upload their voice samples, including categorization by race, gender, and any other relevant attributes
- An upvoting or rating system for users to evaluate the quality of submitted voice samples and provide feedback to contributors
- A progress tracker to monitor the development of voice models for each race and gender, encouraging users to contribute to underrepresented categories

### Part 2: Collecting Quest/Gossip Text Data (LOOKING FOR HELP)

#### New Feature in WoW Voiceover Addon

- Add a new feature to the WoW Voiceover addon that enables users to opt-in to collect quest/gossip text data during gameplay
- Create a lightweight companion executable that runs in the background during gameplay to upload the scraped text data to a central server. This companion executable may need the ability to add information from WoW's cache files.

#### API and Database Development

- Develop a robust API and database to store and manage the collected text data
- The API should provide endpoints for data retrieval, updates, and submission of new data from the companion executable
- Seed the database with initial data from WoWhead and other sources, and continually update it with scraped data from users' gameplay

### Data We Need To Collect

| Column        | Description                                                         | Source                 |
| ------------- | ------------------------------------------------------------------- | ---------------------- |
| source        | Type of interaction ('accept', 'progress', 'complete', or 'gossip') | addon                  |
| quest         | Quest ID or empty string if it's a gossip interaction               | addon                  |
| text          | Text content of the interaction                                     | addon                  |
| npc_race      | Race of the NPC involved in the interaction                         | see below              |
| npc_sex       | Gender of the NPC involved in the interaction                       | see below              |
| npc_name      | Name of the NPC involved in the interaction                         | addon                  |
| npc_type      | Type of the NPC involved ('creature', 'gameobject', or 'item')      | addon (probably)       |
| npc_id        | Creature/gameobject/item ID of the NPC involved in the interaction  | addon                  |
| player_race   | Race of the player involved in the interaction                      | addon                  |
| player_gender | Gender of the player involved in the interaction                    | addon                  |
| player_name   | Name of the player involved in the interaction                      | addon                  |
| player_class  | Class of the player involved in the interaction                     | addon                  |
| language      | Language of the text collected                                      | addon                  |
| expansion     | Expansion text was added to the game. Is optional.                  | wowhead for quest text |

#### NPC Race and Sex Matching

Race and Sex will probably not be possible to collect directly from the game addon for recent/current expansions. UnitRace("target") appears to only work on playable characters. UnitSex("target") works on most targets, but most creatures don't have an assigned sex, only ones that are modeled off playable races.

Potential Guessing Methods:

- Utilize projects like [wow-listfile](https://github.com/wowdev/wow-listfile) to regain filenames for each NPC, as model and sound names are not available in newer expansions, they've been replaced by IDs
- Implement a matching algorithm or use an LLM (e.g., GPT-4) to make educated guesses of race and sex based on available information, such as filenames or sound names
- Continuously refine and improve the race and sex matching algorithm as more data is collected and analyzed

#### Converting uploaded text to template text

The API should be capable of handling variations in the text based on gender, name, class, and race differences. To achieve this, the API collects those pieces of information and post processes the uploaded text. Name should be easy to do a simple substitution along with race. Gender typically has completely different dialog. Through a combination of substitution then diffing user's submissions for the same piece of content, we should be able to make a good estimate as to what the template text is. The most up to date guess on the template text should be stored in the DB.

#### Notes on using client cache

Anything that touches the WoW client cache requires a lot of extra complexity. We can start out with the guessing approaches and add these as refinements later. We may need to observe cache to find the model and sound ID's for a given NPC which would mean cache parsing is needed in the first version.

#### Optimizations for playable race models

Obtaining both race and sex for playable race models (i.e. if the creature is using the same model as players do when creating a character of that race) is trivial using out-of-game tools (creature cache -> displayid -> CreatureDisplayInfo.db2 -> CreatureDisplayInfoExtra.db2), but for non-playable models that info is unavailable and it will have to be guesswork.

#### Other potential text from cache

We can obtain the exact original texts for quest's accept text from quest cache, but not for the progress and complete/reward texts.

We can also obtain the exact original texts for gossip from npccache.wdb cache (which reference BroadcastText.db2, which is bruteforceable, but I don't know how), but without explicit links to which npc does that text belong to. So connecting those texts to gossips scraped by the addon will still involve guesswork.
