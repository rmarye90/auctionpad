-- Luacheck configuration for the Auctionpad WoW addon
std = "lua51"
codes = true
max_line_length = 120

-- WoW API globals (read-only)
read_globals = {
    -- Frames and UI
    "CreateFrame", "UIParent", "GameTooltip", "GameTooltip_SetDefaultAnchor",
    "Minimap", "GetCursorPosition", "GetCursorInfo", "ClearCursor",
    -- Items
    "GetItemCount", "GetItemInfo", "C_Item", "C_Container", "ItemLocation",
    -- Auction house
    "C_AuctionHouse", "AuctionHouseFrame",
    -- Professions
    "C_TradeSkillUI", "GetProfessions", "GetProfessionInfo",
    -- Misc
    "C_Timer", "C_AddOns", "Enum", "unpack",
    "UnitAffectingCombat", "UnitName", "GetRealmName",
    "GetLocale", "GetBuildInfo", "GetMoney", "time",
    -- Optional dependency, guarded at every call site
    "Auctionator",
}

-- Auctionpad globals (writable)
globals = {
    "Auctionpad",
    "AuctionpadDB", -- SavedVariables
    "SLASH_AUCTIONPAD1", "SLASH_AUCTIONPAD2",
    "SlashCmdList",
}

files["**/*_spec.lua"] = {
    read_globals = {"describe", "it", "before_each", "after_each", "assert", "spy", "stub", "mock"},
}

files["test_helpers/**/*.lua"] = {
    allow_defined_top = true,
    ignore = {"212"}, -- unused arguments in mocks are fine
}
