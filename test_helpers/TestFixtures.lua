-- Shared sample data for the specs.

local TestFixtures = {}

TestFixtures.FLASK_ID = 212283
TestFixtures.GEM_ID = 213743
TestFixtures.HERB_ID = 210796

TestFixtures.FLASK_LINK = "|cffa335ee|Hitem:212283::::::::80:::::|h[Flask]|h|r"

-- An owned-auction list in the shape GetOwnedAuctions() returns.
-- counts: { [itemID] = quantity }; every entry is Active unless listed in `sold`.
function TestFixtures.owned_auctions(counts, sold)
    sold = sold or {}
    local auctions = {}
    local auction_id = 1

    for item_id, quantity in pairs(counts or {}) do
        table.insert(auctions, {
            auctionID = auction_id,
            itemKey = { itemID = item_id, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 },
            quantity = quantity,
            status = 0,
        })
        auction_id = auction_id + 1
    end

    for item_id, quantity in pairs(sold) do
        table.insert(auctions, {
            auctionID = auction_id,
            itemKey = { itemID = item_id, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 },
            quantity = quantity,
            status = 1,
        })
        auction_id = auction_id + 1
    end

    return auctions
end

-- A recipe schematic in the shape C_TradeSkillUI.GetRecipeSchematic() returns.
function TestFixtures.recipe_schematic(recipe_id, output_item_id, reagents)
    local slots = {}
    for index, reagent in ipairs(reagents or {}) do
        table.insert(slots, {
            slotIndex = index,
            reagentType = 1,
            required = true,
            quantityRequired = reagent.quantity,
            reagents = { { itemID = reagent.item_id } },
        })
    end

    return {
        recipeID = recipe_id,
        name = "Test Recipe",
        outputItemID = output_item_id,
        quantityMin = 1,
        quantityMax = 1,
        isRecraft = false,
        reagentSlotSchematics = slots,
    }
end

return TestFixtures
