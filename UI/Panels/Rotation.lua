local _, ns = ...
local UI = ns.UI

local WHEN_TEXT = {
    always = "", buff_missing = "if the buff is missing", debuff_missing = "if your debuff is missing on the target",
    ready = "when off cooldown", out_of_combat = "out of combat", in_combat = "in combat",
    target_frozen = "when the target is frozen", manual = "when the situation calls for it",
}
local function whenText(w)
    if not w then return "" end
    if WHEN_TEXT[w] then return WHEN_TEXT[w] end
    local k, v = w:match("^([%w_]+):(.+)$")
    if k == "mana_above" then return "while mana is above " .. v .. "%" end
    if k == "mana_below" then return "when mana is below " .. v .. "%" end
    if k == "target_hp_below" then return "when the target is below " .. v .. "% health" end
    if k == "proc" then return "when " .. v .. " procs" end
    if k == "frozen_or_proc" then return "when the target is frozen or " .. v .. " procs" end
    if k == "stacks_below" or k == "stacks_at_least" then
        local aura, n = v:match("^(.-):(%d+)$")
        if aura then return (k == "stacks_below" and "until %s has %s stacks" or "at %s %s+ stacks"):format(aura, n) end
    end
    return w
end
ns.Rotation.WhenText = whenText

local view -- nil = the profile's context; "cc" | "mana"

local function renderCC(L, c)
    L:Columns({ 0.55, 0.45 })
    L:Label("Your Polymorph")
    local text = ns.CC.StatusText()
    L:Row({ icon = ns.Rotation.Icon("Polymorph"), title = text or "No Polymorph running",
        sub = "The on-screen helper shows your sheep's name and time left, and warns you if it breaks early." })
    L:Check("Track my Polymorph", ns.db.char.cc.enabled, function(v) ns.db.char.cc.enabled = v UI.Refresh() end,
        "Reads your Polymorph aura on target, focus, mouseover and nameplates. If the client hides it, the helper says so.")
    L:Label("Cooldowns")
    local cds = ns.CC.Cooldowns()
    if #cds == 0 then L:Text(UI.Hex(UI.C.dim) .. "Frost Nova, Counterspell and Cone of Cold show here once you know them.|r", { size = 12 }) end
    for _, cd in ipairs(cds) do
        local right = cd.left == nil and (UI.Hex(UI.C.dim) .. "hidden|r") or (cd.left <= 0.1 and (UI.Hex(UI.C.good) .. "ready|r") or ("%ds"):format(math.ceil(cd.left)))
        L:Spell(ns.Rotation.SpellId(cd.name), cd.name, nil, right, ns.Rotation.Icon(cd.name))
    end
    L:NextColumn()
    local content = ns.Learn.Content()
    L:Label("Crowd control tips")
    local any = false
    for _, e in ipairs(content and content.mechanics or {}) do
        if e.topic == "cc" then
            any = true
            L:Text((e.title and (UI.Hex(UI.Accent()) .. e.title .. "|r\n") or "") .. (e.body or ""), { size = 12 })
            for _, src in ipairs(e.sources or {}) do L:Source({ source_url = src }) end
        end
    end
    if not any then L:Text("One sheep at a time: Polymorph breaks on any damage, so don't hit it, and mark it so your group doesn't either.", { size = 12 }) end
    L:EndColumns()
end

local function renderMana(L, c)
    local content = ns.Learn.Content()
    L:Text(UI.Hex(UI.C.dim) .. "How to stay out of the drink-after-every-pull loop. Facts from the research; anything unconfirmed is marked.|r", { size = 12 })
    local any = false
    for _, e in ipairs(content and content.mechanics or {}) do
        if e.topic == "mana" then
            any = true
            local flag = e.unconfirmed and ("\n" .. UI.FLAG_ICON .. " " .. UI.Hex(UI.C.warn) .. ((e.flag and e.flag ~= "") and e.flag or "Unconfirmed") .. "|r") or ""
            L:Row({ title = e.title or "", sub = (e.body or "") .. flag })
            for _, src in ipairs(e.sources or {}) do L:Source({ source_url = src }) end
        end
    end
    local mana = ns.Data.Rotations and ns.Data.Rotations.mana
    if mana then
        L:Label("Regen")
        L:Text(mana, { size = 12 })
        L:Source(ns.Data.Rotations)
    end
    if not any and not mana then L:Text("No mana content in the research yet.") end
end

UI.RegisterPanel({
    key = "rotation", label = "Rotation",
    setSub = function(sub)
        local key = sub and sub:lower()
        if key == "crowd control" or key == "cc" then view = "cc"
        elseif key == "mana" then view = "mana"
        elseif key and ns.Rotation.CONTEXT_LABELS[key] then ns.DB.Profile().rotationContext = key view = nil end
    end,
    render = function(L, c)
        L:Title("Rotation", c.spec and (c.spec .. " · only spells you can use at level " .. c.level) or nil)
        if not c.spec then L:Text("Pick a spec first (spec pill at the top).") return end
        local p = c.profile
        local current = p.rotationContext or "solo"
        local tabs = {}
        for _, key in ipairs(ns.Rotation.CONTEXTS) do
            table.insert(tabs, { label = ns.Rotation.CONTEXT_LABELS[key], active = view == nil and key == current, onClick = function()
                p.rotationContext = key
                view = nil
                ns.Fire("ROTATION_CONTEXT", key)
                UI.Refresh()
            end })
        end
        table.insert(tabs, { label = "Crowd control", active = view == "cc", onClick = function() view = "cc" UI.Refresh() end })
        table.insert(tabs, { label = "Mana", active = view == "mana", onClick = function() view = "mana" UI.Refresh() end })
        L:Tabs(tabs)
        if view == "cc" then renderCC(L, c) return end
        if view == "mana" then renderMana(L, c) return end

        local ctxData = ns.Rotation.Context(c.spec, current)
        if not ctxData then
            L:Flag("No rotation content for this spec and situation yet.")
            return
        end
        if ctxData.unconfirmed then L:Note(c.spec .. " " .. current .. ": " .. ((ctxData.flag ~= "" and ctxData.flag) or "unconfirmed")) end
        for _, s in ipairs(ctxData.sources or {}) do L:Source({ source_url = s }) end

        L:Columns({ 0.6, 0.4 })
        L:Text(UI.Hex(UI.C.dim) .. "Top of the list wins. The on-screen helper lights up the next one. Advice only: you press the buttons.|r", { size = 12 })
        local n, hidden = 0, 0
        for _, step in ipairs(ctxData.priority or {}) do
            local avail = ns.Rotation.Availability(step.spell, c.level, c.race, c.faction)
            if avail then
                n = n + 1
                local sub = whenText(step.when)
                if step.note and step.note ~= "" then sub = (sub ~= "" and (sub .. " - ") or "") .. step.note end
                local chip
                if avail == "trainable" then chip = { text = "Train it", kind = "warn" }
                elseif avail == "no_wand" then chip = { text = "No wand", kind = "warn" } end
                L:Spell(ns.Rotation.SpellId(step.spell), ("%d. %s"):format(n, (step.spell:gsub(" %(talent%)", ""))), sub, nil,
                    ns.Rotation.Icon(step.spell), chip and { chip = chip } or nil)
            else
                hidden = hidden + 1
            end
        end
        if n == 0 then L:Text(UI.Hex(UI.C.dim) .. "Nothing in this list is available at your level yet.|r") end
        if hidden > 0 then
            L:Text(UI.Hex(UI.C.dim) .. hidden .. " more step" .. (hidden == 1 and "" or "s") .. " unlock with levels or talents; they'll appear here when you can use them.|r", { size = 12 })
        end

        L:NextColumn()
        local hud = ns.db.char.rotation
        L:Row({ title = "On-screen helper", sub = hud.showInCombatOnly and "Shows in combat only" or "Next-spell icon near your character",
            button = { label = hud.enabled and "On" or "Off", onClick = function()
                hud.enabled = not hud.enabled
                ns.Fire("HUD_TOGGLE")
                UI.Refresh()
            end } })
        if ctxData.summary then
            L:Label("The plan")
            L:Text(ctxData.summary, { size = 12 })
        end
        if ctxData.tips and #ctxData.tips > 0 then
            L:Label("Tips")
            for _, t in ipairs(ctxData.tips) do L:Text("- " .. t, { size = 12 }) end
        end
        L:Label("Last fight")
        local last = ns.Summary.last
        if last then
            L:Text(("%ds · mana %s -> %s"):format(last.duration, last.manaStart and ("%.0f%%"):format(last.manaStart) or "?", last.manaEnd and ("%.0f%%"):format(last.manaEnd) or "?"), { size = 12 })
            L:Text(UI.Hex(UI.C.dim) .. ns.Summary.Text(last) .. "|r", { size = 12 })
            for _, t in ipairs(last.tips or {}) do L:Text("- " .. t, { size = 12 }) end
        else
            L:Text(UI.Hex(UI.C.dim) .. "After each fight: casts used, mana spent and a tip.|r", { size = 12 })
        end
        L:Buttons({ { label = "Mana tips", onClick = function() view = "mana" UI.Refresh() end },
            { label = "Crowd control", onClick = function() view = "cc" UI.Refresh() end } })
        L:EndColumns()
    end,
})
