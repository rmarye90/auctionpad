-- CRUD over the sell groups stored in the saved variables.
-- Pure module: the database table is always passed in, never read from the global.

if not Auctionpad then Auctionpad = {} end
if not Auctionpad.Data then Auctionpad.Data = {} end

local GroupStore = {}
Auctionpad.Data.GroupStore = GroupStore

local MAX_NAME_LENGTH = 40

local function trim(value)
    return (tostring(value or ""):gsub("^%s*(.-)%s*$", "%1"))
end

local function index_of(list, value)
    for index, candidate in ipairs(list) do
        if candidate == value then
            return index
        end
    end
    return nil
end

local function validate_name(name)
    local clean = trim(name)
    if clean == "" then
        return nil, "empty_name"
    end
    if #clean > MAX_NAME_LENGTH then
        return nil, "name_too_long"
    end
    return clean
end

local function validate_count(value)
    local number = tonumber(value)
    if not number or number ~= math.floor(number) or number < 0 then
        return nil, "invalid_count"
    end
    return number
end

function GroupStore.create(db, name)
    local clean, err = validate_name(name)
    if not clean then
        return nil, err
    end

    local id = db.next_group_id or 1
    db.next_group_id = id + 1
    db.groups[id] = {
        id = id,
        name = clean,
        item_order = {},
        items = {},
        created_at = time(),
    }
    table.insert(db.group_order, id)

    return id
end

function GroupStore.get(db, group_id)
    return db.groups[group_id]
end

-- Groups in display order, skipping any dangling id left by a bad write.
function GroupStore.list(db)
    local result = {}
    for _, id in ipairs(db.group_order) do
        local group = db.groups[id]
        if group then
            table.insert(result, group)
        end
    end
    return result
end

function GroupStore.rename(db, group_id, name)
    local group = db.groups[group_id]
    if not group then
        return false, "no_such_group"
    end

    local clean, err = validate_name(name)
    if not clean then
        return false, err
    end

    group.name = clean
    return true
end

function GroupStore.delete(db, group_id)
    if not db.groups[group_id] then
        return false, "no_such_group"
    end

    db.groups[group_id] = nil
    local position = index_of(db.group_order, group_id)
    if position then
        table.remove(db.group_order, position)
    end

    return true
end

function GroupStore.move_group(db, group_id, new_index)
    local position = index_of(db.group_order, group_id)
    if not position then
        return false, "no_such_group"
    end

    local clamped = math.max(1, math.min(#db.group_order, math.floor(new_index or 1)))
    table.remove(db.group_order, position)
    table.insert(db.group_order, clamped, group_id)

    return true
end

-- Adding an item that is already in the group updates it instead of duplicating.
function GroupStore.add_item(db, group_id, item_id, opts)
    local group = db.groups[group_id]
    if not group then
        return nil, "no_such_group"
    end

    item_id = tonumber(item_id)
    if not item_id then
        return nil, "invalid_item"
    end

    opts = opts or {}
    local entry = group.items[item_id]
    if not entry then
        entry = { item_id = item_id, added_at = time() }
        group.items[item_id] = entry
        table.insert(group.item_order, item_id)
    end

    entry.item_link = opts.item_link or entry.item_link
    entry.target = opts.target or entry.target or 0
    entry.stack_size = opts.stack_size or entry.stack_size or 1
    entry.pricing = opts.pricing or entry.pricing or {
        mode = "market",
        undercut = { mode = "flat", value = 1 },
        floor_copper = 0,
    }

    return entry
end

function GroupStore.remove_item(db, group_id, item_id)
    local group = db.groups[group_id]
    if not group or not group.items[item_id] then
        return false, "no_such_item"
    end

    group.items[item_id] = nil
    local position = index_of(group.item_order, item_id)
    if position then
        table.remove(group.item_order, position)
    end

    return true
end

function GroupStore.items(db, group_id)
    local group = db.groups[group_id]
    if not group then
        return {}
    end

    local result = {}
    for _, item_id in ipairs(group.item_order) do
        local entry = group.items[item_id]
        if entry then
            table.insert(result, entry)
        end
    end
    return result
end

function GroupStore.set_target(db, group_id, item_id, target)
    local group = db.groups[group_id]
    local entry = group and group.items[item_id]
    if not entry then
        return false, "no_such_item"
    end

    local count, err = validate_count(target)
    if not count then
        return false, err
    end

    entry.target = count
    return true
end

function GroupStore.set_stack_size(db, group_id, item_id, stack_size)
    local group = db.groups[group_id]
    local entry = group and group.items[item_id]
    if not entry then
        return false, "no_such_item"
    end

    local count, err = validate_count(stack_size)
    if not count then
        return false, err
    end

    entry.stack_size = math.max(1, count)
    return true
end

function GroupStore.set_pricing(db, group_id, item_id, pricing)
    local group = db.groups[group_id]
    local entry = group and group.items[item_id]
    if not entry then
        return false, "no_such_item"
    end

    entry.pricing = pricing
    return true
end

-- Every item id tracked across all groups, used to prune the recipe cache.
function GroupStore.tracked_item_ids(db)
    local seen = {}
    for _, group in pairs(db.groups) do
        for item_id in pairs(group.items or {}) do
            seen[item_id] = true
        end
    end
    return seen
end
