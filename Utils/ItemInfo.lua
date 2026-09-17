-- Thin wrappers over the item APIs, with the modern/classic fallback pattern.
-- Kept tiny on purpose: everything above it can then be tested with plain numbers.

if not Auctionpad then Auctionpad = {} end
if not Auctionpad.Utils then Auctionpad.Utils = {} end

local ItemInfo = {}
Auctionpad.Utils.ItemInfo = ItemInfo

local name_cache = {}
local icon_cache = {}

-- Bags + personal bank + reagent bank + warband bank: what we own, anywhere.
function ItemInfo.get_owned_total(item_id)
    if not item_id then
        return 0
    end
    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(item_id, true, false, true, true) or 0
    end
    return GetItemCount(item_id, true) or 0
end

-- Bags only: the auction house can only post from there.
function ItemInfo.get_owned_bags(item_id)
    if not item_id then
        return 0
    end
    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(item_id, false, false, false, false) or 0
    end
    return GetItemCount(item_id, false) or 0
end

-- Item data loads asynchronously; the fallback is returned until it lands.
function ItemInfo.get_name(item_id, fallback)
    if not item_id then
        return fallback or ""
    end
    if name_cache[item_id] then
        return name_cache[item_id]
    end

    local name
    if C_Item and C_Item.GetItemInfo then
        name = C_Item.GetItemInfo(item_id)
    end
    if not name then
        name = GetItemInfo(item_id)
    end

    if name then
        name_cache[item_id] = name
        return name
    end

    return fallback or ""
end

function ItemInfo.clear_name_cache()
    name_cache = {}
end

-- Icon texture (fileID) for an item, or nil while its data is still loading
-- asynchronously — callers fall back to a generic icon in that case.
function ItemInfo.get_icon(item_id)
    if not item_id then
        return nil
    end
    if icon_cache[item_id] then
        return icon_cache[item_id]
    end

    local icon
    if C_Item and C_Item.GetItemIcon then
        icon = C_Item.GetItemIcon(item_id)
    end
    if not icon then
        icon = GetItemIcon(item_id)
    end

    if icon then
        icon_cache[item_id] = icon
    end

    return icon
end

function ItemInfo.clear_icon_cache()
    icon_cache = {}
end
