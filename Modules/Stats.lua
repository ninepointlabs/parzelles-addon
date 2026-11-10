-- Item stat parsing, spec weights and upgrade comparison.
--
-- Stats come from the item's tooltip text (Forever items use Classic-style
-- "Equip: Increases damage and healing done by magical spells..." lines, which
-- C_Item.GetItemStats does not report reliably). enUS client text only.
--
-- Weights are DERIVED, not simulated: the research gives each spec an ordered
-- stat priority (Data/Gear.lua -> StatPriority). Rank r of n gets weight
-- (n - r + 1) / n. Percent stats (hit/crit) are multiplied by
-- ParzellesAddonDB.percentScale (default 10 points per 1%), which is an addon
-- assumption and is flagged as such wherever a score is shown. Users can
-- override any weight per profile.
local _, ns = ...

local Stats = {}
ns.Stats = Stats

Stats.DEFAULT_PERCENT_SCALE = 10
Stats.PERCENT_KEYS = { SPELL_HIT = true, SPELL_CRIT = true }

Stats.LABELS = {
    DAMAGE = "Spell damage (your school)", OFF_SCHOOL = "Other-school damage",
    SPELL_HIT = "Spell hit %", SPELL_CRIT = "Spell crit %", INT = "Intellect",
    SPI = "Spirit", STA = "Stamina", MP5 = "Mana per 5",
}

-- Which school-specific damage counts for each spec (Frostfire Bolt uses the
-- higher of Fire/Frost, but a spec's main nukes decide the weight).
Stats.SPEC_SCHOOL = { Arcane = "ARCANE_DAMAGE", Fire = "FIRE_DAMAGE", Frost = "FROST_DAMAGE" }

-- Lower-cased patterns -> raw keys. Order matters: first match wins per line.
Stats.PATTERNS = {
    { "^%+(%d+) intellect$", "INT" },
    { "^%+(%d+) spirit$", "SPI" },
    { "^%+(%d+) stamina$", "STA" },
    { "^equip: increases damage and healing done by magical spells and effects by up to (%d+)%.?$", "SPELL_POWER" },
    { "^%+(%d+) damage and healing spells$", "SPELL_POWER" },
    { "^%+(%d+) spell damage and healing$", "SPELL_POWER" },
    { "^equip: increases healing done by up to (%d+) and damage done by up to (%d+) for all magical spells and effects%.?$", "HEALING", "HEALING_DMG" },
    { "^equip: increases healing done by magical spells and effects by up to (%d+)%.?$", "HEALING" }, -- Forever wording
    { "^equip: increases healing done by spells and effects by up to (%d+)%.?$", "HEALING" },
    { "^equip: increases healing done by up to (%d+)%.?$", "HEALING" },
    { "^%+(%d+) healing spells$", "HEALING" },
    { "^%+(%d+) healing$", "HEALING" },
    { "^equip: increases damage done by magical spells and effects by up to (%d+)%.?$", "SPELL_DAMAGE" },
    { "^%+(%d+) spell damage$", "SPELL_DAMAGE" },
    { "^equip: increases damage done by fire spells and effects by up to (%d+)%.?$", "FIRE_DAMAGE" },
    { "^%+(%d+) fire spell damage$", "FIRE_DAMAGE" },
    { "^%+(%d+) fire damage$", "FIRE_DAMAGE" },
    { "^equip: increases damage done by frost spells and effects by up to (%d+)%.?$", "FROST_DAMAGE" },
    { "^%+(%d+) frost spell damage$", "FROST_DAMAGE" },
    { "^%+(%d+) frost damage$", "FROST_DAMAGE" },
    { "^equip: increases damage done by arcane spells and effects by up to (%d+)%.?$", "ARCANE_DAMAGE" },
    { "^%+(%d+) arcane spell damage$", "ARCANE_DAMAGE" },
    { "^%+(%d+) arcane damage$", "ARCANE_DAMAGE" },
    { "^equip: increases damage done by shadow spells and effects by up to (%d+)%.?$", "SHADOW_DAMAGE" },
    { "^equip: increases damage done by holy spells and effects by up to (%d+)%.?$", "HOLY_DAMAGE" },
    { "^equip: improves your chance to get a critical strike with spells by (%d+)%%%.?$", "SPELL_CRIT" },
    { "^equip: improves your chance to hit with spells by (%d+)%%%.?$", "SPELL_HIT" },
    { "^equip: restores (%d+) mana per 5 sec%.?$", "MP5" },
    { "^%+?(%d+) mana every 5 sec%.?$", "MP5" },
    { "^%+?(%d+) mana per 5 sec%.?$", "MP5" },
    { "^%+?(%d+) mana every 5 seconds$", "MP5" },
    { "^%(([%d%.]+) damage per second%)$", "WAND_DPS" },
}

local function clean(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return strtrim and strtrim(text):lower() or (text:match("^%s*(.-)%s*$")):lower()
end

-- lines: array of strings. Returns raw stat table.
function Stats.ParseLines(lines)
    local raw = {}
    for _, line in ipairs(lines) do
        if type(line) == "string" and line ~= "" then
            local text = clean(line)
            -- Set bonuses only apply with the set; "Use:" effects are not passive stats.
            if not text:find("^%(%d%) set:") and not text:find("^set:") and not text:find("^use:") then
                for _, p in ipairs(Stats.PATTERNS) do
                    local a, b = text:match(p[1])
                    if a then
                        raw[p[2]] = (raw[p[2]] or 0) + tonumber(a)
                        if p[3] and b then raw[p[3]] = (raw[p[3]] or 0) + tonumber(b) end
                        break
                    end
                end
            end
        end
    end
    return raw
end

-- Combine raw tooltip stats into the keys the research priorities use.
-- DAMAGE = all-school spell damage + the spec's own school; damage for other
-- schools is shown (OFF_SCHOOL) but not weighted. Healing power doesn't help a
-- Mage: Forever items print their damage part as its own line, so only explicit
-- damage lines count (the combined "healing ... and damage done by up to N" line
-- keeps its damage part).
function Stats.Derive(raw, spec)
    local school = Stats.SPEC_SCHOOL[spec or ""]
    local schools = (raw.FIRE_DAMAGE or 0) + (raw.FROST_DAMAGE or 0) + (raw.ARCANE_DAMAGE or 0)
    local own = school and (raw[school] or 0) or 0
    local base = (raw.SPELL_POWER or 0) + (raw.SPELL_DAMAGE or 0) + (raw.HEALING_DMG or 0)
    return {
        DAMAGE = base + own,
        OFF_SCHOOL = schools - own,
        SPELL_HIT = raw.SPELL_HIT or 0,
        SPELL_CRIT = raw.SPELL_CRIT or 0,
        INT = raw.INT or 0,
        SPI = raw.SPI or 0,
        STA = raw.STA or 0,
        MP5 = raw.MP5 or 0,
    }
end

-- Which research priority applies to a profile right now.
function Stats.WeightSetName(spec, level, profile)
    if not spec then return "Leveling" end
    local useLeveling = profile and profile.levelingWeights
    if useLeveling == nil then useLeveling = false end
    if not ns.Data.StatPriority.Leveling then useLeveling = false end
    local maxLevel = (ns.Data.Meta and ns.Data.Meta.max_level) or 60
    if useLeveling and level and level < maxLevel then return "Leveling" end
    return ns.Specs[spec].weights
end

function Stats.Weights(setName, percentScale, overrides)
    local prio = ns.Data.StatPriority[setName]
    local weights = {}
    if not prio then return weights end
    local n = #prio.keys
    for r, key in ipairs(prio.keys) do
        local w = (n - r + 1) / n
        if Stats.PERCENT_KEYS[key] then w = w * (percentScale or Stats.DEFAULT_PERCENT_SCALE) end
        weights[key] = w
    end
    if overrides then
        for k, v in pairs(overrides) do
            if type(v) == "number" then weights[k] = v end
        end
    end
    return weights
end

function Stats.Score(derived, weights)
    local s = 0
    for k, w in pairs(weights) do s = s + (derived[k] or 0) * w end
    return s
end

-- Equip location -> inventory slot ids.
Stats.SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_HOLDABLE = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_RANGED = { 18 },
    INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
}

-- Mages: cloth armor (plus misc: neck/rings/trinkets/held), staves, 1h swords, daggers, wands.
local ARMOR, WEAPON = 4, 2
local MAGE_ARMOR = { [0] = true, [1] = true }
local MAGE_WEAPON = { [7] = true, [10] = true, [15] = true, [19] = true }
Stats.WAND_SUBCLASS = 19

function Stats.MageCanUse(classID, subclassID, equipLoc)
    if equipLoc == "INVTYPE_CLOAK" then return true end
    if classID == ARMOR then return MAGE_ARMOR[subclassID] == true end
    if classID == WEAPON then return MAGE_WEAPON[subclassID] == true end
    return false
end

-- Tooltip line provider; replaced in tests.
function Stats.LinesForLink(link)
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
        if ok and data and data.lines then
            local lines = {}
            for i, line in ipairs(data.lines) do lines[i] = line.leftText or "" end
            return lines
        end
    end
    return nil
end

local cache = {}
function Stats.RawForLink(link)
    if not link then return nil end
    if cache[link] then return cache[link] end
    local lines = Stats.LinesForLink(link)
    if not lines or #lines < 2 then return nil end -- item not cached yet
    local raw = Stats.ParseLines(lines)
    cache[link] = raw
    return raw
end

function Stats.ClearCache() cache = {} end

-- Compare an item link against what is equipped. Returns a result table or nil.
-- equippedLink(slot) is injectable for tests.
function Stats.Compare(link, spec, level, profile, percentScale, itemInfo, equippedLink)
    itemInfo = itemInfo or function(l)
        local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(l)
        return equipLoc, classID, subclassID
    end
    equippedLink = equippedLink or function(slot) return GetInventoryItemLink("player", slot) end

    local equipLoc, classID, subclassID = itemInfo(link)
    local slots = equipLoc and Stats.SLOTS[equipLoc]
    if not slots then return nil end
    local result = { equipLoc = equipLoc }
    if not Stats.MageCanUse(classID, subclassID, equipLoc) then
        result.unusable = true
        return result
    end
    local raw = Stats.RawForLink(link)
    if not raw then result.pending = true return result end

    local setName = Stats.WeightSetName(spec, level, profile)
    local weights = Stats.Weights(setName, percentScale, profile and profile.weights)
    local new = Stats.Derive(raw, spec)
    result.setName, result.weights, result.derived = setName, weights, new
    result.score = Stats.Score(new, weights)
    result.isWand = (classID == WEAPON and subclassID == Stats.WAND_SUBCLASS)
    result.wandDps = raw.WAND_DPS

    -- Pick the equipped item this would replace (weakest of a ring/trinket pair).
    local best
    for _, slot in ipairs(slots) do
        local eqLink = equippedLink(slot)
        if eqLink == link then result.isEquipped = true return result end
        local eqRaw = eqLink and Stats.RawForLink(eqLink)
        local eqScore, eqDerived = 0, Stats.Derive(eqRaw or {}, spec)
        if eqRaw then eqScore = Stats.Score(eqDerived, weights) end
        -- A two-hander replaces main hand + off hand.
        if equipLoc == "INVTYPE_2HWEAPON" and slot == 16 then
            local ohLink = equippedLink(17)
            local ohRaw = ohLink and Stats.RawForLink(ohLink)
            if ohRaw then
                local ohDerived = Stats.Derive(ohRaw, spec)
                eqScore = eqScore + Stats.Score(ohDerived, weights)
                for k, v in pairs(ohDerived) do eqDerived[k] = (eqDerived[k] or 0) + v end
            end
        end
        local cand = { slot = slot, link = eqLink, score = eqScore, derived = eqDerived, raw = eqRaw, empty = eqLink == nil }
        if not best or cand.score < best.score then best = cand end
    end
    result.against = best
    result.delta = result.score - best.score
    if best.score > 0 then result.pct = result.delta / best.score * 100 end
    if result.isWand and best.raw then result.wandDelta = (raw.WAND_DPS or 0) - (best.raw.WAND_DPS or 0) end
    result.statDelta = {}
    for k in pairs(Stats.LABELS) do
        local d = (new[k] or 0) - (best.derived[k] or 0)
        if math.abs(d) > 0.001 then result.statDelta[k] = d end
    end
    if C_Item and C_Item.GetItemInfo then
        local ok, _, _, _, _, minLevel = pcall(C_Item.GetItemInfo, link)
        if ok then result.minLevel = minLevel end
    end
    return result
end

Stats.UPGRADE_MIN_PCT = 1 -- ignore rounding-level gains

-- Is this a real upgrade the player can put on right now?
function Stats.IsUpgrade(res, level)
    if not res or res.unusable or res.pending or res.isEquipped or not res.delta then return false end
    if res.minLevel and level and res.minLevel > level then return false end
    if res.against and res.against.empty then return res.score > 0 end
    if res.delta <= 0.05 then return false end
    return res.pct == nil or res.pct >= Stats.UPGRADE_MIN_PCT
end

-- What a stat change means in practice, from documented conversions only.
function Stats.Effect(key, d)
    local conv = ns.Data.StatConversions
    local sign = d > 0 and "+" or "-"
    local a = math.abs(d)
    if key == "INT" and conv then
        return ("%s%d max mana, %s%.2f%% spell crit"):format(sign, math.floor(a * conv.int_mana + 0.5), sign, a / conv.int_per_crit)
    elseif key == "SPI" and conv then
        return ("%s%.1f mana per 2 sec while not casting"):format(sign, a / conv.spirit_divisor)
    elseif key == "MP5" then
        return ("%s%d mana every 5 sec, even while casting"):format(sign, a)
    elseif key == "SPELL_HIT" then
        return d > 0 and "fewer resisted spells" or "more resisted spells"
    elseif key == "SPELL_CRIT" then
        return d > 0 and "more spell crits" or "fewer spell crits"
    elseif key == "DAMAGE" then
        return d > 0 and "harder-hitting spells" or "weaker spells"
    elseif key == "OFF_SCHOOL" then
        return "doesn't help your spec's main spells"
    elseif key == "STA" then
        return d > 0 and "more health" or "less health"
    end
end
