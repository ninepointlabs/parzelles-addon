-- Hand out button (third button on the mage bar) and the "Add food & water"
-- button on the trade window. Logic is in Modules/Share.lua.
--
--   Left-click:  open a trade with your target (a friendly player), or the next
--                person in your group who hasn't had food & water yet. The
--                trade window fills itself; you press Trade.
--   Right-click: pick who from your group (with their mana), tell the party
--                (if that's turned on), or start the list over.
--
-- Not a secure button: trading isn't a spell cast, and nothing here is
-- protected. Works in or out of combat; the game itself won't trade in combat.
local _, ns = ...
local UI = ns.UI

local SB = {}
ns.ShareButton = SB
SB.NAME = "ParzellesHandOutButton"
SB.ICON = "Interface\\Icons\\INV_Misc_Food_33"

local btn, cell, menu, fillBtn

local function manaText(e)
    if not e.manaUser then return UI.Hex(UI.C.dim) .. "no mana|r" end
    if not e.manaPct then return UI.Hex(UI.C.dim) .. "mana ?|r" end
    local col = e.manaPct < 30 and UI.C.bad or (e.manaPct < 60 and UI.C.warn or UI.C.good)
    return UI.Hex(col) .. ("%d%% mana"):format(e.manaPct) .. "|r"
end
SB.ManaText = manaText

function SB.Update()
    if not btn then return end
    local totals = ns.Share.Totals()
    local nxt = ns.Share.Next()
    btn.stock:SetText(UI.Hex(UI.C.dim) .. ("W %d · F %d"):format(totals.water, totals.food) .. "|r")
    if nxt then
        btn.status:SetText((nxt.fromTarget and "" or (UI.Hex(UI.C.dim) .. "next |r")) .. (nxt.name or "?"))
        ns.MageBar.SetLook(btn, totals.water + totals.food > 0)
    else
        btn.status:SetText(UI.Hex(UI.C.dim) .. (IsInGroup() and "all served" or "target someone") .. "|r")
        ns.MageBar.SetLook(btn, false)
    end
    btn.next = nxt
    if GameTooltip:IsShown() and GameTooltip:GetOwner() == btn then btn:GetScript("OnEnter")(btn) end
end

function SB.ShouldShow()
    local c = ns.db and ns.db.char.share
    if not (c and c.enabled) then return false end
    return (ns.Conjure.KnownSpell("water") or ns.Conjure.KnownSpell("food")) ~= nil
end

local function tooltip(s)
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    GameTooltip:SetText("Hand out food & water", 1, 0.82, 0)
    local c = ns.db.char.share
    GameTooltip:AddLine(("Each trade offers up to %d water and %d food."):format(c.water, c.food), 1, 1, 1, true)
    if s.next then
        GameTooltip:AddLine("Click: trade " .. (s.next.name or "?") .. (s.next.inRange == false and " (too far: walk closer)" or ""), 0.6, 1, 0.6, true)
    end
    local q = ns.Share.Queue()
    if #q > 0 then
        GameTooltip:AddLine(" ")
        for _, e in ipairs(q) do
            local left = (e.served and "|cff6f6f6f" or "|cffffffff") .. (e.name or "?") .. "|r" .. (e.served and "  (done)" or "")
            GameTooltip:AddDoubleLine(left, manaText(e))
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Right-click: pick someone, tell the party, start over.", 0.6, 0.6, 0.6, true)
    GameTooltip:AddLine("The trade window fills itself; you press Trade. Anyone in your group who opens a trade with you gets the same offer.", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

-- Right-click menu: one row per group member, then actions.
local function menuRow(i)
    if menu.rows[i] then return menu.rows[i] end
    local r = UI.Button(menu, "", 220, 22)
    r.label:ClearAllPoints()
    r.label:SetPoint("LEFT", 8, 0)
    r.label:SetJustifyH("LEFT")
    r.right = UI.Text(r, 11)
    r.right:SetPoint("RIGHT", -8, 0)
    menu.rows[i] = r
    return r
end

function SB.ShowMenu()
    if not menu then
        menu = CreateFrame("Frame", "ParzellesHandOutMenu", UIParent, "BackdropTemplate")
        menu:SetFrameStrata("DIALOG")
        menu:SetClampedToScreen(true)
        UI.Backdrop(menu, UI.C.bg, UI.Accent())
        menu.title = UI.Text(menu, 12, UI.C.dim)
        menu.title:SetPoint("TOPLEFT", 10, -8)
        menu.title:SetText("Hand out food & water")
        menu.close = CreateFrame("Button", nil, menu, "UIPanelCloseButton")
        menu.close:SetSize(20, 20)
        menu.close:SetPoint("TOPRIGHT", 0, 0)
        menu.rows = {}
        table.insert(UISpecialFrames, "ParzellesHandOutMenu") -- Esc closes it
        menu:Hide()
    end
    local rows = {}
    for _, e in ipairs(ns.Share.Queue()) do
        local unusable = e.dead or e.offline
        table.insert(rows, {
            text = (e.served and "|cff6f6f6f" or "") .. (e.name or "?") .. (e.served and " (done)|r" or "") .. (e.level and (UI.Hex(UI.C.dim) .. "  " .. e.level .. "|r") or ""),
            right = unusable and (UI.Hex(UI.C.dim) .. (e.dead and "dead" or "offline") .. "|r") or manaText(e),
            onClick = not unusable and function() menu:Hide() ns.Share.TradeWith(e.unit, e) end or nil,
        })
    end
    if #rows == 0 then table.insert(rows, { text = UI.Hex(UI.C.dim) .. "Not in a group: target a player and left-click.|r" }) end
    local c = ns.db.char.share
    if c.announce and IsInGroup() then
        table.insert(rows, { text = UI.Hex(UI.C.info) .. "Tell the group|r", right = UI.Hex(UI.C.dim) .. "\"" .. c.message:sub(1, 18) .. "...\"|r",
            onClick = function() menu:Hide() ns.Share.Announce() end })
    end
    table.insert(rows, { text = UI.Hex(UI.C.info) .. "Start over|r", right = UI.Hex(UI.C.dim) .. "everyone gets a turn|r",
        onClick = function() ns.Share.ResetQueue() menu:Hide() SB.Update() end })
    table.insert(rows, { text = UI.Hex(UI.C.info) .. "Settings|r", onClick = function() menu:Hide() UI.Open("settings", "Mage buttons") end })
    for i, row in ipairs(rows) do
        local r = menuRow(i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -26 - (i - 1) * 24)
        r.label:SetText(row.text)
        r.right:SetText(row.right or "")
        r:SetScript("OnClick", row.onClick)
        r:Show()
    end
    for i = #rows + 1, #menu.rows do menu.rows[i]:Hide() end
    menu:SetSize(236, 34 + #rows * 24)
    menu:ClearAllPoints()
    if btn then menu:SetPoint("BOTTOMLEFT", btn, "TOPRIGHT", 4, 0) else menu:SetPoint("CENTER") end
    menu:Show()
    return rows
end

function SB.Build()
    if btn then return btn end
    cell = ns.MageBar.Cell("share", 3)
    btn = CreateFrame("Button", SB.NAME, cell, "BackdropTemplate")
    ns.MageBar.Decorate(btn, cell, SB.ICON)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then SB.ShowMenu() else ns.Share.HandOut() end
        C_Timer.After(0.3, SB.Update)
    end)
    btn:SetScript("OnEnter", tooltip)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return btn
end

local ticker
function SB.Refresh()
    if InCombatLockdown() then return end -- the bar's layout only changes out of combat
    SB.Build()
    local show = SB.ShouldShow()
    cell.want = show
    ns.MageBar.Layout()
    if show and not ticker then
        ticker = C_Timer.NewTicker(1, function() pcall(SB.Update) end)
    elseif not show and ticker then
        ticker:Cancel()
        ticker = nil
    end
    if show then SB.Update() end
end

-- "Add food & water" on Blizzard's trade window: the same fill from your click,
-- for when auto-offer is off, or the game refused the automatic fill.
function SB.TradeButton()
    local tf = rawget(_G, "TradeFrame")
    if not tf then return nil end
    if not fillBtn then
        fillBtn = UI.Button(tf, "Add food & water", 150, 24, function() ns.Share.Fill(true) end)
        fillBtn:SetPoint("TOPLEFT", tf, "BOTTOMLEFT", 0, -2)
        fillBtn.tip = "Parzelle's Addon: puts conjured water and food in the trade (amounts in Settings > Mage buttons). You still press Trade."
    end
    return fillBtn
end

ns.On("SHARE_TRADE_SHOWN", function()
    local b = SB.TradeButton()
    if b then b:SetShown(ns.db.char.share.enabled and true or false) end
end)
ns.On("SHARE_TRADE_CLOSED", function() if btn then C_Timer.After(0.5, SB.Update) end end)
