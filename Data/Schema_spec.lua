local WowApiMock = require("test_helpers.WowApiMock")

describe("Schema", function()
    local Schema

    before_each(function()
        WowApiMock.install()
        _G.Auctionpad = {}
        _G.Auctionpad.Data = {}
        dofile("Data/Schema.lua")
        Schema = Auctionpad.Data
    end)

    describe("initialize", function()
        it("should_build_a_full_db_when_given_nil", function()
            local db = Schema.initialize(nil)

            assert.are.equal(Schema.SCHEMA_VERSION, db.version)
            assert.are.same({}, db.groups)
            assert.are.same({}, db.group_order)
            assert.are.equal(1, db.next_group_id)
            assert.are.equal(3600, db.settings.stale_after)
        end)

        it("should_build_a_full_db_when_given_an_empty_table", function()
            local db = Schema.initialize({})

            assert.are.equal(Schema.SCHEMA_VERSION, db.version)
            assert.is_table(db.recipe_index)
            assert.is_table(db.price_cache)
            assert.is_table(db.owned_snapshot)
        end)

        it("should_keep_user_data_when_db_is_partial", function()
            local db = Schema.initialize({
                groups = { [7] = { id = 7, name = "Flasks", items = {} } },
                settings = { duration = 1 },
            })

            assert.are.equal("Flasks", db.groups[7].name)
            assert.are.equal(1, db.settings.duration)
            -- untouched defaults are filled in around it
            assert.are.equal(3600, db.settings.stale_after)
            assert.are.equal(200, db.settings.minimap.angle)
        end)

        it("should_be_idempotent_when_run_twice", function()
            local once = Schema.initialize({})
            once.groups[1] = { id = 1, name = "Gems", items = {} }

            local twice = Schema.initialize(once)

            assert.are.equal("Gems", twice.groups[1].name)
            assert.are.equal(Schema.SCHEMA_VERSION, twice.version)
        end)

        it("should_treat_a_db_without_version_as_version_one", function()
            local db = Schema.initialize({ groups = {} })

            assert.are.equal(Schema.SCHEMA_VERSION, db.version)
        end)
    end)

    describe("fill_missing", function()
        it("should_not_overwrite_a_falsy_but_present_value", function()
            local target = { settings = { price_floor = false } }

            Schema.fill_missing(target, { settings = { price_floor = true } })

            assert.is_false(target.settings.price_floor)
        end)

        it("should_not_recurse_into_a_value_the_user_replaced_with_a_scalar", function()
            local target = { settings = 5 }

            Schema.fill_missing(target, { settings = { duration = 3 } })

            assert.are.equal(5, target.settings)
        end)
    end)

    describe("migrate", function()
        it("should_stamp_the_current_version_when_no_migration_path_exists", function()
            local db = { version = 0 }

            Schema.migrate(db)

            assert.are.equal(Schema.SCHEMA_VERSION, db.version)
        end)

        it("should_run_a_registered_migration_when_the_db_is_behind", function()
            Schema.SCHEMA_VERSION = 2
            Schema.migrations[1] = function(db)
                db.migrated = true
                db.version = 2
            end

            local db = { version = 1 }
            Schema.migrate(db)

            assert.is_true(db.migrated)
            assert.are.equal(2, db.version)
        end)
    end)
end)
