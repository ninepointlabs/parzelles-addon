-- Hand out conjured food and water with as little effort as Blizzard allows.
--
-- What the client lets an addon do (checked against Blizzard's Forever UI
-- source, wow-ui-source@forever, API documentation):
--   * InitiateTrade(unit): opens a trade. Not restricted; we only call it from
--     your click on the Hand out button (or its menu).
--   * C_Container.PickupContainerItem / SplitContainerItem + ClickTradeButton:
--     put a stack (or part of one) into a trade slot. Not restricted in the
--     docs; ClickTradeButton isn't in the generated docs at all, so whether
--     Forever lets an addon call it outside a click is unconfirmed. If an
--     automatic fill is refused, the "Add food & water" button on the trade
--     window does the same thing from your click.
--   * AcceptTrade is restricted (C_SecureTransfer, HasRestrictions): the final
--     "Trade" click is always yours. We never press it.
--   * SendChatMessage is restricted: the optional party / whisper line is only
--     sent from your click, and is off by default.
--   * Trade range is about 11 yards (CheckInteractDistance index 2).
local _, ns = ...

local Share = {}
ns.Share = Share

Share.SLOTS = 6 -- tradable slots (MAX_TRADABLE_ITEMS); slot 7 is "will not be traded"
Share.SERVED_TTL = 15 * 60 -- the queue forgets who it served after 15 minutes
Share.TRADE_RANGE = 2 -- CheckInteractDistance index for trading

local served = {}  -- guid -> GetTime() of the last completed trade with them
local trade = nil  -- the open trade: { guid, name, filled, accepted }
local pending = nil -- trade we asked for: { guid, name, at }

-- ---------------------------------------------------------------------------
-- Pure helpers (tested headless)

-- Plan what to put in the trade window.
-- stacks: { {bag, slot, kind = "water"|"food", count, minLevel} ... }
-- opts:   { level = recipient level (nil = unknown), water = n, food = n,
--           manaUser = bool, slots = free trade slots }
-- Returns items { {bag, slot, count, kind, split} ... } and totals { water, food },
-- plus a list of kinds we wanted but had nothing usable for.
function Share.Plan(stacks, opts)
    local items, totals, short = {}, { water = 0, food = 0 }, {}
    local free = opts.slots or Share.SLOTS
    local want = { water = opts.manaUser == false and 0 or (opts.water or 0), food = opts.food or 0 }
    for _, kind in ipairs({ "water", "food" }) do
        if want[kind] > 0 then
            local usable = {}
            for _, s in ipairs(stacks) do
                if s.kind == kind and (s.count or 0) > 0 and (not opts.level or not s.minLevel or s.minLevel <= opts.level) then
                    table.insert(usable, s)
                end
            end
            -- Best rank they can use first (known level beats unknown), then fullest stack.
            table.sort(usable, function(a, b)
                local al, bl = a.minLevel or -1, b.minLevel or -1
                if al ~= bl then return al > bl end
                return (a.count or 0) > (b.count or 0)
            end)
            local left = want[kind]
            for _, s in ipairs(usable) do
                if left <= 0 or free <= 0 then break end
                local n = math.min(left, s.count)
                table.insert(items, { bag = s.bag, slot = s.slot, count = n, kind = kind, split = n < s.count })
                totals[kind] = totals[kind] + n
                left = left - n
                free = free - 1
            end
            if totals[kind] == 0 then table.insert(short, kind) end
        end
    end
    return items, totals, short
end

-- Order the group for handing out: not yet served first, then mana users by
-- lowest mana, then everyone else. entries: { name, manaUser, manaPct, served }
function Share.Sort(entries)
    table.sort(entries, function(a, b)
        if (a.served and 1 or 0) ~= (b.served and 1 or 0) then return not a.served end
        if (a.manaUser and 0 or 1) ~= (b.manaUser and 0 or 1) then return a.manaUser end
        local am, bm = a.manaPct or 101, b.manaPct or 101
        if am ~= bm then return am < bm end
        return (a.name or "") < (b.name or "")
    end)
    return entries
end

-- ---------------------------------------------------------------------------
-- Client readers

local function cfg() return ns.db.char.share end

local function safe(fn, ...)
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
    return nil
end

local function itemMinLevel(link)
    local getInfo = (C_Item and C_Item.GetItemInfo) or rawget(_G, "GetItemInfo")
    if not getInfo then return nil end
    local _, _, _, _, minLevel = safe(getInfo, link)
    if type(minLevel) ~= "number" or ns.Auras.IsSecret(minLevel) then return nil end
    return minLevel
end

-- Conjured water and food stacks in your bags.
function Share.Stacks()
    local out = {}
    if not C_Container then return out end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local n = safe(C_Container.GetContainerNumSlots, bag) or 0
        for slot = 1, n do
            local info = safe(C_Container.GetContainerItemInfo, bag, slot)
            if info and info.hyperlink and not info.isLocked then
                local kind = ns.Conjure.ItemKind(info.itemID, info.hyperlink)
                if kind == "water" or kind == "food" then
                    table.insert(out, { bag = bag, slot = slot, kind = kind, count = info.stackCount or 1,
                        minLevel = itemMinLevel(info.hyperlink), link = info.hyperlink })
                end
            end
        end
    end
    return out
end

function Share.Totals(stacks)
    local t = { water = 0, food = 0 }
    for _, s in ipairs(stacks or Share.Stacks()) do t[s.kind] = t[s.kind] + (s.count or 0) end
    return t
end

local function groupUnits()
    local list = {}
    if IsInRaid() then
        for i = 1, 40 do table.insert(list, "raid" .. i) end
    elseif IsInGroup() then
        for i = 1, 4 do table.insert(list, "party" .. i) end
    end
    return list
end

function Share.InTradeRange(unit)
    if not CheckInteractDistance then return nil end
    local ok, r = pcall(CheckInteractDistance, unit, Share.TRADE_RANGE)
    if not ok or ns.Auras.IsSecret(r) then return nil end
    return r and true or false
end

function Share.IsServed(guid, now)
    local t = guid and served[guid]
    return t ~= nil and ((now or GetTime()) - t) < Share.SERVED_TTL
end

function Share.MarkServed(guid) if guid then served[guid] = GetTime() end end
function Share.ResetQueue() served = {} end

-- Group members (not you) in hand-out order.
function Share.Queue()
    local out, now = {}, GetTime()
    for _, u in ipairs(groupUnits()) do
        local guid = UnitExists(u) and UnitGUID(u)
        if guid and not ns.Auras.IsSecret(guid) and not UnitIsUnit(u, "player") and UnitIsPlayer(u) then
            local manaUser = ns.Auras.UsesMana(u)
            table.insert(out, {
                unit = u, guid = guid, name = UnitName(u), level = UnitLevel(u),
                manaUser = manaUser, manaPct = manaUser and ns.Auras.PowerPct(u) or nil,
                served = Share.IsServed(guid, now), dead = UnitIsDeadOrGhost(u), offline = not UnitIsConnected(u),
                inRange = Share.InTradeRange(u),
            })
        end
    end
    return Share.Sort(out)
end

-- Who the Hand out button trades next: your target if it's a friendly player,
-- else the first group member not yet served (alive, online).
function Share.Next()
    if UnitExists("target") and UnitIsPlayer("target") and UnitCanAssist("player", "target") and not UnitIsUnit("target", "player") then
        return { unit = "target", guid = UnitGUID("target"), name = UnitName("target"), level = UnitLevel("target"),
            manaUser = ns.Auras.UsesMana("target"), inRange = Share.InTradeRange("target"), fromTarget = true }
    end
    for _, e in ipairs(Share.Queue()) do
        if not e.served and not e.dead and not e.offline then return e end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Actions (from your clicks)

local function send(msg, chatType, target)
    local fn = (C_ChatInfo and C_ChatInfo.SendChatMessage) or rawget(_G, "SendChatMessage")
    if not fn then return false end
    return pcall(fn, msg, chatType, nil, target)
end

-- "Water's up" line to your party/raid. Click only; off unless enabled.
function Share.Announce()
    local c = cfg()
    if not c.announce then return false end
    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)
    if not channel then ns.Print("You're not in a group.") return false end
    return send(c.message, channel)
end

-- Open a trade with a unit (your click). The fill happens when the trade window opens.
function Share.TradeWith(unit, entry)
    if not unit or not UnitExists(unit) then ns.Print("Nobody to hand out to.") return false end
    local name = UnitName(unit) or "?"
    local totals = Share.Totals()
    if totals.water + totals.food == 0 then
        ns.Print("No conjured food or water in your bags. Press the Conjure button first.")
        return false
    end
    if Share.InTradeRange(unit) == false then
        ns.Print(name .. " is too far away to trade (about 10 yards).")
        if cfg().announce and UnitIsPlayer(unit) then
            local full = (GetUnitName and safe(GetUnitName, unit, true)) or name
            send(cfg().message, "WHISPER", full)
        end
        return false
    end
    pending = { guid = UnitGUID(unit), name = name, at = GetTime() }
    local ok = pcall(InitiateTrade, unit)
    if not ok then ns.Print("The game didn't open a trade with " .. name .. ".") return false end
    return true
end

-- Left-click on Hand out.
function Share.HandOut()
    local nxt = Share.Next()
    if not nxt then
        if IsInGroup() then ns.Print("Everyone in your group has had food and water (Hand out > right-click > Start over).")
        else ns.Print("Target a player, or join a group, to hand out food and water.") end
        return false
    end
    return Share.TradeWith(nxt.unit, nxt)
end

-- ---------------------------------------------------------------------------
-- Filling the trade window

local function freeTradeSlots()
    local free = {}
    for i = 1, Share.SLOTS do
        local name = GetTradePlayerItemInfo and safe(GetTradePlayerItemInfo, i)
        if not name then table.insert(free, i) end
    end
    return free
end

function Share.IsTrading() return trade ~= nil end

-- Put the planned stacks into the trade window. fromClick = the player pressed
-- the trade-window button (always fills, even if auto-offer is off).
function Share.Fill(fromClick)
    if not trade then return false, "no trade open" end
    if trade.filled and not fromClick then return false, "already filled" end
    local c = cfg()
    local free = freeTradeSlots()
    local level = UnitLevel("NPC")
    if type(level) ~= "number" or level <= 0 or ns.Auras.IsSecret(level) then level = nil end
    local manaUser = ns.Auras.UsesMana("NPC")
    local items, totals, short = Share.Plan(Share.Stacks(), { level = level, water = c.water, food = c.food, manaUser = manaUser, slots = #free })
    trade.filled = true
    if #items == 0 then
        local why = (#free == 0) and "the trade window is full" or
            ((level and #short > 0) and ("nothing conjured that a level " .. level .. " can use") or "no conjured food or water in your bags")
        ns.Print("Nothing added for " .. (trade.name or "?") .. ": " .. why .. ".")
        return false, why
    end
    local step = 0
    local function place()
        step = step + 1
        local it = items[step]
        if not it or not trade then return end
        if CursorHasItem and CursorHasItem() then ClearCursor() end
        local ok
        if it.split then ok = pcall(C_Container.SplitContainerItem, it.bag, it.slot, it.count)
        else ok = pcall(C_Container.PickupContainerItem, it.bag, it.slot) end
        if ok then ok = pcall(ClickTradeButton, free[step]) end
        if CursorHasItem and CursorHasItem() then ClearCursor() end
        if not ok then
            ns.Print("The game didn't let the addon add items. Drag them in yourself, or press \"Add food & water\" on the trade window.")
            return
        end
        if step < #items then C_Timer.After(0.15, place) end
    end
    place()
    local parts = {}
    if totals.water > 0 then table.insert(parts, totals.water .. " water") end
    if totals.food > 0 then table.insert(parts, totals.food .. " food") end
    local note = (manaUser == false and (c.water or 0) > 0) and " (no water: they don't use mana)" or ""
    ns.Print(("Offered %s to %s%s. Press Trade to finish."):format(table.concat(parts, " + "), trade.name or "?", note))
    return true, totals
end

local function isGroupMember(guid)
    if not guid then return false end
    for _, u in ipairs(groupUnits()) do
        if UnitExists(u) and UnitGUID(u) == guid then return true end
    end
    return false
end

function Share.OnTradeShow()
    local guid, name = UnitGUID("NPC"), UnitName("NPC")
    trade = { guid = guid, name = name, filled = false }
    local asked = pending and pending.guid == guid and (GetTime() - pending.at) < 30
    pending = nil
    local c = cfg()
    ns.Fire("SHARE_TRADE_SHOWN")
    if not c.enabled then return end
    if asked or (c.autoOffer and (c.autoOfferAnyone or isGroupMember(guid))) then
        C_Timer.After(0.2, function() Share.Fill(false) end)
    end
end

ns.On("WOW_TRADE_SHOW", Share.OnTradeShow)
ns.On("WOW_TRADE_ACCEPT_UPDATE", function(player, target)
    if trade and player == 1 and target == 1 then trade.accepted = true end
end)
-- "Trade complete." can arrive just after TRADE_CLOSED, so remember the last
-- closed trade for a moment.
local lastClosed
ns.On("WOW_UI_INFO_MESSAGE", function(_, message)
    local done = rawget(_G, "ERR_TRADE_COMPLETE")
    if not done or message ~= done then return end
    if trade then trade.accepted = true
    elseif lastClosed and GetTime() - lastClosed.at < 3 then Share.MarkServed(lastClosed.guid) end
end)
ns.On("WOW_TRADE_CLOSED", function()
    if trade then
        if trade.accepted then Share.MarkServed(trade.guid) end
        lastClosed = { guid = trade.guid, at = GetTime() }
    end
    trade = nil
    ns.Fire("SHARE_TRADE_CLOSED")
end)
