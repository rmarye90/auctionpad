-- WoW API mock for running the pure modules outside the game.
-- Every entry is a no-op default; specs override the ones they care about.
--
-- `require` caches the module, so specs that overwrite a global would leak into
-- the next file. Call WowApiMock.install() in before_each to get a clean slate.

local WowApiMock = {}

-- Methods are listed explicitly rather than auto-stubbed: a typo like
-- `frame:Setmovable(true)` must blow up in the smoke test, not silently no-op.
local REGION_METHODS = {
    "SetPoint", "SetAllPoints", "ClearAllPoints", "SetText", "SetTextColor", "SetWidth",
    "SetHeight", "SetSize", "SetTexture", "SetColorTexture", "SetTexCoord", "SetJustifyH",
    "SetWordWrap", "SetVertexColor", "Show", "Hide", "IsShown",
}

local FRAME_METHODS = {
    "SetSize", "SetPoint", "SetAllPoints", "ClearAllPoints", "SetWidth", "SetHeight",
    "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
    "EnableMouse", "SetMovable", "SetResizable", "SetClampedToScreen",
    "RegisterForDrag", "RegisterForClicks", "RegisterEvent", "UnregisterEvent",
    "StartMoving", "StopMovingOrSizing", "Show", "Hide", "Raise",
    "SetFrameStrata", "SetFrameLevel", "SetScrollChild", "SetVerticalScroll",
    "SetAutoFocus", "SetNumeric", "SetJustifyH", "SetText", "SetMaxLetters",
    "ClearFocus", "SetFocus", "LockHighlight", "UnlockHighlight", "SetHighlightTexture",
    "SetNormalTexture", "SetPushedTexture", "Enable", "Disable", "SetEnabled",
    -- Auction house tab docking (SetParent/GetParent/IsObjectType are defined below,
    -- with real bookkeeping instead of a no-op)
    "SetHitRectInsets", "SetDisplayMode", "SetTitle",
}

local function stub_region()
    local region = {}
    for _, method in ipairs(REGION_METHODS) do
        region[method] = function() end
    end
    return region
end

local function stub_frame()
    local frame = { scripts = {} }

    for _, method in ipairs(FRAME_METHODS) do
        frame[method] = function() end
    end

    frame.IsShown = function() return frame.shown == true end
    frame.Show = function()
        frame.shown = true
        local on_show = frame.scripts and frame.scripts.OnShow
        if on_show then on_show(frame) end
    end
    frame.Hide = function()
        frame.shown = false
        local on_hide = frame.scripts and frame.scripts.OnHide
        if on_hide then on_hide(frame) end
    end
    frame.GetText = function() return frame.text or "" end
    frame.HasFocus = function() return false end
    frame.GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end
    frame.GetCenter = function() return 0, 0 end
    frame.GetEffectiveScale = function() return 1 end
    frame.IsEnabled = function() return true end
    frame.IsObjectType = function() return true end
    frame.GetParent = function() return frame.parent end
    frame.SetParent = function(_, parent) frame.parent = parent end
    frame.SetScript = function(_, name, handler) frame.scripts[name] = handler end
    frame.GetScript = function(_, name) return frame.scripts[name] end
    frame.CreateFontString = stub_region
    frame.CreateTexture = stub_region

    return frame
end

WowApiMock.stub_frame = stub_frame

function WowApiMock.install()
    _G.CreateFrame = function() return stub_frame() end

    _G.UIParent = stub_frame()
    _G.Minimap = stub_frame()
    _G.GetCursorPosition = function() return 0, 0 end
    _G.GetCursorInfo = function() return nil end
    _G.ClearCursor = function() end
    _G.GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        SetItemByID = function() end,
        Show = function() end,
        Hide = function() end,
    }

    _G.print = function() end
    _G.time = function() return 1758067200 end
    -- WoW defines string.match as a global alias for speed; LibStub uses it.
    _G.strmatch = string.match
    _G.GetTime = function() return 1000.0 end
    _G.GetLocale = function() return "enUS" end
    _G.GetBuildInfo = function() return "12.1.0", "62000", "Sep 17 2026", 120100 end
    _G.UnitAffectingCombat = function() return false end
    _G.UnitName = function() return "Tester" end
    _G.GetRealmName = function() return "Hyjal" end

    _G.C_Timer = {
        After = function(_, callback) callback() end,
        NewTicker = function() return { Cancel = function() end } end,
    }

    _G.C_AddOns = {
        IsAddOnLoaded = function() return false end,
        GetAddOnMetadata = function() return nil end,
    }

    _G.GetItemInfo = function() return nil end
    _G.GetItemCount = function() return 0 end

    _G.C_Item = {
        GetItemCount = function() return 0 end,
        GetItemInfo = function() return nil end,
        GetItemInfoInstant = function() return nil end,
    }

    _G.C_Container = {
        GetContainerNumSlots = function() return 0 end,
        GetContainerItemID = function() return nil end,
        GetContainerItemInfo = function() return nil end,
    }

    _G.ItemLocation = {
        CreateFromBagAndSlot = function(bag, slot) return { bag = bag, slot = slot } end,
    }

    _G.Enum = {
        AuctionStatus = { Active = 0, Sold = 1 },
        AuctionHouseDuration = { Short = 1, Medium = 2, Long = 3 },
        CraftingReagentType = { Basic = 1, Modifying = 2, Finishing = 3, Automatic = 4 },
        BagIndex = { Backpack = 0 },
    }

    -- Posting is deliberately made to fail: it needs a hardware event, so nothing
    -- in the tested code is ever allowed to call it.
    _G.C_AuctionHouse = {
        QueryOwnedAuctions = function() end,
        GetOwnedAuctions = function() return {} end,
        GetNumOwnedAuctions = function() return 0 end,
        GetOwnedAuctionInfo = function() return nil end,
        MakeItemKey = function(item_id) return { itemID = item_id } end,
        GetItemKeyFromItem = function() return { itemID = 0 } end,
        GetItemKeyInfo = function() return { isCommodity = true } end,
        CalculateItemDeposit = function() return 0 end,
        CalculateCommodityDeposit = function() return 0 end,
        IsSellItemValid = function() return true end,
        SendSearchQuery = function() end,
        GetNumItemSearchResults = function() return 0 end,
        GetItemSearchResultInfo = function() return nil end,
        GetNumCommoditySearchResults = function() return 0 end,
        GetCommoditySearchResultInfo = function() return nil end,
        PostItem = function() error("PostItem requires a hardware event") end,
        PostCommodity = function() error("PostCommodity requires a hardware event") end,
    }

    _G.C_TradeSkillUI = {
        IsTradeSkillReady = function() return true end,
        GetAllRecipeIDs = function() return {} end,
        GetRecipeInfo = function() return nil end,
        GetRecipeSchematic = function() return nil end,
        OpenRecipe = function() end,
    }

    -- Auctionator is absent by default: that is the case the addon must survive.
    _G.Auctionator = nil

    -- The Blizzard auction house window doesn't exist until Blizzard_AuctionHouseUI
    -- loads (first AH visit of the session) — absent by default, same as in game.
    _G.AuctionHouseFrame = nil

    -- LibStub deliberately persists its registry across dofile() calls (that's
    -- the point, in a real client) — wipe it so each test starts a fresh
    -- "session" instead of reusing the previous test's LibAHTab tab state.
    _G.LibStub = nil

    -- Real hooksecurefunc semantics: run the original, then every registered hook,
    -- in order. LibAHTab relies on this to hide our tab when Blizzard's own
    -- SetDisplayMode runs (e.g. the user clicks a native Buy/Sell/Auctions tab).
    _G.hooksecurefunc = function(object, method, hook)
        local original = object[method]
        object[method] = function(...)
            if original then original(...) end
            hook(...)
        end
    end

    _G.PanelTemplates_TabResize = function() end
    _G.PanelTemplates_SelectTab = function() end
    _G.PanelTemplates_DeselectTab = function() end
end

-- Builds and installs a mocked AuctionHouseFrame, as if Blizzard_AuctionHouseUI
-- had just loaded (i.e. the player opened the auction house once this session).
function WowApiMock.install_auction_house_frame()
    local ah = stub_frame()
    ah.Tabs = { stub_frame(), stub_frame(), stub_frame() } -- Buy / Sell / Auctions
    ah.SetTitle = function(_, title) ah.title = title end
    ah.SetDisplayMode = function(_, mode) ah.display_mode = mode end
    _G.AuctionHouseFrame = ah
    return ah
end

-- Installs a fake Auctionator whose price table is keyed by item id or item link.
function WowApiMock.install_auctionator(prices)
    prices = prices or {}
    _G.Auctionator = {
        API = {
            v1 = {
                GetAuctionPriceByItemID = function(caller_id, item_id)
                    assert(type(caller_id) == "string" and caller_id ~= "", "callerID is required")
                    return prices[item_id]
                end,
                GetAuctionPriceByItemLink = function(caller_id, item_link)
                    assert(type(caller_id) == "string" and caller_id ~= "", "callerID is required")
                    return prices[item_link]
                end,
                IsAuctionDataExactByItemID = function() return true end,
                IsAuctionDataExactByItemLink = function() return true end,
                GetAuctionAgeByItemID = function() return 0 end,
                GetVendorPriceByItemID = function() return nil end,
                RegisterForDBUpdate = function() end,
                CreateShoppingList = function() end,
            },
        },
    }
    return _G.Auctionator
end

-- counts: { [itemID] = { bags = n, total = n } }
function WowApiMock.set_item_counts(counts)
    _G.C_Item.GetItemCount = function(item_id, include_bank)
        local entry = counts[item_id]
        if not entry then
            return 0
        end
        if include_bank then
            return entry.total or entry.bags or 0
        end
        return entry.bags or 0
    end
end

WowApiMock.install()

return WowApiMock
