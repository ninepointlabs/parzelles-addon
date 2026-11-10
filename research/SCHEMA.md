# research/data.json schema (Parzelle's Addon, Mage)

Same shape as Andric's Addon (`/home/tim/Projects/wow-forever-priest-addon/research/data.json`, read it for examples) with Mage additions.
**Every record** (list item or dict) carries `source_url` (the page the fact came from) and `checked` (`"2026-11-10"`, or the date of the source record you copy).
Never invent spell IDs, item IDs, quest IDs, NPC IDs, stats or costs: use only what a raw page (or a page you fetched and archived in `research/raw/`) states. Unknown → omit the field (or `null`) and add a `gaps[]` entry. Conflicts → add a `conflicts[]` entry.

`tools/build_data.py` turns this into `Data/*.lua`. Spell names must be the exact English in-game names (e.g. `Frostbolt`, `Arcane Missiles`, `Teleport: Stormwind`, `Portal: Darnassus`, `Conjure Water`).

## Core part (`research/parts/core.json`)
- `meta`: copy the Priest `meta` (game, client_version, latest_build_seen, launch_build, toc_interface 16001, wow_project_id, toc_suffixes, api_note, max_level 60, …), plus `class: "Mage"`, `checked`.
- `sources`: `{ short_key: url }` for every page used (deep dive, launch notes, Icy Veins pages, Wowhead pages, foreverguide…).
- `spells_by_level`: `[{ name, wowhead_base_spell_id, rank_learn_levels: [1, 8, …], rank_spell_ids?: [...] (only if sourced, same length), school: "Arcane"|"Fire"|"Frost"|null, category: "damage"|"aoe"|"cc"|"defense"|"buff"|"conjure"|"teleport"|"portal"|"utility"|"mana", faction?: "Alliance"|"Horde" (teleports/portals only), talent_tree?: "Arcane"|"Fire"|"Frost" (talent-taught spells whose later ranks are trained: name them `"<Name> (talent)"`, e.g. `"Pyroblast (talent)"`), notes?, id_source?, source_url, checked }]`. Every Mage trainer spell 1–60 for Forever, including Frostfire Bolt (40), all Teleports (20/30) and Portals (40) for **both** factions (with `faction`), Teleport: Dalaran only if its faction/level is sourced (else gap), conjure spells (water/food/mana gem; record the exact Forever spell names and learn levels), Arcane Intellect, Arcane Brilliance (book? flag), Frost/Ice Armor, Mage Armor, Dampen/Amplify Magic, Polymorph, Counterspell, Blink, Evocation, Slow Fall, Remove Lesser Curse, Detect Magic, Fire Ward, Frost Ward, Mana Shield, Cone of Cold, Frost Nova, Blizzard, Flamestrike, Arcane Explosion, Fire Blast, Scorch, Fireball, Frostbolt, Arcane Missiles, Arcane Blast (if trained), etc. Use the Icy Veins leveling spell tables as the primary source for levels; IDs from Wowhead/Icy Veins links in the raw HTML. Watch the TBC data warning in NOTES.md.
- `talent_and_other_spell_ids`: `[{ name, spell_id, tree?, source_url, checked }]` for talent spells and procs/buffs the rotation needs (Missile Barrage, Fingers of Frost, Heating Up, Arcane Blast debuff/buff, Ice Barrier, Ice Lance, Arcane Wrath, Presence of Mind, Arcane Power, Combustion, Cold Snap, Ice Block, Blast Wave, Pyroblast, Clearcasting/Arcane Concentration, Mana Gem/Mana Gems spell 1318827, …). Use names exactly as the buff appears in game where sources say so.
- `teleports_portals`: `[{ name, spell_id, kind: "teleport"|"portal", faction, level, city, reagent?: "Rune of Teleportation"|"Rune of Portals"|null, reagent_status: "confirmed"|"classic-only"|"unknown", source_url, checked }]`.
- `milestones`: `{ items: [{level, what}], talent_milestones: "11/16/21/31 points (gold medal)", trainer_costs: "...", source_url, checked }`.
- `talent_changes`: `[{ tree: "Arcane"|"Fire"|"Frost"|"Baseline", change, source_url, checked }]` (deep dive + Nov 2 launch values; say which).
- `builds`: `[{ spec: "Arcane"|"Fire"|"Frost"|"Alt route", purpose: "Leveling"|"Dungeon"|"Raid"|"PvP"|…, talent_calc_url, notes?, source_url, checked }]`, every build link on the Icy Veins spec-builds-talents and leveling pages (and Wowhead if any). Keep the URL exactly as published.
- `rotations`: `{ arcane: "...", fire: "...", frost: "...", frostfire: "...", mana: "<five-second rule / Spirit regen text, as sourced>", source_url, checked }` (short sourced summaries).
- `stat_priority`: `[{ spec: "Arcane"|"Fire"|"Frost"|"Leveling", priority: "A > B > C", source_url, checked }]`. Tokens must be from: `Hit`, `Crit`, `Spell power` / `Spell damage`, `Fire damage`, `Frost damage`, `Arcane damage`, `Intellect`, `Spirit`, `Stamina`, `MP5` (parentheses allowed for notes, e.g. `Hit (to 16% cap)`). Add `{spec: "Conversions", priority: "1 Int = N mana; N Int = 1% spell crit"}` only if a source states Mage numbers (else gap).
- `quests`: `[{ type: "class"|"breadcrumb"|"reagent", level, races: "Skyborne"|"All"|"Human/Gnome"…, faction: "Alliance"|"Horde"|"Both", name, quest_id?, zone?, start_npc?, reward?, reward_item_id?, notes?, source_url, checked }]`: Skyborne lvl 10 "Boughs in the Wind" + "Speak with Belann" breadcrumb, Alliance 15 Manaweave Robe, 26 Astral Knot Robe/Blouse, 30 wand chain, 35 Celestial Power, 50 Destroy Morphaz, 60 Fragmented Magic (and Horde equivalents marked Horde). Quest IDs only from raw pages / db.icy-veins pages you fetch.
- `class_trainers`: `{ trainers: ["Name (City/Zone)", ...], valanaar_note, source_url, checked }`.
- `racials`: `[{ race: "Skyborne"|…, faction, spell, spell_id?, effect, source_url, checked }]` (Skyborne racials at least; other Alliance mage races optional).
- `race_notes`: `{ text, source_url, checked }` (High Order Skyborne Alliance-only Mage etc.).
- `mana_gems`: `{ spell_name, learn_levels, item_names?: [...], item_ids?: [...], notes, source_url, checked }` with whatever is sourced; conflicts recorded.
- `changes_log`: `[{ date, change, source_url, checked }]` Mage-relevant dated changes (deep dive Oct 7, launch notes Nov 2, hotfixes).
- `conflicts`: `[{ topic, detail, source_url, checked }]` (e.g. Arcane Blast 8 s vs 18 s, Mana Gem names, portal reagents, Cone of Cold duration).
- `gaps`: `[{ gap, source_url, checked }]`.

## Gear/world part (`research/parts/gear.json`)
- `gear_by_bracket`: `[{ bracket: "level 20"|"level 30"|…|"level 60 pre-raid", spec?: "Arcane"|"Fire"|"Frost"|null, name, item_id, slot?, source: "<dungeon/quest/crafted label as the page says>", source_url, checked }]` (Icy Veins BiS + Wowhead bis-gear + leveling gear tables).
- `wands`: `[{ name, item_id, dps?, required_level?, source, source_url, checked }]`.
- `other_weapons`: `{ note, source_url, checked }`.
- `bis`: `{ status, tier1_datamined_placeholder?: {...}, flag, source_url, checked }`.
- `consumables_enchants`: `[{ type: "consumable"|"enchant"|"camp"|"note", bracket?, name, item_id?, spell_id?, slot?, profession?, notes?, source_url, checked }]`.
- `reagents`: `[{ name, item_id?, used_by, vendor_note?, status: "confirmed"|"classic-only"|"unknown", source_url, checked }]` (Rune of Teleportation, Rune of Portals, Arcane Powder, Light Feather…: only what a Forever source confirms is "confirmed").
- `conjured`: `[{ kind: "water"|"food"|"gem", name, item_id?, level?, spell?, source_url, checked }]` (only sourced rows).
- `professions`: `{ leveling, raiding, alternatives: [...], comprehension: "<Comprehension / Comprehend Scroll text>", source_url, checked }`.
- `riding`, `mounts`, `zones_by_level`, `new_zones`, `dungeons`, `raids`, `raid_rules`, `roadmap`, `addons`, `addon_dev`: copy from the Priest data.json (race-independent facts keep the original source_url/checked). Add a `mounts` row for Skyborne only if sourced (else a gap). Zephras Isle zones for Skyborne (Thendal Village, Shen'dar Village, Valanaar) if sourced.
- `change_sources`: copy the Priest list (feeds are game-wide) and add Mage pages worth watching.
- `gaps`, `conflicts`: as above, for gear/world.
