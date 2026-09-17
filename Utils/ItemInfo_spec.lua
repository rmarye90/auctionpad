local WowApiMock = require("test_helpers.WowApiMock")

describe("ItemInfo", function()
    local ItemInfo

    before_each(function()
        WowApiMock.install()
        _G.Auctionpad = {}
        _G.Auctionpad.Utils = {}
        dofile("Utils/ItemInfo.lua")
        ItemInfo = Auctionpad.Utils.ItemInfo
    end)

    describe("get_owned_total", function()
        it("should_include_bank_reagent_bank_and_warband_bank", function()
            local captured
            _G.C_Item.GetItemCount = function(item_id, bank, uses, reagent, account)
                captured = { item_id, bank, uses, reagent, account }
                return 12
            end

            assert.are.equal(12, ItemInfo.get_owned_total(212283))
            assert.are.same({ 212283, true, false, true, true }, captured)
        end)

        it("should_fall_back_to_the_classic_api_when_c_item_is_absent", function()
            _G.C_Item = nil
            _G.GetItemCount = function() return 7 end

            assert.are.equal(7, ItemInfo.get_owned_total(212283))
        end)

        it("should_return_zero_when_the_item_id_is_nil", function()
            assert.are.equal(0, ItemInfo.get_owned_total(nil))
        end)

        it("should_return_zero_when_the_api_returns_nil", function()
            _G.C_Item.GetItemCount = function() return nil end

            assert.are.equal(0, ItemInfo.get_owned_total(212283))
        end)
    end)

    describe("get_owned_bags", function()
        it("should_ask_for_bags_only", function()
            local captured
            _G.C_Item.GetItemCount = function(item_id, bank, uses, reagent, account)
                captured = { item_id, bank, uses, reagent, account }
                return 4
            end

            assert.are.equal(4, ItemInfo.get_owned_bags(212283))
            assert.are.same({ 212283, false, false, false, false }, captured)
        end)
    end)

    describe("get_name", function()
        it("should_return_the_name_when_item_data_is_loaded", function()
            _G.C_Item.GetItemInfo = function() return "Flask of Alchemical Chaos" end

            assert.are.equal("Flask of Alchemical Chaos", ItemInfo.get_name(212283))
        end)

        it("should_return_the_fallback_while_item_data_is_still_loading", function()
            _G.C_Item.GetItemInfo = function() return nil end
            _G.GetItemInfo = function() return nil end

            assert.are.equal("item:212283", ItemInfo.get_name(212283, "item:212283"))
        end)

        it("should_cache_the_name_and_stop_hitting_the_api", function()
            local calls = 0
            _G.C_Item.GetItemInfo = function()
                calls = calls + 1
                return "Flask"
            end

            ItemInfo.get_name(212283)
            ItemInfo.get_name(212283)

            assert.are.equal(1, calls)
        end)
    end)
end)
