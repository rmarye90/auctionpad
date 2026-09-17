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
end)
