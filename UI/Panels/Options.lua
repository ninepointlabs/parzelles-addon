-- Settings: General · Mage buttons · Tooltips & bags · Reminders · About the data.
local _, ns = ...
local UI = ns.UI

UI.SettingsSections = UI.SettingsSections or {}
local S = UI.SettingsSections

local TABS = { "General", "Mage buttons", "Tooltips & bags", "Reminders", "About the data", "About" }
local tab = "General"

S.General = function(L, c)
    local g, ch = ns.db.global, ns.db.char
    L:Label("Specs & dual spec")
    for _, id in ipairs(ns.DB.PROFILE_IDS) do
        local p = ns.DB.Profile(id)
        local items = {}
        for _, spec in ipairs(ns.SPEC_ORDER) do
            table.insert(items, { label = spec, active = p.spec == spec, onClick = function()
                ns.DB.SetSpec(spec, id)
                UI.Refresh()
            end })
        end
        L:Text(("Profile %s · talent spec %s%s"):format(id, id == "A" and "1" or "2", ns.DB.ActiveId() == id and (UI.Hex(UI.C.good) .. "  (active)|r") or ""))
        L:Buttons(items, 110)
    end
    local cb = L:Check("Switch profile automatically with my talent spec", ch.autoSwitch, function(v)
        ch.autoSwitch = v
        if v then ns.DualSpec.Sync() end
        UI.Refresh()
    end, "Swapping talent specs (dual spec, level 40) swaps the addon profile: spec 1 -> A, spec 2 -> B.")
    if not ns.DualSpec.IsAvailable() then
        cb:Disable()
        L:Text(UI.Hex(UI.C.dim) .. "This client doesn't expose the talent-group API.|r", { size = 12, indent = 30 })
    else
        local grp = ns.DualSpec.ActiveGroup()
        L:Text(UI.Hex(UI.C.dim) .. (ns.DualSpec.HasDualSpec() and ("Dual spec learned. Active talent spec: " .. tostring(grp or "?") .. ".")
            or "Dual spec not learned yet (level 40, at your class trainer). Profile B is ready for it.") .. "|r", { size = 12, indent = 30 })
    end

    L:Label("Rotation helper & fight summary")
    L:Check("Show the on-screen rotation helper", ch.rotation.enabled, function(v) ch.rotation.enabled = v ns.Fire("HUD_TOGGLE") end)
    L:Check("Only in combat", ch.rotation.showInCombatOnly, function(v) ch.rotation.showInCombatOnly = v ns.Fire("HUD_TOGGLE") end)
    L:Check("Post-fight summary in chat", ch.summary.enabled, function(v) ch.summary.enabled = v end)
    L:Buttons({ { label = "Reset helper position", onClick = function() ch.rotation.point = nil ns.Fire("HUD_RESET") end } })

    L:Label("Learning & window")
    L:Check("Hint the first time I learn a spell", ch.learn.hints, function(v) ch.learn.hints = v end)
    L:Check("Show minimap button", not g.minimap.hide, function(v) g.minimap.hide = not v ns.Fire("MINIMAP_TOGGLE") end)
    L:Check("Debug messages", g.debug, function(v) g.debug = v end)
    L:Text(UI.Hex(UI.C.dim) .. "Slash: /parzelle (or /mage) · /parzelle spec arcane|fire|frost · /parzelle rotation · /parzelle portals · /parzelle conjure|buff key · /parzelle share|r", { size = 12 })
end

-- Cycle a setting through steps (button label "Keep 20" -> next value).
local function cycle(cfgT, key, steps, after)
    return function()
        local nextV = steps[1]
        for i, v in ipairs(steps) do if v == cfgT[key] then nextV = steps[i + 1] or steps[1] end end
        cfgT[key] = nextV
        if after then after() end
        UI.Refresh()
    end
end

local function keyRow(L, key, what, startCapture, clear)
    L:Row({ title = what .. " key", sub = key and "Pressing it presses the button, even if the key is bound to something else in Blizzard's menu." or "No key set (none by default).",
        right = key and (UI.Hex(UI.C.good) .. key .. "|r") or (UI.Hex(UI.C.dim) .. "none|r") })
    L:Buttons({
        { label = "Set key", onClick = startCapture, tip = "Press any key (Shift/Ctrl/Alt combos work). Esc cancels." },
        { label = "Clear key", onClick = function() clear(nil) UI.Refresh() end },
    })
end

S["Mage buttons"] = function(L, c)
    local cfg, ai, sh = ns.db.char.conjure, ns.db.char.intellect, ns.db.char.share
    L:Text("Three buttons side by side on one small bar: Conjure, Arcane Intellect and Hand out (food & water). Drag the strip above them to move the bar. Each shows up once you know its spell.", { size = 13 })
    L:Buttons({ { label = "Reset bar position", onClick = function() ns.MageBar.ResetPosition() end } })

    -- Conjure
    L:Label("Conjure")
    L:Text("Each press casts the highest rank you know of whatever you're shortest on: a mana gem if you have none, then water up to your target, then food.", { size = 12 })
    L:Check("Show the Conjure button", cfg.enabled, function(v)
        if InCombatLockdown() then ns.Print("Out of combat only.") return end
        cfg.enabled = v
        ns.ConjureButton.Refresh()
    end)
    L:Check("Remind me after login when I'm low", cfg.loginNudge, function(v) cfg.loginNudge = v end)
    local counts = ns.Conjure.Counts()
    for _, kind in ipairs({ "water", "food", "gem" }) do
        local spell = ns.Conjure.KnownSpell(kind)
        L:Row({ icon = ns.Conjure.ICONS[kind], title = (ns.Conjure.LABELS[kind]:gsub("^%l", string.upper)) .. ": " .. (counts[kind] or 0) .. " in bags",
            sub = spell and ("Casts " .. spell) or "You don't know this conjure spell yet.",
            button = { label = "Keep " .. (cfg[kind] or 0), onClick = cycle(cfg, kind, kind == "gem" and { 0, 1 } or { 0, 10, 20, 40, 60, 80 },
                function() if not InCombatLockdown() then ns.ConjureButton.Update() end end) } })
    end
    keyRow(L, cfg.key, "Conjure", ns.ConjureButton.StartKeyCapture, ns.ConjureButton.SetKey)

    -- Arcane Intellect
    L:Label("Arcane Intellect")
    L:Text("One press buffs the nearest friendly player who's missing Arcane Intellect: you, your group, your target, then players with friendly nameplates shown (Shift+V). Warriors and Rogues are skipped (no mana).", { size = 12 })
    L:Check("Show the Arcane Intellect button", ai.enabled, function(v)
        if InCombatLockdown() then ns.Print("Out of combat only.") return end
        ai.enabled = v
        ns.Intellect.Refresh()
    end)
    L:Check("Use Arcane Brilliance when " .. ai.brillianceMin .. "+ of my party need it", ai.brilliance, function(v) ai.brilliance = v end,
        "Only if your spellbook has Arcane Brilliance. Party only, not raids.")
    L:Note("Arcane Brilliance: no WoW Forever source mentions it (only a Burning Crusade level-70 trainer list does). The button uses it only if your spellbook has it.")
    keyRow(L, ai.key, "Arcane Intellect", ns.Intellect.StartKeyCapture, ns.Intellect.SetKey)

    -- Hand out
    L:Label("Hand out food & water")
    L:Text("Left-click the Hand out button to open a trade with your target, or the next person in your group who hasn't had any yet. The trade window fills itself with the amounts below; you press Trade. Right-click picks someone from your group (with their mana).", { size = 12 })
    L:Check("Show the Hand out button", sh.enabled, function(v)
        if InCombatLockdown() then ns.Print("Out of combat only.") return end
        sh.enabled = v
        ns.ShareButton.Refresh()
    end)
    local totals = ns.Share.Totals()
    L:Row({ icon = ns.Conjure.ICONS.water, title = "Water per trade", sub = totals.water .. " conjured water in your bags. Never given to Warriors or Rogues.",
        button = { label = "Give " .. sh.water, onClick = cycle(sh, "water", { 0, 5, 10, 20, 40, 60 }) } })
    L:Row({ icon = ns.Conjure.ICONS.food, title = "Food per trade", sub = totals.food .. " conjured food in your bags.",
        button = { label = "Give " .. sh.food, onClick = cycle(sh, "food", { 0, 5, 10, 20, 40 }) } })
    L:Check("Fill the trade when someone in my group opens a trade with me", sh.autoOffer, function(v) sh.autoOffer = v end)
    L:Check("...and when anyone else does", sh.autoOfferAnyone, function(v) sh.autoOfferAnyone = v end,
        "Off by default: strangers who open a trade with you get nothing added unless you press \"Add food & water\" on the trade window.")
    L:Check("Group line (Hand out menu > Tell the group; whispers people who are too far)", sh.announce, function(v) sh.announce = v end,
        "Off by default. Only ever sent when you click.")
    L:Text(UI.Hex(UI.C.dim) .. "The line: \"" .. sh.message .. "\"|r", { size = 12, indent = 30 })
    L:Text(UI.Hex(UI.C.dim) .. "Each person gets the best rank they can use (the item's required level). The final Trade click is always yours (Blizzard rule). If the game won't let the addon fill the window, press \"Add food & water\" under the trade window.|r", { size = 12 })

    L:Space(6)
    L:Text(UI.Hex(UI.C.dim) .. "Pick keys your desktop doesn't use (on Omarchy, Super combos belong to the desktop, so they're never offered). What the secure buttons cast and their keys only change out of combat (Blizzard rule).|r", { size = 12 })
    for _, cf in ipairs(ns.Data.Conflicts or {}) do
        local t = (cf.topic or ""):lower()
        if t:find("gem") or t:find("conjure") then L:Note(cf.topic .. ": " .. cf.detail) end
    end
    L:Note("Conjured items are recognised by their tooltip ('Conjured Item' plus what they restore), because Forever's conjured food and water names aren't in the research yet.")
    L:Note("Ritual of Refreshment (the conjured table) isn't included: the only source is a Burning Crusade level-70 trainer list, nothing for Forever.")
end

S["Tooltips & bags"] = function(L, c)
    local g = ns.db.global
    L:Check("Upgrade tips on item tooltips", g.tooltip.enabled, function(v) g.tooltip.enabled = v end)
    L:Check("Show what improves (stat changes) in tooltips", g.tooltip.showStats, function(v) g.tooltip.showStats = v end)
    L:Check("Highlight upgrades in my bags", g.bags.highlight, function(v) g.bags.highlight = v ns.Bags.RefreshAll() end,
        "Glow + arrow on bag items that beat what you're wearing for your active spec and that you can equip now.")
    L:Check("Tell me when an upgrade lands in my bags", g.bags.toast, function(v) g.bags.toast = v end)
    L:Space(6)
    L:Row({ title = "Hit/crit value", sub = "How many points of spell power/healing 1% hit or crit is worth. An addon assumption, not from the research.",
        button = { label = g.percentScale .. " per 1%", onClick = function()
            local steps = { 5, 8, 10, 12, 14, 20 }
            local nextV = steps[1]
            for i, v in ipairs(steps) do if v == g.percentScale then nextV = steps[i + 1] or steps[1] end end
            g.percentScale = nextV
            ns.Stats.ClearCache()
            UI.Refresh()
        end } })
end

S.About = function(L, c)
    local version = tostring(ns.VERSION)
    if not version:match("^v") then version = "v" .. version end
    L:Row({ icon = ns.NEUTRAL_ICON, title = ns.TITLE .. " " .. version,
        sub = "The do-everything Mage companion for World of Warcraft: Forever." })
    L:Label("Named for")
    L:Row({ icon = "Interface\\Icons\\Spell_Arcane_StarFire", title = "Parzelle Starfall",
        sub = "The High Order Skyborne Mage who started it all, out of Zephras Isle. This addon was built for her and tested on her." })
    L:Text(UI.Hex(UI.C.dim) .. "If you see a Skyborne Mage handing out water and opening portals, say hello.|r", { size = 12 })
    L:Label("Links")
    L:Link("Website", "https://parzellesaddon.myazerothlife.com")
    L:Link("Source, releases and issues", "https://github.com/ninepointlabs/parzelles-addon")
    L:Label("Credits")
    L:Row({ title = "Made by Nine Point Labs", sub = "Free and open source, MIT licence." })
    L:Row({ title = "Information from Blizzard, Icy Veins and Wowhead", sub = "Credited per fact: see About the data, or the Sources & notes link on each screen." })
    L:Text(UI.Hex(UI.C.dim) .. "Parzelle's Addon is an unofficial fan project, not affiliated with or endorsed by Blizzard Entertainment. World of Warcraft and Warcraft are trademarks of Blizzard Entertainment, Inc.|r", { size = 11 })
end

UI.RegisterPanel({
    key = "settings", label = "Settings",
    setSub = function(sub) for _, t in ipairs(TABS) do if t == sub then tab = sub end end end,
    render = function(L, c)
        L:Title("Settings")
        local items = {}
        for _, t in ipairs(TABS) do
            table.insert(items, { label = t, active = tab == t, onClick = function() tab = t UI.Refresh() end })
        end
        L:Tabs(items)
        local fn = S[tab] or S.General
        fn(L, c)
    end,
})
