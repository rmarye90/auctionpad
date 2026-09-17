local WowApiMock = require("test_helpers.WowApiMock")

describe("StockLedger", function()
    local Ledger

    before_each(function()
        WowApiMock.install()
        _G.Auctionpad = {}
        _G.Auctionpad.Stock = {}
        dofile("Stock/StockLedger.lua")
        Ledger = Auctionpad.Stock.Ledger
    end)

    local function ctx(overrides)
        local base = { bag = 0, owned = 0, listed = 0, listed_age = 0, stale_after = 3600 }
        for key, value in pairs(overrides or {}) do
            base[key] = value
        end
        return base
    end

    describe("unknown auction data", function()
        it("should_report_unknown_when_listed_is_nil", function()
            -- assigning nil inside a table constructor is a no-op, so clear it explicitly
            local context = ctx({ bag = 10, owned = 10 })
            context.listed = nil

            local result = Ledger.compute({ target = 20 }, context)

            assert.are.equal(Ledger.UNKNOWN, result.status)
            assert.is_nil(result.to_post)
            assert.is_nil(result.to_recraft)
        end)

        it("should_report_unknown_when_the_snapshot_is_stale", function()
            local result = Ledger.compute({ target = 20 }, ctx({ listed = 5, listed_age = 7200 }))

            assert.are.equal(Ledger.UNKNOWN, result.status)
        end)

        it("should_trust_the_snapshot_when_it_is_within_the_stale_window", function()
            local result = Ledger.compute({ target = 20 }, ctx({ listed = 20, listed_age = 60 }))

            assert.are.equal(Ledger.READY, result.status)
        end)

        it("should_trust_listed_when_no_age_is_provided", function()
            local context = ctx({ listed = 20 })
            context.listed_age = nil

            local result = Ledger.compute({ target = 20 }, context)

            assert.are.equal(Ledger.READY, result.status)
        end)
    end)

    describe("status", function()
        it("should_be_ready_when_the_target_is_already_on_sale", function()
            local result = Ledger.compute({ target = 20 }, ctx({ listed = 20, bag = 5, owned = 5 }))

            assert.are.equal(Ledger.READY, result.status)
            assert.are.equal(0, result.missing)
            assert.are.equal(0, result.to_post)
            assert.are.equal(0, result.to_recraft)
        end)

        it("should_be_ready_when_more_than_the_target_is_on_sale", function()
            local result = Ledger.compute({ target = 20 }, ctx({ listed = 25 }))

            assert.are.equal(Ledger.READY, result.status)
            assert.are.equal(0, result.missing)
        end)

        it("should_be_post_when_the_bags_cover_the_gap", function()
            local result = Ledger.compute({ target = 20 }, ctx({ listed = 16, bag = 10, owned = 10 }))

            assert.are.equal(Ledger.POST, result.status)
            assert.are.equal(4, result.missing)
            assert.are.equal(4, result.to_post)
            assert.are.equal(0, result.in_bank)
            assert.are.equal(0, result.to_recraft)
        end)

        it("should_be_bank_when_we_own_enough_but_not_in_the_bags", function()
            local result = Ledger.compute({ target = 20 }, ctx({ listed = 16, bag = 0, owned = 5 }))

            assert.are.equal(Ledger.BANK, result.status)
            assert.are.equal(0, result.to_post)
            assert.are.equal(4, result.in_bank)
            assert.are.equal(0, result.to_recraft)
        end)

        it("should_split_between_post_and_bank_when_the_bags_only_cover_part_of_the_gap", function()
            local result = Ledger.compute({ target = 20 }, ctx({ listed = 16, bag = 2, owned = 5 }))

            assert.are.equal(Ledger.BANK, result.status)
            assert.are.equal(2, result.to_post)
            assert.are.equal(2, result.in_bank)
            assert.are.equal(0, result.to_recraft)
        end)

        it("should_be_craft_when_we_do_not_own_enough_anywhere", function()
            local result = Ledger.compute({ target = 20 }, ctx({ listed = 16, bag = 2, owned = 2 }))

            assert.are.equal(Ledger.CRAFT, result.status)
            assert.are.equal(2, result.to_post)
            assert.are.equal(0, result.in_bank)
            assert.are.equal(2, result.to_recraft)
        end)

        it("should_never_report_a_recraft_when_the_target_is_zero", function()
            local result = Ledger.compute({ target = 0 }, ctx({ listed = 0, bag = 0, owned = 0 }))

            assert.are.equal(Ledger.READY, result.status)
            assert.are.equal(0, result.to_recraft)
        end)

        it("should_treat_a_missing_target_as_zero", function()
            local result = Ledger.compute({}, ctx({ listed = 0 }))

            assert.are.equal(Ledger.READY, result.status)
        end)
    end)

    describe("num_posts", function()
        it("should_split_into_stacks_and_round_the_last_one_up", function()
            local result = Ledger.compute({ target = 20, stack_size = 5 }, ctx({ listed = 8, bag = 12, owned = 12 }))

            assert.are.equal(12, result.to_post)
            assert.are.equal(3, result.num_posts)
        end)

        it("should_make_a_single_post_when_the_stack_size_exceeds_what_is_postable", function()
            local result = Ledger.compute({ target = 20, stack_size = 200 }, ctx({ listed = 18, bag = 2, owned = 2 }))

            assert.are.equal(2, result.to_post)
            assert.are.equal(1, result.num_posts)
        end)

        it("should_default_to_one_per_post_when_stack_size_is_missing_or_zero", function()
            local result = Ledger.compute({ target = 5, stack_size = 0 }, ctx({ listed = 2, bag = 3, owned = 3 }))

            assert.are.equal(3, result.num_posts)
        end)
    end)

    describe("crafts_needed", function()
        it("should_round_up_when_a_craft_yields_several_pieces", function()
            assert.are.equal(2, Ledger.crafts_needed(4, 3))
        end)

        it("should_map_one_to_one_when_a_craft_yields_a_single_piece", function()
            assert.are.equal(6, Ledger.crafts_needed(6, 1))
        end)

        it("should_return_zero_when_nothing_is_missing", function()
            assert.are.equal(0, Ledger.crafts_needed(0, 3))
        end)

        it("should_treat_a_missing_output_quantity_as_one", function()
            assert.are.equal(4, Ledger.crafts_needed(4, nil))
        end)
    end)
end)
