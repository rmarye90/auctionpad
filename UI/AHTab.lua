-- Wraps LibAHTab-1-0 to attach Auctionpad's shared content frame as a tab of
-- the Blizzard Auction House, instead of reimplementing tab anchoring
-- ourselves. See Libs/LibAHTab/README.md: doing this by hand (with the
-- PanelTemplates_ functions directly) causes a taint bug on the second AH
-- open. Never edit Libs/LibAHTab/LibAHTab.lua — any behavior change belongs
-- here.

if not Auctionpad then Auctionpad = {} end
if not Auctionpad.UI then Auctionpad.UI = {} end

local AHTab = {}
Auctionpad.UI.AHTab = AHTab

local TAB_ID = "Auctionpad"

local created = false
local selected = false

local function lib()
    return LibStub and LibStub("LibAHTab-1-0", true)
end

-- Attaches content_frame as our AH tab, the first time this is possible.
-- Safe to call at any time: returns nil (not an error) when
-- Blizzard_AuctionHouseUI hasn't loaded yet, or LibAHTab is unavailable for
-- some reason — callers keep the standalone window as their only option then.
-- Idempotent: a second call is a no-op that returns the same frame.
function AHTab.EnsureTab(content_frame)
    if created then
        return content_frame
    end

    if not AuctionHouseFrame then
        return nil
    end

    local ahtab = lib()
    if not ahtab then
        return nil
    end

    content_frame:SetParent(AuctionHouseFrame)
    content_frame:ClearAllPoints()
    content_frame:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPLEFT", 12, -70)
    content_frame:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", -12, 12)

    -- SetParent() only changes anchoring/visibility lineage — it does NOT
    -- re-derive strata or level from the new parent (those are only copied
    -- once, from whatever parent a frame is given at CreateFrame time; ours
    -- was created under UIParent). Left alone, content stays at UIParent's
    -- (lower) strata while sitting inside a "HIGH"-strata Blizzard panel,
    -- which is exactly the kind of mismatch that makes mouse-focus-sensitive
    -- interactions (like a drag-and-drop release) resolve to some other
    -- frame overlapping the same screen area instead of ours, even though
    -- plain clicks still land correctly. Match it explicitly, with margin.
    content_frame:SetFrameStrata(AuctionHouseFrame:GetFrameStrata())
    content_frame:SetFrameLevel(AuctionHouseFrame:GetFrameLevel() + 10)

    ahtab:CreateTab(TAB_ID, content_frame, Auctionpad.Utils.Locale.get("Auctionpad"))

    -- LibAHTab has no IsSelected(): track it ourselves from the show/hide it
    -- already drives (its own SetSelected and its SetDisplayMode hook both
    -- work by calling Show()/Hide() on the frame we handed it). HookScript,
    -- not SetScript: MainFrame.lua's own OnShow (refreshing the UI) must
    -- keep firing too, whichever of us registered first.
    content_frame:HookScript("OnShow", function() selected = true end)
    content_frame:HookScript("OnHide", function() selected = false end)

    created = true
    return content_frame
end

-- Selects our tab: hides Blizzard's native Buy/Sell/Auctions panel and any
-- other LibAHTab-registered tab, shows ours, retitles the AH window.
-- No-op (returns false) if EnsureTab() hasn't succeeded yet.
function AHTab.Select()
    local ahtab = lib()
    if not created or not ahtab then
        return false
    end
    ahtab:SetSelected(TAB_ID)
    return true
end

function AHTab.IsSelected()
    return selected
end

function AHTab.IsCreated()
    return created
end
