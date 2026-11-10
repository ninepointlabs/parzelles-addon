-- Leveling › Portals & teleports, plus the travel bar.
--
-- The list (here) explains each teleport/portal for your faction: known or
-- "unlock at N", reagents in your bags and where they come from. The clickable
-- buttons live on a separate small travel bar (secure action buttons, one cast
-- per click). It's its own top-level frame, built and re-filled only out of
-- combat, so the main window never holds protected buttons (it stays closable
-- in combat). No macros, no /click.
local _, ns = ...
local UI = ns.UI

UI.LevelingSections = UI.LevelingSections or {}

local Bar = {}
ns.TravelBar = Bar
Bar.SIZE, Bar.GAP = 34, 4

local bar, buttons = nil, {}

function Bar.Build()
    if bar then return bar end
    bar = CreateFrame("Frame", "ParzellesTravelBar", UIParent, "BackdropTemplate")
    bar:SetSize(120, Bar.SIZE + 26)
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    UI.Backdrop(bar, { 0.05, 0.05, 0.07, 0.85 }, UI.C.border)
    bar:SetScript("OnDragStart", function(s) if not InCombatLockdown() then s:StartMoving() end end)
    bar:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local point, _, rel, x, y = s:GetPoint()
        ns.db.char.travelBar = ns.db.char.travelBar or {}
        ns.db.char.travelBar.point = { point, rel, x, y }
    end)
    bar.title = UI.Text(bar, 10, UI.C.dim)
    bar.title:SetPoint("TOPLEFT", 8, -5)
    bar.title:SetText("Teleports & portals")
    bar.close = CreateFrame("Button", nil, bar, "UIPanelCloseButton")
    bar.close:SetSize(20, 20)
    bar.close:SetPoint("TOPRIGHT", 0, 0)
    bar.close:SetScript("OnClick", function() Bar.Hide() end)
    local p = ns.db.char.travelBar and ns.db.char.travelBar.point
    if p then bar:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else bar:SetPoint("CENTER", UIParent, "CENTER", 0, 160) end
    bar:Hide()
    return bar
end

local function button(i)
    if buttons[i] then return buttons[i] end
    local b = CreateFrame("Button", "ParzellesTravelButton" .. i, bar, "SecureActionButtonTemplate, BackdropTemplate")
    b:SetSize(Bar.SIZE, Bar.SIZE)
    UI.Backdrop(b, { 0, 0, 0, 0.7 }, UI.C.border)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("useOnKeyDown", false)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        if s.spellId then pcall(GameTooltip.SetSpellByID, GameTooltip, s.spellId) else GameTooltip:SetText(s.spellName or "?", 1, 1, 1) end
        if s.reagentText then GameTooltip:AddLine(s.reagentText, 0.8, 0.8, 0.8, true) end
        GameTooltip:AddLine("Click: cast (one cast per click).", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    buttons[i] = b
    return b
end

-- Known teleports first, then portals. Out of combat only.
function Bar.Fill()
    if InCombatLockdown() then return false end
    Bar.Build()
    local level = UnitLevel("player") or 1
    local t = ns.Travel.ForFaction(UnitFactionGroup("player"), level)
    local list = {}
    for _, kind in ipairs({ "teleport", "portal" }) do
        for _, e in ipairs(t[kind]) do if e.known then table.insert(list, e) end end
    end
    for i, e in ipairs(list) do
        local b = button(i)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", bar, "TOPLEFT", 8 + (i - 1) * (Bar.SIZE + Bar.GAP), -20)
        b:SetAttribute("type", "spell")
        b:SetAttribute("spell", e.rec.name)
        b.spellId, b.spellName = e.rec.spell_id, e.rec.name
        b.icon:SetTexture(ns.Rotation.Icon(e.rec.name))
        local r = ns.Travel.Reagent(e.rec.reagent)
        b.reagentText = r and (r.name .. ": " .. tostring(ns.Travel.ReagentCount(r) or 0) .. " in bags" .. (r.status ~= "confirmed" and " (reagent not confirmed for Forever)" or "")) or nil
        b:Show()
    end
    for i = #list + 1, #buttons do
        buttons[i]:Hide()
        buttons[i]:SetAttribute("type", nil)
        buttons[i]:SetAttribute("spell", nil)
    end
    bar:SetWidth(math.max(140, 16 + #list * (Bar.SIZE + Bar.GAP)))
    bar.count = #list
    return true
end

function Bar.Show()
    if InCombatLockdown() then ns.Print("The travel bar can only be opened out of combat.") return end
    Bar.Fill()
    if (bar.count or 0) == 0 then ns.Print("You don't know any teleports or portals yet.") return end
    bar:Show()
    ns.db.char.travelBar = ns.db.char.travelBar or {}
    ns.db.char.travelBar.shown = true
end

function Bar.Hide()
    if not bar then return end
    if InCombatLockdown() then ns.Print("Close the travel bar after combat.") return end
    bar:Hide()
    if ns.db.char.travelBar then ns.db.char.travelBar.shown = false end
end

function Bar.IsShown() return bar ~= nil and bar:IsShown() end

-- Keep it in step with the spellbook (new teleport learned).
ns.On("WOW_SPELLS_CHANGED", function()
    if bar and bar:IsShown() and not InCombatLockdown() then Bar.Fill() end
end)

UI.LevelingSections["Portals & teleports"] = function(L, c)
    local t = ns.Travel.ForFaction(c.faction, c.level)
    local knownAny = false
    for _, kind in ipairs({ "teleport", "portal" }) do
        for _, e in ipairs(t[kind]) do if e.known then knownAny = true end end
    end
    L:Row({ icon = "Interface\\Icons\\Spell_Arcane_TeleportStormWind", title = "Travel bar",
        sub = knownAny and "One small bar with a button per teleport/portal you know. Click = one cast. Opens and updates out of combat."
            or "Your teleports appear here as you learn them.",
        button = knownAny and { label = Bar.IsShown() and "Hide bar" or "Show bar", onClick = function()
            if Bar.IsShown() then Bar.Hide() else Bar.Show() end
            UI.Refresh()
        end } or nil })
    L:Text(UI.Hex(UI.C.dim) .. (c.faction or "Your faction") .. " cities only; the other faction's teleports aren't listed.|r", { size = 12 })

    local labels = { teleport = "Teleports (just you)", portal = "Portals (your group)" }
    for _, kind in ipairs({ "teleport", "portal" }) do
        L:Label(labels[kind])
        if #t[kind] == 0 then L:Text(UI.Hex(UI.C.dim) .. "None in the research for your faction.|r", { size = 12 }) end
        for _, e in ipairs(t[kind]) do
            local p = e.rec
            local chip
            if e.known then chip = { text = "Known", kind = "good" }
            elseif e.available then chip = { text = "Train it", kind = "warn" }
            else chip = { text = "Unlock at " .. (p.level or "?"), kind = "neutral" } end
            local sub = {}
            local r = ns.Travel.Reagent(p.reagent)
            if r then
                local n = ns.Travel.ReagentCount(r) or 0
                table.insert(sub, ("Reagent: %s (%d in bags)%s"):format(r.name, n, r.status ~= "confirmed" and " - not confirmed for Forever" or ""))
                if r.vendor_note then table.insert(sub, r.vendor_note) end
                if r.status ~= "confirmed" then L:Note(r.name .. ": the research couldn't confirm Forever still uses this reagent.") end
            elseif p.reagent_status == "unknown" or p.reagent == nil then
                table.insert(sub, "Reagent: not confirmed for Forever")
            end
            L:Spell(p.spell_id, p.name, table.concat(sub, "\n"), p.level and ("level " .. p.level) or nil, nil, { chip = chip })
            L:Source(p)
        end
    end
    local hint = ns.Travel.HearthHint(t.teleport)
    L:Label("Tip")
    L:Text(hint or "Don't set your hearthstone to a city you can teleport to: bind it to the inn where you're questing, and teleport home instead.", { size = 12 })
    for _, cf in ipairs(ns.Data.Conflicts or {}) do
        if (cf.topic or ""):lower():find("portal") or (cf.topic or ""):lower():find("teleport") or (cf.topic or ""):lower():find("rune") then
            L:Note(cf.topic .. ": " .. cf.detail)
        end
    end
end
