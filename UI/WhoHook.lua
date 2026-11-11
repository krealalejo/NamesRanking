local _, NR = ...

local WhoHook = {}
NR.WhoHook = WhoHook

local BUTTON_SIZE = 26
local BUTTON_GAP = 2

local holders = {}

local function IsFrame(value)
	return type(value) == "table" and type(value.GetObjectType) == "function" and (pcall(value.GetObjectType, value))
end

local function FindRightEdgeButton(row, holder)
	local rowRight = row:GetRight()
	if not rowRight then return end
	for _, child in ipairs({ row:GetChildren() }) do
		if child ~= holder and child:GetObjectType() == "Button" and child:IsShown() then
			local right = child:GetRight()
			if right and rowRight - right < 40 then
				return child
			end
		end
	end
end

local function AnchorHolder(holder)
	if holder.anchored then return end
	local row = holder:GetParent()
	if not row:GetRight() then return end
	holder:ClearAllPoints()
	local button = row.InviteButton or FindRightEdgeButton(row, holder)
	if button then
		holder:SetPoint("RIGHT", button, "LEFT", -6, 0)
	else
		holder:SetPoint("RIGHT", row, "RIGHT", -52, 0)
	end
	holder.anchored = true
end

local function UpdateHolder(holder)
	AnchorHolder(holder)
	NR.UpdateVoteButtons(holder)
end

local function CreateHolder(row)
	local holder = NR.CreateVoteButtons(row, BUTTON_SIZE, BUTTON_GAP, true)
	holder:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	holders[row] = holder
	return holder
end

local function StripColors(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function ResolveName(row, elementData)
	if elementData == false then return nil end
	if elementData == nil and row.GetElementData then
		elementData = row:GetElementData()
	end

	local info
	if type(elementData) == "table" then
		if type(elementData.info) == "table" then
			info = elementData.info
		elseif type(elementData.whoInfo) == "table" then
			info = elementData.whoInfo
		elseif type(elementData.fullName) == "string" then
			info = elementData
		end
	end
	if not info then
		local index = (type(elementData) == "number" and elementData)
			or (type(elementData) == "table" and elementData.index)
			or row.index or row.whoIndex
		if type(index) == "number" then
			info = NR.Compat.GetWhoInfo(index)
		end
	end

	local name = info and (info.fullName or info.name)
	if type(name) ~= "string" or name == "" then
		local label = row.Name or row.name
		if type(label) == "table" and label.GetText then
			name = label:GetText()
		end
	end
	if type(name) ~= "string" or NR.Compat.IsSecret(name) then return nil end
	return NR.NormalizeName(StripColors(name)), info
end

local function OnRowInitialized(row, elementData)
	if not IsFrame(row) then return end
	local name, info = ResolveName(row, elementData)
	local holder = holders[row] or CreateHolder(row)
	holder.name = name
	if name and info then
		NR.Votes:CacheClass(name, info.filename)
	end
	UpdateHolder(holder)
end

local function UpdateLegacyRows()
	for i = 1, WHOS_TO_DISPLAY or 17 do
		local row = _G["WhoFrameButton" .. i]
		if row then
			OnRowInitialized(row, row:IsShown() and row.whoIndex or false)
		end
	end
end

local function IsScrollBox(value)
	return IsFrame(value) and type(value.GetFrames) == "function" and type(value.RegisterCallback) == "function"
end

local function FindScrollBoxIn(frame, path)
	if IsScrollBox(frame.ScrollBox) then
		return frame.ScrollBox, path .. ".ScrollBox"
	end
	for key, child in pairs(frame) do
		if IsScrollBox(child) then
			return child, path .. "." .. tostring(key)
		end
	end
	for key, child in pairs(frame) do
		if type(key) == "string" and key ~= "parent" and IsFrame(child) then
			for key2, grandchild in pairs(child) do
				if IsScrollBox(grandchild) then
					return grandchild, path .. "." .. key .. "." .. tostring(key2)
				end
			end
		end
	end
end

local function FindScrollBox()
	if IsFrame(WhoFrame) then
		return FindScrollBoxIn(WhoFrame, "WhoFrame")
	end
	for name, value in pairs(_G) do
		if type(name) == "string" and name:find("Who") and IsFrame(value) then
			local scrollBox, where = FindScrollBoxIn(value, name)
			if scrollBox then
				return scrollBox, where
			end
		end
	end
end

function WhoHook:ScanRows()
	if not self.scrollBox then
		if self.mode == "legacy" then UpdateLegacyRows() end
		return
	end
	local ok, frames = pcall(self.scrollBox.GetFrames, self.scrollBox)
	if not ok or type(frames) ~= "table" then return end
	for _, row in ipairs(frames) do
		OnRowInitialized(row)
	end
end

local function OnWhoListUpdate()
	for i = 1, NR.Compat.GetNumWhoResults() do
		local info = NR.Compat.GetWhoInfo(i)
		local name = info and NR.NormalizeName(info.fullName)
		if name then
			NR.Votes:CacheClass(name, info.filename)
		end
	end
	C_Timer.After(0.2, function()
		WhoHook:TryAttach()
		WhoHook:ScanRows()
	end)
end

function WhoHook:TryAttach()
	if self.attached then return end

	local scrollBox = FindScrollBox()
	if scrollBox and ScrollUtil and ScrollUtil.AddInitializedFrameCallback then
		self.scrollBox, self.mode = scrollBox, "scrollbox"
		ScrollUtil.AddInitializedFrameCallback(scrollBox, function(a, b, c)
			if a == WhoHook then
				OnRowInitialized(b, c)
			else
				OnRowInitialized(a, b)
			end
		end, WhoHook, true)
		local window = scrollBox:GetParent()
		if window and window.HookScript then
			window:HookScript("OnShow", function() C_Timer.After(0.2, function() WhoHook:ScanRows() end) end)
		end
	elseif WhoList_Update then
		self.mode = "legacy"
		hooksecurefunc("WhoList_Update", UpdateLegacyRows)
	else
		return
	end
	self.attached = true
end

function WhoHook:Refresh()
	for row, holder in pairs(holders) do
		if row:IsShown() then
			UpdateHolder(holder)
		end
	end
end

function WhoHook:Init()
	self:TryAttach()
	NR:On("ADDON_LOADED", function() WhoHook:TryAttach() end)
	NR:On("WHO_LIST_UPDATE", OnWhoListUpdate)
	NR:Listen("VOTES_CHANGED", function() WhoHook:Refresh() end)
end
