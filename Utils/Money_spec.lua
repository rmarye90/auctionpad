local WowApiMock = require("test_helpers.WowApiMock")

describe("Money", function()
    local Money

    before_each(function()
        WowApiMock.install()
        _G.Auctionpad = {}
        _G.Auctionpad.Utils = {}
        dofile("Utils/Money.lua")
        Money = Auctionpad.Utils.Money
    end)

    describe("format", function()
        it("should_show_all_three_units_when_amount_exceeds_a_gold", function()
            assert.are.equal("123g 45s 67c", Money.format(1234567))
        end)

        it("should_drop_gold_when_amount_is_under_a_gold", function()
            assert.are.equal("45s 67c", Money.format(4567))
        end)

        it("should_show_copper_only_when_amount_is_under_a_silver", function()
            assert.are.equal("67c", Money.format(67))
        end)

        it("should_return_zero_copper_when_amount_is_nil", function()
            assert.are.equal("0c", Money.format(nil))
        end)
    end)

    describe("round_to_step", function()
        it("should_floor_to_a_whole_silver_when_copper_remains", function()
            assert.are.equal(182400, Money.round_to_step(182499))
        end)

        it("should_leave_an_exact_silver_untouched", function()
            assert.are.equal(182400, Money.round_to_step(182400))
        end)

        it("should_clamp_to_one_silver_when_price_is_below_it", function()
            assert.are.equal(100, Money.round_to_step(1))
            assert.are.equal(100, Money.round_to_step(0))
        end)
    end)

    describe("apply_undercut", function()
        it("should_subtract_a_flat_amount", function()
            assert.are.equal(9999, Money.apply_undercut(10000, { mode = "flat", value = 1 }))
        end)

        it("should_subtract_a_percentage", function()
            assert.are.equal(9500, Money.apply_undercut(10000, { mode = "percent", value = 5 }))
        end)

        it("should_return_the_price_unchanged_when_undercut_is_absent_or_zero", function()
            assert.are.equal(10000, Money.apply_undercut(10000, nil))
            assert.are.equal(10000, Money.apply_undercut(10000, { mode = "flat", value = 0 }))
        end)
    end)

    describe("compute_post_price", function()
        it("should_undercut_then_round_when_using_a_market_price", function()
            local price = Money.compute_post_price(182499, { undercut = { mode = "flat", value = 1 } })

            assert.are.equal(182400, price)
        end)

        it("should_use_the_fixed_price_and_ignore_the_undercut", function()
            local price = Money.compute_post_price(999999, {
                mode = "fixed",
                fixed_copper = 50000,
                undercut = { mode = "percent", value = 50 },
            })

            assert.are.equal(50000, price)
        end)

        it("should_raise_the_price_to_the_floor_when_the_market_is_below_it", function()
            local price = Money.compute_post_price(10000, {
                undercut = { mode = "flat", value = 1 },
                floor_copper = 150000,
            })

            assert.are.equal(150000, price)
        end)

        it("should_return_nil_when_no_market_price_is_known", function()
            assert.is_nil(Money.compute_post_price(nil, { undercut = { mode = "flat", value = 1 } }))
        end)

        it("should_return_nil_when_fixed_mode_has_no_amount", function()
            assert.is_nil(Money.compute_post_price(182400, { mode = "fixed" }))
        end)

        it("should_never_post_below_one_silver_even_with_a_full_percent_undercut", function()
            local price = Money.compute_post_price(150, { undercut = { mode = "percent", value = 100 } })

            assert.are.equal(100, price)
        end)
    end)
end)
