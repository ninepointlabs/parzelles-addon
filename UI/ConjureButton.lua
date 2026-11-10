-- Conjure button: shows your conjured stock (water / food / mana gem) and each
-- press casts the highest known rank of whatever is most needed: the mana gem
-- if you have none, then water below your target, then food.
--
-- Rules this follows (lessons from Andric's Addon on Forever):
--   * A secure action button (SecureActionButtonTemplate) does the cast; every
--     cast needs your click or key press. The addon never casts by itself.
--   * It casts through the button's own "/cast <spell>" line (type "macro"):
--     on Forever Andric's type "spell" button didn't cast, the /cast line did.
--     Not a player macro and no /click (Forever's /click refuses addon buttons).
--   * What the button casts only changes out of combat; in combat it's disarmed
--     (conjuring is an out-of-combat job anyway).
--   * The key is an override binding that clicks the button directly
--     (Settings > Mage buttons > Set key), per character, out of combat. No key
--     is bound by default.
--   * It sits on the mage bar (UI/MageBar.lua) with the buff and hand-out buttons.
local _, ns = ...
local UI = ns.UI

local CB = {}
ns.ConjureButton = CB

CB.NAME = "ParzellesConjureButton"
CB.CLICK = CB.NAME

local btn, cell, current

local function setLook(active) ns.MageBar.SetLook(btn, active) end

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
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", ns.MageBar.CastText(pick.spell))
        btn.icon:SetTexture(ns.Rotation.Icon(pick.spell) ~= "Interface\\Icons\\INV_Misc_QuestionMark" and ns.Rotation.Icon(pick.spell) or ns.Conjure.ICONS[pick.kind])
        btn.status:SetText(ns.Conjure.LABELS[pick.kind] .. UI.Hex(UI.C.dim) .. (" %d/%d|r"):format(pick.have, pick.want))
        setLook(true)
    else
        btn:SetAttribute("type", nil)
        btn:SetAttribute("macrotext", nil)
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

function CB.Place() ns.MageBar.Place() end

function CB.Build()
    if btn then return btn end
    cell = ns.MageBar.Cell("conjure", 1)
    btn = CreateFrame("Button", CB.NAME, cell, "SecureActionButtonTemplate, BackdropTemplate")
    ns.MageBar.Decorate(btn, cell, ns.Conjure.ICONS.water)
    -- Mouse and key binding act on release (same as Andric's working button).
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("useOnKeyDown", false)
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
        GameTooltip:AddLine("Click or press " .. (CB.Key() or "your key (Settings > Mage buttons)") .. ": one cast per press, highest rank you know.", 0.6, 0.6, 0.6, true)
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
    return btn
end

function CB.Refresh()
    if InCombatLockdown() then return end -- show/hide of secure frames is blocked in combat
    CB.Build()
    local show = CB.ShouldShow()
    cell.want = show and true or false
    ns.MageBar.Layout()
    if show then CB.Update() end
    CB.ApplyKey()
end

-- /parzelle conjure debug
function CB.Debug()
    CB.Build()
    local function a(n) return tostring(btn:GetAttribute(n)) end
    local counts = ns.Conjure.Counts()
    ns.Print("Conjure button debug:")
    print(("  shown=%s combat=%s enabled=%s"):format(tostring(cell:IsShown()), tostring(InCombatLockdown()), tostring(ns.db.char.conjure.enabled)))
    print(("  type=%s macrotext=%s useOnKeyDown=%s"):format(a("type"), a("macrotext"), a("useOnKeyDown")))
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
    if not btn then return end
    ns.MageBar.ApplyKey(btn, CB.CLICK, CB.Key())
end

function CB.SetKey(key)
    if InCombatLockdown() then ns.Print("Can't change key bindings in combat.") return end
    CB.Build()
    ns.db.char.conjure.key = key
    CB.ApplyKey()
    ns.Print(key and ("Conjure button bound to " .. key .. ".") or "Conjure button key cleared.")
    ns.Fire("CONJURE_KEY_CHANGED")
end

CB.KeyString = function(key) return ns.MageBar.KeyString(key) end

function CB.StartKeyCapture()
    ns.MageBar.CaptureKey("Conjure button", CB.SetKey)
end
