-- How many of each item we currently have listed on the auction house.
--
-- The counts are only available at the auction house, so they are snapshotted
-- per character in the saved variables and read back (aged) everywhere else.

if not Auctionpad then Auctionpad = {} end
if not Auctionpad.Auction then Auctionpad.Auction = {} end

local OwnedAuctions = {}
Auctionpad.Auction.OwnedAuctions = OwnedAuctions

local ACTIVE_STATUS = 0 -- Enum.AuctionStatus.Active

-- Pure: turns the raw OwnedAuctionInfo list into { [itemID] = quantity }.
-- Sold auctions are excluded: they are waiting to be collected, not on sale.
function OwnedAuctions.aggregate(auction_infos)
    local counts = {}

    for _, info in ipairs(auction_infos or {}) do
        local item_key = info.itemKey
        local item_id = item_key and item_key.itemID
        local status = info.status or ACTIVE_STATUS

        if item_id and status == ACTIVE_STATUS then
            counts[item_id] = (counts[item_id] or 0) + (info.quantity or 0)
        end
    end

    return counts
end

function OwnedAuctions.character_key()
    local name = UnitName("player") or "?"
    local realm = GetRealmName() or "?"
    return name .. "-" .. realm
end

-- Ask the server to refresh the owned auction list; OWNED_AUCTIONS_UPDATED follows.
function OwnedAuctions.request()
    if not C_AuctionHouse or not C_AuctionHouse.QueryOwnedAuctions then
        return false
    end
    local ok = pcall(C_AuctionHouse.QueryOwnedAuctions, {})
    return ok
end

-- Reads whatever the client currently holds and stores it as this character's snapshot.
function OwnedAuctions.refresh(db)
    if not C_AuctionHouse or not C_AuctionHouse.GetOwnedAuctions then
        return nil
    end

    local ok, auctions = pcall(C_AuctionHouse.GetOwnedAuctions)
    if not ok or type(auctions) ~= "table" then
        return nil
    end

    local counts = OwnedAuctions.aggregate(auctions)
    db.owned_snapshot = db.owned_snapshot or {}
    db.owned_snapshot[OwnedAuctions.character_key()] = {
        updated_at = time(),
        counts = counts,
    }

    return counts
end

-- Returns the snapshot and its age in seconds, or nil when we have never seen one.
function OwnedAuctions.get_snapshot(db)
    local snapshot = db.owned_snapshot and db.owned_snapshot[OwnedAuctions.character_key()]
    if not snapshot then
        return nil
    end

    local age = math.max(0, time() - (snapshot.updated_at or 0))
    return snapshot.counts or {}, age
end

-- Convenience for the UI: the listed quantity for one item, plus the snapshot age.
-- Returns nil when no snapshot exists at all, so callers can render "unknown".
function OwnedAuctions.get_listed(db, item_id)
    local counts, age = OwnedAuctions.get_snapshot(db)
    if not counts then
        return nil, nil
    end
    return counts[item_id] or 0, age
end
