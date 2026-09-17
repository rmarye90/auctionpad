-- Auctionpad — namespace, saved variables bootstrap and event dispatch.
-- Every piece of logic runs from ADDON_LOADED or later, never at file top level.

Auctionpad = Auctionpad or {}
Auctionpad.Version = "0.1.0"
Auctionpad.Utils = Auctionpad.Utils or {}
Auctionpad.Data = Auctionpad.Data or {}
Auctionpad.Stock = Auctionpad.Stock or {}
Auctionpad.Auction = Auctionpad.Auction or {}
Auctionpad.UI = Auctionpad.UI or {}

local ADDON_NAME = "Auctionpad"

-- Several events can fire in the same frame (a bag update is rarely alone);
-- coalesce them into a single refresh.
local refresh_pending = false

local function refresh_soon()
    if refresh_pending or not Auctionpad.UI.IsShown or not Auctionpad.UI.IsShown() then
        return
    end

    refresh_pending = true
    C_Timer.After(0.1, function()
        refresh_pending = false
        if not UnitAffectingCombat("player") then
            Auctionpad.UI.Refresh()
        end
    end)
end

Auctionpad.RefreshSoon = refresh_soon

local function on_addon_loaded(loaded_addon)
    if loaded_addon ~= ADDON_NAME then
        return
    end

    AuctionpadDB = Auctionpad.Data.initialize(AuctionpadDB)
    Auctionpad.db = AuctionpadDB
end

local function on_player_login()
    Auctionpad.UI.CreateMinimapButton()
end

-- Tracks whether the floating window was open right before the AH showed up,
-- so on_auction_house_closed() knows whether to bring it back.
local was_standalone_visible_before_ah = false

local function on_auction_house_show()
    Auctionpad.Auction.OwnedAuctions.request()

    was_standalone_visible_before_ah = Auctionpad.UI.IsStandaloneShown()
    if was_standalone_visible_before_ah then
        Auctionpad.UI.Hide()
    end

    Auctionpad.UI.AHTab.EnsureTab(Auctionpad.UI.GetContent())

    -- No forced Select() here by default: a well-behaved addon doesn't steal
    -- the tab focus the user (or Auctionator) already had. auto_open_at_ah
    -- opts into that if the user wants it.
    if Auctionpad.db.settings.auto_open_at_ah then
        Auctionpad.UI.AHTab.Select()
    end
end

local function on_auction_house_closed()
    if was_standalone_visible_before_ah then
        Auctionpad.UI.Show()
    end
    was_standalone_visible_before_ah = false
end

local function on_owned_auctions_updated()
    Auctionpad.Auction.OwnedAuctions.refresh(Auctionpad.db)
    refresh_soon()
end

local EVENT_HANDLERS = {
    ADDON_LOADED = on_addon_loaded,
    PLAYER_LOGIN = on_player_login,
    AUCTION_HOUSE_SHOW = on_auction_house_show,
    AUCTION_HOUSE_CLOSED = on_auction_house_closed,
    OWNED_AUCTIONS_UPDATED = on_owned_auctions_updated,
    BAG_UPDATE_DELAYED = refresh_soon,
    PLAYERBANKSLOTS_CHANGED = refresh_soon,
}

local event_frame = CreateFrame("Frame")
for event in pairs(EVENT_HANDLERS) do
    event_frame:RegisterEvent(event)
end

event_frame:SetScript("OnEvent", function(_, event, ...)
    local handler = EVENT_HANDLERS[event]
    if handler then
        handler(...)
    end
end)

Auctionpad.eventFrame = event_frame
