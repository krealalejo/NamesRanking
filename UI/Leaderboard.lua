local _, NR = ...

local Leaderboard = {}
NR.Leaderboard = Leaderboard

local WIDTH, HEIGHT = 560, 460
local ROWS = 14
local ROW_HEIGHT, PODIUM_HEIGHT, PODIUM_SIZE = 24, 30, 3
local LIST_TOP = -76
local LIST_HEIGHT = PODIUM_SIZE * PODIUM_HEIGHT + (ROWS - PODIUM_SIZE) * ROW_HEIGHT
local HEADER_TOP = -58
local ROW_LEFT = 12
local SLOT_RIGHT = 416
local BUTTON_SIZE, BUTTON_GAP = 18, 2
local COLUMNS = {
	{ x = 16, width = 36, justify = "LEFT" },
	{ x = 54, width = 270, justify = "LEFT" },
	{ x = 330, width = 86, justify = "RIGHT" },
	{ x = 420, width = 52, justify = "RIGHT" },
	{ x = 476, width = 40, justify = "RIGHT" },
}
local HEADERS = {
	top = { "#", "Name", "", "Points", "Votes" },
	mine = { "#", "Name", "Your vote", "Points", "" },
	recent = { "When", "Name", "", "Vote", "" },
}
local TABS = {
	{ key = "top", label = "Top" },
	{ key = "mine", label = "My votes" },
	{ key = "recent", label = "Recent" },
}
local RANK_COLORS = {
	{ 1, 0.82, 0 },
	{ 0.84, 0.86, 0.89 },
	{ 0.83, 0.54, 0.31 },
}
local MUTED = { 0.6, 0.6, 0.6 }
local STAR = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t"
local CREDIT = "with |TInterface\\AddOns\\NamesRanking\\Media\\Heart.tga:12:12|t by kames"

local function Font(name, fallback)
	return _G[name] or _G[fallback]
end

local FONTS = {
	rank = Font("GameFontHighlightSmall", "GameFontHighlight"),
	text = Font("GameFontHighlight", "GameFontHighlightSmall"),
	big = Font("GameFontHighlightMedium", "GameFontHighlight"),
	bigRank = Font("GameFontNormalLarge", "GameFontNormal"),
	small = Font("GameFontHighlightSmall", "GameFontHighlight"),
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
				items[#items + 1] = { name = entry.name, rank = entry.rank, entry.rank, NR.ColoredName(entry.name), "", entry.points, entry.votes }
			end
		end
	elseif mode == "mine" then
		for name, vote in pairs(NR.Votes:GetVotesBy(NR.player) or {}) do
			if vote[1] > 0 and Matches(name, filter) then
				local entry = NR.Ranking:GetEntry(name)
				local points = entry and entry.points or 0
				local rank = entry and entry.rank
				items[#items + 1] = { name = name, vote = vote[1], points = points, rank = rank, rank or "-", NR.ColoredName(name), "", points, "" }
			end
		end
		table.sort(items, function(a, b)
			if a.vote ~= b.vote then return a.vote > b.vote end
			return a.points > b.points
		end)
	else
		for _, vote in ipairs(NR.Votes:GetRecent(200)) do
			if Matches(vote.target, filter) then
				items[#items + 1] = { name = vote.target, NR.Ago(vote.ts), NR.ColoredName(vote.target), "", vote.value, "" }
			end
		end
	end
end

local function IsPodium(item)
	return mode == "top" and item.rank ~= nil and item.rank <= PODIUM_SIZE
end

local function RowHeight(item)
	return IsPodium(item) and PODIUM_HEIGHT or ROW_HEIGHT
end

local function MaxOffset()
	local height, fit = 0, 0
	for i = #items, 1, -1 do
		height = height + RowHeight(items[i])
		if height > LIST_HEIGHT then break end
		fit = fit + 1
	end
	return math.max(0, #items - fit)
end

local function Summary()
	local voters = 0
	for voter, list in pairs(NR.Votes:GetAll()) do
		if not NR:IsBlocked(voter) then
			for _, entry in pairs(list) do
				if entry[1] > 0 then
					voters = voters + 1
					break
				end
			end
		end
	end
	return ("%s · %s"):format(NR.Plural(#NR.Ranking:GetList(), "name"), NR.Plural(voters, "voter"))
end

local function ShowRowTooltip(row)
	local name = row.item and row.item.name
	if not name then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(NR.ColoredName(name))
	local entry = NR.Ranking:GetEntry(name)
	if entry then
		GameTooltip:AddLine(("Rank #%d - %s"):format(entry.rank, NR.Plural(entry.points, "point")), 1, 1, 1)
		local votes = NR.Plural(entry.votes, "vote")
		if entry.threes > 0 then
			votes = ("%s, %d worth 3 points"):format(votes, entry.threes)
		end
		GameTooltip:AddLine(votes, 0.8, 0.8, 0.8)
		GameTooltip:AddLine(("First voted by %s, %s"):format(NR.ColoredName(entry.firstVoter), NR.Ago(entry.firstTs)), 0.8, 0.8, 0.8)
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

local function UpdateSlot(row)
	local item = row.item
	local votable = item ~= nil and mode ~= "recent" and item.name ~= NR.player
	local mine = votable and NR.Votes:GetMyVote(item.name) or 0
	local hovered = row.hovered
	row.badge:SetShown(mine > 0)
	if mine > 0 then
		row.badge:SetText(STAR .. mine)
	end
	row.remove:SetShown(hovered and mine > 0)
	if votable and hovered and mine == 0 then
		row.vote.name = item.name
		NR.UpdateVoteButtons(row.vote)
	else
		row.vote.name = nil
		row.vote:Hide()
	end
end

local function SetHovered(row, hovered)
	row.hovered = hovered
	row.highlight:SetShown(hovered)
	UpdateSlot(row)
end

local function CheckHover(row)
	if not row:IsMouseOver() then
		SetHovered(row, false)
	end
end

local function StyleRow(row, item)
	local podium = IsPodium(item)
	local cols = row.cols
	cols[1]:SetFontObject(podium and FONTS.bigRank or FONTS.rank)
	cols[2]:SetFontObject(podium and FONTS.big or FONTS.text)
	cols[4]:SetFontObject(podium and FONTS.big or FONTS.text)
	cols[5]:SetFontObject(FONTS.small)
	local rankColor = mode ~= "recent" and item.rank and RANK_COLORS[item.rank] or MUTED
	cols[1]:SetTextColor(unpack(rankColor))
	cols[2]:SetTextColor(1, 1, 1)
	cols[4]:SetTextColor(1, 1, 1)
	cols[5]:SetTextColor(unpack(MUTED))
end

local function CreateRow(parent, i)
	local row = CreateFrame("Button", nil, parent)
	row:SetSize(WIDTH - 48, ROW_HEIGHT)
	if i % 2 == 0 then
		local stripe = row:CreateTexture(nil, "BACKGROUND")
		stripe:SetAllPoints()
		stripe:SetColorTexture(1, 1, 1, 0.04)
	end
	row.highlight = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.highlight:SetAllPoints()
	row.highlight:SetColorTexture(1, 0.82, 0, 0.10)
	row.highlight:Hide()

	row.cols = {}
	for c, col in ipairs(COLUMNS) do
		local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetWordWrap(false)
		text:SetPoint("LEFT", row, "LEFT", col.x - ROW_LEFT, 0)
		text:SetWidth(col.width)
		text:SetJustifyH(col.justify)
		row.cols[c] = text
	end

	row.vote = NR.CreateVoteButtons(row, BUTTON_SIZE, BUTTON_GAP, false)
	row.vote:SetPoint("RIGHT", row, "LEFT", SLOT_RIGHT - ROW_LEFT, 0)
	row.vote:Hide()

	row.remove = NR.CreateRemoveButton(row, BUTTON_SIZE)
	row.remove:SetPoint("RIGHT", row, "LEFT", SLOT_RIGHT - ROW_LEFT, 0)
	row.remove:SetScript("OnClick", OnRemoveClick)
	row.remove:SetScript("OnEnter", ShowRemoveTooltip)
	row.remove:SetScript("OnLeave", GameTooltip_Hide)
	row.remove:Hide()

	row.badge = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.badge:SetPoint("RIGHT", row.remove, "LEFT", -4, 0)
	row.badge:Hide()

	local children = { row.remove }
	for v = 1, NR.MAX_VOTE do
		children[#children + 1] = row.vote.buttons[v]
	end
	for _, child in ipairs(children) do
		child:HookScript("OnEnter", function() SetHovered(row, true) end)
		child:HookScript("OnLeave", function() CheckHover(row) end)
	end

	row:SetScript("OnEnter", function(self)
		SetHovered(self, true)
		ShowRowTooltip(self)
	end)
	row:SetScript("OnLeave", function(self)
		GameTooltip_Hide()
		CheckHover(self)
	end)
	return row
end

local function CreateScrollBar(parent)
	local bar = CreateFrame("Slider", nil, parent)
	bar:SetOrientation("VERTICAL")
	bar:SetSize(12, LIST_HEIGHT)
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

local function CreateTabs(f)
	f.tabs = {}
	for i, def in ipairs(TABS) do
		local ok, tab = pcall(CreateFrame, "Button", "NamesRankingFrameTab" .. i, f, "PanelTabButtonTemplate")
		if ok and tab then
			f.usesPanelTabs = true
		else
			tab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
			tab:SetSize(88, 22)
		end
		tab:SetID(i)
		tab:SetText(def.label)
		if f.usesPanelTabs and PanelTemplates_TabResize then
			PanelTemplates_TabResize(tab, 0)
		end
		if i == 1 then
			tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 8, 2)
		else
			tab:SetPoint("LEFT", f.tabs[i - 1], "RIGHT", f.usesPanelTabs and -14 or 4, 0)
		end
		tab:SetScript("OnClick", function()
			mode = def.key
			Leaderboard:Refresh(true)
		end)
		f.tabs[i] = tab
	end
	if f.usesPanelTabs and PanelTemplates_SetNumTabs then
		f.Tabs = f.tabs
		PanelTemplates_SetNumTabs(f, #f.tabs)
	end
end

local function SelectTab()
	for i, def in ipairs(TABS) do
		if def.key == mode then
			if frame.usesPanelTabs and PanelTemplates_SetTab then
				PanelTemplates_SetTab(frame, i)
			else
				for j, tab in ipairs(frame.tabs) do
					tab:SetEnabled(j ~= i)
				end
			end
			return
		end
	end
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

	CreateTabs(f)

	local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	search:SetSize(140, 20)
	search:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -30)
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
	for c, col in ipairs(COLUMNS) do
		local header = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		header:SetPoint("TOPLEFT", f, "TOPLEFT", col.x, HEADER_TOP)
		header:SetWidth(col.width)
		header:SetJustifyH(col.justify)
		f.headers[c] = header
	end
	local divider = f:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(1, 1, 1, 0.15)
	divider:SetPoint("TOPLEFT", f, "TOPLEFT", ROW_LEFT, LIST_TOP + 5)
	divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, LIST_TOP + 5)
	divider:SetHeight(1)

	f.rows = {}
	for i = 1, ROWS do
		f.rows[i] = CreateRow(f, i)
	end
	f.scrollBar = CreateScrollBar(f)

	f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	f.empty:SetPoint("TOP", f, "TOP", 0, LIST_TOP - 40)
	f.empty:SetWidth(WIDTH - 60)

	local footer = f:CreateTexture(nil, "ARTWORK")
	footer:SetColorTexture(1, 1, 1, 0.08)
	footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", ROW_LEFT, 30)
	footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 30)
	footer:SetHeight(1)

	f.summary = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	f.summary:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 12)

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

function Leaderboard:RenderRows()
	local y, index = 0, offset + 1
	for _, row in ipairs(frame.rows) do
		local item = items[index]
		local height = item and RowHeight(item)
		if item and y + height <= LIST_HEIGHT then
			row:SetHeight(height)
			row:SetPoint("TOPLEFT", frame, "TOPLEFT", ROW_LEFT, LIST_TOP - y)
			row.item = item
			StyleRow(row, item)
			for c = 1, #COLUMNS do
				row.cols[c]:SetText(item[c] ~= nil and tostring(item[c]) or "")
			end
			row:Show()
			row.hovered = row:IsMouseOver()
			row.highlight:SetShown(row.hovered)
			UpdateSlot(row)
			y = y + height
			index = index + 1
		else
			row.item = nil
			row.hovered = false
			row.highlight:Hide()
			row:Hide()
		end
	end
end

function Leaderboard:Refresh(resetScroll)
	if not frame or not frame:IsShown() then return end
	local filter = strtrim(frame.search:GetText() or ""):lower()
	BuildItems(filter)

	local maxOffset = MaxOffset()
	if resetScroll then offset = 0 end
	offset = math.min(offset, maxOffset)
	frame.scrollBar:SetMinMaxValues(0, maxOffset)
	frame.scrollBar:SetValue(offset)
	frame.scrollBar:SetShown(maxOffset > 0)

	for c, header in ipairs(frame.headers) do
		header:SetText(HEADERS[mode][c])
	end
	SelectTab()

	if filter ~= "" then
		frame.empty:SetText("No names match your search.")
	elseif mode == "mine" then
		frame.empty:SetText("You haven't voted yet. Hover a name in Top, or open /who, and click 1, 2 or 3.")
	else
		frame.empty:SetText("No votes yet. Open /who and vote for your favorite names!")
	end
	frame.empty:SetShown(#items == 0)
	frame.summary:SetText(Summary())

	self:RenderRows()
end

function Leaderboard:Toggle()
	frame = frame or CreateMainFrame()
	frame:SetShown(not frame:IsShown())
end

function Leaderboard:Init()
	NR:Listen("VOTES_CHANGED", function() Leaderboard:Refresh(false) end)
	NR:Listen("CLASSES_CHANGED", function() Leaderboard:Refresh(false) end)
end
