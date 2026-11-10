-- Settings › Reminders: live status + what to remind about.
local _, ns = ...
local UI = ns.UI

UI.SettingsSections = UI.SettingsSections or {}

UI.SettingsSections.Reminders = function(L, c)
    local cfg = ns.db.char.reminders
    L:Columns({ 0.5, 0.5 })
    L:Label("Right now")
    local list = ns.Reminders.Evaluate()
    if #list == 0 then L:Text(UI.Hex(UI.C.dim) .. "Nothing to check yet at your level.|r") end
    for _, r in ipairs(list) do
        local chip = r.id == "dampen" and { text = "Tip", kind = "info" } or (r.ok and { text = "OK", kind = "good" } or { text = "Missing", kind = "warn" })
        L:Row({ chip = chip, title = r.label, sub = r.detail })
    end
    L:Text(UI.Hex(UI.C.dim) .. "Checked out of combat; missing items pop up on screen (also /parzelle remind).|r", { size = 12 })
    L:NextColumn()
    L:Label("Remind me about")
    local function check(label, key)
        L:Check(label, cfg[key], function(v) cfg[key] = v ns.Fire("REMINDERS_CHANGED") UI.Refresh() end)
    end
    check("Reminders on", "enabled")
    check("Arcane Intellect", "intellect")
    check("Armor spell (Frost/Ice/Mage Armor)", "armor")
    check("Ice Barrier (Frost only)", "iceBarrier")
    check("Conjured food, water & gem stock", "conjured")
    check("Travel reagents (once confirmed for Forever)", "reagents")
    check("Wand equipped", "wand")
    check("Dampen/Amplify Magic tip", "dampen")
    L:Buttons({
        { label = "Reagents: want " .. cfg.reagentMin .. "+", onClick = function()
            cfg.reagentMin = (cfg.reagentMin >= 20) and 1 or (cfg.reagentMin + (cfg.reagentMin < 5 and 4 or 5))
            UI.Refresh()
        end, tip = "Click to cycle 1-20." },
    })
    L:EndColumns()
end
