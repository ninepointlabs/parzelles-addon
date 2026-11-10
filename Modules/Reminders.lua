-- Out-of-combat reminders: Arcane Intellect, armor, Ice Barrier (Frost),
-- conjured stock, reagents, wand. Dampen/Amplify Magic is shown as a
-- situational tip, never as "missing".
local _, ns = ...

local Reminders = {}
ns.Reminders = Reminders

Reminders.ARMORS = { "Mage Armor", "Ice Armor", "Frost Armor" }
Reminders.INTELLECT = { "Arcane Intellect", "Arcane Brilliance" }

local function itemCount(id)
    if C_Item and C_Item.GetItemCount then
        local ok, n = pcall(C_Item.GetItemCount, id)
        if ok then return n or 0 end
    end
    return 0
end
Reminders.ItemCount = itemCount

local function wandEquipped()
    local link = GetInventoryItemLink("player", 18)
    if not link then return false end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(link)
    return classID == 2 and subclassID == ns.Stats.WAND_SUBCLASS
end

-- Any of these buffs on you? true / false / nil (can't read auras right now).
local function hasAny(names)
    local unknown = false
    for _, n in ipairs(names) do
        local has = ns.Auras.PlayerHas(ns.Auras.SpellName(ns.Rotation.SpellId(n)) or n)
        if has then return true end
        if has == nil then unknown = true end
    end
    if unknown then return nil end
    return false
end

local function knowsAny(names)
    for _, n in ipairs(names) do
        if ns.Progress.Knows(n) then return n end
    end
    return nil
end

-- Returns { {id, label, ok, detail, icon} ... } for the active spec.
function Reminders.Evaluate()
    local cfg = ns.db.char.reminders
    local spec = ns.DB.ActiveSpec()
    local out = {}
    local function add(id, enabled, applies, label, ok, detail, icon)
        if enabled and applies then
            table.insert(out, { id = id, label = label, ok = ok, detail = detail, icon = icon })
        end
    end

    local int = knowsAny(Reminders.INTELLECT)
    local has = hasAny(Reminders.INTELLECT)
    add("intellect", cfg.intellect, int ~= nil, "Arcane Intellect", has ~= false,
        has == nil and "can't read auras right now" or "More mana and spell crit. Buff your group too.", ns.Rotation.Icon("Arcane Intellect"))

    local armor = knowsAny(Reminders.ARMORS)
    has = hasAny(Reminders.ARMORS)
    add("armor", cfg.armor, armor ~= nil, "Armor spell", has ~= false,
        "Frost/Ice Armor for safety, Mage Armor for mana regen (its Spirit regen was raised in Forever).", ns.Rotation.Icon(armor or "Frost Armor"))

    has = hasAny({ "Ice Barrier" })
    add("iceBarrier", cfg.iceBarrier, spec == "Frost" and ns.Progress.Knows("Ice Barrier"), "Ice Barrier", has ~= false,
        "In Forever Ice Barrier also raises your Frost damage while it's up: keep it rolling.", ns.Rotation.Icon("Ice Barrier"))

    local low = ns.Conjure.LowStock()
    local counts = ns.Conjure.Counts()
    local anyConjure = ns.Conjure.KnownSpell("water") or ns.Conjure.KnownSpell("food") or ns.Conjure.KnownSpell("gem")
    add("conjured", cfg.conjured, anyConjure ~= nil, "Conjured food & water", #low == 0,
        ("%d water, %d food, %d gem%s. Press the Conjure button out of combat."):format(counts.water, counts.food, counts.gem, counts.gem == 1 and "" or "s"),
        ns.Conjure.ICONS.water)

    -- Reagents: only for travel spells you know and only when a Forever source confirms the reagent.
    local level = UnitLevel("player") or 1
    local faction = UnitFactionGroup("player")
    local travel = ns.Travel.ForFaction(faction, level)
    for _, kind in ipairs({ "teleport", "portal" }) do
        local knowsOne
        for _, e in ipairs(travel[kind]) do if e.known then knowsOne = e end end
        local r = knowsOne and ns.Travel.Reagent(knowsOne.rec.reagent)
        if r and r.status == "confirmed" then
            local n = ns.Travel.ReagentCount(r) or 0
            add("reagents", cfg.reagents, true, r.name, n >= cfg.reagentMin, ("%d in bags (want %d+)"):format(n, cfg.reagentMin),
                "Interface\\Icons\\INV_Misc_Rune_06")
        end
    end

    add("wand", cfg.wand, level >= 5, "Wand equipped", wandEquipped(),
        "Wands are your mana-free damage: finish low enemies with it so your mana can regenerate.", "Interface\\Icons\\INV_Wand_07")

    local damp = knowsAny({ "Dampen Magic", "Amplify Magic" })
    add("dampen", cfg.dampen, damp ~= nil, "Dampen / Amplify Magic", true,
        "Situational: Dampen Magic on a target taking spell damage, Amplify Magic when your healer wants bigger heals on you.",
        ns.Rotation.Icon(damp or "Dampen Magic"))
    return out
end

-- Consumables recommended for the player's bracket.
function Reminders.Consumables(level)
    local out = {}
    for _, c in ipairs(ns.Data.Consumables or {}) do
        if c.type == "consumable" then
            local lvl = tonumber((c.bracket or ""):match("(%d+)"))
            table.insert(out, { item = c, count = c.item_id and itemCount(c.item_id) or 0, current = lvl and level >= lvl - 8 and level <= lvl + 9 })
        end
    end
    return out
end

function Reminders.Missing()
    if not ns.db.char.reminders.enabled or InCombatLockdown() then return {} end
    local miss = {}
    for _, r in ipairs(Reminders.Evaluate()) do
        if not r.ok then table.insert(miss, r) end
    end
    return miss
end
