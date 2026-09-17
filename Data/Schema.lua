-- Saved variables schema: defaults, non-destructive fill and versioned migrations.
-- Pure module: it never touches the AuctionpadDB global, the caller passes the table in.

if not Auctionpad then Auctionpad = {} end
if not Auctionpad.Data then Auctionpad.Data = {} end

local Schema = Auctionpad.Data

Schema.SCHEMA_VERSION = 2

-- Returns a fresh copy every call: callers mutate what they get back.
function Schema.defaults()
    return {
        version = Schema.SCHEMA_VERSION,
        next_group_id = 1,
        group_order = {},
        groups = {},
        recipe_index = {},
        price_cache = {},
        owned_snapshot = {},
        settings = {
            duration = 3,
            undercut = { mode = "flat", value = 1 },
            price_floor = true,
            auto_open_at_ah = false,
            stale_after = 3600,
            minimap = { hide = false, angle = 200 },
        },
    }
end

-- Fills in missing keys without ever overwriting user data.
local function fill_missing(target, defaults)
    for key, default_value in pairs(defaults) do
        if target[key] == nil then
            if type(default_value) == "table" then
                target[key] = {}
                fill_missing(target[key], default_value)
            else
                target[key] = default_value
            end
        elseif type(default_value) == "table" and type(target[key]) == "table" then
            fill_missing(target[key], default_value)
        end
    end
    return target
end

Schema.fill_missing = fill_missing

-- [from_version] = function(db) ... end. Each migration bumps db.version itself.
Schema.migrations = {
    -- auto_open_at_ah used to mean "open the floating window when the AH
    -- shows up"; it now means "auto-select the Auctionpad tab". Force it off
    -- for anyone coming from the old default of true, so opening the AH
    -- doesn't suddenly hijack their view of Buy/Sell/Auctions.
    [1] = function(db)
        if db.settings and db.settings.auto_open_at_ah == true then
            db.settings.auto_open_at_ah = false
        end
        db.version = 2
    end,
}

function Schema.migrate(db)
    if type(db.version) ~= "number" then
        db.version = 1
    end

    while db.version < Schema.SCHEMA_VERSION do
        local migration = Schema.migrations[db.version]
        if not migration then
            -- No path forward: stamp the current version rather than looping.
            db.version = Schema.SCHEMA_VERSION
            break
        end
        migration(db)
    end

    return db
end

-- Entry point called once from ADDON_LOADED.
function Schema.initialize(db)
    db = db or {}
    Schema.migrate(db)
    -- migrate() already stamped the version; a db from a *newer* addon is left alone.
    fill_missing(db, Schema.defaults())
    return db
end
