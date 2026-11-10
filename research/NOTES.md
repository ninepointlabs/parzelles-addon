# WoW Forever Mage – research notes (checked 2026-11-10, America/Chicago)

Raw copies of every page are in `raw/` (HTML + extracted .md). These notes are a starting summary, NOT a finished data.json:
Claude should build `research/data.json` (same shape as the priest research: meta, spells, quests, builds, gear brackets,
consumables, reagents, riding, gaps, change_sources), each fact with `source_url` + `checked`, from these raw pages.

## Client baseline (same as Andric's Addon)
- Forever 1.60.1.70862, TOC Interface 16001, WOW_PROJECT_ID 18 (WOW_PROJECT_CAMELOT), `_Forever.toc`. Re-check with `omaforge clients` before tagging.
- Talents from level 10; gold-medal talents at 11/16/21/31 points; respec at a class trainer in a major city; **Dual Specialization at 40** (foreverguide.net).
- Training costs evened out across classes (~206–207g for all ranks 1–60) (foreverguide.net, unofficial summary of Blizzard notes).

## Race note for Parzelle
- Skyborne is a neutral race in Forever; Alliance version = **High Order Skyborne**, Horde = Windshaper Skyborne. **Mage is Alliance-only (High Order)** (Icy Veins /skyborne, foreverguide.net).
- Starting zone Zephras Isle. Skyborne Mage class quest: **Level 10 "Boughs in the Wind"**, breadcrumb "Speak with Belann" from the Mage trainer in **Valanaar**, Zephras Isle; item at 48.5, 68.2; rewards a wand ("definitely worth doing") (Icy Veins /mage-class-quests). Get quest IDs from the raw page / db.icy-veins.
- Skyborne racials: see raw `www_icy_veins_com_wow_forever_skyborne.md`.

## Baseline Mage changes (Blizzard deep dive Oct 7 + Nov 2 launch notes)
- **Frostfire Bolt** (new, level 40): 3 s cast, Fire AND Frost; uses higher of Fire/Frost spell damage and the lower target resistance; DoT + slow.
- **Comprehension** (new Mage-only minor tradeskill) + **Comprehend Scroll** (General tab): read scrolls dropped in the world for buffs/items.
- Cone of Cold duration reduced; Mage Armor Spirit regen increased; Magic Attunement baseline.
- Low-rank penalty: proc talents (Arcane Concentration, Impact, etc.) trigger less from much-lower-rank spells → downranking advice must account for this.
- **Mana Gems** appear as a Forever spell (db.icy-veins spells/1318827); Conjure Mana Gem learned at 28/38/48/58 (Icy Veins frost leveling table). Sportskeeda mentions "Conjured Mana Agates". Verify names/ranks.
- Teleport: City at 20 and 30; Portal: City at 40 (Icy Veins frost leveling). Forever lists **Teleport: Dalaran** (spells/1297659) – verify faction/level. Portals listed: Stormwind 10059, Ironforge 11416, Darnassus 11419, Orgrimmar 11417, Undercity 11418, Thunder Bluff 11420; Teleports 3561/3562/3565/3567/3563/3566. Portals/teleports need Rune of Teleportation/Portals reagents in Classic – VERIFY for Forever.
- Evocation (12051) at 20, 8 s channel; Blink 1953 at 20; Polymorph (rank spell 12826 cited); Conjure Food 28612 / Conjure Water 10140 (top ranks cited).

## Talents at launch (Nov 2 notes, per foreverguide.net; deep dive had earlier values)
- Arcane: **Arcane Blast** (11-pt gold medal; 2.5 s; stacks x4; launch: +100% mana per stack, 12% Int as spell dmg per stack, 18 s — deep dive said 8 s: CONFLICT, launch wins), **Missile Barrage** (row 2 at launch), **Arcane Wrath** (16-pt slot, 3.5 s nuke scaling with max mana), Arcane Geometry, Arcane Impact, Arcane Mind (Int + Arcane crit dmg), Arcane Resilience row 1 (3 pts, 75% Int as armor), Improved Channeling, Arcane Meditation, Arcane Power needs Presence of Mind.
- Fire: **Heating Up** (needs Pyroblast; crits from Fireball/FFB/Fire Blast/Scorch cut next Pyroblast by 25%/stack, x3 → 1.5 s), Accelerant (ex-Improved Fireball; also Arcane Wrath), Incineration (5 pts, 10% crit; also Ice Lance + Arcane Blast), Critical Mass 3 pts, per-Mage Ignite, Improved Scorch self-only, Blast Wave no Pyroblast prereq.
- Frost: **Ice Lance** (11-pt gold medal; launch: 8 s CD shared with Fire Blast, 300% vs frozen), **Fingers of Frost**, Ice Block 16-pt, Cold Snap 21-pt (10 min), Ice Barrier (launch: +15% Frost dmg 1 min + 5% while shield holds), Precision 2/4/6% hit, Improved Blizzard max 40% slow, Winter's Chill self-only, Permafrost %-based; Frost Blast and Piercing Ice removed.
- Talent calculator: https://www.icy-veins.com/wow-forever/mage-talent-calculator (Andric used Icy Veins' calculator data for tree JSON; do the same for `research/talents_mage.json`).

## Leveling / rotation (Icy Veins leveling + PvE guides, Wowhead overview/rotation)
- Frost = safest leveler (Frostbolt → Fingers of Frost/Frostbite procs → Ice Lance; Frost Nova + Ice Lance; Blizzard when safe; Ice Barrier uptime late).
- Arcane = viable standalone leveler in Forever (Arcane Blast stacks fishing for Missile Barrage → fast free Arcane Missiles; Arcane Wrath burst; 100% Spirit regen in combat with Arcane Meditation + Mage Armor).
- Fire = mana-hungry leveler; start in Arcane (Missile Barrage/Arcane Blast) then Fire (Heating Up, Pyroblast pulls, Ignite).
- Tips: conjure food/water/gem at login; keep Arcane Intellect + Frost/Ice Armor (Mage Armor for regen); Polymorph extra adds; Blink ~20% travel speed on CD; don't set Hearth to a city you can teleport to; wand when low; Spirit improves Evocation.
- Spell-learn table by level in raw Icy Veins leveling pages (e.g. 20: Blink, Evocation, Teleport, Arcane Blast; 28/38/48/58 Conjure Mana Gem; 40 Portals + Frostfire Bolt).

## Stats / gear
- Icy Veins stat-priority pages per spec (raw `*_stat_priority.md`) – priority order only, no numeric weights (same situation as Priest). BiS pages (Icy Veins + Wowhead bis-gear) are phase-1 placeholders; raids open Dec 9.
- Class quest gear: Lvl 15 Manaweave Robe (Alliance), Lvl 26 Astral Knot Robe/Blouse, Lvl 30 Mage's Wand chain (elemental wands e.g. Icefury Wand), Lvl 35 Celestial Power, Lvl 50 Destroy Morphaz, Lvl 60 Fragmented Magic. No abilities are locked behind Mage class quests.

## Data warnings
- **Wowhead `frost/leveling-tips` contains TBC-era content** (Water Elemental 31687, Shattrath portals, levels 63–67). Do NOT import those rows; Forever max level is 60. Treat Wowhead mage tables as suspect unless confirmed by Icy Veins/Blizzard.
- Wowhead talent-builds/abilities/stat-priority URLs for Forever mage returned "not found" (2026-11-10). Use Icy Veins spec-builds-talents pages for build links.
- Sportskeeda page fetched empty; snippet only.
