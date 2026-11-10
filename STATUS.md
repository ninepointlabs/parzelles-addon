# STATUS: Parzelle's Addon (updated 2026-11-10)

**What it is:** the WoW Forever-only, do-everything Mage companion for Parzelle Starfall (High Order Skyborne, Alliance). It follows the final structure, window design, README and website style of Andric's Addon v0.2.2.

**Repo:** `ninepointlabs/parzelles-addon` (public; topics not set yet). Local checkout: `/home/tim/Projects/parzelles-addon`.
**Branching:** Tim decided on 2026-11-10 (8:11 AM CT) to commit straight to `main`, like Andric's later changes, with no PR. `feature/initial-addon` was fast-forwarded into `main`.
**Not done (not authorized):** no tag, no release, no custom domain, DNS records or Pages custom-domain setting (only `docs/CNAME` exists), no email or social posts. Before any future tag, re-run `omaforge clients` and bump `## Interface` in both `.toc` files to match.

**Tim's decisions (2026-11-10, 8:11 AM CT):**
1. Keep the name Parzelle's Addon, the slash commands `/parzelle` and `/mage`, and the repo `ninepointlabs/parzelles-addon`.
2. Commit straight to `main`, with no tag or release until Tim asks.
3. Leveling focus is Frost (the picker recommends it). TBC-only rows such as Water Elemental and the Shattrath portals stay out.
4. The Conjure button makes whatever she's lowest on: mana gem first, then water, then food. This is the built behaviour: gem if she has none, otherwise water below its target, otherwise food.

## What works (verified headlessly, 2026-11-10)

| Check | Result |
|---|---|
| `lua5.1 tests/run.lua` | **35/35 pass**. A strict WoW mock loads every TOC file. It renders all 8 screens and every sub-tab for Arcane, Fire and Frost at levels 8, 24 and 60, plus a level-8 character with no talents and no spec. |
| `python3 tools/mage-changes-poller/tests/test_poller.py` | **4/4 pass** |
| `python3 tools/build_data.py --check` | up to date |
| `python3 tools/ivcalc.py` | all 22 build links decode. Every level-60 build totals exactly 51 points; Wowhead's Frost "Leveling 1-33" is a 24-point build by design. |
| Lua syntax | every `.lua` file loads |
| CI | `.github/workflows/test.yml` runs on PRs; `release.yml` uses the BigWigs packager to build the zip and `release.json` on `v*` tags (not triggered) |

**What the tests cover:**
- Spec picker and the "no talents yet" path (it recommends Frost as the safest leveling spec).
- A/B profiles and dual-spec auto-switch.
- Stat parsing with per-spec school damage, weights, upgrade compare, tooltips and bag highlights.
- Faction-filtered training, and Skyborne class quests (Boughs in the Wind).
- Every rotation step's condition and spell name, plus the level-8 "known spells only" rule.
- Conjure classification, stock counts and pick order; the conjure button's secure attributes, key binding and combat freeze; Super/Meta refused.
- Portals: own faction only, the secure travel bar, and the hearth tip.
- Polymorph timer, early-break warning and hidden-aura fallback.
- Fight summary, reminders, What's new, lessons, the map pin, Settings › About (Parzelle Starfall), slash commands and events.
- A check that no "Priest" or "Andric" text appears anywhere in the window.

## Features (v0.1.0 on the branch)

- **Window:** same as Andric's v0.2.x. 8 grouped screens: Home · Play (Rotation, Gear) · Progress (Leveling, Talents) · Learn the Mage · What's new · Settings. It keeps the search box, the "Sources & notes" popups, and the spec pill plus A/B profile in the header.
  - Rotation sub-tabs: Solo · Dungeon · Raid · **Crowd control** · **Mana**.
  - Leveling sub-tabs: Path · Zones & dungeons · Trainer · Class quests · Riding & gold · **Portals & teleports**.
  - Settings sub-tabs: General · **Conjure button** · Tooltips & bags · Reminders · About the data · About.
  - Palette per spec: Arcane violet/blue, Fire ember orange/gold, Frost ice blue/white.
- **Conjure button** (`UI/ConjureButton.lua`, `Modules/Conjure.lua`):
  - It's a secure action button, `type=spell`, casting by spell name, so you get your highest known rank.
  - Order: mana gem if you have none, then water below its target, then food. Default targets are 20/20/1, set in Settings.
  - It's re-aimed out of combat only and shows stock counts.
  - Key: Settings › Conjure button › Set key, applied with `SetOverrideBindingClick`. No key is bound by default, Super/Meta combos are refused, and there are no macros, no `/click` and no `Bindings.xml`.
  - It nudges you on Home and after login when stock is low.
- **Portals & teleports:**
  - Your faction only; the other faction's spells are never listed.
  - Each entry shows "Known", "Train it" or "Unlock at N", plus reagent counts flagged "not confirmed for Forever" and a hearthstone tip.
  - Clicking is done on a separate **travel bar** of secure buttons. It is its own top-level frame, so the main window never holds protected frames and stays closable in combat.
- **CC tracker** (`Modules/CC.lua`):
  - Shows your Polymorph target and time left on the on-screen helper, and warns if it breaks early.
  - Lists Frost Nova, Counterspell and Cone of Cold cooldowns.
  - Uses `UNIT_SPELLCAST_SENT`/`SUCCEEDED` plus aura reads on target, focus, mouseover and nameplates, with no combat log. Hidden values show as "timer hidden".
- **Rotation:**
  - Solo, Dungeon and Raid priorities per spec, with new conditions: `frozen_or_proc`, `stacks_below`/`stacks_at_least`, `target_frozen` and `manual`.
  - Shows only known spells; spells you can train show "Train it"; talents appear only once taken.
  - Post-fight chat summary with Mage mana tips. Advice only.
- **Other screens:**
  - Gear: per-spec school damage weights; Mages use cloth, staves, daggers, 1h swords and wands.
  - Talents: builds drawn on Forever's real trees, from Icy Veins and Wowhead.
  - Learn the Mage: 49 spells, 36 talents, 25 mechanics, 44 lessons, and leveling tips per spec.
  - Reminders: Arcane Intellect, armor, Ice Barrier (Frost), conjured stock, reagents and wand, plus a Dampen/Amplify Magic tip.
  - What's new: change poller in `tools/mage-changes-poller`, with an example systemd timer that is **not enabled**.
- **Slash:** `/parzelle` (alias `/mage`). Includes `spec arcane|fire|frost`, `profile A|B`, `portals`, `cc`, `mana`, `conjure [key|debug]` and `about`.

## Install / test in game on TUF

```sh
cd ~/Projects/parzelles-addon
tools/install-dev.sh            # copies to …/_forever_/Interface/AddOns/ParzellesAddon
python3 tools/build_data.py     # regenerate Data/*.lua (--check fails if stale)
lua5.1 tests/run.lua            # headless tests
```

In game, `/reload` and then `/parzelle`. You can check the client with `/run print(GetBuildInfo()) print(WOW_PROJECT_ID)`.

## Client check

| | Value |
|---|---|
| `omaforge clients` on TUF (2026-11-10) | Forever `1.60.1.70862`, Interface `16001`, path `~/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_` |
| `.toc` Interface used | `16001` (matches), in `ParzellesAddon_Forever.toc` and the identical `ParzellesAddon.toc` |
| Runtime guard | runs only when `WOW_PROJECT_ID == 18` (`WOW_PROJECT_CAMELOT`) and prints a message otherwise |

Re-run `omaforge clients` before any tag.

## Research

- `research/` holds `NOTES.md`, `sources.md`, the fetch helpers, `data.json`, `item_sources.json`, `talents_mage.json` (70862) and `talents_mage_70755.json` (needed for older Icy Veins links).
  - `data.json` is merged from two extraction passes; every record has `source_url` and `checked`.
  - Contents: 49 spells including 13 teleports/portals, 44 quests all with IDs, 22 builds, 28 gear rows, 9 wands, 31 conflicts and 26 gaps.
- **`research/raw/` (11 MB) is gitignored**, the same decision as Andric's Addon: the pages are third-party copyrighted HTML. They stay on TUF only.
- **Icy Veins build links:** each character after `#tc-` is one talent point, given by that talent's `urlId` in the calculator data for the link's version. `tools/fetch_talents.py` now stores `url_id`, and `tools/ivcalc.py` decodes and validates the links. Prerequisite arrows (e.g. Arcane Power needs Presence of Mind) aren't in the tree data, so they aren't validated.
- **Teleport: Dalaran (Tim, 2026-11-10: keep, flag unconfirmed):** its facts (Alliance, level 50, Rune of Teleportation) come from one db.icy-veins page. A research agent fetched that page once with a full browser user-agent to get past a Cloudflare challenge. The records in `data.json` carry `unconfirmed` and a `flag`, and Leveling › Portals & teleports shows the flag next to the spell.

### Gaps the addon flags instead of filling (full list in Settings › About the data)

- Portal/teleport reagents (Rune of Teleportation/Portals) aren't confirmed for Forever (only Dalaran's is), and the reagents have no item IDs.
- Forever's conjured water and food names and item IDs are unknown, so the addon recognises conjured items from their tooltip text ("Conjured Item" plus what they restore). Mana gem item IDs are missing except Mana Ruby 8008.
- Flamestrike's learn levels, the trained ranks of Ice Barrier, Blast Wave and Ice Lance, and the Detect Magic and Arcane Brilliance levels.
- Aura IDs for procs (Missile Barrage, Clearcasting, Heating Up, …). The helper matches these by name.
- Per-rank training costs; only the ~206–207g total for 1–60 is known (foreverguide.net summary).
- Leveling gear past 30, pre-raid and raid best-in-slot (the BiS pages are empty placeholders; raids open Dec 9), enchants, and the Destroy Morphaz reward IDs.
- Skyborne riding: trainer and vendor Genn Fairweather is now sourced from Wowhead. Thendal Village and Shen'dar Village don't appear in any source; Valanaar does.

### Conflicts shown in game (31; main ones)

- Arcane Blast duration: 8 s (deep dive) vs 18 s (launch, which the addon uses). Its cast time is also uncertain.
- Mana gems: Conjure Mana Agate/Jade/Citrine/Ruby vs "Conjure Mana Gem" vs the spell "Mana Gems" (1318827).
- Level 40 vs 50 for Teleport: Dalaran, Portal: Darnassus and Portal: Thunder Bluff.
- Intellect per 1% crit: 54 vs 59.5/60.
- Combustion charges: 3 vs 4.
- Several spell IDs: Ice Lance, Precision, Arcane Wrath, Ice Barrier, Conjure Water.
- The low-rank proc penalty: `NOTES.md` says it applies, but the launch notes removed it except for Blizzard. The addon follows the launch notes.
- Wowhead's `frost/leveling-tips` page is TBC content, and the Mage `/overview` pages are modern retail. Nothing was imported from either.

## Decisions and assumptions

- **Name and identity** follow the brief's defaults: Parzelle's Addon, `ParzellesAddon`, `ParzellesAddonDB`/`ParzellesAddonCharDB`, `/parzelle` + `/mage`, `X-Website` set to the GitHub URL until the site is live. Commits use `179739321+ninepointlabs@users.noreply.github.com`. No Ace3; Blizzard API only.
- **No talents yet (level < 10):** you can still pick a spec, and the advice follows it. Frost is marked "recommended for leveling" and Arcane is mentioned as viable.
- **Gear weights** use the same rule as Andric's: (n − rank + 1)/n from each spec's stat priority, with 10 points per 1% hit/crit (an addon assumption you can change). Spell damage counts all schools plus your own; other schools are shown but not weighted. Healing power doesn't count for a Mage.
- **Travel bar instead of in-window cast buttons:** this keeps protected frames out of the main window, which has to stay closable in combat.
- **Rotation thresholds** come from the sources: Evocation at ~5% mana (Icy Veins), wand when the target is below 15% (Icy Veins Fire). Pyroblast fires at 3 Heating Up stacks. Raid rotations are flagged as pre-raid guidance.
- **Skyborne race token:** the client race string isn't researched, so anything containing "Skyborne" maps to Skyborne.
- **Website (`docs/`):** same OmaForge-style CSS/JS; art is linked, not copied. Sections: hero, Conjure button spotlight with a demo, quest log, "The Mage Who Started It All", loot window and tavern FAQ.
  - There are no screenshots yet, only placeholders. Other players' names must be pixelated when screenshots are added.
  - `docs/` is excluded from the zip, and `docs/CNAME` = `parzellesaddon.myazerothlife.com`.
  - Flavour names (Innkeeper "Emberwick", item names) are invented for the site.
- **autonomix-cli** isn't listed, because this addon ships no Linux executables.

## Still to check in game

1. **Conjure button:**
   - Does `type=spell` with a bare spell name cast the highest rank on Forever?
   - Does the override key binding work?
   - Does the tooltip classifier recognise Forever's conjured water, food and gems? `/parzelle conjure debug` shows counts and spells.
2. **Travel bar:** does a click cast each teleport/portal?
3. **Polymorph tracker:** are aura `expirationTime` values readable on Forever, or secret?
4. **Rotation stacks:** is the Arcane Blast stack a buff or a debuff (a recorded conflict)? The engine checks both. Also check the Heating Up stack count.
5. **Race token** for High Order Skyborne (`/run print(UnitRace("player"))`) and the Skyborne class quests' IDs (93791, 93797) being marked done.
6. **Dual spec at 40,** the window layout, bag overlays, map pins, and Lua errors (`/console scriptErrors 1`).
