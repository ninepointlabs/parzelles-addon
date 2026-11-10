-- Item tooltip: spec-aware upgrade tips vs. the equipped item in the same slot.
local _, ns = ...

local Tooltip = {}
ns.Tooltip = Tooltip

local GREEN, RED, GREY, GOLD, WHITE = "|cff3fdc5a", "|cffff5050", "|cff9a9a9a", "|cffffd200", "|cffffffff"

-- itemID -> research notes (gear lists, wands) so the tooltip can say "recommended".
local index
local function ResearchIndex()
    if index then return index end
    index = {}
    for bracket, list in pairs(ns.Data.GearBrackets or {}) do
        for _, g in ipairs(list) do
            index[g.item_id] = index[g.item_id] or {}
            table.insert(index[g.item_id], bracket .. " list (" .. (g.source or "?") .. ")")
        end
    end
    for _, w in ipairs(ns.Data.Wands or {}) do
        index[w.item_id] = index[w.item_id] or {}
        if w.dps then table.insert(index[w.item_id], ("wand list: %.1f DPS"):format(w.dps)) end
    end
    return index
end
Tooltip.ResearchIndex = ResearchIndex

-- Against an (almost) empty slot a percentage is meaningless (+5175% in Tim's
-- screenshot); say "much better/worse" past 300%.
local function pctText(v)
    if v >= 300 then return "(much better)" end
    if v <= -300 then return "(much worse)" end
    return ("%+.1f%%"):format(v)
end

-- Build tooltip lines for a link and spec. Pure (returns strings) for testing.
function Tooltip.LinesFor(link, spec, profile, level, percentScale, opts)
    opts = opts or {}
    local lines = {}
    local res = ns.Stats.Compare(link, spec, level, profile, percentScale, opts.itemInfo, opts.equippedLink)
    if not res then return lines end
    local head = GOLD .. ns.TITLE .. "|r " .. GREY .. "· " .. (spec or "no spec picked") .. "|r"
    if res.unusable then
        table.insert(lines, head .. "  " .. RED .. "Mages can't use this|r")
        return lines
    end
    if res.pending then
        table.insert(lines, head .. "  " .. GREY .. "loading item data...|r")
        return lines
    end
    local setLabel = (res.setName == "Leveling") and "leveling weights" or (res.setName .. " weights")
    table.insert(lines, head .. GREY .. " (" .. setLabel .. ")|r")
    if res.isEquipped then
        table.insert(lines, GREY .. "Equipped|r")
        return lines
    end
    local against = res.against
    local vs = ""
    if against.link then
        local name = against.link:match("%[(.-)%]")
        if name then vs = " vs " .. name end
    end
    local canWear = not (res.minLevel and level and res.minLevel > level)
    if against.empty then
        table.insert(lines, GREEN .. "UPGRADE: that slot is empty|r")
    elseif math.abs(res.delta) < 0.05 then
        table.insert(lines, GREY .. "Sidegrade" .. vs .. "|r")
    elseif res.delta > 0 then
        table.insert(lines, GREEN .. "UPGRADE " .. (res.pct and pctText(res.pct) or ("+" .. ("%.1f"):format(res.delta) .. " score")) .. vs .. "|r")
    else
        table.insert(lines, RED .. "Downgrade " .. (res.pct and pctText(res.pct) or (("%.1f"):format(res.delta) .. " score")) .. vs .. "|r")
    end
    if res.wandDelta and math.abs(res.wandDelta) > 0.05 then
        table.insert(lines, (res.wandDelta > 0 and GREEN or RED) .. ("Wand DPS %+.1f|r"):format(res.wandDelta))
    end
    if opts.showStats ~= false then
        -- What improves (and what you'd give up), most important stat for your spec first.
        local order, seen = {}, {}
        local prio = ns.Data.StatPriority[res.setName]
        for _, k in ipairs(prio and prio.keys or {}) do table.insert(order, k) seen[k] = true end
        for _, k in ipairs({ "DAMAGE", "SPELL_CRIT", "SPELL_HIT", "INT", "SPI", "MP5", "STA", "OFF_SCHOOL" }) do
            if not seen[k] then table.insert(order, k) seen[k] = true end
        end
        local gains, losses = {}, {}
        for _, key in ipairs(order) do
            local d = res.statDelta[key]
            if d then
                local num = (d % 1 == 0) and ("%+d"):format(d) or ("%+.1f"):format(d)
                local label = ns.Stats.LABELS[key]
                if key == "SPELL_HIT" or key == "SPELL_CRIT" then label = label:gsub(" %%", "") num = num .. "%" end
                local effect = ns.Stats.Effect(key, d)
                local line = (d > 0 and GREEN or RED) .. "  " .. num .. " " .. label .. "|r" .. (effect and (GREY .. "  (" .. effect .. ")|r") or "")
                -- Other-school damage is neither a gain nor a loss for this spec: list it as a note.
                if key == "OFF_SCHOOL" then table.insert(gains, GREY .. "  " .. num .. " " .. label .. " (not your school)|r")
                else table.insert(d > 0 and gains or losses, line) end
            end
        end
        if #gains > 0 then
            table.insert(lines, WHITE .. "What improves:|r")
            for _, l in ipairs(gains) do table.insert(lines, l) end
        end
        if #losses > 0 then
            table.insert(lines, WHITE .. "What you'd lose:|r")
            for _, l in ipairs(losses) do table.insert(lines, l) end
        end
    end
    if ns.Stats.IsUpgrade(res, level) then
        table.insert(lines, GREEN .. ">> Equip this: it's better for your " .. (spec or "") .. " than what you're wearing.|r")
    elseif res.delta and res.delta > 0.05 and not canWear then
        table.insert(lines, GOLD .. ("Upgrade once you reach level %d.|r"):format(res.minLevel))
    end
    local itemID = tonumber(link:match("item:(%d+)"))
    local notes = itemID and ResearchIndex()[itemID]
    if notes then table.insert(lines, GOLD .. "Recommended: |r" .. table.concat(notes, "; ")) end
    table.insert(lines, GREY .. "Estimate from research stat priority order; % stats ×" .. (percentScale or 10) .. " (addon assumption)|r")
    return lines
end

local function OnItem(tooltip, needShow)
    if not ns.db or not ns.db.global.tooltip.enabled then return end
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
    local ok, _, link = pcall(tooltip.GetItem, tooltip)
    if not ok or not link then return end
    local level = UnitLevel("player")
    local g = ns.db.global
    local spec = ns.DB.ActiveSpec()
    local lines = Tooltip.LinesFor(link, spec, ns.DB.Profile(), level, g.percentScale, { showStats = g.tooltip.showStats })
    if #lines == 0 then return end
    tooltip:AddLine(" ")
    for _, l in ipairs(lines) do tooltip:AddLine(l, 1, 1, 1, true) end
    -- Second profile (dual-spec ready): one compact line if it has a different spec.
    local other = ns.DB.Profile(ns.DB.OtherProfileId())
    if other.spec and other.spec ~= spec then
        local res = ns.Stats.Compare(link, other.spec, level, other, g.percentScale)
        if res and res.delta and not res.isEquipped then
            local col = res.delta > 0.05 and GREEN or (res.delta < -0.05 and RED or GREY)
            local txt = res.against.empty and "upgrade (empty slot)" or (res.pct and ("%+.1f%%"):format(res.pct) or ("%+.1f"):format(res.delta))
            tooltip:AddLine(GREY .. "Profile " .. ns.DB.OtherProfileId() .. " (" .. other.spec .. "): |r" .. col .. txt .. "|r")
        end
    end
    if needShow then tooltip:Show() end -- legacy hook path needs a resize; the data processor lays out itself
end

function Tooltip.Install()
    if Tooltip.installed then return end
    Tooltip.installed = true
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt) pcall(OnItem, tt) end)
    else
        GameTooltip:HookScript("OnTooltipSetItem", function(tt) pcall(OnItem, tt, true) end)
    end
end
