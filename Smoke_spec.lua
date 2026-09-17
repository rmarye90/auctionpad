-- Loads every file the .toc ships, in the .toc order, and drives the UI through
-- the mocked API. This is what catches a misspelled frame method or a module
-- that reaches for something a file loaded after it defines.

local WowApiMock = require("test_helpers.WowApiMock")
local Fixtures = require("test_helpers.TestFixtures")

local function toc_files()
    local files = {}
    for line in io.lines("Auctionpad.toc") do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and not trimmed:match("^#") then
            table.insert(files, (trimmed:gsub("\\", "/")))
        end
    end
    return files
end

describe("addon load", function()
    local files

    before_each(function()
        WowApiMock.install()
        _G.Auctionpad = nil
        _G.AuctionpadDB = nil
        _G.SlashCmdList = {}

        files = toc_files()
        for _, path in ipairs(files) do
            dofile(path)
        end

        -- What the client does on ADDON_LOADED / PLAYER_LOGIN.
        _G.AuctionpadDB = Auctionpad.Data.initialize(_G.AuctionpadDB)
        Auctionpad.db = _G.AuctionpadDB
    end)

    it("should_list_every_shipped_lua_file_in_the_toc", function()
        assert.is_true(#files >= 10)
        for _, path in ipairs(files) do
            local handle = io.open(path, "r")
            assert.is_truthy(handle, path .. " is listed in the toc but missing on disk")
            handle:close()
        end
    end)

    it("should_expose_the_whole_namespace_after_loading", function()
        assert.is_table(Auctionpad.Data.GroupStore)
        assert.is_table(Auctionpad.Stock.Ledger)
        assert.is_table(Auctionpad.Auction.OwnedAuctions)
        assert.is_table(Auctionpad.Utils.Money)
        assert.is_table(Auctionpad.Utils.ItemInfo)
        assert.is_table(Auctionpad.Utils.Locale)
        assert.is_function(Auctionpad.UI.Toggle)
    end)

    it("should_register_the_slash_command", function()
        assert.is_function(SlashCmdList["AUCTIONPAD"])
        assert.are.equal("/apad", SLASH_AUCTIONPAD2)
    end)

    it("should_build_the_minimap_button_without_error", function()
        assert.has_no.errors(function()
            Auctionpad.UI.CreateMinimapButton()
        end)
    end)

    it("should_open_and_render_an_empty_window_without_error", function()
        assert.has_no.errors(function()
            Auctionpad.UI.Show()
        end)
        assert.is_true(Auctionpad.UI.IsShown())
    end)

    it("should_render_groups_and_items_without_error", function()
        local group_id = Auctionpad.Data.GroupStore.create(Auctionpad.db, "Flasks")
        Auctionpad.Data.GroupStore.add_item(Auctionpad.db, group_id, Fixtures.FLASK_ID, { target = 20 })
        Auctionpad.Data.GroupStore.add_item(Auctionpad.db, group_id, Fixtures.GEM_ID, { target = 5 })

        assert.has_no.errors(function()
            Auctionpad.UI.Show()
            Auctionpad.UI.Refresh()
        end)
    end)

    it("should_render_with_auction_data_loaded", function()
        local group_id = Auctionpad.Data.GroupStore.create(Auctionpad.db, "Flasks")
        Auctionpad.Data.GroupStore.add_item(Auctionpad.db, group_id, Fixtures.FLASK_ID, { target = 20 })

        _G.C_AuctionHouse.GetOwnedAuctions = function()
            return Fixtures.owned_auctions({ [Fixtures.FLASK_ID] = 12 })
        end
        Auctionpad.Auction.OwnedAuctions.refresh(Auctionpad.db)

        assert.has_no.errors(function()
            Auctionpad.UI.Show()
        end)
        assert.are.equal(12, (Auctionpad.Auction.OwnedAuctions.get_listed(Auctionpad.db, Fixtures.FLASK_ID)))
    end)

    it("should_toggle_closed_and_open_again", function()
        Auctionpad.UI.Show()
        Auctionpad.UI.Toggle()
        assert.is_false(Auctionpad.UI.IsShown())

        Auctionpad.UI.Toggle()
        assert.is_true(Auctionpad.UI.IsShown())
    end)

    it("should_run_the_slash_command_without_error", function()
        assert.has_no.errors(function()
            SlashCmdList["AUCTIONPAD"]("")
            SlashCmdList["AUCTIONPAD"]("help")
        end)
    end)

    describe("auction house tab docking", function()
        local function fire(event, ...)
            Auctionpad.eventFrame:GetScript("OnEvent")(nil, event, ...)
        end

        local function open_auction_house()
            local ah = WowApiMock.install_auction_house_frame()
            ah.IsShown = function() return true end
            fire("AUCTION_HOUSE_SHOW")
            return ah
        end

        local function close_auction_house()
            AuctionHouseFrame.IsShown = function() return false end
            fire("AUCTION_HOUSE_CLOSED")
        end

        it("should_noop_ensure_tab_before_the_auction_house_addon_loads", function()
            assert.has_no.errors(function()
                Auctionpad.UI.AHTab.EnsureTab(Auctionpad.UI.GetContent())
            end)
            assert.is_false(Auctionpad.UI.AHTab.IsCreated())
        end)

        it("should_create_the_tab_when_the_auction_house_opens", function()
            assert.has_no.errors(open_auction_house)
            assert.is_true(Auctionpad.UI.AHTab.IsCreated())
        end)

        it("should_not_create_a_second_tab_on_a_second_auction_house_show", function()
            open_auction_house()
            local tabs_after_first = #LibStub("LibAHTab-1-0").internalState.Tabs

            fire("AUCTION_HOUSE_SHOW")

            assert.are.equal(tabs_after_first, #LibStub("LibAHTab-1-0").internalState.Tabs)
        end)

        it("should_not_select_the_tab_by_default_when_the_auction_house_opens", function()
            open_auction_house()

            assert.is_false(Auctionpad.UI.AHTab.IsSelected())
        end)

        it("should_select_the_tab_automatically_when_auto_open_at_ah_is_enabled", function()
            Auctionpad.db.settings.auto_open_at_ah = true

            open_auction_house()

            assert.is_true(Auctionpad.UI.AHTab.IsSelected())
        end)

        it("should_dock_the_content_into_the_tab_via_apad_while_the_auction_house_is_open", function()
            open_auction_house()

            SlashCmdList["AUCTIONPAD"]("")

            assert.is_true(Auctionpad.UI.AHTab.IsSelected())
            assert.is_true(Auctionpad.UI.IsShown())
        end)

        it("should_still_toggle_the_floating_window_when_the_auction_house_is_closed", function()
            assert.has_no.errors(function()
                Auctionpad.UI.Toggle()
            end)
            assert.is_true(Auctionpad.UI.IsShown())
            assert.is_true(Auctionpad.UI.IsStandaloneShown())
        end)

        it("should_hide_the_floating_window_when_the_auction_house_opens", function()
            Auctionpad.UI.Show() -- floating window, AH closed

            open_auction_house()

            assert.is_false(Auctionpad.UI.IsStandaloneShown())
        end)

        it("should_restore_the_floating_window_after_the_auction_house_closes_if_it_was_open_before", function()
            Auctionpad.UI.Show() -- floating window, AH closed

            open_auction_house()
            close_auction_house()

            assert.is_true(Auctionpad.UI.IsStandaloneShown())
        end)

        it("should_not_reopen_the_floating_window_if_it_was_not_open_before_the_auction_house", function()
            open_auction_house()
            close_auction_house()

            assert.is_false(Auctionpad.UI.IsStandaloneShown())
        end)
    end)
end)
