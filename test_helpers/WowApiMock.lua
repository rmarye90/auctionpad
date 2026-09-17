-- WoW API mock for running the pure modules outside the game.
-- Every entry is a no-op default; specs override the ones they care about.
--
-- `require` caches the module, so specs that overwrite a global would leak into
-- the next file. Call WowApiMock.install() in before_each to get a clean slate.

local WowApiMock = {}

local function stub_region()
    return {
        SetPoint = function() end,
        SetText = function() end,
        SetTextColor = function() end,
        SetWidth = function() end,
        SetHeight = function() end,
        SetSize = function() end,
        SetTexture = function() end,
        SetColorTexture = function() end,
        SetJustifyH = function() end,
        SetWordWrap = function() end,
        Show = function() end,
        Hide = function() end,
    }
end

function WowApiMock.install()
    _G.CreateFrame = function()
        return {
            SetSize = function() end,
            SetPoint = function() end,
            SetBackdrop = function() end,
            SetBackdropColor = function() end,
            SetBackdropBorderColor = function() end,
            EnableMouse = function() end,
            SetMovable = function() end,
            SetResizable = function() end,
            SetClampedToScreen = function() end,
            RegisterForDrag = function() end,
            RegisterEvent = function() end,
            UnregisterEvent = function() end,
            SetScript = function() end,
            GetScript = function() return nil end,
            StartMoving = function() end,
            StopMovingOrSizing = function() end,
            Show = function() end,
            Hide = function() end,
            IsShown = function() return false end,
            CreateFontString = stub_region,
            CreateTexture = stub_region,
        }
    end

    _G.UIParent = {}
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
