-- Hand-rolled minimap button (no LibDBIcon, to stay dependency free like the
-- other addons in this repo). The angle is kept in the saved variables.

if not Auctionpad then Auctionpad = {} end
if not Auctionpad.UI then Auctionpad.UI = {} end

local UI = Auctionpad.UI

local RADIUS = 80
local ICON = "Interface/Icons/INV_Misc_Coin_01"

local button

local function settings()
    return Auctionpad.db.settings.minimap
end

local function place(angle)
    local radians = math.rad(angle)
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * RADIUS, math.sin(radians) * RADIUS)
end

local function drag_to_cursor()
    local scale = Minimap:GetEffectiveScale()
    local center_x, center_y = Minimap:GetCenter()
    local cursor_x, cursor_y = GetCursorPosition()

    local angle = math.deg(math.atan2(cursor_y / scale - center_y, cursor_x / scale - center_x))
    settings().angle = angle
    place(angle)
end

function UI.CreateMinimapButton()
    if button then
        return button
    end

    button = CreateFrame("Button", "AuctionpadMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface/Minimap/MiniMap-TrackingBorder")

    button:SetScript("OnClick", function()
        UI.Toggle()
    end)

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", drag_to_cursor)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(Auctionpad.Utils.Locale.get("Auctionpad"))
        GameTooltip:AddLine("/apad", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    place(settings().angle or 200)

    if settings().hide then
        button:Hide()
    end

    return button
end

function UI.SetMinimapButtonShown(shown)
    settings().hide = not shown
    if not button then
        return
    end
    if shown then
        button:Show()
    else
        button:Hide()
    end
end
