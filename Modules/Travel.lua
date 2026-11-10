-- Teleports & portals: your faction's list, what you know, reagents in bags and
-- where to buy them. Other-faction spells are never listed. The clickable
-- buttons live in UI/Panels/Portals.lua (secure action buttons, out of combat).
local _, ns = ...

local Travel = {}
ns.Travel = Travel

-- Rows from research (Data.TeleportsPortals), falling back to trainer spells
-- with category teleport/portal when the dedicated list is missing.
function Travel.All()
    local list = {}
    if ns.Data.TeleportsPortals and #ns.Data.TeleportsPortals > 0 then
        for _, p in ipairs(ns.Data.TeleportsPortals) do table.insert(list, p) end
    else
        for _, s in ipairs(ns.Data.Spells) do
            if s.category == "teleport" or s.category == "portal" then
                table.insert(list, { name = s.display, spell_id = s.wowhead_base_spell_id, kind = s.category, faction = s.faction,
                    level = s.rank_learn_levels[1], source_url = s.source_url, checked = s.checked })
            end
        end
    end
    return list
end

-- Your faction only: { teleports = {...}, portals = {...} }, each entry
-- { rec, known, level, available }.
function Travel.ForFaction(faction, level)
    local out = { teleport = {}, portal = {} }
    for _, p in ipairs(Travel.All()) do
        local mine = p.faction == nil or p.faction == "Both" or p.faction == faction
        if mine and out[p.kind] then
            local known = ns.Progress.KnowsSpell(p.spell_id) or ns.Progress.Knows(p.name)
            table.insert(out[p.kind], { rec = p, known = known, level = p.level, available = p.level and level >= p.level })
        end
    end
    for _, k in ipairs({ "teleport", "portal" }) do
        table.sort(out[k], function(a, b)
            if (a.level or 99) ~= (b.level or 99) then return (a.level or 99) < (b.level or 99) end
            return a.rec.name < b.rec.name
        end)
    end
    return out
end

local function reagentByName(name)
    for _, r in ipairs(ns.Data.Reagents or {}) do
        if r.name == name then return r end
    end
end
Travel.Reagent = reagentByName

-- Count of a reagent in bags (by research ID, or by name when the ID isn't sourced).
function Travel.ReagentCount(r)
    if not r then return nil end
    if r.item_id then return ns.Reminders.ItemCount(r.item_id) end
    local n, seen = 0, false
    if C_Container then
        for bag = 0, (NUM_BAG_SLOTS or 4) do
            local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
            for slot = 1, (ok and slots or 0) do
                local okInfo, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
                local link = okInfo and info and info.hyperlink
                if link and link:match("%[(.-)%]") == r.name then
                    n = n + (info.stackCount or 1)
                    seen = true
                end
            end
        end
    end
    return n, seen
end

-- Your hearthstone city, if it's a city you can teleport to.
function Travel.HearthHint(entries)
    local bind = GetBindLocation and GetBindLocation()
    if not bind or bind == "" then return nil end
    for _, e in ipairs(entries or {}) do
        local city = e.rec.city or (e.rec.name:match(":%s*(.+)$"))
        if e.known and city and (bind:find(city, 1, true) or city:find(bind, 1, true)) then
            return ("Your hearthstone is set to %s, which you can already teleport to. Set it to the inn where you're questing instead."):format(bind)
        end
    end
    return nil
end
