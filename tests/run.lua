-- Headless tests. Run from the repo root:  lua5.1 tests/run.lua
package.path = "./tests/?.lua;" .. package.path
local M = require("wow_mock")
M.Install()
local S = M.state

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1 io.stderr:write("FAIL " .. name .. ": " .. tostring(err) .. "\n") end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end
local function near(a, b, msg) if math.abs(a - b) > 1e-6 then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end
local function truthy(v, msg) if not v then error(msg or "expected truthy", 2) end end
local function textHas(pattern)
    for _, t in ipairs(M.texts) do if t:find(pattern, 1, true) then return true end end
    return false
end

local ns = M.LoadAddon("ParzellesAddon_Forever.toc", ".")

-- Mark a spell as known by name (by research ID when there is one, else by name).
local function know(name)
    local id = ns.Rotation.SpellId(name)
    if id then S.known[id] = true end
    S.knownNames[name] = true
end
local function forget()
    S.known, S.knownNames = {}, {}
end

local function renderAll(label)
    for _, key in ipairs(ns.PanelOrder) do
        M.texts = {}
        ns.UI.Open(key)
        for _, t in ipairs(M.texts) do
            if t:find("This panel hit an error", 1, true) then error(label .. "/" .. key .. ": " .. t) end
        end
    end
end

local SUBS = {
    leveling = { "Path", "Zones & dungeons", "Trainer", "Class quests", "Riding & gold", "Portals & teleports" },
    gear = { "For my level", "Best overall", "By bracket", "Consumables", "Weights" },
    settings = { "General", "Conjure button", "Tooltips & bags", "Reminders", "About the data", "About" },
    learn = { "Lessons", "Spells", "Talents", "How the class works", "In a group", "Leveling", "Common mistakes" },
    rotation = { "Solo", "Dungeon", "Raid", "Crowd control", "Mana" },
}
local function renderSubs(label)
    for key, list in pairs(SUBS) do
        for _, sub in ipairs(list) do
            M.texts = {}
            ns.UI.Open(key, sub)
            for _, t in ipairs(M.texts) do
                if t:find("This panel hit an error", 1, true) then error(label .. "/" .. key .. "/" .. sub .. ": " .. t) end
            end
        end
    end
    ns.UI.Open("rotation", "Solo")
end

test("toc files match between plain and _Forever", function()
    local a, b = io.open("ParzellesAddon.toc"):read("*a"), io.open("ParzellesAddon_Forever.toc"):read("*a")
    eq(a, b)
    truthy(a:find("## Interface: 16001", 1, true), "interface")
    truthy(a:find("## X-Website: https://github.com/ninepointlabs/parzelles-addon", 1, true), "website")
    truthy(a:find("## Title: Parzelle's Addon", 1, true), "title")
    truthy(a:find("## SavedVariables: ParzellesAddonDB", 1, true), "saved variables")
end)

test("generated data present", function()
    truthy(#ns.Data.Spells >= 30, "spells")
    for _, spec in ipairs(ns.SPEC_ORDER) do
        truthy(ns.Data.Learn and ns.Data.Learn.rotation and ns.Data.Learn.rotation[spec] and ns.Data.Learn.rotation[spec].solo, "learn rotation " .. spec)
        truthy(ns.Data.StatPriority[spec], "stat priority " .. spec)
    end
    eq(ns.Data.Meta.toc_interface, 16001)
    truthy(ns.Rotation.SpellId("Frostbolt"), "Frostbolt id")
    truthy(ns.Rotation.SpellId("Polymorph"), "Polymorph id")
end)

-- Login: Parzelle, level 8, no talents, no spec.
S.level = 8
M.Fire("ADDON_LOADED", "ParzellesAddon")
M.Fire("PLAYER_LOGIN")
M.RunTimers()

test("login creates profile A/B with no spec", function()
    truthy(ns.db and ns.db.char.profiles.A and ns.db.char.profiles.B)
    eq(ns.DB.ActiveSpec(), nil)
    truthy(SlashCmdList.PARZELLESADDON, "slash")
    eq(SLASH_PARZELLESADDON1, "/parzelle")
    eq(SLASH_PARZELLESADDON2, "/mage")
    eq(ns.isMage, true)
    eq(ns.Progress.PlayerRace(), "Skyborne")
end)

test("level 8, no talents, no spec: every screen renders and the picker recommends a leveling spec", function()
    S.level = 8
    renderAll("no spec")
    renderSubs("no spec")
    M.texts = {}
    ns.UI.ShowPicker()
    truthy(textHas("talents start at 10"), "picker explains no talents yet")
    truthy(textHas("recommended for leveling"), "recommended badge")
    truthy(textHas(ns.RECOMMENDED_LEVELING_SPEC .. " (safest)"))
    M.texts = {}
    ns.UI.Open("home")
    truthy(textHas("No talents yet"), "home nudge")
    M.texts = {}
    ns.UI.Open("talents")
    truthy(textHas("Pick a spec first"))
end)

test("dual-spec ready profiles", function()
    local fired = 0
    ns.On("SPEC_CHANGED", function() fired = fired + 1 end)
    ns.DB.SetSpec("Frost")
    ns.DB.SetSpec("Fire", "B")
    eq(ns.DB.ActiveSpec(), "Frost")
    truthy(ns.DB.SwitchProfile("B"))
    eq(ns.DB.ActiveSpec(), "Fire")
    eq(ns.DB.SwitchProfile("B"), false)
    ns.DB.SwitchProfile("A")
    eq(fired, 3, "SPEC_CHANGED fires on active changes only")
    truthy(M.events.ACTIVE_TALENT_GROUP_CHANGED, "dual-spec event registered")
    eq(ns.db.char.autoSwitch, true)
    S.numSpecGroups, S.specGroup = 2, 2
    eq(ns.DualSpec.HasDualSpec(), true)
    M.Fire("ACTIVE_TALENT_GROUP_CHANGED", 2, 1)
    eq(ns.DB.ActiveId(), "B")
    eq(ns.DB.ActiveSpec(), "Fire")
    S.specGroup = 1
    M.Fire("ACTIVE_TALENT_GROUP_CHANGED", 1, 2)
    eq(ns.DB.ActiveId(), "A")
    ns.db.char.autoSwitch = false
    M.Fire("ACTIVE_TALENT_GROUP_CHANGED", 2, 1)
    eq(ns.DB.ActiveId(), "A", "no switch when disabled")
    ns.db.char.autoSwitch = true
    S.specGroup = 2
    truthy(ns.DualSpec.Sync(), "sync to active group")
    eq(ns.DB.ActiveId(), "B")
    S.specGroup = 1
    ns.DualSpec.Sync()
    S.numSpecGroups = 1
end)

test("DB.Init keeps saved values and fills defaults", function()
    local acc, ch = ns.DB.Init({ percentScale = 14 }, { active = "B", profiles = { B = { spec = "Arcane" } } })
    eq(acc.percentScale, 14)
    eq(ch.active, "B")
    eq(ch.profiles.B.spec, "Arcane")
    eq(ch.profiles.A.rotationContext, "solo")
    eq(ch.conjure.water, 20)
    eq(ch.conjure.key, nil, "no key bound by default")
    ns.DB.Init(ParzellesAddonDB, ParzellesAddonCharDB)
end)

test("stat parsing and per-spec school damage", function()
    local raw = ns.Stats.ParseLines({
        "Robe of Testing", "+7 Intellect", "+5 Spirit", "+4 Stamina",
        "Equip: Increases damage and healing done by magical spells and effects by up to 12.",
        "Equip: Improves your chance to get a critical strike with spells by 1%.",
        "Equip: Improves your chance to hit with spells by 2%.",
        "Equip: Restores 3 mana per 5 sec.",
        "Equip: Increases damage done by Fire spells and effects by up to 6.",
        "Equip: Increases damage done by Frost spells and effects by up to 9.",
        "(2) Set: +10 Intellect", "Use: Restores 375 mana.",
        "|cff00ff00Equip: Increases damage done by magical spells and effects by up to 4.|r",
        "Equip: Increases healing done by magical spells and effects by up to 20.",
    })
    eq(raw.INT, 7); eq(raw.SPI, 5); eq(raw.STA, 4); eq(raw.SPELL_POWER, 12)
    eq(raw.SPELL_CRIT, 1); eq(raw.SPELL_HIT, 2); eq(raw.MP5, 3); eq(raw.FIRE_DAMAGE, 6); eq(raw.FROST_DAMAGE, 9); eq(raw.SPELL_DAMAGE, 4)
    local fire = ns.Stats.Derive(raw, "Fire")
    eq(fire.DAMAGE, 12 + 4 + 6, "fire counts fire damage"); eq(fire.OFF_SCHOOL, 9)
    local frost = ns.Stats.Derive(raw, "Frost")
    eq(frost.DAMAGE, 12 + 4 + 9); eq(frost.OFF_SCHOOL, 6)
    eq(ns.Stats.Derive(raw, "Arcane").DAMAGE, 16, "healing power doesn't count for a mage")
    eq(ns.Stats.ParseLines({ "x", "(16.5 damage per second)" }).WAND_DPS, 16.5)
end)

test("weights derive from priority order", function()
    for _, spec in ipairs(ns.SPEC_ORDER) do
        local prio = ns.Data.StatPriority[spec]
        local w = ns.Stats.Weights(spec, 10)
        local n = #prio.keys
        for r, k in ipairs(prio.keys) do
            local expect = (n - r + 1) / n
            if ns.Stats.PERCENT_KEYS[k] then expect = expect * 10 end
            near(w[k], expect, spec .. " " .. k)
        end
        eq(ns.Stats.WeightSetName(spec, 30, {}), spec)
    end
end)

-- Item fixtures
local NEW, OLD, RING1, RING2, PLATE, SWORD = "item:1001", "item:1002", "item:1003", "item:1004", "item:1005", "item:1007"
S.itemInfo[1001] = { equipLoc = "INVTYPE_CHEST", classID = 4, subclassID = 1 }
S.itemInfo[1002] = { equipLoc = "INVTYPE_ROBE", classID = 4, subclassID = 1 }
S.itemInfo[1003] = { equipLoc = "INVTYPE_FINGER", classID = 4, subclassID = 0 }
S.itemInfo[1004] = { equipLoc = "INVTYPE_FINGER", classID = 4, subclassID = 0 }
S.itemInfo[1005] = { equipLoc = "INVTYPE_CHEST", classID = 4, subclassID = 4 }
S.itemInfo[1007] = { equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 7 }
S.itemLines[NEW] = { "New", "+10 Intellect", "Equip: Increases damage done by Frost spells and effects by up to 12." }
S.itemLines[OLD] = { "Old", "+10 Intellect", "+10 Spirit" }
S.itemLines[RING1] = { "R1", "+3 Intellect" }
S.itemLines[RING2] = { "R2", "+8 Intellect" }
S.itemLines[PLATE] = { "Plate", "+20 Stamina" }
S.itemLines[SWORD] = { "Sword", "+5 Intellect" }
S.equipped[5] = OLD
S.equipped[11] = RING1
S.equipped[12] = RING2

test("compare: school matters, plate unusable, swords usable", function()
    ns.Stats.ClearCache()
    local frost = ns.Stats.Compare(NEW, "Frost", 30, {}, 10)
    truthy(frost.delta > 0, "frost robe is a frost upgrade")
    local fire = ns.Stats.Compare(NEW, "Fire", 30, {}, 10)
    truthy(fire.delta < frost.delta, "worth less to fire")
    eq(ns.Stats.Compare(PLATE, "Frost", 30, {}, 10).unusable, true)
    truthy(not ns.Stats.Compare(SWORD, "Frost", 30, {}, 10).unusable, "mages use one-hand swords")
end)

test("compare: rings replace the weaker ring", function()
    eq(ns.Stats.Compare(OLD, "Frost", 30, {}, 10).isEquipped, true)
    S.itemInfo[1006] = { equipLoc = "INVTYPE_FINGER", classID = 4, subclassID = 0 }
    S.itemLines["item:1006"] = { "R3", "+5 Intellect" }
    local res = ns.Stats.Compare("item:1006", "Frost", 30, {}, 10)
    eq(res.against.slot, 11, "compares to weaker ring")
    truthy(res.delta > 0)
end)

test("tooltip lines", function()
    local all = table.concat(ns.Tooltip.LinesFor(NEW, "Frost", {}, 30, 10), "\n")
    truthy(all:find("Spell damage (your school)", 1, true), all)
    truthy(all:find("addon assumption", 1, true))
    truthy(M.tooltipHook, "tooltip hook installed via TooltipDataProcessor")
    all = table.concat(ns.Tooltip.LinesFor(PLATE, "Frost", {}, 30, 10), "\n")
    truthy(all:find("Mages can't use this", 1, true))
    all = table.concat(ns.Tooltip.LinesFor(NEW, "Fire", {}, 30, 10), "\n")
    truthy(all:find("not your school", 1, true), "frost damage is off-school for fire")
end)

test("training: faction and talent filtering", function()
    local seenHorde, seenAlliance = false, false
    for lvl = 1, 60 do
        for _, e in ipairs(ns.Training.At(lvl, "Frost", "Alliance")) do
            if e.spell.faction == "Horde" then seenHorde = true end
            if e.spell.faction == "Alliance" then seenAlliance = true end
            if e.spell.talent then eq(e.spell.talent_tree, "Frost", "only Frost talent spells for Frost: " .. e.spell.name) end
        end
    end
    eq(seenHorde, false, "no Horde teleports/portals for an Alliance mage")
    truthy(seenAlliance, "Alliance teleports listed")
    truthy(ns.Training.NextLevel(8, "Frost"), "a next trainer level after 8")
    eq(ns.Training.NextLevel(60, "Frost"), nil)
end)

test("quests: Skyborne Alliance mage sees Boughs in the Wind, not Horde quests", function()
    local list = ns.Progress.ClassQuests("Skyborne", "Alliance")
    local boughs = false
    for _, q in ipairs(list) do
        if q.name == "Boughs in the Wind" then boughs = true eq(q.level, 10) end
        truthy(q.faction ~= "Horde", "no Horde quest: " .. q.name)
    end
    truthy(boughs, "Boughs in the Wind listed")
    local nextQ = ns.Progress.NextClassQuest("Skyborne", "Alliance", 8)
    truthy(nextQ, "next class quest at level 8")
end)

test("gold goals from research", function()
    local g = ns.Progress.GoldGoals()
    eq(g[1].gold, 100); eq(g[1].level, 40)
    eq(g[2].gold, 1000); eq(g[2].level, 60)
end)

-- Rotation engine with a fake state
local function fakeState(o)
    return {
        inCombat = function() return o.combat or false end,
        hasTarget = function() return o.target ~= false end,
        spellName = function(n) return n end,
        playerBuff = function(n) return o.buffs and o.buffs[n] or false end,
        playerDebuff = function(n) return o.debuffs and o.debuffs[n] or false end,
        playerStacks = function(n) return o.stacks and o.stacks[n] or 0 end,
        targetDebuff = function(n) return o.tdebuffs and o.tdebuffs[n] or false end,
        targetFrozen = function() return o.frozen or false end,
        cooldown = function(n) return o.cds and o.cds[n] or 0 end,
        manaPct = function() return o.mana or 100 end,
        targetHpPct = function() return o.hp or 100 end,
        known = function(n) return o.known == nil or o.known[n] == true end,
    }
end

test("rotation: every step uses a supported condition and a researched spell", function()
    for spec, ctxs in pairs(ns.Data.Learn.rotation) do
        for ctxName, ctx in pairs(ctxs) do
            truthy(#ctx.priority > 0, spec .. "/" .. ctxName .. " empty")
            for _, step in ipairs(ctx.priority) do
                local r = ns.Rotation.Check(step, fakeState({}))
                truthy(r ~= nil, ("%s/%s: condition %s unsupported"):format(spec, ctxName, tostring(step.when)))
                truthy(step.spell == "Wand" or ns.Rotation.IsKnownName(step.spell), ("%s/%s: unknown spell %s"):format(spec, ctxName, step.spell))
            end
        end
    end
end)

test("rotation: conditions", function()
    local C = ns.Rotation.Check
    eq(C({ spell = "Ice Lance", when = "frozen_or_proc:Fingers of Frost" }, fakeState({ frozen = true })), true)
    eq(C({ spell = "Ice Lance", when = "frozen_or_proc:Fingers of Frost" }, fakeState({ buffs = { ["Fingers of Frost"] = true } })), true)
    eq(C({ spell = "Ice Lance", when = "frozen_or_proc:Fingers of Frost" }, fakeState({})), false)
    eq(C({ spell = "Arcane Blast", when = "stacks_below:Arcane Blast:4" }, fakeState({ stacks = { ["Arcane Blast"] = 2 } })), true)
    eq(C({ spell = "Arcane Blast", when = "stacks_below:Arcane Blast:4" }, fakeState({ stacks = { ["Arcane Blast"] = 4 } })), false)
    eq(C({ spell = "Arcane Missiles", when = "stacks_at_least:Arcane Blast:4" }, fakeState({ stacks = { ["Arcane Blast"] = 4 } })), true)
    eq(C({ spell = "Blizzard", when = "manual" }, fakeState({})), false)
    eq(C({ spell = "Frost Nova", when = "target_frozen" }, fakeState({ frozen = true })), true)
    eq(C({ spell = "Evocation", when = "mana_below:20" }, fakeState({ mana = 10 })), true)
end)

test("rotation: frost solo suggestion follows state", function()
    local ctx = ns.Rotation.Context("Frost", "solo")
    -- Everything known, nothing on cooldown, buffs up: the first unconditional nuke wins.
    local buffs = {}
    for _, step in ipairs(ctx.priority) do if step.when == "buff_missing" then buffs[step.spell] = true end end
    local s = ns.Rotation.Suggest("Frost", "solo", fakeState({ buffs = buffs, mana = 80 }), 3)
    truthy(#s > 0, "something suggested")
    for _, step in ipairs(s) do truthy(step.when ~= "buff_missing" and step.when ~= "manual", "no satisfied buff steps / manual steps suggested") end
    -- Only Frostbolt known: Frostbolt it is.
    local only = ns.Rotation.Suggest("Frost", "solo", fakeState({ known = { Frostbolt = true }, buffs = buffs }), 1)
    eq(only[1] and only[1].spell, "Frostbolt")
end)

test("rotation shows only spells usable at your level (level 8, no talents)", function()
    local savedLevel = S.level
    S.level = 8
    forget()
    know("Frostbolt"); know("Fireball"); know("Arcane Missiles")
    eq(ns.Rotation.Availability("Frostbolt", 8, "Skyborne", "Alliance"), "known")
    eq(ns.Rotation.Availability("Blizzard", 8, "Skyborne", "Alliance"), nil, "Blizzard not before its level")
    eq(ns.Rotation.Availability("Ice Lance", 8, "Skyborne", "Alliance"), nil, "talent not taken")
    -- other faction's teleport never shows
    for _, sp in ipairs(ns.Data.Spells) do
        if sp.faction == "Horde" then eq(ns.Rotation.Availability(sp.name, 60, "Skyborne", "Alliance"), nil, sp.name) end
    end
    ns.DB.SetSpec("Frost")
    ns.DB.Profile().rotationContext = "solo"
    M.texts = {}
    ns.UI.Open("rotation", "Solo")
    truthy(textHas(". Frostbolt"), "Frostbolt step shown")
    truthy(not textHas(". Blizzard"), "Blizzard hidden at 8")
    truthy(textHas("unlock with levels or talents"))
    forget()
    S.level = savedLevel
end)

test("conjure: classify tooltips, count stock, pick what's needed", function()
    local K = ns.Conjure.Classify
    eq(K({ "Conjured Water", "Conjured Item", "Use: Restores 1344 mana over 30 sec." }), "water")
    eq(K({ "Conjured Bread", "Conjured Item", "Use: Restores 874 health over 27 sec." }), "food")
    eq(K({ "Mana Agate", "Conjured Item", "Use: Restores 375 to 425 mana." }), "gem")
    eq(K({ "Refreshing Spring Water", "Use: Restores 151 mana over 18 sec." }), nil, "bought water isn't conjured")
    S.itemLines["item:9001"] = { "Conjured Water", "Conjured Item", "Use: Restores 1344 mana over 30 sec." }
    S.itemLines["item:9002"] = { "Conjured Bread", "Conjured Item", "Use: Restores 874 health over 27 sec." }
    S.bagSlots = { [0] = { "item:9001", "item:9002" } }
    S.bagStacks = { ["item:9001"] = 12, ["item:9002"] = 20 }
    ns.Conjure.ClearCache()
    local c = ns.Conjure.Counts()
    eq(c.water, 12); eq(c.food, 20); eq(c.gem, 0)
    local knowsAll = function() return "Conjure X" end
    local nxt = ns.Conjure.Next(c, { water = 20, food = 20, gem = 1 }, knowsAll)
    eq(nxt.kind, "gem", "gem first when missing")
    nxt = ns.Conjure.Next(c, { water = 20, food = 20, gem = 0 }, knowsAll)
    eq(nxt.kind, "water"); eq(nxt.have, 12)
    local _, reason = ns.Conjure.Next({ water = 20, food = 20, gem = 1 }, { water = 20, food = 20, gem = 1 }, knowsAll)
    eq(reason, "stocked up")
    _, reason = ns.Conjure.Next(c, nil, function() return nil end)
    eq(reason, "no conjure spells known yet")
    eq(ns.Conjure.KindOfSpell("Conjure Water"), "water")
    eq(ns.Conjure.KindOfSpell("Conjure Mana Agate"), "gem")
    eq(ns.Conjure.KindOfSpell("Conjure Food"), "food")
    eq(#ns.Conjure.LowStock(c, { water = 20, food = 20, gem = 0 }, knowsAll), 1)
end)

test("conjure button: secure spell button, highest rank by name, key binding, combat freeze", function()
    forget()
    eq(ns.ConjureButton.ShouldShow(), false, "hidden until you know a conjure spell")
    local water = ns.Conjure.Spells("water")[1]
    truthy(water, "a conjure water spell in the research")
    know(water.display)
    ns.ConjureButton.Refresh()
    local b = _G.ParzellesConjureButton
    truthy(b, "button exists")
    eq(b:GetAttribute("type"), "spell")
    eq(b:GetAttribute("spell"), water.display, "casts by name: highest known rank")
    eq(b:GetAttribute("useOnKeyDown"), nil, "acts on release")
    truthy(b.stock:GetText():find("W 12", 1, true), "stock count shown")
    -- stocked up: disarmed
    ns.db.char.conjure.water = 10
    ns.ConjureButton.Update()
    eq(b:GetAttribute("type"), nil, "nothing to conjure -> disarmed")
    ns.db.char.conjure.water = 20
    -- combat: frozen
    S.combat = true
    ns.db.char.conjure.water = 10
    ns.ConjureButton.Update()
    eq(b:GetAttribute("type"), nil, "doesn't re-aim in combat")
    S.combat = false
    ns.db.char.conjure.water = 20
    ns.ConjureButton.Update()
    eq(b:GetAttribute("type"), "spell")
    -- key binding via override click; Super/Meta refused; no key by default
    eq(ns.db.char.conjure.key, nil)
    eq(ns.ConjureButton.KeyString("LSHIFT"), nil, "modifier alone ignored")
    S.meta = true
    eq(ns.ConjureButton.KeyString("F"), nil, "Super/Meta combos refused (Omarchy)")
    S.meta = false
    S.shift = true
    eq(ns.ConjureButton.KeyString("F"), "SHIFT-F")
    S.shift = false
    ns.ConjureButton.SetKey("SHIFT-F")
    eq(M.overrides["SHIFT-F"], "ParzellesConjureButton:LeftButton")
    eq(b.hotkey:GetText(), "SHIFT-F")
    ns.ConjureButton.SetKey(nil)
    eq(next(M.overrides), nil, "cleared")
    S.combat = true
    ns.ConjureButton.SetKey("G")
    eq(ns.db.char.conjure.key, nil, "can't rebind in combat")
    S.combat = false
    ns.ConjureButton.StartKeyCapture()
    local cap = _G.ParzellesConjureKeyCapture
    cap.__scripts.OnKeyDown(cap, "G")
    eq(ns.db.char.conjure.key, "G", "captured key saved")
    ns.ConjureButton.SetKey(nil)
    ns.ConjureButton.Debug()
    for _, m in ipairs(M.macros) do error("no macros may be created: " .. m.name) end
    forget()
end)

test("portals & teleports: own faction only, travel bar of secure buttons", function()
    forget()
    S.level = 40
    local t = ns.Travel.ForFaction("Alliance", 40)
    truthy(#t.teleport > 0, "Alliance teleports in research")
    for _, kind in ipairs({ "teleport", "portal" }) do
        for _, e in ipairs(t[kind]) do truthy(e.rec.faction ~= "Horde", "no Horde: " .. e.rec.name) end
    end
    eq(#ns.Travel.ForFaction("Alliance", 40).teleport, #t.teleport)
    know(t.teleport[1].rec.name)
    ns.TravelBar.Show()
    truthy(ns.TravelBar.IsShown(), "bar shown")
    local b1 = _G.ParzellesTravelButton1
    eq(b1:GetAttribute("type"), "spell")
    eq(b1:GetAttribute("spell"), t.teleport[1].rec.name)
    S.bind = t.teleport[1].rec.city or t.teleport[1].rec.name:match(":%s*(.+)$")
    local refreshed = ns.Travel.ForFaction("Alliance", 40)
    truthy(ns.Travel.HearthHint(refreshed.teleport), "hearth hint when bound to a teleport city")
    S.bind = nil
    M.texts = {}
    ns.UI.Open("leveling", "Portals & teleports")
    truthy(textHas("Travel bar"))
    for _, txt in ipairs(M.texts) do truthy(not txt:find("Orgrimmar", 1, true), "Horde city shown: " .. txt) end
    S.combat = true
    ns.TravelBar.Hide()
    truthy(ns.TravelBar.IsShown(), "can't close secure bar in combat")
    S.combat = false
    ns.TravelBar.Hide()
    truthy(not ns.TravelBar.IsShown())
    forget()
    S.level = 24
end)

test("CC tracker: polymorph timer and early break warning", function()
    forget()
    know("Polymorph")
    local polyId = ns.Rotation.SpellId("Polymorph")
    S.spellNames = { [polyId] = "Polymorph" }
    S.target, S.targetName, S.targetGUID = true, "Kobold", "MOB1"
    S.targetAuras = {}
    S.time = 2000
    M.Fire("UNIT_SPELLCAST_SENT", "player", "Kobold", "cast", polyId)
    ns.CC.OnCast(polyId, 2000)
    S.targetAuras = { Polymorph = { expirationTime = 2050 } }
    ns.CC.Scan(2001)
    eq(ns.CC.Current().state, "active")
    truthy(ns.CC.StatusText(2010):find("Kobold 40s", 1, true), ns.CC.StatusText(2010))
    local said = {}
    local realPrint = ns.Print
    ns.Print = function(m) table.insert(said, tostring(m)) end
    S.targetAuras = {}
    ns.CC.Scan(2010)
    ns.Print = realPrint
    eq(ns.CC.Current().state, "broken")
    truthy(table.concat(said, "\n"):find("broke early", 1, true), "break warning")
    -- hidden auras degrade gracefully
    ns.CC.OnCast(polyId, 2100)
    local realFind = ns.Auras.Find
    ns.Auras.Find = function() return nil end
    ns.CC.Scan(2101)
    eq(ns.CC.Current().state, "hidden")
    truthy(ns.CC.StatusText(2101):find("hidden", 1, true))
    ns.Auras.Find = realFind
    ns.CC.Reset()
    S.spellNames, S.targetName, S.targetGUID, S.time = nil, nil, nil, nil
    forget()
end)

test("summary tips", function()
    local knows = function() return true end
    local f = { duration = 20, manaStart = 90, manaEnd = 10, casts = { ["Arcane Blast"] = 6 }, order = { "Arcane Blast" }, hidden = 0 }
    local tips = table.concat(ns.Summary.Tips(f, "Arcane", "solo", knows), "\n")
    truthy(tips:find("Arcane Missiles", 1, true), tips)
    truthy(tips:find("wand", 1, true), "wand tip at low mana")
    f = { duration = 20, manaStart = 90, manaEnd = 60, casts = { ["Frost Nova"] = 1, Frostbolt = 4 }, order = {}, hidden = 0 }
    truthy(table.concat(ns.Summary.Tips(f, "Frost", "solo", knows), "\n"):find("Ice Lance", 1, true))
    f = { duration = 20, manaStart = 90, manaEnd = 10, casts = { Fireball = 5 }, order = {}, hidden = 2 }
    tips = table.concat(ns.Summary.Tips(f, "Fire", "dungeon", knows, 1), "\n")
    truthy(tips:find("Pyroblast", 1, true)); truthy(tips:find("mana gem", 1, true)); truthy(tips:find("hidden", 1, true))
    ns.Summary.Start(0, 90)
    eq(ns.Summary.Finish(2, 90), nil, "too short")
end)

test("changes: research baseline unread, mark read", function()
    local n = ns.Changes.UnreadCount()
    truthy(n >= 3, "research changes")
    ns.Changes.MarkRead(ns.Changes.All()[1])
    eq(ns.Changes.UnreadCount(), n - 1)
    ns.Changes.MarkAllRead()
    eq(ns.Changes.UnreadCount(), 0)
end)

test("learn: lessons unlock by level, hints after first scan", function()
    local unlocked, upcoming = ns.Learn.Lessons(24, "Frost")
    truthy(#unlocked > 0 and #upcoming > 0)
    forget()
    ns.db.char.learn.seenSpells = { Fireball = true }
    know("Frostbolt")
    ns.Learn.ScanSpells(false)
    truthy(ns.db.char.learn.seenSpells.Frostbolt, "marks new spell seen")
    forget()
end)

test("reminders", function()
    forget()
    know("Arcane Intellect"); know("Frost Armor")
    S.auras = { ["Frost Armor"] = true }
    S.level = 24
    local miss = ns.Reminders.Missing()
    local labels = {}
    for _, r in ipairs(miss) do labels[r.label] = true end
    truthy(labels["Arcane Intellect"], "AI missing")
    truthy(labels["Wand equipped"], "wand missing")
    truthy(not labels["Armor spell"], "armor up")
    S.auras = {}
    forget()
end)

test("every panel and sub-tab renders for every spec (level 24 and level 8)", function()
    for _, lvl in ipairs({ 24, 8, 60 }) do
        S.level = lvl
        for _, spec in ipairs(ns.SPEC_ORDER) do
            ns.DB.SetSpec(spec)
            renderAll(spec .. "@" .. lvl)
            renderSubs(spec .. "@" .. lvl)
        end
    end
    S.level = 24
    eq(#ns.PanelOrder, 8, "8 screens")
    for _, old in ipairs({ "overview", "training", "quests", "mounts", "reminders", "sources", "options", "changes", "portals", "cc", "mana", "conjure" }) do
        ns.UI.Open(old)
    end
    truthy(#ns.UI.Search("frost") > 0, "search finds Frost spells")
    eq(#ns.UI.Search("f"), 0, "search needs 2+ characters")
end)

test("no Priest or Andric text anywhere in the window", function()
    local bad = {}
    for _, spec in ipairs(ns.SPEC_ORDER) do
        ns.DB.SetSpec(spec)
        for key, list in pairs(SUBS) do
            for _, sub in ipairs(list) do
                M.texts = {}
                ns.UI.Open(key, sub)
                for _, t in ipairs(M.texts) do
                    if t:find("Andric", 1, true) or t:find("Priest", 1, true) then bad[#bad + 1] = key .. "/" .. sub .. ": " .. t end
                end
            end
        end
    end
    eq(#bad, 0, table.concat(bad, "\n"))
end)

test("talent builds decode onto Forever's trees", function()
    eq(#ns.Data.TalentTrees, 3, "three trees")
    local valid, valid60 = 0, 0
    for _, b in ipairs(ns.Data.DecodedBuilds) do
        if b.valid then
            valid = valid + 1
            for ti, tree in ipairs(ns.Data.TalentTrees) do
                eq(#b.trees[ti].points, #tree.talents, "points per talent")
                for i, t in ipairs(tree.talents) do truthy(b.trees[ti].points[i] <= t.max_rank) end
            end
            if b.level == 60 then valid60 = valid60 + 1 eq(b.total, 51) end
            truthy(b.total <= 51)
        else
            truthy(b.reason and b.reason ~= "", "invalid builds say why")
        end
    end
    truthy(valid > 0, "at least one build draws")
    for _, spec in ipairs(ns.SPEC_ORDER) do
        ns.DB.SetSpec(spec)
        M.texts = {}
        ns.UI.Open("talents")
        truthy(textHas("points (level"), spec .. " build summary line")
    end
end)

test("gear: my-level view vs best overall", function()
    S.level = 24
    ns.Data.GearBrackets["level 20"] = ns.Data.GearBrackets["level 20"] or {}
    table.insert(ns.Data.GearBrackets["level 20"], { name = "Testing Robe Low", item_id = 8801, source = "Test Dungeon" })
    table.insert(ns.Data.GearBrackets["level 20"], { name = "Testing Robe High", item_id = 8802, source = "Test Dungeon" })
    S.itemInfo[8801] = { equipLoc = "INVTYPE_ROBE", classID = 4, subclassID = 1, minLevel = 18 }
    S.itemInfo[8802] = { equipLoc = "INVTYPE_ROBE", classID = 4, subclassID = 1, minLevel = 31 }
    S.itemLines["item:8801"] = { "Robe", "+6 Intellect", "+5 Spirit" }
    S.itemLines["item:8802"] = { "Robe", "+40 Intellect", "+30 Spirit" }
    ns.Stats.ClearCache()
    ns.DB.SetSpec("Frost")
    ns.UI.SetGearView("mine")
    M.texts = {}
    ns.UI.Open("gear")
    truthy(not textHas("Testing Robe High"), "level-31 item hidden at 24")
    ns.UI.SetGearView("best")
    M.texts = {}
    ns.UI.Refresh()
    truthy(textHas("Testing Robe High"), "best overall includes higher-level items")
    ns.UI.SetGearView("mine")
end)

test("bags: highlight + one-time announcement", function()
    ns.DB.SetSpec("Frost")
    S.level = 30
    S.bagSlots = { [0] = { NEW, PLATE } }
    S.bagStacks = {}
    ns.Bags.Reset()
    local printed = 0
    local realPrint = ns.Print
    ns.Print = function(m) if tostring(m):find("Upgrade in your bags", 1, true) then printed = printed + 1 end end
    local found = ns.Bags.Scan(false)
    eq(#found, 1, "robe is an upgrade, plate is not")
    ns.Bags.Scan(false)
    eq(printed, 1, "announced once")
    ns.Print = realPrint
    ns.Bags.RefreshAll()
    truthy(rawget(M.bagButtons[1], "ParzellesUpgrade") and rawget(M.bagButtons[1], "ParzellesUpgrade").__shown, "upgrade highlighted")
    truthy(not (rawget(M.bagButtons[2], "ParzellesUpgrade") and rawget(M.bagButtons[2], "ParzellesUpgrade").__shown), "plate not highlighted")
    S.bagSlots = {}
end)

test("map pin helpers", function()
    local e = ns.Map.FindDungeonEntrance("Wailing Caverns")
    truthy(e, "entrance from client map data")
    M.waypoints = {}
    truthy(ns.Map.SetWaypoint(e.mapID, e.x, e.y, "WC"))
    eq(M.waypoints[1].mapID, 10); eq(M.superTracked, true)
end)

test("About names Parzelle Starfall", function()
    M.texts = {}
    SlashCmdList.PARZELLESADDON("about")
    truthy(textHas("Parzelle Starfall"), "About tab shows Parzelle's full name")
    truthy(textHas("parzellesaddon.myazerothlife.com"), "website link")
end)

test("slash commands", function()
    SlashCmdList.PARZELLESADDON("spec fire")
    eq(ns.DB.ActiveSpec(), "Fire")
    SlashCmdList.PARZELLESADDON("profile")
    eq(ns.DB.ActiveId(), "B")
    SlashCmdList.PARZELLESADDON("profile A")
    for _, cmd in ipairs({ "gear", "portals", "cc", "mana", "conjure", "conjure debug", "bogus", "" }) do SlashCmdList.PARZELLESADDON(cmd) end
end)

test("events: level up, combat, casts", function()
    S.level = 26
    M.Fire("PLAYER_LEVEL_UP", 26)
    S.combat = true
    M.Fire("PLAYER_REGEN_DISABLED")
    M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", ns.Rotation.SpellId("Frostbolt"))
    S.time = 1030
    S.combat = false
    M.Fire("PLAYER_REGEN_ENABLED")
    M.Fire("SPELLS_CHANGED")
    M.Fire("UNIT_AURA", "player")
    M.Fire("UNIT_AURA", "target")
    M.Fire("PLAYER_TARGET_CHANGED")
    M.Fire("PLAYER_EQUIPMENT_CHANGED")
    M.Fire("BAG_UPDATE_DELAYED")
    M.RunTimers()
    S.time = nil
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
