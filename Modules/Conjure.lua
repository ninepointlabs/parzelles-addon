-- Conjured stock: counts water, food and mana gems in your bags and picks what
-- the Conjure button should make next (gem if missing, then water below the
-- target, then food). No casting here: UI/ConjureButton.lua is the secure
-- button, re-aimed out of combat; every cast needs your click or key press.
--
-- Item names/IDs for Forever's conjured items aren't all in the research, so a
-- bag item is classified by its tooltip: the "Conjured Item" line plus the "Use:"
-- text (mana over time = water, health over time = food, an instant mana range
-- = mana gem). Items listed in research (Data.Conjured) are matched by ID first.
local _, ns = ...

local Conjure = {}
ns.Conjure = Conjure

Conjure.KINDS = { "gem", "water", "food" } -- also the order the button fills them
Conjure.LABELS = { gem = "mana gem", water = "water", food = "food" }
Conjure.ICONS = {
    water = "Interface\\Icons\\INV_Drink_06",
    food = "Interface\\Icons\\INV_Misc_Food_33",
    gem = "Interface\\Icons\\INV_Misc_Gem_Emerald_01",
}

-- Which conjure spell makes which kind, from the spell's name.
function Conjure.KindOfSpell(name)
    local n = (name or ""):lower()
    if not n:find("^conjure") then return nil end
    if n:find("water") then return "water" end
    if n:find("food") then return "food" end
    if n:find("mana") or n:find("gem") or n:find("agate") or n:find("jade") or n:find("citrine") or n:find("ruby") then return "gem" end
    return nil
end

-- Conjure spells per kind, highest first-learn level first.
function Conjure.Spells(kind)
    local out = {}
    for _, s in ipairs(ns.Data.Spells) do
        if Conjure.KindOfSpell(s.display) == kind then table.insert(out, s) end
    end
    table.sort(out, function(a, b) return (a.rank_learn_levels[1] or 0) > (b.rank_learn_levels[1] or 0) end)
    return out
end

-- The spell name the button casts for a kind, or nil if none is known.
-- Casting by name without a rank uses your highest known rank.
function Conjure.KnownSpell(kind)
    for _, s in ipairs(Conjure.Spells(kind)) do
        if ns.Progress.Knows(s.display) then return s.display, s end
    end
    return nil
end

-- Research-listed conjured items by ID.
local byId
local function researchKind(itemID)
    if not byId then
        byId = {}
        for _, c in ipairs(ns.Data.Conjured or {}) do
            if c.item_id then byId[c.item_id] = c.kind end
        end
    end
    return itemID and byId[itemID]
end

-- Tooltip lines -> kind (or nil). Pure for tests.
function Conjure.Classify(lines)
    local conjured, water, food, gem = false, false, false, false
    for _, line in ipairs(lines or {}) do
        local t = tostring(line):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
        if t == "conjured item" then conjured = true end
        if t:find("^use: restores [%d%.,]+ mana over") or t:find("^use: restores [%d%.,]+ health and [%d%.,]+ mana over") then water = true end
        if t:find("^use: restores [%d%.,]+ health over") or t:find("^use: restores [%d%.,]+ health and") then food = true end
        if t:find("^use: restores [%d%.,]+ to [%d%.,]+ mana") then gem = true end
    end
    if not conjured then return nil end
    if gem then return "gem" end
    if water and not food then return "water" end
    if food and not water then return "food" end
    if water and food then return "water" end -- mana-and-health treats count as drinks
    return nil
end

local kindCache = {}
local function itemKind(itemID, link)
    local k = researchKind(itemID)
    if k then return k end
    if itemID and kindCache[itemID] ~= nil then return kindCache[itemID] or nil end
    local lines = ns.Stats.LinesForLink(link)
    if not lines or #lines < 2 then return nil end -- not cached yet; try again later
    k = Conjure.Classify(lines)
    if itemID then kindCache[itemID] = k or false end
    return k
end
Conjure.ItemKind = itemKind
function Conjure.ClearCache() kindCache, byId = {}, nil end

-- { water = n, food = n, gem = n } from your bags.
function Conjure.Counts()
    local counts = { water = 0, food = 0, gem = 0 }
    if not C_Container then return counts end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
        for slot = 1, (ok and n or 0) do
            local okInfo, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
            if okInfo and info and info.hyperlink then
                local k = itemKind(info.itemID, info.hyperlink)
                if k then counts[k] = counts[k] + (info.stackCount or 1) end
            end
        end
    end
    return counts
end

function Conjure.Targets()
    local cfg = ns.db.char.conjure
    return { water = cfg.water, food = cfg.food, gem = cfg.gem }
end

-- What to conjure next: { kind, spell, have, want } or nil (+ reason).
function Conjure.Next(counts, targets, knownSpell)
    counts = counts or Conjure.Counts()
    targets = targets or Conjure.Targets()
    knownSpell = knownSpell or Conjure.KnownSpell
    local anyKnown = false
    for _, kind in ipairs(Conjure.KINDS) do
        local spell = knownSpell(kind)
        if spell then
            anyKnown = true
            if (targets[kind] or 0) > 0 and (counts[kind] or 0) < targets[kind] then
                return { kind = kind, spell = spell, have = counts[kind] or 0, want = targets[kind] }
            end
        end
    end
    return nil, anyKnown and "stocked up" or "no conjure spells known yet"
end

-- Labels of kinds you know and are short of (for the Home nudge and login line).
function Conjure.LowStock(counts, targets, knownSpell)
    counts = counts or Conjure.Counts()
    targets = targets or Conjure.Targets()
    knownSpell = knownSpell or Conjure.KnownSpell
    local low = {}
    for _, kind in ipairs(Conjure.KINDS) do
        if knownSpell(kind) and (targets[kind] or 0) > 0 and (counts[kind] or 0) < targets[kind] then
            table.insert(low, Conjure.LABELS[kind])
        end
    end
    return low
end
