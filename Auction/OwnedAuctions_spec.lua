local WowApiMock = require("test_helpers.WowApiMock")
local Fixtures = require("test_helpers.TestFixtures")

describe("OwnedAuctions", function()
    local OwnedAuctions

    before_each(function()
        WowApiMock.install()
        _G.Auctionpad = {}
        _G.Auctionpad.Auction = {}
        dofile("Auction/OwnedAuctions.lua")
        OwnedAuctions = Auctionpad.Auction.OwnedAuctions
    end)

    describe("aggregate", function()
        it("should_sum_quantities_per_item", function()
            local counts = OwnedAuctions.aggregate({
                { itemKey = { itemID = 212283 }, quantity = 5, status = 0 },
                { itemKey = { itemID = 212283 }, quantity = 7, status = 0 },
                { itemKey = { itemID = 213743 }, quantity = 1, status = 0 },
            })

            assert.are.equal(12, counts[212283])
            assert.are.equal(1, counts[213743])
        end)

        it("should_exclude_sold_auctions_that_are_waiting_to_be_collected", function()
            local counts = OwnedAuctions.aggregate({
                { itemKey = { itemID = 212283 }, quantity = 5, status = 0 },
                { itemKey = { itemID = 212283 }, quantity = 40, status = 1 },
            })

            assert.are.equal(5, counts[212283])
        end)

        it("should_return_an_empty_table_for_an_empty_or_nil_list", function()
            assert.are.same({}, OwnedAuctions.aggregate({}))
            assert.are.same({}, OwnedAuctions.aggregate(nil))
        end)

        it("should_skip_an_entry_with_no_item_key", function()
            local counts = OwnedAuctions.aggregate({
                { quantity = 5, status = 0 },
                { itemKey = { itemID = 212283 }, quantity = 3, status = 0 },
            })

            assert.are.equal(3, counts[212283])
        end)

        it("should_treat_a_missing_status_as_active", function()
            local counts = OwnedAuctions.aggregate({
                { itemKey = { itemID = 212283 }, quantity = 2 },
            })

            assert.are.equal(2, counts[212283])
        end)

        it("should_handle_the_fixture_shape", function()
            local counts = OwnedAuctions.aggregate(
                Fixtures.owned_auctions({ [Fixtures.FLASK_ID] = 8 }, { [Fixtures.FLASK_ID] = 3 })
            )

            assert.are.equal(8, counts[Fixtures.FLASK_ID])
        end)
    end)

    describe("refresh and get_listed", function()
        it("should_store_a_snapshot_for_the_current_character", function()
            local db = { owned_snapshot = {} }
            _G.C_AuctionHouse.GetOwnedAuctions = function()
                return Fixtures.owned_auctions({ [Fixtures.FLASK_ID] = 8 })
            end

            OwnedAuctions.refresh(db)

            local listed, age = OwnedAuctions.get_listed(db, Fixtures.FLASK_ID)
            assert.are.equal(8, listed)
            assert.are.equal(0, age)
        end)

        it("should_report_zero_for_a_tracked_item_that_is_not_on_sale", function()
            local db = { owned_snapshot = {} }
            _G.C_AuctionHouse.GetOwnedAuctions = function()
                return Fixtures.owned_auctions({ [Fixtures.FLASK_ID] = 8 })
            end

            OwnedAuctions.refresh(db)

            assert.are.equal(0, (OwnedAuctions.get_listed(db, Fixtures.GEM_ID)))
        end)

        it("should_return_nil_when_no_snapshot_was_ever_taken", function()
            local listed, age = OwnedAuctions.get_listed({ owned_snapshot = {} }, Fixtures.FLASK_ID)

            assert.is_nil(listed)
            assert.is_nil(age)
        end)

        it("should_age_an_older_snapshot", function()
            local db = {
                owned_snapshot = {
                    [OwnedAuctions.character_key()] = {
                        updated_at = 1758067200 - 120,
                        counts = { [Fixtures.FLASK_ID] = 4 },
                    },
                },
            }

            local listed, age = OwnedAuctions.get_listed(db, Fixtures.FLASK_ID)

            assert.are.equal(4, listed)
            assert.are.equal(120, age)
        end)

        it("should_survive_an_auction_api_that_throws", function()
            local db = { owned_snapshot = {} }
            _G.C_AuctionHouse.GetOwnedAuctions = function() error("not at the auction house") end

            assert.is_nil(OwnedAuctions.refresh(db))
        end)

        it("should_survive_a_missing_auction_api", function()
            _G.C_AuctionHouse = nil

            assert.is_nil(OwnedAuctions.refresh({ owned_snapshot = {} }))
            assert.is_false(OwnedAuctions.request())
        end)
    end)
end)
