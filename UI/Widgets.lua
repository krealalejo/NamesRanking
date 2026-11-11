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

local REMOVE = 0

local function ShowVoteTooltip(button)
	local name = button:GetParent().name
	if not name then return end
	local mine = NR.Votes:GetMyVote(name)
	local entry = NR.Ranking:GetEntry(name)

	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:AddLine(NR.ColoredName(name))
	if entry then
		GameTooltip:AddLine(("Rank #%d - %d points - %d votes"):format(entry.rank, entry.points, entry.votes), 1, 1, 1)
	else
		GameTooltip:AddLine("No votes yet", 0.7, 0.7, 0.7)
	end
	if mine > 0 then
		GameTooltip:AddLine(("Your vote: %d"):format(mine), 1, 0.82, 0)
	end
	if button.value == REMOVE then
		GameTooltip:AddLine(mine > 0 and "Click to remove your vote" or "You haven't voted for this name", 0.6, 0.6, 0.6)
	elseif mine == button.value then
		GameTooltip:AddLine("This is your current vote", 0.6, 0.6, 0.6)
	elseif mine > 0 then
		GameTooltip:AddLine("Remove your vote to vote again", 0.6, 0.6, 0.6)
	else
		GameTooltip:AddLine(("Click to give %d point%s"):format(button.value, button.value == 1 and "" or "s"), 0.6, 0.6, 0.6)
	end
	GameTooltip:Show()
end

function NR.UpdateVoteButtons(holder)
	local name = holder.name
	if not name or name == NR.player then
		holder:Hide()
		return
	end
	local mine = NR.Votes:GetMyVote(name)
	for i = 1, NR.MAX_VOTE do
		local button = holder.buttons[i]
		local active = mine == i
		button.fill:SetShown(active)
		button:SetEnabled(mine == 0)
		if active then
			button.label:SetTextColor(0.15, 0.08, 0)
		elseif mine == 0 then
			button.label:SetTextColor(1, 0.82, 0)
		else
			button.label:SetTextColor(0.6, 0.6, 0.6)
		end
	end
	local remove = holder.buttons[REMOVE]
	if remove then
		remove:SetEnabled(mine > 0)
		remove:SetAlpha(mine > 0 and 1 or 0.35)
	end
	holder:Show()
end

local function OnVoteClick(button)
	local holder = button:GetParent()
	if not holder.name then return end
	NR.Votes:CastLocal(holder.name, button.value)
	NR.UpdateVoteButtons(holder)
	ShowVoteTooltip(button)
end

local function CreateVoteButton(holder, value, position, size, gap)
	local button
	if value == REMOVE then
		button = NR.CreateRemoveButton(holder, size)
	else
		button = NR.CreateMenuButton(holder, size, tostring(value), 1, 0.82, 0, 0.85)
	end
	button:SetPoint("LEFT", holder, "LEFT", (position - 1) * (size + gap), 0)
	button.value = value
	button:SetScript("OnClick", OnVoteClick)
	button:SetScript("OnEnter", ShowVoteTooltip)
	button:SetScript("OnLeave", GameTooltip_Hide)
	return button
end

function NR.CreateVoteButtons(parent, size, gap, withRemove)
	local count = NR.MAX_VOTE + (withRemove and 1 or 0)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(count * size + (count - 1) * gap, size)
	holder:SetFrameLevel(parent:GetFrameLevel() + 5)
	holder.buttons = {}
	for i = 1, NR.MAX_VOTE do
		holder.buttons[i] = CreateVoteButton(holder, i, i, size, gap)
	end
	if withRemove then
		holder.buttons[REMOVE] = CreateVoteButton(holder, REMOVE, count, size, gap)
	end
	return holder
end
