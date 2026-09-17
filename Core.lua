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

local function on_addon_loaded(loaded_addon)
    if loaded_addon ~= ADDON_NAME then
        return
    end

    AuctionpadDB = Auctionpad.Data.initialize(AuctionpadDB)
    Auctionpad.db = AuctionpadDB
end

local function on_player_login()
    -- Nothing to do yet; UI modules will hook in here.
end

local event_frame = CreateFrame("Frame")
event_frame:RegisterEvent("ADDON_LOADED")
event_frame:RegisterEvent("PLAYER_LOGIN")
event_frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        on_addon_loaded(...)
    elseif event == "PLAYER_LOGIN" then
        on_player_login()
    end
end)

Auctionpad.eventFrame = event_frame
