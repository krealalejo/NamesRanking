local _, NR = ...

local Leaderboard = {}
NR.Leaderboard = Leaderboard

local WIDTH, HEIGHT = 440, 450
local ROWS, ROW_HEIGHT = 16, 20
local LIST_TOP = -84
local COLUMNS = {
	{ x = 14, width = 46, justify = "LEFT" },
	{ x = 62, width = 196, justify = "LEFT" },
	{ x = 262, width = 64, justify = "RIGHT" },
	{ x = 330, width = 70, justify = "RIGHT" },
}
local MINE_COLUMNS = {
	{ x = 14, width = 46, justify = "LEFT" },
	{ x = 62, width = 150, justify = "LEFT" },
	{ x = 216, width = 60, justify = "RIGHT" },
	{ x = 278, width = 60, justify = "RIGHT" },
	{ x = 344, width = 60, justify = "CENTER" },
}
local REMOVE_SIZE = 18
local CREDIT = "with |TInterface\\AddOns\\NamesRanking\\Media\\Heart.tga:12:12|t by kames"
local HEADERS = {
	top = { "#", "Name", "Points", "Votes" },
	mine = { "Rank", "Name", "Your vote", "Points", "Remove" },
	recent = { "When", "Name", "", "Vote" },
}
local TABS = {
	{ key = "top", label = "Realm top" },
	{ key = "mine", label = "My votes" },
	{ key = "recent", label = "Recent" },
}

local frame
local mode = "top"
local items = {}
local offset = 0

local function Matches(name, filter)
	if filter == "" then return true end
	if name:lower():find(filter, 1, true) then return true end
	local classFile = NR.Votes:GetClass(name)
	if not classFile then return false end
	local localized = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile]) or classFile
	return localized:lower():find(filter, 1, true) ~= nil or classFile:lower():find(filter, 1, true) ~= nil
end

local function BuildItems(filter)
	wipe(items)
	if mode == "top" then
		for _, entry in ipairs(NR.Ranking:GetList()) do
			if Matches(entry.name, filter) then
				items[#items + 1] = { name = entry.name, entry.rank, NR.ColoredName(entry.name), entry.points, entry.votes }
			end
		end
	elseif mode == "mine" then
		for name, vote in pairs(NR.Votes:GetVotesBy(NR.player) or {}) do
			if vote[1] > 0 and Matches(name, filter) then
				local entry = NR.Ranking:GetEntry(name)
				local points = entry and entry.points or 0
				items[#items + 1] = { name = name, vote = vote[1], points = points, entry and entry.rank or "-", NR.ColoredName(name), vote[1], points }
			end
		end
		table.sort(items, function(a, b)
			if a.vote ~= b.vote then return a.vote > b.vote end
			return a.points > b.points
		end)
	else
		for _, vote in ipairs(NR.Votes:GetRecent(200)) do
			if Matches(vote.target, filter) then
				items[#items + 1] = { name = vote.target, NR.Ago(vote.ts), NR.ColoredName(vote.target), "", vote.value }
			end
		end
	end
end

local function ShowRowTooltip(row)
	local name = row.item and row.item.name
	if not name then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(NR.ColoredName(name))
	local entry = NR.Ranking:GetEntry(name)
	if entry then
		GameTooltip:AddLine(("Rank #%d - %d points"):format(entry.rank, entry.points), 1, 1, 1)
		GameTooltip:AddLine(("%d votes, %d of them worth 3 points"):format(entry.votes, entry.threes), 0.8, 0.8, 0.8)
	end
	local mine = NR.Votes:GetMyVote(name)
	if mine > 0 then
		GameTooltip:AddLine(("Your vote: %d"):format(mine), 1, 0.82, 0)
	end
	GameTooltip:Show()
end

local function OnRemoveClick(button)
	local item = button:GetParent().item
	if item then
		GameTooltip_Hide()
		NR.Votes:CastLocal(item.name, 0)
	end
end

local function ShowRemoveTooltip(button)
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:AddLine("Remove your vote", 1, 1, 1)
	GameTooltip:Show()
end

local function CreateRow(parent, i)
	local row = CreateFrame("Button", nil, parent)
	row:SetSize(WIDTH - 48, ROW_HEIGHT)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, LIST_TOP - (i - 1) * ROW_HEIGHT)
	if i % 2 == 0 then
		local stripe = row:CreateTexture(nil, "BACKGROUND")
		stripe:SetAllPoints()
		stripe:SetColorTexture(1, 1, 1, 0.04)
	end
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

	row.cols = {}
	for c = 1, #COLUMNS do
		local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetWordWrap(false)
		row.cols[c] = text
	end

	local removeColumn = MINE_COLUMNS[5]
	row.remove = NR.CreateRemoveButton(row, REMOVE_SIZE)
	row.remove:SetPoint("CENTER", row, "LEFT", removeColumn.x + removeColumn.width / 2 - 12, 0)
	row.remove:SetScript("OnClick", OnRemoveClick)
	row.remove:SetScript("OnEnter", ShowRemoveTooltip)
	row.remove:SetScript("OnLeave", GameTooltip_Hide)
	row.remove:Hide()

	row:SetScript("OnEnter", ShowRowTooltip)
	row:SetScript("OnLeave", GameTooltip_Hide)
	return row
end

local function CreateScrollBar(parent)
	local bar = CreateFrame("Slider", nil, parent)
	bar:SetOrientation("VERTICAL")
	bar:SetSize(12, ROWS * ROW_HEIGHT)
	bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, LIST_TOP)

	local track = bar:CreateTexture(nil, "BACKGROUND")
	track:SetAllPoints()
	track:SetColorTexture(0, 0, 0, 0.35)

	bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
	bar:GetThumbTexture():SetSize(16, 24)
	bar:SetMinMaxValues(0, 0)
	bar:SetValueStep(1)
	if bar.SetObeyStepOnDrag then
		bar:SetObeyStepOnDrag(true)
	end
	bar:SetValue(0)
	bar:SetScript("OnValueChanged", function(_, value)
		local newOffset = math.floor(value + 0.5)
		if newOffset ~= offset then
			offset = newOffset
			Leaderboard:RenderRows()
		end
	end)
	return bar
end

local function CreateMainFrame()
	local ok, f = pcall(CreateFrame, "Frame", "NamesRankingFrame", UIParent, "BasicFrameTemplateWithInset")
	if not ok or not f then
		f = CreateFrame("Frame", "NamesRankingFrame", UIParent, "BackdropTemplate")
		f:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 8, right = 8, top = 8, bottom = 8 },
		})
		local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", -4, -4)
	end

	f:SetSize(WIDTH, HEIGHT)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()
	tinsert(UISpecialFrames, "NamesRankingFrame")

	local title = f.TitleText
	if not title then
		title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		title:SetPoint("TOP", f, "TOP", 0, -6)
	end
	title:SetText("Names Ranking")

	f.tabs = {}
	for i, def in ipairs(TABS) do
		local tab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		tab:SetSize(88, 22)
		tab:SetPoint("TOPLEFT", f, "TOPLEFT", 12 + (i - 1) * 92, -32)
		tab:SetText(def.label)
		tab.key = def.key
		tab:SetScript("OnClick", function()
			mode = def.key
			Leaderboard:Refresh(true)
		end)
		f.tabs[i] = tab
	end

	local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	search:SetSize(116, 20)
	search:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -33)
	search:SetAutoFocus(false)
	search:SetMaxLetters(24)
	local hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("LEFT", search, "LEFT", 2, 0)
	hint:SetText("Search")
	search:SetScript("OnTextChanged", function(self)
		hint:SetShown(self:GetText() == "")
		Leaderboard:Refresh(true)
	end)
	search:SetScript("OnEscapePressed", search.ClearFocus)
	search:SetScript("OnEnterPressed", search.ClearFocus)
	f.search = search

	f.headers = {}
	for c = 1, #MINE_COLUMNS do
		f.headers[c] = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	end
	local divider = f:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(1, 1, 1, 0.15)
	divider:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -79)
	divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, -79)
	divider:SetHeight(1)

	f.rows = {}
	for i = 1, ROWS do
		f.rows[i] = CreateRow(f, i)
	end
	f.scrollBar = CreateScrollBar(f)

	f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	f.empty:SetPoint("TOP", f, "TOP", 0, LIST_TOP - 40)
	f.empty:SetWidth(WIDTH - 60)

	f.credit = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	f.credit:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
	f.credit:SetText(CREDIT)

	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(_, delta)
		local _, maxOffset = f.scrollBar:GetMinMaxValues()
		f.scrollBar:SetValue(math.max(0, math.min(maxOffset, offset - delta * 3)))
	end)
	f:SetScript("OnShow", function() Leaderboard:Refresh(true) end)
	return f
end

local function PlaceColumn(text, parent, point, x, y, col)
	text:ClearAllPoints()
	text:SetPoint(point, parent, point, x, y)
	text:SetWidth(col.width)
	text:SetJustifyH(col.justify)
end

function Leaderboard:PlaceColumns()
	if frame.columnsMode == mode then return end
	frame.columnsMode = mode
	local columns = mode == "mine" and MINE_COLUMNS or COLUMNS
	for c, header in ipairs(frame.headers) do
		local col = columns[c]
		header:SetShown(col ~= nil)
		if col then
			PlaceColumn(header, frame, "TOPLEFT", col.x, -66, col)
			header:SetText(HEADERS[mode][c])
		end
	end
	for _, row in ipairs(frame.rows) do
		for c, text in ipairs(row.cols) do
			PlaceColumn(text, row, "LEFT", columns[c].x - 12, 0, columns[c])
		end
	end
end

function Leaderboard:RenderRows()
	for i, row in ipairs(frame.rows) do
		local item = items[offset + i]
		row.item = item
		if item then
			for c = 1, #COLUMNS do
				row.cols[c]:SetText(item[c] ~= nil and tostring(item[c]) or "")
			end
			row.remove:SetShown(mode == "mine")
			row:Show()
		else
			row:Hide()
		end
	end
end

function Leaderboard:Refresh(resetScroll)
	if not frame or not frame:IsShown() then return end
	local filter = strtrim(frame.search:GetText() or ""):lower()
	BuildItems(filter)

	local maxOffset = math.max(0, #items - ROWS)
	if resetScroll then offset = 0 end
	offset = math.min(offset, maxOffset)
	frame.scrollBar:SetMinMaxValues(0, maxOffset)
	frame.scrollBar:SetValue(offset)
	frame.scrollBar:SetShown(maxOffset > 0)

	self:PlaceColumns()
	for _, tab in ipairs(frame.tabs) do
		tab:SetEnabled(tab.key ~= mode)
	end

	if filter ~= "" then
		frame.empty:SetText("No names match your search.")
	elseif mode == "mine" then
		frame.empty:SetText("You haven't voted yet. Open /who and click 1, 2 or 3 next to a name.")
	else
		frame.empty:SetText("No votes yet. Open /who and vote for your favorite names!")
	end
	frame.empty:SetShown(#items == 0)

	self:RenderRows()
end

function Leaderboard:Toggle()
	frame = frame or CreateMainFrame()
	frame:SetShown(not frame:IsShown())
end

function Leaderboard:Init()
	NR:Listen("VOTES_CHANGED", function() Leaderboard:Refresh(false) end)
end
