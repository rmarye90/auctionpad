local WowApiMock = require("test_helpers.WowApiMock")

describe("Locale", function()
    local Locale

    before_each(function()
        WowApiMock.install()
        _G.Auctionpad = {}
        _G.Auctionpad.Utils = {}
        dofile("Utils/Locale.lua")
        Locale = Auctionpad.Utils.Locale
    end)

    describe("get", function()
        it("should_return_the_english_key_itself_on_an_english_client", function()
            _G.GetLocale = function() return "enUS" end

            assert.are.equal("On sale", Locale.get("On sale"))
        end)

        it("should_translate_on_a_french_client", function()
            _G.GetLocale = function() return "frFR" end

            assert.are.equal("En vente", Locale.get("On sale"))
        end)

        it("should_fall_back_to_the_key_for_an_unknown_locale", function()
            _G.GetLocale = function() return "koKR" end

            assert.are.equal("On sale", Locale.get("On sale"))
        end)

        it("should_fall_back_to_the_key_when_a_translation_is_missing", function()
            _G.GetLocale = function() return "frFR" end

            assert.are.equal("Not translated yet", Locale.get("Not translated yet"))
        end)
    end)

    describe("format_age", function()
        it("should_say_less_than_a_minute_for_a_fresh_snapshot", function()
            _G.GetLocale = function() return "enUS" end

            assert.are.equal("less than a minute", Locale.format_age(30))
        end)

        it("should_round_down_to_whole_minutes", function()
            _G.GetLocale = function() return "enUS" end

            assert.are.equal("12 min", Locale.format_age(12 * 60 + 59))
        end)

        it("should_switch_to_hours_past_an_hour", function()
            _G.GetLocale = function() return "enUS" end

            assert.are.equal("3 h", Locale.format_age(3 * 3600 + 120))
        end)

        it("should_treat_nil_or_negative_as_zero", function()
            _G.GetLocale = function() return "enUS" end

            assert.are.equal("less than a minute", Locale.format_age(nil))
            assert.are.equal("less than a minute", Locale.format_age(-5))
        end)
    end)
end)
