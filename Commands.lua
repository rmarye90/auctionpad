-- Slash commands.

if not Auctionpad then Auctionpad = {} end

local function show_help()
    print("|cff33ff99Auctionpad|r v" .. (Auctionpad.Version or "?"))
    print("  /apad          - toggle the main window")
    print("  /apad help     - show this help")
end

SLASH_AUCTIONPAD1 = "/auctionpad"
SLASH_AUCTIONPAD2 = "/apad"

SlashCmdList["AUCTIONPAD"] = function(msg)
    local command = (msg or ""):match("^%s*(%S*)"):lower()

    if command == "" then
        if Auctionpad.UI and Auctionpad.UI.Toggle then
            Auctionpad.UI.Toggle()
        else
            show_help()
        end
        return
    end

    show_help()
end
