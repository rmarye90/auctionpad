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
    "GetItemCount", "GetItemInfo", "GetItemIcon", "C_Item", "C_Container", "ItemLocation",
    -- Auction house
    "C_AuctionHouse", "AuctionHouseFrame",
    -- Professions
    "C_TradeSkillUI", "GetProfessions", "GetProfessionInfo",
    -- Misc
    "C_Timer", "C_AddOns", "Enum", "unpack",
    "UnitAffectingCombat", "UnitName", "GetRealmName",
    "GetLocale", "GetBuildInfo", "GetMoney", "time",
    -- Confirmation popups
    "StaticPopup_Show", "YES", "NO",
    -- Optional dependency, guarded at every call site
    "Auctionator",
    -- Auction house window (used by UI/AHTab.lua; Libs/ itself is style-excluded below)
    "LibStub", "AuctionHouseFrame",
}

-- Auctionpad globals (writable)
globals = {
    "Auctionpad",
    "AuctionpadDB", -- SavedVariables
    "SLASH_AUCTIONPAD1", "SLASH_AUCTIONPAD2",
    "SlashCmdList",
    "StaticPopupDialogs",
}

files["**/*_spec.lua"] = {
    read_globals = {"describe", "it", "before_each", "after_each", "assert", "spy", "stub", "mock"},
    -- Tests poke fields on the mocked AuctionHouseFrame (e.g. IsShown) to
    -- simulate it opening/closing — legitimate only in test code.
    ignore = {"122"},
}

files["test_helpers/**/*.lua"] = {
    allow_defined_top = true,
    ignore = {"212"}, -- unused arguments in mocks are fine
}

-- Vendored third-party code (see Libs/*/README or LICENSE) — not our style,
-- and never edited beyond an attribution comment. Skip style checks entirely.
files["Libs/**/*.lua"] = {
    ignore = {"1", "2", "4", "6"}, -- undefined/global-write, unused, shadowing, formatting
}
