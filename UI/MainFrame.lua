-- The main window: groups on the left, the tracked items of the selected group
-- on the right. Rendering only — every number comes from Stock/StockLedger.

if not Auctionpad then Auctionpad = {} end
if not Auctionpad.UI then Auctionpad.UI = {} end

local UI = Auctionpad.UI

local WINDOW_WIDTH = 780
local WINDOW_HEIGHT = 470
local SIDEBAR_WIDTH = 190
local ROW_HEIGHT = 22
local GROUP_ROW_HEIGHT = 20

-- Column x offsets inside the item list, measured from its left edge.
local COL_NAME = 4
local COL_STOCK = 300
local COL_LISTED = 360
local COL_TARGET = 424
local COL_POST = 496
local COL_CRAFT = 566
local COL_REMOVE = 636

local STATUS_COLORS = {
    unknown = { 0.55, 0.55, 0.55 },
    craft = { 1.00, 0.36, 0.36 },
    bank = { 1.00, 0.72, 0.24 },
    post = { 1.00, 0.90, 0.36 },
    ready = { 0.42, 0.89, 0.46 },
}

local BACKDROP = {
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local frame
local group_rows = {}
local item_rows = {}
local selected_group_id
local recraft_only = false

local function L(key)
    return Auctionpad.Utils.Locale.get(key)
end

local function db()
    return Auctionpad.db
end

local function store()
    return Auctionpad.Data.GroupStore
end

-- Builds the ledger context for one item: what we own, and what is on sale.
local function build_context(item_id)
    local ItemInfo = Auctionpad.Utils.ItemInfo
    local listed, age = Auctionpad.Auction.OwnedAuctions.get_listed(db(), item_id)

    return {
        bag = ItemInfo.get_owned_bags(item_id),
        owned = ItemInfo.get_owned_total(item_id),
        listed = listed,
        listed_age = age,
        stale_after = db().settings.stale_after,
    }
end

local function status_color(status)
    local color = STATUS_COLORS[status] or STATUS_COLORS.unknown
    return color[1], color[2], color[3]
end

local function count_text(value)
    if value == nil then
        return "?"
    end
    return tostring(value)
end

-- ---------------------------------------------------------------- group rows

local function select_group(group_id)
    selected_group_id = group_id
    UI.Refresh()
end

local function create_group_row(index, parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(GROUP_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * GROUP_ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", 0, -(index - 1) * GROUP_ROW_HEIGHT)

    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetPoint("TOPLEFT")
    row.highlight:SetPoint("BOTTOMRIGHT")
    row.highlight:SetColorTexture(1, 1, 1, 0.12)
    row.highlight:Hide()

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", 6, 0)
    row.label:SetPoint("RIGHT", -6, 0)
    row.label:SetJustifyH("LEFT")

    return row
end

local function refresh_groups(container)
    local groups = store().list(db())

    for index, group in ipairs(groups) do
        local row = group_rows[index]
        if not row then
            row = create_group_row(index, container)
            group_rows[index] = row
        end

        row.label:SetText(group.name)
        row:SetScript("OnClick", function() select_group(group.id) end)

        if group.id == selected_group_id then
            row.highlight:Show()
            row.label:SetTextColor(1, 0.82, 0)
        else
            row.highlight:Hide()
            row.label:SetTextColor(1, 1, 1)
        end

        row:Show()
    end

    for index = #groups + 1, #group_rows do
        group_rows[index]:Hide()
    end

    container:SetHeight(math.max(1, #groups * GROUP_ROW_HEIGHT))
end

-- ----------------------------------------------------------------- item rows

local function create_item_row(index, parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)
    row:EnableMouse(true)

    local function column(x, width, template, justify)
        local text = row:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
        text:SetPoint("LEFT", x, 0)
        text:SetWidth(width)
        text:SetJustifyH(justify or "CENTER")
        return text
    end

    row.name = column(COL_NAME, COL_STOCK - COL_NAME - 8, "GameFontHighlight", "LEFT")
    row.stock = column(COL_STOCK, 54)
    row.listed = column(COL_LISTED, 54)
    row.to_post = column(COL_POST, 62)
    row.to_craft = column(COL_CRAFT, 62)

    row.target = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.target:SetSize(52, 18)
    row.target:SetPoint("LEFT", COL_TARGET, 0)
    row.target:SetAutoFocus(false)
    row.target:SetNumeric(true)
    row.target:SetJustifyH("CENTER")

    row.remove = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    row.remove:SetSize(20, 20)
    row.remove:SetPoint("LEFT", COL_REMOVE, 0)

    row:SetScript("OnEnter", function(self)
        if not self.item_id then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.item_id)
        if self.age_line then
            GameTooltip:AddLine(self.age_line, 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return row
end

local function commit_target(row)
    local value = tonumber(row.target:GetText()) or 0
    store().set_target(db(), selected_group_id, row.item_id, value)
    row.target:ClearFocus()
    UI.Refresh()
end

local function bind_item_row(row, entry)
    local Ledger = Auctionpad.Stock.Ledger
    local result = Ledger.compute(entry, build_context(entry.item_id))

    row.item_id = entry.item_id
    row.name:SetText(Auctionpad.Utils.ItemInfo.get_name(entry.item_id, "item:" .. entry.item_id))

    local red, green, blue = status_color(result.status)
    row.name:SetTextColor(red, green, blue)

    row.stock:SetText(tostring(Auctionpad.Utils.ItemInfo.get_owned_total(entry.item_id)))
    row.listed:SetText(count_text(result.listed))
    row.to_post:SetText(count_text(result.to_post))
    row.to_craft:SetText(count_text(result.to_recraft))
    row.to_craft:SetTextColor(red, green, blue)

    if not row.target:HasFocus() then
        row.target:SetText(tostring(entry.target or 0))
    end
    row.target:SetScript("OnEnterPressed", function() commit_target(row) end)
    row.target:SetScript("OnEditFocusLost", function() commit_target(row) end)

    row.remove:SetScript("OnClick", function()
        store().remove_item(db(), selected_group_id, entry.item_id)
        UI.Refresh()
    end)

    local _, age = Auctionpad.Auction.OwnedAuctions.get_listed(db(), entry.item_id)
    if age == nil then
        row.age_line = L("On sale: unknown (never seen at the auction house).")
    else
        row.age_line = string.format(L("On sale as of %s ago."), Auctionpad.Utils.Locale.format_age(age))
    end

    row:Show()
    return result
end

local function visible_entries(entries)
    if not recraft_only then
        return entries
    end

    local Ledger = Auctionpad.Stock.Ledger
    local filtered = {}
    for _, entry in ipairs(entries) do
        local result = Ledger.compute(entry, build_context(entry.item_id))
        if result.status == Ledger.CRAFT then
            table.insert(filtered, entry)
        end
    end
    return filtered
end

local function refresh_items(container)
    local entries = {}
    if selected_group_id then
        entries = visible_entries(store().items(db(), selected_group_id))
    end

    for index, entry in ipairs(entries) do
        local row = item_rows[index]
        if not row then
            row = create_item_row(index, container)
            item_rows[index] = row
        end
        bind_item_row(row, entry)
    end

    for index = #entries + 1, #item_rows do
        item_rows[index]:Hide()
    end

    container:SetHeight(math.max(1, #entries * ROW_HEIGHT))
    return #entries
end

-- ------------------------------------------------------------- adding items

-- Accepts an item dropped from the bags, or an item link / id typed in the box.
local function add_item(item_id, item_link)
    if not selected_group_id then
        print("|cff33ff99Auctionpad|r " .. L("No group yet. Create one to get started."))
        return false
    end

    local entry = store().add_item(db(), selected_group_id, item_id, { item_link = item_link })
    if not entry then
        return false
    end

    UI.Refresh()
    return true
end

local function add_from_cursor()
    local kind, item_id, item_link = GetCursorInfo()
    if kind ~= "item" then
        return false
    end

    ClearCursor()
    return add_item(item_id, item_link)
end

local function add_from_text(text)
    if not text or text == "" then
        return false
    end

    -- Either a raw id, or an item link the user shift-clicked into the box.
    local item_id = tonumber(text) or tonumber(text:match("item:(%d+)"))
    if not item_id then
        return false
    end

    return add_item(item_id, text:match("|c.-|h.-|h|r"))
end

-- ------------------------------------------------------------------- window

local function create_window()
    local window = CreateFrame("Frame", "AuctionpadFrame", UIParent, "BackdropTemplate")
    window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    window:SetPoint("CENTER")
    window:SetBackdrop(BACKDROP)
    window:SetBackdropColor(0, 0, 0, 0.9)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        db().settings.frame_position = { point = point, x = x, y = y }
    end)
    window:Hide()

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText(L("Auctionpad"))

    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    return window, title
end

local function create_sidebar(window)
    local groups_header = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    groups_header:SetPoint("TOPLEFT", 16, -44)
    groups_header:SetText(L("Groups"))

    local scroll = CreateFrame("ScrollFrame", "AuctionpadGroupScroll", window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -64)
    scroll:SetSize(SIDEBAR_WIDTH - 24, WINDOW_HEIGHT - 132)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(SIDEBAR_WIDTH - 24, 1)
    scroll:SetScrollChild(content)

    local name_box = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    name_box:SetSize(SIDEBAR_WIDTH - 66, 20)
    name_box:SetPoint("BOTTOMLEFT", 20, 18)
    name_box:SetAutoFocus(false)

    local add_button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    add_button:SetSize(44, 22)
    add_button:SetPoint("LEFT", name_box, "RIGHT", 6, 0)
    add_button:SetText(L("Add"))

    local function create_group()
        local group_id = store().create(db(), name_box:GetText())
        if group_id then
            name_box:SetText("")
            name_box:ClearFocus()
            select_group(group_id)
        end
    end

    add_button:SetScript("OnClick", create_group)
    name_box:SetScript("OnEnterPressed", create_group)

    return content
end

local function create_item_panel(window)
    local panel = CreateFrame("Frame", nil, window, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", SIDEBAR_WIDTH, -44)
    panel:SetPoint("BOTTOMRIGHT", -12, 46)
    panel:SetBackdrop(BACKDROP)
    panel:SetBackdropColor(0, 0, 0, 0.35)
    panel:EnableMouse(true)
    -- Dropping a bag item anywhere on the panel adds it to the selected group.
    panel:SetScript("OnReceiveDrag", add_from_cursor)
    panel:SetScript("OnMouseUp", add_from_cursor)

    local function header(x, width, label, justify)
        local text = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("TOPLEFT", x + 8, -10)
        text:SetWidth(width)
        text:SetJustifyH(justify or "CENTER")
        text:SetText(label)
        return text
    end

    header(COL_NAME, COL_STOCK - COL_NAME - 8, L("Item"), "LEFT")
    header(COL_STOCK, 54, L("Stock"))
    header(COL_LISTED, 54, L("On sale"))
    header(COL_TARGET, 54, L("Target"))
    header(COL_POST, 62, L("To post"))
    header(COL_CRAFT, 62, L("To recraft"))

    local scroll = CreateFrame("ScrollFrame", "AuctionpadItemScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -30)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WINDOW_WIDTH - SIDEBAR_WIDTH - 50, 1)
    scroll:SetScrollChild(content)

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("CENTER", 0, 0)
    hint:SetText(L("Drag an item here, or paste an item link."))

    return panel, content, hint
end

local function create_footer(window)
    local item_box = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    item_box:SetSize(200, 20)
    item_box:SetPoint("BOTTOMLEFT", SIDEBAR_WIDTH + 12, 18)
    item_box:SetAutoFocus(false)
    item_box:SetScript("OnEnterPressed", function(self)
        if add_from_text(self:GetText()) then
            self:SetText("")
        end
        self:ClearFocus()
    end)

    local filter = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    filter:SetSize(150, 22)
    filter:SetPoint("LEFT", item_box, "RIGHT", 8, 0)
    filter:SetText(L("Recraft only"))
    filter:SetScript("OnClick", function(self)
        recraft_only = not recraft_only
        if recraft_only then
            self:LockHighlight()
        else
            self:UnlockHighlight()
        end
        UI.Refresh()
    end)

    local status = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    status:SetPoint("BOTTOMRIGHT", -16, 24)
    status:SetJustifyH("RIGHT")

    return status
end

local function ensure_frame()
    if frame then
        return frame
    end

    local window = create_window()
    frame = window
    frame.group_content = create_sidebar(window)
    frame.item_panel, frame.item_content, frame.item_hint = create_item_panel(window)
    frame.status = create_footer(window)

    return frame
end

local function restore_position(window)
    local saved = db().settings.frame_position
    if not saved or not saved.point then
        return
    end
    window:ClearAllPoints()
    window:SetPoint(saved.point, UIParent, saved.point, saved.x or 0, saved.y or 0)
end

-- --------------------------------------------------------------- public API

function UI.Refresh()
    if not frame or not frame:IsShown() then
        return
    end

    -- Keep the selection pointing at something that still exists.
    local groups = store().list(db())
    if selected_group_id and not store().get(db(), selected_group_id) then
        selected_group_id = nil
    end
    if not selected_group_id and groups[1] then
        selected_group_id = groups[1].id
    end

    refresh_groups(frame.group_content)
    local shown = refresh_items(frame.item_content)

    if shown > 0 then
        frame.item_hint:Hide()
    else
        frame.item_hint:Show()
    end

    local _, age = Auctionpad.Auction.OwnedAuctions.get_snapshot(db())
    if age == nil then
        frame.status:SetText(L("Open the auction house to refresh what is on sale."))
    else
        frame.status:SetText(string.format(L("On sale as of %s ago."), Auctionpad.Utils.Locale.format_age(age)))
    end
end

function UI.Show()
    local window = ensure_frame()
    restore_position(window)
    window:Show()
    UI.Refresh()
end

function UI.Hide()
    if frame then
        frame:Hide()
    end
end

function UI.Toggle()
    if frame and frame:IsShown() then
        UI.Hide()
    else
        UI.Show()
    end
end

function UI.IsShown()
    return frame ~= nil and frame:IsShown()
end
