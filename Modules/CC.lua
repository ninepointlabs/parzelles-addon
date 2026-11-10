-- Polymorph / crowd-control tracker. Advice only.
--
-- When you cast Polymorph, we remember who it went on (UNIT_SPELLCAST_SENT gives
-- the target name; the target's GUID if it's still your target). Then we look
-- for your Polymorph aura on target / focus / mouseover / nameplates to read
-- the time left. If the aura vanishes well before it should have ended, that's
-- a break and you get a warning. No combat log: if the client hides aura data
-- (secret values), the tracker says "hidden" instead of guessing.
local _, ns = ...

local CC = {}
ns.CC = CC

CC.EARLY_BREAK_MARGIN = 1.5 -- seconds before the expected end that count as "broke"
CC.COOLDOWNS = { "Frost Nova", "Counterspell", "Cone of Cold" }

local sheep -- { name, guid, castAt, expires, seen, state }
local pendingName

local function polyName()
    return ns.Auras.SpellName(ns.Rotation.SpellId("Polymorph")) or "Polymorph"
end

local function isPolymorph(spellID)
    if not spellID or ns.Auras.IsSecret(spellID) then return false end
    local n = ns.Auras.SpellName(spellID)
    return n ~= nil and n:find("^Polymorph") ~= nil
end
CC.IsPolymorph = isPolymorph

function CC.Current() return sheep end
function CC.Reset() sheep, pendingName = nil, nil end

-- UNIT_SPELLCAST_SENT (player, targetName, castGUID, spellID)
ns.On("WOW_UNIT_SPELLCAST_SENT", function(unit, targetName, _, spellID)
    if unit == "player" and isPolymorph(spellID) and type(targetName) == "string" and not ns.Auras.IsSecret(targetName) then
        pendingName = targetName
    end
end)

-- Called on UNIT_SPELLCAST_SUCCEEDED for the player.
function CC.OnCast(spellID, now)
    if not isPolymorph(spellID) then return end
    now = now or GetTime()
    local name, guid = pendingName, nil
    if UnitExists("target") then
        local tn = UnitName("target")
        if not name or name == tn then
            name = tn
            local g = UnitGUID("target")
            if g and not ns.Auras.IsSecret(g) then guid = g end
        end
    end
    pendingName = nil
    sheep = { name = name or "?", guid = guid, castAt = now, state = "cast" }
    if ns.db and ns.db.char.cc.enabled and ns.Hud and ns.Hud.Refresh then pcall(ns.Hud.Refresh) end
    CC.Scan(now)
end

local function units()
    local list = { "target", "focus", "mouseover" }
    for i = 1, 40 do list[#list + 1] = "nameplate" .. i end
    return list
end

local function matches(unit)
    if not sheep or not UnitExists(unit) then return false end
    if sheep.guid then
        local g = UnitGUID(unit)
        return g ~= nil and not ns.Auras.IsSecret(g) and g == sheep.guid
    end
    return UnitName(unit) == sheep.name
end

-- Look for our Polymorph aura on any unit we can see.
function CC.Scan(now)
    if not sheep or sheep.state == "broken" or sheep.state == "ended" then return end
    now = now or GetTime()
    local name = polyName()
    local sawUnit, hidden = false, false
    for _, u in ipairs(units()) do
        if matches(u) then
            sawUnit = true
            if not sheep.guid then
                local g = UnitGUID(u)
                if g and not ns.Auras.IsSecret(g) then sheep.guid = g end
            end
            local data = ns.Auras.Find(u, name, "HARMFUL|PLAYER")
            if data == nil then
                hidden = true
            elseif data then
                local exp = data.expirationTime
                if exp and not ns.Auras.IsSecret(exp) and exp > 0 then sheep.expires = exp end
                sheep.seen, sheep.lastSeen, sheep.state = true, now, "active"
                return sheep
            elseif sheep.seen then
                -- It was on, now it's gone.
                local early = sheep.expires and (sheep.expires - now) > CC.EARLY_BREAK_MARGIN
                sheep.state = early and "broken" or "ended"
                if early then
                    ns.Print(("|cffff5050Polymorph broke early|r on %s. Re-sheep it (one sheep at a time) or burn it down."):format(sheep.name))
                    ns.Fire("TOAST", "Polymorph broke!", sheep.name .. " is loose again.", ns.Rotation.Icon("Polymorph"))
                end
                return sheep
            end
        end
    end
    if hidden then sheep.state = "hidden"
    elseif not sawUnit and sheep.state ~= "active" then sheep.state = "unseen" end
    -- Past the expected end: done.
    if sheep.expires and now > sheep.expires + 1 then sheep.state = "ended" end
    return sheep
end

function CC.OnAura(unit)
    if sheep and matches(unit) then CC.Scan() end
end

-- One line for the HUD / Rotation screen, or nil when there's nothing to show.
function CC.StatusText(now)
    if not sheep then return nil end
    now = now or GetTime()
    if sheep.state == "active" and sheep.expires then
        local left = math.max(0, sheep.expires - now)
        if left <= 0 then return nil end
        local warn = left <= 5 and "|cffff9933" or "|cffb48cff"
        return ("%sPolymorph|r %s %ds"):format(warn, sheep.name, math.ceil(left))
    elseif sheep.state == "broken" then
        if now - (sheep.lastSeen or sheep.castAt) > 10 then return nil end
        return "|cffff5050Polymorph broke:|r " .. sheep.name
    elseif sheep.state == "hidden" then
        return "Polymorph " .. sheep.name .. " |cff9a9a9a(timer hidden)|r"
    elseif sheep.state == "cast" or sheep.state == "unseen" then
        if now - sheep.castAt > 50 then return nil end
        return "Polymorph " .. sheep.name .. " |cff9a9a9a(out of view)|r"
    end
    return nil
end

-- Known CC cooldowns: { {name, left} } (left nil = unknown).
function CC.Cooldowns()
    local out = {}
    for _, n in ipairs(CC.COOLDOWNS) do
        if ns.Rotation.Known(n) then
            table.insert(out, { name = n, left = ns.Rotation.LiveState.cooldown(n) })
        end
    end
    return out
end
