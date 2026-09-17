-- Money helpers: formatting, and the price arithmetic used before posting.
-- Pure module, no WoW API calls, fully unit tested.

if not Auctionpad then Auctionpad = {} end
if not Auctionpad.Utils then Auctionpad.Utils = {} end

local Money = {}
Auctionpad.Utils.Money = Money

local COPPER_PER_SILVER = 100
local COPPER_PER_GOLD = 10000

-- The auction house silently rejects commodity unit prices carrying copper,
-- so every posted price is floored to a whole silver.
Money.PRICE_STEP = COPPER_PER_SILVER

function Money.split(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local gold = math.floor(copper / COPPER_PER_GOLD)
    local silver = math.floor((copper % COPPER_PER_GOLD) / COPPER_PER_SILVER)
    return gold, silver, copper % COPPER_PER_SILVER
end

-- "123g 45s 67c", dropping leading zero units.
function Money.format(copper)
    local gold, silver, rest = Money.split(copper)

    if gold > 0 then
        return string.format("%dg %02ds %02dc", gold, silver, rest)
    end
    if silver > 0 then
        return string.format("%ds %02dc", silver, rest)
    end
    return string.format("%dc", rest)
end

-- Floors to a whole silver, never below one silver.
function Money.round_to_step(copper)
    local value = math.floor(tonumber(copper) or 0)
    if value < Money.PRICE_STEP then
        return Money.PRICE_STEP
    end
    return value - (value % Money.PRICE_STEP)
end

-- undercut: { mode = "flat", value = <copper> } or { mode = "percent", value = <0-100> }
function Money.apply_undercut(copper, undercut)
    local value = math.floor(tonumber(copper) or 0)
    if not undercut or not undercut.value or undercut.value <= 0 then
        return value
    end

    if undercut.mode == "percent" then
        local percent = math.min(100, undercut.value)
        return math.floor(value * (100 - percent) / 100)
    end

    return value - math.floor(undercut.value)
end

-- pricing: { mode, fixed_copper, undercut, floor_copper }
-- Returns the copper amount to post, or nil when no price can be determined.
function Money.compute_post_price(market_copper, pricing)
    pricing = pricing or {}

    local base
    if pricing.mode == "fixed" then
        base = pricing.fixed_copper
    else
        base = market_copper
    end

    if not base or base <= 0 then
        return nil
    end

    local price = base
    if pricing.mode ~= "fixed" then
        price = Money.apply_undercut(price, pricing.undercut)
    end

    local floor_copper = pricing.floor_copper or 0
    if floor_copper > 0 and price < floor_copper then
        price = floor_copper
    end

    return Money.round_to_step(price)
end
