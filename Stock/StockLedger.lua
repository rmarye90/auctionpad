-- The heart of the addon: turns raw counts into "what do I still need to do?".
-- Pure module. Everything it needs is handed to it; it never reads a WoW API.

if not Auctionpad then Auctionpad = {} end
if not Auctionpad.Stock then Auctionpad.Stock = {} end

local StockLedger = {}
Auctionpad.Stock.Ledger = StockLedger

-- Returned in `status`, ordered by the priority the UI paints them in.
StockLedger.UNKNOWN = "unknown" -- auction data not loaded (or stale): we know nothing
StockLedger.CRAFT = "craft"     -- missing pieces we do not own anywhere
StockLedger.BANK = "bank"       -- we own enough, but not in the bags
StockLedger.POST = "post"       -- ready to be posted right now
StockLedger.READY = "ready"     -- target already met on the auction house

local function as_count(value)
    return math.max(0, math.floor(tonumber(value) or 0))
end

-- Auction data is only trustworthy once OWNED_AUCTIONS_UPDATED landed, and only
-- for a while after that. Anything else must read as unknown, never as zero:
-- a false zero would tell the user to recraft what is already on sale.
function StockLedger.is_listed_known(ctx)
    if ctx == nil or ctx.listed == nil then
        return false
    end
    if ctx.listed_age == nil then
        return true
    end
    local stale_after = ctx.stale_after
    if stale_after == nil then
        return true
    end
    return ctx.listed_age <= stale_after
end

-- entry: { target, stack_size }
-- ctx:   { bag, owned, listed, listed_age, stale_after }
function StockLedger.compute(entry, ctx)
    entry = entry or {}
    ctx = ctx or {}

    if not StockLedger.is_listed_known(ctx) then
        return { status = StockLedger.UNKNOWN }
    end

    local target = as_count(entry.target)
    local bag = as_count(ctx.bag)
    local owned = math.max(as_count(ctx.owned), bag) -- owned always includes the bags
    local listed = as_count(ctx.listed)

    local missing = math.max(0, target - listed)
    local to_post = math.min(missing, bag)
    local in_bank = math.max(0, math.min(missing, owned) - to_post)
    local to_recraft = math.max(0, missing - owned)

    local stack_size = math.max(1, as_count(entry.stack_size))
    local num_posts = math.ceil(to_post / stack_size)

    local status
    if missing == 0 then
        status = StockLedger.READY
    elseif to_recraft > 0 then
        status = StockLedger.CRAFT
    elseif in_bank > 0 then
        status = StockLedger.BANK
    else
        status = StockLedger.POST
    end

    return {
        status = status,
        target = target,
        listed = listed,
        owned = owned,
        bag = bag,
        missing = missing,
        to_post = to_post,
        in_bank = in_bank,
        to_recraft = to_recraft,
        num_posts = num_posts,
    }
end

-- How many crafts are needed to cover `to_recraft` pieces, given a recipe that
-- yields `output_quantity` per craft.
function StockLedger.crafts_needed(to_recraft, output_quantity)
    local pieces = as_count(to_recraft)
    if pieces == 0 then
        return 0
    end
    return math.ceil(pieces / math.max(1, as_count(output_quantity)))
end
