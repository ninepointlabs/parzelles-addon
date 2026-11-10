-- "Buff next" button: one press casts Arcane Intellect on the next friendly
-- player who needs it, nearest first. Ported from Andric's Addon's Fortitude
-- button (same rules, same look), plus two mage twists:
--   * Warriors and Rogues are skipped (no mana, Intellect is wasted on them).
--   * Arcane Brilliance, if you know it, is used when 3+ of your party need the
--     buff. No Forever source confirms Arcane Brilliance exists (research gap),
--     so it's only ever used once your spellbook has it.
--
-- Blizzard rules this follows:
--   * A secure action button does the cast; every cast needs your click / key
--     press. The addon never casts by itself.
--   * Who the button targets only changes out of combat. In combat it keeps its
--     last target (and says so).
--   * It casts through the button's own "/cast [@unit,help,nodead] Arcane
--     Intellect" line, which Andric's Addon confirmed works on Forever (a type
--     "spell" button didn't). Strangers are reached with /targetexact (Forever
--     silently ignores [@nameplateN]) and your target is restored afterwards.
--   * Distances to players outside your group aren't available to addons, so
--     "nearest" = you, then group members (nearest first when the client reports
--     distance), your target, then friendly players with a visible nameplate.
local _, ns = ...
local UI = ns.UI

local Int = {}
ns.Intellect = Int

Int.NAME = "ParzellesIntellectButton"
Int.CLICK = Int.NAME
Int.SPELL = "Arcane Intellect"
Int.BRILLIANCE = "Arcane Brilliance" -- unconfirmed for Forever; by name only
Int.RECENT_SECONDS = 4 -- skip someone we just buffed until their aura shows up
Int.ICON = "Interface\\Icons\\Spell_Holy_MagicalSentry"

local btn, cell, current
local recent = {} -- guid -> GetTime() of our last cast on them

local function safe(fn, ...)
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil
end

function Int.SpellId() return ns.Rotation.SpellId(Int.SPELL) end

local function spellName()
    return ns.Auras.SpellName(Int.SpellId()) or Int.SPELL
end

function Int.KnowsBrilliance()
    return ns.Progress.Knows(Int.BRILLIANCE) and true or false
end

-- Does this unit already have Arcane Intellect (or Brilliance)? true/false/nil(unknown)
function Int.HasBuff(unit)
    local ai = ns.Auras.Find(unit, spellName(), "HELPFUL")
    if ai then return true end
    local ab = ns.Auras.Find(unit, Int.BRILLIANCE, "HELPFUL")
    if ab then return true end
    if ai == nil or ab == nil then return nil end
    return false
end

function Int.InRange(unit)
    if UnitIsUnit("player", unit) then return true end
    if C_Spell and C_Spell.IsSpellInRange then
        local r = safe(C_Spell.IsSpellInRange, Int.SpellId() or Int.SPELL, unit)
        if r ~= nil then return r end
        return safe(C_Spell.IsSpellInRange, spellName(), unit)
    end
    return nil
end

-- Unit tokens to consider, in "nearest first" order.
function Int.CandidateUnits()
    local list = { { unit = "player", order = 0 } }
    local group = {}
    if IsInRaid() then
        for i = 1, 40 do table.insert(group, "raid" .. i) end
    elseif IsInGroup() then
        for i = 1, 4 do table.insert(group, "party" .. i) end
    end
    for _, u in ipairs(group) do
        if UnitExists(u) then
            local d, checked = nil, false
            if UnitDistanceSquared then d, checked = safe(UnitDistanceSquared, u) end
            local dist = (checked and type(d) == "number" and not ns.Auras.IsSecret(d)) and d or nil
            table.insert(list, { unit = u, order = 1, dist = dist })
        end
    end
    table.insert(list, { unit = "target", order = 2 })
    for i = 1, 40 do
        local u = "nameplate" .. i
        if UnitExists(u) then table.insert(list, { unit = u, order = 3 }) end
    end
    return list
end

-- Pick the next unit to buff. Returns { unit, name, guid, rangeKnown, buffKnown } or nil,
-- plus a reason, the eligible count and how many group members need it (for Brilliance).
function Int.Pick(now)
    now = now or GetTime()
    local seen, eligible = {}, {}
    local outOfRange, groupNeed = 0, 0
    for _, c in ipairs(Int.CandidateUnits()) do
        local u = c.unit
        local guid = UnitExists(u) and UnitGUID(u)
        if guid and not ns.Auras.IsSecret(guid) and not seen[guid] then
            seen[guid] = true
            local ok = UnitIsPlayer(u) and UnitCanAssist("player", u) and not UnitIsDeadOrGhost(u)
                and UnitIsConnected(u) and ns.Auras.UsesMana(u)
                and not (recent[guid] and now - recent[guid] < Int.RECENT_SECONDS)
            if ok then
                local has = Int.HasBuff(u)
                local range = Int.InRange(u)
                if range == false then
                    if has ~= true then outOfRange = outOfRange + 1 end
                elseif has ~= true then
                    if c.order <= 1 then groupNeed = groupNeed + 1 end
                    table.insert(eligible, { unit = u, guid = guid, name = UnitName(u), order = c.order, dist = c.dist,
                        buffKnown = has == false, rangeKnown = range == true })
                end
            end
        end
    end
    table.sort(eligible, function(a, b)
        -- Confirmed missing + confirmed in range first, then group order, then distance.
        local ak = (a.buffKnown and 0 or 1) + (a.rangeKnown and 0 or 2)
        local bk = (b.buffKnown and 0 or 1) + (b.rangeKnown and 0 or 2)
        if ak ~= bk then return ak < bk end
        if a.order ~= b.order then return a.order < b.order end
        if a.dist and b.dist then return a.dist < b.dist end
        return false
    end)
    local reason
    if #eligible == 0 then
        if outOfRange > 0 then reason = outOfRange .. " player(s) need it but are out of range"
        else reason = "everyone nearby is buffed" end
    end
    return eligible[1], reason, #eligible, groupNeed
end

-- Which spell to cast on the pick: Brilliance for a party (not raid: the
-- research can't say whether Forever's Brilliance is party- or raid-wide).
function Int.SpellFor(pick, groupNeed)
    local cfg = ns.db.char.intellect
    if pick and pick.order <= 1 and cfg.brilliance and not IsInRaid() and IsInGroup()
        and (groupNeed or 0) >= (cfg.brillianceMin or 3) and Int.KnowsBrilliance() then
        return Int.BRILLIANCE
    end
    return spellName()
end

local DIRECT = { player = true, target = true, focus = true }
function Int.IsDirectUnit(unit)
    return DIRECT[unit] or unit:match("^party%d+$") ~= nil or unit:match("^raid%d+$") ~= nil
end

function Int.MacroText(unit, name, hadTarget, spell)
    spell = spell or spellName()
    if Int.IsDirectUnit(unit) or not name then
        return ns.MageBar.CastText(spell, unit)
    end
    return ("/targetexact %s\n/cast [@target,help,nodead] %s\n%s"):format(name, spell, hadTarget and "/targetlasttarget" or "/cleartarget")
end

-- Full name (with realm for other-realm players) for /targetexact.
local function fullName(unit)
    if GetUnitName then
        local ok, n = pcall(GetUnitName, unit, true)
        if ok and n and not ns.Auras.IsSecret(n) then return n end
    end
    return UnitName(unit)
end

-- Re-aim the secure button (out of combat only).
function Int.Update()
    if not btn then return end
    if InCombatLockdown() then
        btn.status:SetText(current and (UI.Hex(UI.C.dim) .. "in combat: " .. (current.name or "?") .. "|r") or (UI.Hex(UI.C.dim) .. "in combat|r"))
        return
    end
    local pick, reason, count, groupNeed = Int.Pick()
    current = pick
    if pick then
        local spell = Int.SpellFor(pick, groupNeed)
        pick.spell = spell
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", Int.MacroText(pick.unit, fullName(pick.unit), UnitExists("target"), spell))
        btn:SetAttribute("unit", pick.unit)
        btn.status:SetText((UnitIsUnit(pick.unit, "player") and "you" or (pick.name or "?")) .. (count > 1 and (UI.Hex(UI.C.dim) .. " +" .. (count - 1) .. "|r") or ""))
        btn.stock:SetText(spell == Int.BRILLIANCE and (UI.Hex(UI.C.info) .. "Brilliance|r") or "")
        btn.icon:SetTexture(spell == Int.BRILLIANCE and ns.Rotation.Icon(Int.BRILLIANCE) or Int.ICON)
        ns.MageBar.SetLook(btn, true)
    else
        btn:SetAttribute("type", nil)
        btn:SetAttribute("macrotext", nil)
        btn:SetAttribute("unit", nil)
        btn.status:SetText(UI.Hex(UI.C.dim) .. (reason == "everyone nearby is buffed" and "all buffed" or "none in range") .. "|r")
        btn.stock:SetText("")
        btn.icon:SetTexture(Int.ICON)
        ns.MageBar.SetLook(btn, false)
    end
    btn.reason = reason
    btn.count = count
    if GameTooltip:IsShown() and GameTooltip:GetOwner() == btn then btn:GetScript("OnEnter")(btn) end
end

function Int.ShouldShow()
    local cfg = ns.db and ns.db.char.intellect
    return cfg and cfg.enabled and ns.Progress.Knows(Int.SPELL) and true or false
end

function Int.Build()
    if btn then return btn end
    cell = ns.MageBar.Cell("intellect", 2)
    btn = CreateFrame("Button", Int.NAME, cell, "SecureActionButtonTemplate, BackdropTemplate")
    ns.MageBar.Decorate(btn, cell, Int.ICON)
    -- Mouse and key binding act on release (see SecureActionButton_OnClick).
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("useOnKeyDown", false)
    btn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText("Buff next: " .. (current and current.spell or Int.SPELL), 1, 0.82, 0)
        if current then
            GameTooltip:AddLine("Next: " .. (current.name or "?") .. (current.rangeKnown and "" or " (range unknown)") .. (current.buffKnown and "" or " (buff state unknown)"), 1, 1, 1)
            if (s.count or 0) > 1 then GameTooltip:AddLine((s.count - 1) .. " more after that", 0.7, 0.7, 0.7) end
        else
            GameTooltip:AddLine("Nobody to buff: " .. (s.reason or "?"), 0.7, 0.7, 0.7)
        end
        GameTooltip:AddLine("Click or press " .. (Int.Key() or "your key (Settings > Mage buttons)") .. ": one cast per press.", 0.6, 0.6, 0.6, true)
        GameTooltip:AddLine("Nearest = you, your group, your target, then players with friendly nameplates shown (Shift+V). Warriors and Rogues are skipped.", 0.6, 0.6, 0.6, true)
        if InCombatLockdown() then GameTooltip:AddLine("In combat the target can't change until combat ends.", 1, 0.5, 0.3, true) end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- After a press, remember who we just buffed, watch what the game did, move on.
    btn:HookScript("PostClick", function(_, _, down)
        if down then return end -- the action fires on release; ignore the press half
        if current and current.guid then recent[current.guid] = GetTime() end
        Int.Watch(current)
        C_Timer.After(0.3, function() if not InCombatLockdown() then Int.Update() end end)
    end)
    return btn
end

local ticker
function Int.Refresh()
    if InCombatLockdown() then return end -- show/hide of secure frames is blocked in combat
    Int.Build()
    local show = Int.ShouldShow()
    cell.want = show
    ns.MageBar.Layout()
    if show and not ticker then
        ticker = C_Timer.NewTicker(0.5, function() pcall(Int.Update) end)
    elseif not show and ticker then
        ticker:Cancel()
        ticker = nil
    end
    if show then Int.Update() end
    Int.ApplyKey()
end

-- Click diagnostics: for ~1.5s after a press, report whether a cast started,
-- failed (red error text) or was blocked by the client.
local watch
function Int.ConditionCheck(unit)
    if not unit or not SecureCmdOptionParse then return "n/a" end
    local ok, action, target = pcall(SecureCmdOptionParse, "[@" .. unit .. ",help,nodead] x")
    if not ok then return "error" end
    if action then return "pass (" .. tostring(target) .. ")" end
    return "FAIL"
end

function Int.Watch(target)
    watch = { name = target and target.name or "?", unit = target and target.unit, spell = target and target.spell or Int.SPELL }
    watch.cond = Int.ConditionCheck(watch.unit)
    watch.macro = btn and btn:GetAttribute("macrotext")
    C_Timer.After(1.5, function()
        local w = watch
        watch = nil
        if not w then return end
        if w.sent or w.succeeded then
            if ns.db.global.debug then ns.Print(w.spell .. " on " .. w.name .. (w.succeeded and " succeeded." or " started.")) end
        elseif w.error then
            ns.Print("|cffff5050" .. w.spell .. " on " .. w.name .. " failed:|r " .. w.error)
        elseif w.blocked then
            ns.Print("|cffff5050The game blocked the buff button|r (" .. w.blocked .. "). /parzelle buff debug shows details.")
        elseif target then
            ns.Print("|cffff5050Buff button pressed but no cast started|r (target " .. w.name .. ", " .. tostring(w.unit)
                .. ", macro condition " .. tostring(w.cond) .. "). Please share this line and /parzelle buff debug.")
        end
    end)
end

local function isOurs(spellID)
    local n = spellID and ns.Auras.SpellName(spellID)
    return n ~= nil and (n == spellName() or n == Int.BRILLIANCE)
end
ns.On("WOW_UNIT_SPELLCAST_SENT", function(unit, targetName, _, spellID)
    if unit ~= "player" or not isOurs(spellID) then return end
    if watch then watch.sent = true end
    -- Casts from the action bar don't fire PostClick: skip whoever we just buffed.
    if current and current.guid and (targetName == nil or targetName == current.name or (current.name and tostring(targetName):find("^" .. current.name))) then
        recent[current.guid] = GetTime()
    end
    C_Timer.After(0.3, function() if btn and not InCombatLockdown() then Int.Update() end end)
end)
ns.On("WOW_UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if watch and unit == "player" and isOurs(spellID) then watch.succeeded = true end
end)
ns.On("WOW_UNIT_SPELLCAST_FAILED", function(unit, _, spellID)
    if watch and unit == "player" and isOurs(spellID) and not watch.error then watch.error = "spell failed" end
end)
ns.On("WOW_UI_ERROR_MESSAGE", function(_, message)
    if watch and type(message) == "string" then watch.error = message end
end)
local function blocked(addon, func)
    if watch then watch.blocked = tostring(addon) .. ": " .. tostring(func) end
end
ns.On("WOW_ADDON_ACTION_BLOCKED", blocked)
ns.On("WOW_ADDON_ACTION_FORBIDDEN", blocked)

-- /parzelle buff debug
function Int.Debug()
    Int.Build()
    local function a(n) return tostring(btn:GetAttribute(n)) end
    ns.Print("Arcane Intellect button debug:")
    print(("  shown=%s combat=%s knows=%s brilliance=%s enabled=%s"):format(tostring(cell:IsShown()), tostring(InCombatLockdown()),
        tostring(ns.Progress.Knows(Int.SPELL)), tostring(Int.KnowsBrilliance()), tostring(ns.db.char.intellect.enabled)))
    print(("  type=%s unit=%s useOnKeyDown=%s"):format(a("type"), a("unit"), a("useOnKeyDown")))
    print("  macrotext=" .. a("macrotext"):gsub("\n", " | "))
    if current then
        print("  macro condition [@" .. current.unit .. ",help,nodead]: " .. Int.ConditionCheck(current.unit))
        print(("  next=%s (%s) inRange=%s hasBuff=%s"):format(tostring(current.name), current.unit,
            tostring(Int.InRange(current.unit)), tostring(Int.HasBuff(current.unit))))
    else
        print("  next=none (" .. tostring(btn.reason) .. ")")
    end
    print("  key: " .. tostring(Int.Key()))
end

-- Key binding (same as the Conjure button): override binding that clicks the
-- button, per character, out of combat. None by default.
function Int.Key()
    return ns.db and ns.db.char.intellect.key
end

function Int.ApplyKey()
    if not btn then return end
    ns.MageBar.ApplyKey(btn, Int.CLICK, Int.Key())
end

function Int.SetKey(key)
    if InCombatLockdown() then ns.Print("Can't change key bindings in combat.") return end
    Int.Build()
    ns.db.char.intellect.key = key
    Int.ApplyKey()
    ns.Print(key and ("Arcane Intellect button bound to " .. key .. ".") or "Arcane Intellect button key cleared.")
    ns.Fire("CONJURE_KEY_CHANGED")
end

function Int.StartKeyCapture()
    ns.MageBar.CaptureKey("Arcane Intellect button", Int.SetKey)
end
