local _, NR = ...

local ART_NORMAL = "common-button-tertiary-square-normal"
local ART_PRESSED = "common-button-tertiary-square-pressed"

local function ApplyArt(button)
	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(ART_NORMAL) then
		button:SetNormalAtlas(ART_NORMAL)
		button:SetPushedAtlas(ART_PRESSED)
		button:SetDisabledAtlas(ART_NORMAL)
		button:SetHighlightAtlas(ART_NORMAL, "ADD")
	else
		local background = button:CreateTexture(nil, "BACKGROUND")
		background:SetAllPoints()
		background:SetColorTexture(0.20, 0.13, 0.07)
		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	end
end

function NR.CreateMenuButton(parent, size, text, r, g, b, a)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(size, size)
	button:SetMotionScriptsWhileDisabled(true)
	ApplyArt(button)

	local inset = math.floor(size / 8)
	button.fill = button:CreateTexture(nil, "OVERLAY", nil, -1)
	button.fill:SetPoint("TOPLEFT", inset, -inset)
	button.fill:SetPoint("BOTTOMRIGHT", -inset, inset)
	button.fill:SetColorTexture(r, g, b, a)
	button.fill:Hide()

	button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	button.label:SetPoint("CENTER", 0, 0)
	button.label:SetText(text)
	return button
end

function NR.CreateRemoveButton(parent, size)
	local button = NR.CreateMenuButton(parent, size, "X", 0.70, 0.12, 0.12, 0.85)
	button.fill:Show()
	button.label:SetTextColor(1, 1, 1)
	return button
end
