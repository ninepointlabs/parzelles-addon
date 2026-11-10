-- Conjure button: shows your conjured stock (water / food / mana gem) and each
-- press casts the highest known rank of whatever is most needed: the mana gem
-- if you have none, then water below your target, then food.
--
-- Rules this follows (lessons from Andric's Addon on Forever):
--   * A secure action button (SecureActionButtonTemplate, type "spell") does
--     the cast; every cast needs your click or key press. The addon never casts.
--   * What the button casts only changes out of combat; in combat it's disarmed
--     (conjuring is an out-of-combat job anyway).
--   * No macros and no /click: Forever's /click refuses addon buttons. The key
--     is an override binding that clicks the button directly (Settings >
--     Conjure button > Set key), per character, out of combat. No key is bound
--     by default.
local _, ns = ...
local UI = ns.UI

local CB = {}
ns.ConjureButton = CB

CB.NAME = "ParzellesConjureButton"
CB.CLICK = CB.NAME

local btn, holder, current

local function setLook(active)
    if not btn then return end
    btn.icon:SetDesaturated(not active)
    btn.icon:SetAlpha(active and 1 or 0.45)
    btn:SetBackdropBorderColor(unpack(active and UI.Accent() or UI.C.border))
end

-- Stock line under the button: "W 12 · F 20 · G 1" (only kinds you can conjure).
function CB.StockText(counts, targets, knownSpell)
    knownSpell = knownSpell or ns.Conjure.KnownSpell
    local parts = {}
    for _, kind in ipairs({ "water", "food", "gem" }) do
        if knownSpell(kind) then
            local have, want = counts[kind] or 0, targets[kind] or 0
            local col = (want > 0 and have < want) and UI.Hex(UI.C.warn) or UI.Hex(UI.C.good)
            table.insert(parts, col .. kind:sub(1, 1):upper() .. " " .. have .. "|r")
        end
    end
    return table.concat(parts, UI.Hex(UI.C.dim) .. " · |r")
end

-- Re-aim the secure button (out of combat only).
function CB.Update()
    if not btn then return end
    local counts, targets = ns.Conjure.Counts(), ns.Conjure.Targets()
    btn.stock:SetText(CB.StockText(counts, targets))
    if InCombatLockdown() then
        btn.status:SetText(UI.Hex(UI.C.dim) .. "in combat|r")
        return
    end
    local pick, reason = ns.Conjure.Next(counts, targets)
    current = pick
    if pick then
        btn:SetAttribute("type", "spell")
        btn:SetAttribute("spell", pick.spell)
        btn.icon:SetTexture(ns.Rotation.Icon(pick.spell) ~= "Interface\\Icons\\INV_Misc_QuestionMark" and ns.Rotation.Icon(pick.spell) or ns.Conjure.ICONS[pick.kind])
        btn.status:SetText(ns.Conjure.LABELS[pick.kind] .. UI.Hex(UI.C.dim) .. (" %d/%d|r"):format(pick.have, pick.want))
        setLook(true)
    else
        btn:SetAttribute("type", nil)
        btn:SetAttribute("spell", nil)
        btn.icon:SetTexture(ns.Conjure.ICONS.water)
        btn.status:SetText(UI.Hex(UI.C.dim) .. (reason == "stocked up" and "stocked up" or "nothing yet") .. "|r")
        setLook(false)
    end
    btn.reason = reason
    if GameTooltip:IsShown() and GameTooltip:GetOwner() == btn then btn:GetScript("OnEnter")(btn) end
end

function CB.ShouldShow()
    local cfg = ns.db and ns.db.char.conjure
    if not (cfg and cfg.enabled) then return false end
    return (ns.Conjure.KnownSpell("water") or ns.Conjure.KnownSpell("food") or ns.Conjure.KnownSpell("gem")) ~= nil
end

function CB.Place()
    if not holder then return end
    holder:ClearAllPoints()
    local p = ns.db.char.conjure.point
    if p then holder:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else holder:SetPoint("CENTER", UIParent, "CENTER", -160, -190) end
end

function CB.Build()
    if btn then return btn end
    -- Non-secure holder so it can be dragged (out of combat) without interfering with clicks.
    holder = CreateFrame("Frame", "ParzellesConjureHolder", UIParent)
    holder:SetSize(64, 84)
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    holder.handle = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    holder.handle:SetSize(46, 8)
    holder.handle:SetPoint("TOP", 0, 0)
    UI.Backdrop(holder.handle, { 0.2, 0.2, 0.25, 0.8 }, { 0, 0, 0, 0 })
    holder.handle:EnableMouse(true)
    holder.handle:RegisterForDrag("LeftButton")
    holder.handle:SetScript("OnDragStart", function() if not InCombatLockdown() then holder:StartMoving() end end)
    holder.handle:SetScript("OnDragStop", function()
        holder:StopMovingOrSizing()
        local point, _, rel, x, y = holder:GetPoint()
        ns.db.char.conjure.point = { point, rel, x, y }
    end)
    holder.handle:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText("Drag to move (out of combat)", 1, 1, 1)
        GameTooltip:Show()
    end)
    holder.handle:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn = CreateFrame("Button", CB.NAME, holder, "SecureActionButtonTemplate, BackdropTemplate")
    btn:SetSize(40, 40)
    btn:SetPoint("TOP", holder.handle, "BOTTOM", 0, -2)
    UI.Backdrop(btn, { 0, 0, 0, 0.7 }, UI.C.border)
    -- Mouse and key binding act on release (same as Andric's working button).
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("useOnKeyDown", false)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 1, -1)
    btn.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn.icon:SetTexture(ns.Conjure.ICONS.water)
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    btn.hotkey = UI.Text(btn, 10)
    UI.Font(btn.hotkey, 10, "OUTLINE")
    btn.hotkey:SetPoint("TOPRIGHT", -2, -2)
    btn.hotkey:SetJustifyH("RIGHT")
    btn.hotkey:SetWordWrap(false)
    btn.status = UI.Text(holder, 10)
    btn.status:SetPoint("TOP", btn, "BOTTOM", 0, -2)
    btn.status:SetWidth(120)
    btn.status:SetJustifyH("CENTER")
    btn.status:SetWordWrap(false)
    btn.stock = UI.Text(holder, 10)
    btn.stock:SetPoint("TOP", btn.status, "BOTTOM", 0, -2)
    btn.stock:SetWidth(120)
    btn.stock:SetJustifyH("CENTER")
    btn.stock:SetWordWrap(false)
    btn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText("Conjure: " .. (current and current.spell or "nothing needed"), 1, 0.82, 0)
        local counts, targets = ns.Conjure.Counts(), ns.Conjure.Targets()
        for _, kind in ipairs({ "gem", "water", "food" }) do
            local spell = ns.Conjure.KnownSpell(kind)
            if spell then
                GameTooltip:AddDoubleLine(ns.Conjure.LABELS[kind]:gsub("^%l", string.upper), ("%d / %d"):format(counts[kind] or 0, targets[kind] or 0), 1, 1, 1, 1, 1, 1)
            end
        end
        if not current then GameTooltip:AddLine("Nothing to conjure: " .. (s.reason or "?"), 0.7, 0.7, 0.7, true) end
        GameTooltip:AddLine("Click or press " .. (CB.Key() or "your key (Settings > Conjure button)") .. ": one cast per press, highest rank you know.", 0.6, 0.6, 0.6, true)
        GameTooltip:AddLine("Order: mana gem if you have none, then water, then food. Targets in Settings.", 0.6, 0.6, 0.6, true)
        if InCombatLockdown() then GameTooltip:AddLine("Out of combat only.", 1, 0.5, 0.3, true) end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- After a press: give the bags a moment, then re-aim.
    btn:HookScript("PostClick", function(_, _, down)
        if down then return end
        C_Timer.After(0.5, function() if not InCombatLockdown() then CB.Update() end end)
    end)
    CB.Place()
    holder:Hide()
    return btn
end

function CB.Refresh()
    if InCombatLockdown() then return end -- show/hide of secure frames is blocked in combat
    CB.Build()
    local show = CB.ShouldShow()
    holder:SetShown(show and true or false)
    if show then CB.Update() end
    CB.ApplyKey()
end

-- /parzelle conjure debug
function CB.Debug()
    CB.Build()
    local function a(n) return tostring(btn:GetAttribute(n)) end
    local counts = ns.Conjure.Counts()
    ns.Print("Conjure button debug:")
    print(("  shown=%s combat=%s enabled=%s"):format(tostring(holder:IsShown()), tostring(InCombatLockdown()), tostring(ns.db.char.conjure.enabled)))
    print(("  type=%s spell=%s useOnKeyDown=%s"):format(a("type"), a("spell"), a("useOnKeyDown")))
    print(("  stock water=%d food=%d gem=%d"):format(counts.water, counts.food, counts.gem))
    for _, kind in ipairs({ "water", "food", "gem" }) do print(("  %s spell: %s"):format(kind, tostring(ns.Conjure.KnownSpell(kind)))) end
    print("  key: " .. tostring(CB.Key()))
end

-- Key binding: an override binding that clicks the button directly. Stored
-- per character, applied out of combat, doesn't touch Blizzard's binding sets.
function CB.Key()
    return ns.db and ns.db.char.conjure.key
end

function CB.ApplyKey()
    if not holder or InCombatLockdown() then return end
    ClearOverrideBindings(holder)
    local key = CB.Key()
    if key then SetOverrideBindingClick(holder, true, key, CB.CLICK, "LeftButton") end
    btn.hotkey:SetText(key and ((GetBindingText and GetBindingText(key, true)) or key) or "")
end

function CB.SetKey(key)
    if InCombatLockdown() then ns.Print("Can't change key bindings in combat.") return end
    CB.Build()
    ns.db.char.conjure.key = key
    CB.ApplyKey()
    ns.Print(key and ("Conjure button bound to " .. key .. ".") or "Conjure button key cleared.")
    ns.Fire("CONJURE_KEY_CHANGED")
end

-- Turn a key press into a binding string like "ALT-CTRL-SHIFT-F" (nil = ignore).
-- Super/Meta is never used: on Omarchy (Hyprland) the Super key belongs to the
-- desktop, so META combos are refused.
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true, UNKNOWN = true }
function CB.KeyString(key)
    if not key or MODIFIERS[key] then return nil end
    if IsMetaKeyDown and IsMetaKeyDown() then return nil end
    local prefix = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "")
    return prefix .. key
end

local capture
function CB.StartKeyCapture()
    if InCombatLockdown() then ns.Print("Can't change key bindings in combat.") return end
    if not capture then
        capture = CreateFrame("Frame", "ParzellesConjureKeyCapture", UIParent, "BackdropTemplate")
        capture:SetSize(380, 96)
        capture:SetPoint("CENTER", 0, 120)
        capture:SetFrameStrata("FULLSCREEN_DIALOG")
        UI.Backdrop(capture, UI.C.bg, UI.Accent())
        capture.text = UI.Text(capture, 14)
        capture.text:SetPoint("CENTER")
        capture.text:SetWidth(350)
        capture.text:SetJustifyH("CENTER")
        capture:EnableKeyboard(true)
        capture:SetPropagateKeyboardInput(false)
        capture:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then self:Hide() return end
            local k = CB.KeyString(key)
            if k then
                self:Hide()
                CB.SetKey(k)
            end
        end)
        capture:SetScript("OnMouseDown", function(self, mouseButton)
            if mouseButton == "Button4" or mouseButton == "Button5" or mouseButton == "MiddleButton" then
                local k = CB.KeyString(mouseButton == "MiddleButton" and "BUTTON3" or mouseButton:upper())
                self:Hide()
                CB.SetKey(k)
            end
        end)
    end
    capture.text:SetText("Press a key for the Conjure button\n" .. UI.Hex(UI.C.dim) .. "(Shift/Ctrl/Alt combos work; Super isn't used; Esc cancels)|r")
    capture:Show()
end
