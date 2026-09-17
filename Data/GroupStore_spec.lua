local WowApiMock = require("test_helpers.WowApiMock")

describe("GroupStore", function()
    local GroupStore
    local Schema
    local db

    before_each(function()
        WowApiMock.install()
        _G.Auctionpad = {}
        _G.Auctionpad.Data = {}
        dofile("Data/Schema.lua")
        dofile("Data/GroupStore.lua")
        Schema = Auctionpad.Data
        GroupStore = Auctionpad.Data.GroupStore
        db = Schema.initialize({})
    end)

    describe("create", function()
        it("should_return_an_id_and_register_the_group_in_display_order", function()
            local id = GroupStore.create(db, "Flasks")

            assert.are.equal("Flasks", db.groups[id].name)
            assert.are.same({ id }, db.group_order)
        end)

        it("should_hand_out_distinct_ids", function()
            local first = GroupStore.create(db, "Flasks")
            local second = GroupStore.create(db, "Gems")

            assert.are_not.equal(first, second)
        end)

        it("should_trim_surrounding_whitespace", function()
            local id = GroupStore.create(db, "  Flasks  ")

            assert.are.equal("Flasks", db.groups[id].name)
        end)

        it("should_reject_an_empty_or_blank_name", function()
            local id, err = GroupStore.create(db, "   ")

            assert.is_nil(id)
            assert.are.equal("empty_name", err)
        end)

        it("should_reject_a_name_longer_than_the_limit", function()
            local id, err = GroupStore.create(db, string.rep("x", 41))

            assert.is_nil(id)
            assert.are.equal("name_too_long", err)
        end)
    end)

    describe("rename and delete", function()
        it("should_rename_an_existing_group", function()
            local id = GroupStore.create(db, "Flasks")

            assert.is_true(GroupStore.rename(db, id, "Potions"))
            assert.are.equal("Potions", db.groups[id].name)
        end)

        it("should_refuse_to_rename_a_group_that_does_not_exist", function()
            local ok, err = GroupStore.rename(db, 99, "Potions")

            assert.is_false(ok)
            assert.are.equal("no_such_group", err)
        end)

        it("should_drop_the_group_from_both_the_table_and_the_order", function()
            local id = GroupStore.create(db, "Flasks")

            assert.is_true(GroupStore.delete(db, id))
            assert.is_nil(db.groups[id])
            assert.are.same({}, db.group_order)
        end)
    end)

    describe("list", function()
        it("should_return_groups_in_display_order", function()
            GroupStore.create(db, "Flasks")
            GroupStore.create(db, "Gems")

            local names = {}
            for _, group in ipairs(GroupStore.list(db)) do
                table.insert(names, group.name)
            end

            assert.are.same({ "Flasks", "Gems" }, names)
        end)

        it("should_skip_a_dangling_id_left_in_the_order", function()
            local id = GroupStore.create(db, "Flasks")
            db.groups[id] = nil

            assert.are.same({}, GroupStore.list(db))
        end)
    end)

    describe("move_group", function()
        it("should_move_a_group_to_the_requested_position", function()
            local first = GroupStore.create(db, "Flasks")
            local second = GroupStore.create(db, "Gems")

            GroupStore.move_group(db, second, 1)

            assert.are.same({ second, first }, db.group_order)
        end)

        it("should_clamp_an_out_of_range_index", function()
            local first = GroupStore.create(db, "Flasks")
            local second = GroupStore.create(db, "Gems")

            GroupStore.move_group(db, first, 99)

            assert.are.same({ second, first }, db.group_order)
        end)
    end)

    describe("add_item", function()
        it("should_create_an_entry_with_sane_defaults", function()
            local id = GroupStore.create(db, "Flasks")

            local entry = GroupStore.add_item(db, id, 212283)

            assert.are.equal(212283, entry.item_id)
            assert.are.equal(0, entry.target)
            assert.are.equal(1, entry.stack_size)
            assert.are.equal("market", entry.pricing.mode)
        end)

        it("should_update_the_existing_entry_instead_of_duplicating_it", function()
            local id = GroupStore.create(db, "Flasks")
            GroupStore.add_item(db, id, 212283, { target = 20 })

            local entry = GroupStore.add_item(db, id, 212283, { stack_size = 5 })

            assert.are.equal(20, entry.target)
            assert.are.equal(5, entry.stack_size)
            assert.are.same({ 212283 }, db.groups[id].item_order)
        end)

        it("should_reject_an_item_id_that_is_not_a_number", function()
            local id = GroupStore.create(db, "Flasks")

            local entry, err = GroupStore.add_item(db, id, "not-an-item")

            assert.is_nil(entry)
            assert.are.equal("invalid_item", err)
        end)

        it("should_reject_an_unknown_group", function()
            local entry, err = GroupStore.add_item(db, 99, 212283)

            assert.is_nil(entry)
            assert.are.equal("no_such_group", err)
        end)
    end)

    describe("remove_item", function()
        it("should_drop_the_entry_from_both_the_table_and_the_order", function()
            local id = GroupStore.create(db, "Flasks")
            GroupStore.add_item(db, id, 212283)

            assert.is_true(GroupStore.remove_item(db, id, 212283))
            assert.are.same({}, db.groups[id].item_order)
            assert.are.same({}, GroupStore.items(db, id))
        end)

        it("should_report_an_item_that_is_not_there", function()
            local id = GroupStore.create(db, "Flasks")

            local ok, err = GroupStore.remove_item(db, id, 212283)

            assert.is_false(ok)
            assert.are.equal("no_such_item", err)
        end)
    end)

    describe("set_target", function()
        it("should_accept_a_non_negative_integer", function()
            local id = GroupStore.create(db, "Flasks")
            GroupStore.add_item(db, id, 212283)

            assert.is_true(GroupStore.set_target(db, id, 212283, 20))
            assert.are.equal(20, db.groups[id].items[212283].target)
        end)

        it("should_accept_zero_so_an_item_can_be_tracked_without_selling", function()
            local id = GroupStore.create(db, "Flasks")
            GroupStore.add_item(db, id, 212283, { target = 20 })

            assert.is_true(GroupStore.set_target(db, id, 212283, 0))
            assert.are.equal(0, db.groups[id].items[212283].target)
        end)

        it("should_reject_a_negative_or_fractional_target", function()
            local id = GroupStore.create(db, "Flasks")
            GroupStore.add_item(db, id, 212283)

            assert.is_false(GroupStore.set_target(db, id, 212283, -1))
            assert.is_false(GroupStore.set_target(db, id, 212283, 2.5))
            assert.is_false(GroupStore.set_target(db, id, 212283, "abc"))
        end)
    end)

    describe("set_stack_size", function()
        it("should_never_drop_below_one", function()
            local id = GroupStore.create(db, "Flasks")
            GroupStore.add_item(db, id, 212283)

            GroupStore.set_stack_size(db, id, 212283, 0)

            assert.are.equal(1, db.groups[id].items[212283].stack_size)
        end)
    end)

    describe("tracked_item_ids", function()
        it("should_collect_ids_across_every_group_without_duplicates", function()
            local flasks = GroupStore.create(db, "Flasks")
            local gems = GroupStore.create(db, "Gems")
            GroupStore.add_item(db, flasks, 212283)
            GroupStore.add_item(db, gems, 212283)
            GroupStore.add_item(db, gems, 213743)

            local tracked = GroupStore.tracked_item_ids(db)

            assert.is_true(tracked[212283])
            assert.is_true(tracked[213743])
        end)
    end)
end)
