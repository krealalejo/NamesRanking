local _, NR = ...

local MinimapButton = {}
NR.MinimapButton = MinimapButton

local LOGO = "Interface\\AddOns\\NamesRanking\\Media\\Logo.tga"
local SIZE = 32
local DEFAULT_ANGLE = 215

local button

local function Place()
	local angle = math.rad(NR.db.settings.minimapAngle or DEFAULT_ANGLE)
	local radius = Minimap:GetWidth() / 2 + 6
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function FollowCursor()
	local centerX, centerY = Minimap:GetCenter()
	local scale = Minimap:GetEffectiveScale()
	local cursorX, cursorY = GetCursorPosition()
	NR.db.settings.minimapAngle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX)) % 360
	Place()
end

local function ShowTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("Names Ranking", 1, 0.82, 0)
	GameTooltip:AddLine("Click to open the leaderboard", 1, 1, 1)
	GameTooltip:AddLine("Drag to move this button", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

function MinimapButton:Init()
	button = CreateFrame("Button", "NamesRankingMinimapButton", Minimap)
	button:SetSize(SIZE, SIZE)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:SetNormalTexture(LOGO)
	button:SetHighlightTexture(LOGO, "ADD")
	button:RegisterForClicks("LeftButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetScript("OnClick", function() NR.Leaderboard:Toggle() end)
	button:SetScript("OnEnter", ShowTooltip)
	button:SetScript("OnLeave", GameTooltip_Hide)
	button:SetScript("OnDragStart", function(self)
		GameTooltip_Hide()
		self:SetScript("OnUpdate", FollowCursor)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	Place()
end
