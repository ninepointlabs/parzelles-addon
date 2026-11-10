# content/learn.json

Hand-written teaching and rotation content for **Learn the Mage** and the **Rotation** tab (including its Crowd control and Mana sub-tabs). `tools/build_data.py` turns it into `Data/Learn.lua`.

Rules (the weekly recheck must keep to them):

- Only facts from `research/data.json` or the archived pages behind it. Every entry lists `sources`.
- Anything not stated by a source, stated by only one third-party site, or conflicting between sources gets `"unconfirmed": true` and a short `"flag"`. The addon shows the flag in-game.
- Don't invent numbers (costs, coefficients, cooldowns, durations).
- Spell keys must match `data.json` names exactly (`spells_by_level[].name` without " (talent)", `teleports_portals[].name`); talent keys match `talent_and_other_spell_ids[].name` minus any parenthetical.
- Never import TBC-era rows (Water Elemental, Molten Armor, Shattrath, levels above 60): Forever's cap is 60.

## Sections

`spells`, `talents`, `mechanics`, `roles`, `leveling` (per spec), `mistakes`, `lessons` (unlock at `level`, optional `spec`), `first_learn_hints`, `rotation`.

`mechanics[]` entries may carry `"topic": "mana"` (shown on Rotation › Mana) or `"topic": "cc"` (Rotation › Crowd control).

`rotation.<Arcane|Fire|Frost>.<solo|dungeon|raid>` = `{ summary, kind: "damage", priority: [{spell, when, note}], tips, unconfirmed, flag, sources }`.

`when` must be one the engine (`Modules/Rotation.lua`) understands:
`always`, `manual` (listed for reading, never suggested by the on-screen helper, e.g. AoE or situational spells), `buff_missing`, `debuff_missing`, `ready`, `out_of_combat`, `in_combat`, `target_frozen`, `mana_above:N`, `mana_below:N`, `target_hp_below:N`, `proc:<Buff name>`, `frozen_or_proc:<Buff name>`, `stacks_below:<Aura>:N`, `stacks_at_least:<Aura>:N`. `spell: "Wand"` means "use your wand". `tests/run.lua` fails if a step uses anything else or names a spell the research doesn't know.

After editing: `python3 tools/build_data.py && lua5.1 tests/run.lua`.
