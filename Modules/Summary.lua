-- Post-fight summary: what you cast and mana tips.
-- Uses UNIT_SPELLCAST_SUCCEEDED for the player only (no combat log). If the
-- client hides spell ids as secret values in combat, those casts are counted as
-- "hidden" and the summary says so instead of guessing.
local _, ns = ...

local Summary = {}
ns.Summary = Summary

local fight

function Summary.Start(now, manaPct)
    fight = { start = now, manaStart = manaPct, casts = {}, order = {}, hidden = 0 }
end

function Summary.OnCast(spellID, name)
    if not fight then return end
    if spellID == nil or ns.Auras.IsSecret(spellID) then
        fight.hidden = fight.hidden + 1
        return
    end
    name = name or ns.Auras.SpellName(spellID) or tostring(spellID)
    if spellID == ns.Rotation.SHOOT_ID then name = "Wand" end
    if not fight.casts[name] then
        fight.casts[name] = 0
        table.insert(fight.order, name)
    end
    fight.casts[name] = fight.casts[name] + 1
end

-- Rule-based tips. Each tip references a mechanic in content/learn.json.
-- knows(name) and gemCount are injectable for tests.
function Summary.Tips(f, spec, context, knows, gemCount)
    knows = knows or function(name) return ns.Progress.Knows(name) end
    local tips = {}
    local dur = f.duration or 0
    local used = f.manaStart and f.manaEnd and (f.manaStart - f.manaEnd) or nil
    local c = f.casts
    local function n(name) return c[name] or 0 end
    if spec == "Arcane" and n("Arcane Blast") >= 4 and n("Arcane Missiles") == 0 and knows("Arcane Missiles") then
        table.insert(tips, "Arcane Blast but no Arcane Missiles. Spend Missile Barrage procs on Arcane Missiles: they're fast and free.")
    end
    if spec == "Fire" and dur >= 10 and n("Pyroblast") == 0 and knows("Pyroblast") and n("Fireball") + n("Scorch") >= 3 then
        table.insert(tips, "No Pyroblast. Crits stack Heating Up, which makes your next Pyroblast much faster: use it.")
    end
    if spec == "Frost" and n("Frost Nova") > 0 and n("Ice Lance") == 0 and knows("Ice Lance") then
        table.insert(tips, "You used Frost Nova but no Ice Lance. Ice Lance hits frozen targets for triple damage.")
    end
    if f.manaEnd and f.manaEnd < 20 then
        if context == "solo" and n("Wand") == 0 then
            table.insert(tips, "Mana ended under 20% and you never used your wand. Finish low enemies with the wand so Spirit regen kicks in sooner (five-second rule).")
        elseif (gemCount or 0) > 0 then
            table.insert(tips, "Mana ended under 20% with a mana gem in your bags. Use the gem first, then Evocation, then drink.")
        else
            table.insert(tips, "Mana ended under 20%. Lower ranks cost less; drink between pulls.")
        end
        if knows("Evocation") then
            local left = ns.Auras.CooldownLeft and ns.Auras.CooldownLeft(ns.Rotation.SpellId("Evocation") or "Evocation")
            if left == 0 then table.insert(tips, "Evocation is ready: channel it now instead of drinking.") end
        end
    end
    if used and used > 0 and dur > 0 and #tips == 0 then
        table.insert(tips, ("Mana used: %.0f%% over %ds. Nice and tidy."):format(used, dur))
    end
    if f.hidden > 0 then
        table.insert(tips, ("%d cast(s) were hidden by the client's addon restrictions and aren't counted."):format(f.hidden))
    end
    return tips
end

function Summary.Finish(now, manaPct)
    if not fight then return nil end
    local f = fight
    fight = nil
    f.duration = math.floor((now - f.start) + 0.5)
    f.manaEnd = manaPct
    local total = 0
    for _, v in pairs(f.casts) do total = total + v end
    if f.duration < 4 or (total == 0 and f.hidden == 0) then return nil end
    local spec = ns.DB.ActiveSpec()
    local counts = ns.Conjure and ns.Conjure.Counts() or {}
    f.tips = Summary.Tips(f, spec, ns.DB.Profile().rotationContext, nil, counts.gem)
    Summary.last = f
    return f
end

function Summary.Text(f)
    local parts = {}
    table.sort(f.order, function(a, b) return f.casts[a] > f.casts[b] end)
    for _, name in ipairs(f.order) do table.insert(parts, name .. " x" .. f.casts[name]) end
    return table.concat(parts, ", ")
end
