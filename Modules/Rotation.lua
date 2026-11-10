-- Rotation helper: priority lists per spec/context from content/learn.json and a
-- next-spell suggestion. Advice only: nothing here casts, targets or presses
-- anything (Blizzard forbids automation; we only read state).
local _, ns = ...

local Rotation = {}
ns.Rotation = Rotation

Rotation.CONTEXTS = { "solo", "dungeon", "raid" }
Rotation.CONTEXT_LABELS = { solo = "Solo leveling", dungeon = "Dungeon", raid = "Raid" }
Rotation.WAND = "Wand"
Rotation.SHOOT_ID = 5019 -- "Shoot" (wand auto-attack), long-standing Blizzard spell ID
-- Target debuffs that count as "frozen" for Shatter / Ice Lance (Forever: Frost
-- Nova, Frostbite procs, Freeze). Matched by name.
Rotation.FROZEN = { "Frost Nova", "Frostbite", "Freeze" }

local function clean(name)
    return (name:gsub("%s*%(talent%)%s*$", ""))
end
Rotation.Clean = clean

-- name -> spell id / record, built from research (trainer spells, talents,
-- procs, teleports/portals, racials).
local idByName, recByName
local function index()
    if idByName then return end
    idByName, recByName = {}, {}
    for _, s in ipairs(ns.Data.Spells) do
        idByName[s.name] = idByName[s.name] or s.wowhead_base_spell_id
        idByName[s.display] = idByName[s.display] or s.wowhead_base_spell_id
        recByName[s.name], recByName[s.display] = s, s
    end
    for _, t in ipairs(ns.Data.TalentSpells or {}) do
        local c = clean(t.name)
        if not idByName[c] then idByName[c] = t.spell_id end
    end
    for _, p in ipairs(ns.Data.TeleportsPortals or {}) do
        if not idByName[p.name] then idByName[p.name] = p.spell_id end
    end
    for _, r in ipairs(ns.Data.Racials or {}) do
        if r.spell and not idByName[r.spell] then idByName[r.spell] = r.spell_id end
    end
end

function Rotation.SpellId(name)
    if not name then return nil end
    index()
    return idByName[name] or idByName[clean(name)]
end

function Rotation.SpellRecord(name)
    if not name then return nil end
    index()
    return recByName[name] or recByName[clean(name)]
end

-- Is the name a spell/talent/proc the research knows (even without an ID)?
function Rotation.IsKnownName(name)
    index()
    if idByName[name] or recByName[name] or recByName[clean(name)] then return true end
    for _, t in ipairs(ns.Data.TalentSpells or {}) do
        if clean(t.name) == clean(name) then return true end
    end
    return false
end

function Rotation.Context(spec, context)
    local learn = ns.Data.Learn
    local bySpec = learn and learn.rotation and learn.rotation[spec]
    return bySpec and bySpec[context]
end

-- Spell icon (texture id/path) or a question mark.
function Rotation.Icon(name)
    if name == Rotation.WAND then return "Interface\\Icons\\INV_Wand_07" end
    local id = Rotation.SpellId(name)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, tex = pcall(C_Spell.GetSpellTexture, id or clean(name))
        if ok and tex then return tex end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Is this step's spell usable by the player at all?
function Rotation.Known(name)
    if name == Rotation.WAND then
        local link = GetInventoryItemLink("player", 18)
        return link ~= nil
    end
    return ns.Progress.Knows(clean(name))
end

-- Can the player use this step at their level?
--   "known"     spell is in the spellbook (or a wand is equipped)
--   "trainable" not detected as known, but a trainer rank is available at this level
--   "no_wand"   wand step without a wand equipped
--   nil         can't be learned yet (talent not taken, level too low, other faction)
function Rotation.Availability(name, level, race, faction)
    if name == Rotation.WAND then return Rotation.Known(name) and "known" or "no_wand" end
    if Rotation.Known(name) then return "known" end
    local s = Rotation.SpellRecord(name)
    if s then
        if s.faction and faction and s.faction ~= faction then return nil end
        if not s.talent and s.rank_learn_levels[1] and s.rank_learn_levels[1] <= level then return "trainable" end
        return nil
    end
    return nil -- talents and procs: only once taken
end

-- Evaluate one condition. state: table of readers (injectable for tests).
-- Returns true/false, or nil when the client won't tell us (secret/unknown).
function Rotation.Check(step, state)
    local when = step.when or "always"
    local name = clean(step.spell)
    if when == "always" then return true end
    if when == "manual" then return false end -- listed for reading; the HUD never suggests it
    if when == "out_of_combat" then return not state.inCombat() end
    if when == "in_combat" then return state.inCombat() and true or false end
    if when == "buff_missing" then
        local has = state.playerBuff(state.spellName(name))
        if has == nil then return nil end
        return has == false
    end
    if when == "debuff_missing" then
        if not state.hasTarget() then return false end
        local has = state.targetDebuff(state.spellName(name))
        if has == nil then return nil end
        return has == false
    end
    if when == "ready" then
        local left = state.cooldown(name)
        if left == nil then return nil end
        return left <= 0.1
    end
    if when == "target_frozen" then
        if not state.hasTarget() then return false end
        return state.targetFrozen()
    end
    local kind, arg = when:match("^([%w_]+):(.+)$")
    local num = tonumber(arg)
    if kind == "mana_above" or kind == "mana_below" then
        local pct = state.manaPct()
        if pct == nil then return nil end
        if kind == "mana_above" then return pct > num else return pct < num end
    end
    if kind == "target_hp_below" then
        local pct = state.targetHpPct()
        if pct == nil then return nil end
        return pct < num
    end
    if kind == "proc" then
        local has = state.playerBuff(arg)
        if has == nil then return nil end
        return has ~= false
    end
    if kind == "frozen_or_proc" then
        local has = state.playerBuff(arg)
        if has and has ~= false then return true end
        if state.hasTarget() then
            local frozen = state.targetFrozen()
            if frozen then return true end
            if frozen == nil or has == nil then return nil end
        end
        return false
    end
    -- stacks_below:<Aura>:N / stacks_at_least:<Aura>:N (player aura applications)
    if kind == "stacks_below" or kind == "stacks_at_least" then
        local aura, n = arg:match("^(.-):(%d+)$")
        n = tonumber(n)
        if not aura then return nil end
        local stacks = state.playerStacks(aura)
        if stacks == nil then return nil end
        if kind == "stacks_below" then return stacks < n else return stacks >= n end
    end
    return nil
end

local function frozen()
    if not UnitExists("target") then return false end
    local unknown = false
    for _, n in ipairs(Rotation.FROZEN) do
        local has = ns.Auras.Find("target", ns.Auras.SpellName(Rotation.SpellId(n)) or n, "HARMFUL")
        if has then return true end
        if has == nil then unknown = true end
    end
    if unknown then return nil end
    return false
end

-- Live readers backed by Modules/Auras.lua.
Rotation.LiveState = {
    inCombat = function() return UnitAffectingCombat("player") end,
    hasTarget = function() return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target") end,
    spellName = function(name)
        local id = Rotation.SpellId(name)
        return (id and ns.Auras.SpellName(id)) or name
    end,
    playerBuff = function(n) return ns.Auras.Find("player", n, "HELPFUL") end,
    playerDebuff = function(n) return ns.Auras.Find("player", n, "HARMFUL") end,
    playerStacks = function(n)
        local data = ns.Auras.Find("player", n, "HELPFUL")
        if data == false then data = ns.Auras.Find("player", n, "HARMFUL") end
        if data == nil then return nil end
        if data == false then return 0 end
        local c = data.applications or data.charges or data.count
        if c == nil or ns.Auras.IsSecret(c) then return nil end
        return math.max(1, c)
    end,
    targetDebuff = function(n) return ns.Auras.TargetHasMine(n) end,
    targetFrozen = frozen,
    cooldown = function(name)
        if name == Rotation.WAND then return 0 end
        local id = Rotation.SpellId(name)
        return ns.Auras.CooldownLeft(id or name)
    end,
    manaPct = function() return ns.Auras.PowerPct("player") end,
    targetHpPct = function() return ns.Auras.HealthPct("target") end,
    known = function(name) return Rotation.Known(name) end,
}

-- Steps that are "ready" conditions on any step also feed the cooldown bar.
function Rotation.Cooldowns(ctx)
    local seen, out = {}, {}
    for _, step in ipairs(ctx and ctx.priority or {}) do
        if step.when == "ready" and not seen[step.spell] then
            seen[step.spell] = true
            table.insert(out, step.spell)
        end
    end
    return out
end

-- Returns suggestion list (up to `max` steps whose conditions currently pass),
-- plus a flag when some conditions could not be read.
function Rotation.Suggest(spec, context, state, max)
    state = state or Rotation.LiveState
    local ctx = Rotation.Context(spec, context)
    if not ctx then return {}, false, nil end
    local out, blocked = {}, false
    for _, step in ipairs(ctx.priority or {}) do
        if state.known(step.spell) then
            local ok = Rotation.Check(step, state)
            if ok == nil then blocked = true end
            if ok then
                table.insert(out, step)
                if #out >= (max or 3) then break end
            end
        end
    end
    return out, blocked, ctx
end
