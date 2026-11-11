local _, NR = ...

local Comm = {}
NR.Comm = Comm

local Compat = NR.Compat
local CHANNEL_NAME = "NamesRankingSync"
local SEP = "~"
local MAX_MESSAGE = 255
local TICK = 0.2
local BURST, REGEN_SECONDS = 6, 1.5
local HELLO_INTERVAL = 900
local LIST_REFRESH = 60
local LIST_HIDE = 5
local SWEEP_INTERVAL = 3
local LIVE_PEERS = 10
local NOT_FOUND_HIDE = 30
local REQUEST_COOLDOWN = 600
local REPLY_COOLDOWN = 300
local SNAPSHOT_TIMEOUT = 60
local MAX_SNAPSHOT_PARTS = 800
local MAX_QUEUE = 1000

local queue = {}
local tokens = BURST
local requested = {}
local replied = {}
local snapshots = {}
local peers = {}
local sweep = {}
local missed = {}
local listAsked = 0
local lastHello, helloPending = 0, false
local enabled = false
local myClassId

local function ClassIdOf(name)
	return Compat.GetClassId(NR.Votes:GetClass(name))
end

local function Enqueue(msg, chatType, target)
	if #queue >= MAX_QUEUE then
		table.remove(queue, 1)
	end
	queue[#queue + 1] = { msg = msg, chatType = chatType, target = target }
end

local function Flush()
	tokens = math.min(BURST, tokens + TICK / REGEN_SECONDS)
	while queue[1] and tokens >= 1 do
		if not Compat.CanSendAddonMessages() then return end
		local item = queue[1]
		local sent, throttled = Compat.SendAddonMessage(NR.PREFIX, item.msg, item.chatType, item.target)
		if throttled then
			tokens = 0
			return
		end
		table.remove(queue, 1)
		if sent then
			tokens = tokens - 1
		end
	end
end

local function Readable(text)
	return type(text) == "string" and not Compat.IsSecret(text)
end

local function AddPeer(name)
	if not Readable(name) then return end
	local key = NR.NormalizeName(name)
	if not key or key == NR.player or peers[key] then return end
	peers[key] = name
	missed[key] = nil
	sweep[#sweep + 1] = key
end

local function RemovePeer(name)
	if not Readable(name) then return end
	local key = NR.NormalizeName(name)
	if key then peers[key] = nil end
end

local function IsOurChannel(name)
	return Readable(name) and name:upper() == CHANNEL_NAME:upper()
end

local function BaseName(arg4, arg9)
	if Readable(arg9) and arg9 ~= "" then return arg9 end
	return Readable(arg4) and arg4:gsub("^%d+%.%s*", "") or nil
end

local function OnMemberList(text, _, _, arg4, _, _, _, _, arg9)
	if not enabled or not Readable(text) or not IsOurChannel(BaseName(arg4, arg9)) then return end
	for entry in text:gmatch("[^,]+") do
		AddPeer((entry:gsub("^%s*[%*@%+]*", ""):gsub("%s+$", "")))
	end
end

local function NotFoundPattern()
	if not ERR_CHAT_PLAYER_NOT_FOUND_S then return end
	local escaped = ERR_CHAT_PLAYER_NOT_FOUND_S:gsub("[%^%$%(%)%.%[%]%*%+%-%?%%]", "%%%0")
	return "^" .. escaped:gsub("%%%%s", "(.+)") .. "$"
end

local notFoundPattern

local function NotFoundPeer(text)
	if not notFoundPattern or not Readable(text) then return end
	local name = text:match(notFoundPattern)
	local key = name and NR.NormalizeName(name)
	if key and (peers[key] or (missed[key] and GetServerTime() - missed[key] < NOT_FOUND_HIDE)) then
		return key
	end
end

local function HideNotFound(_, _, text)
	return NotFoundPeer(text) ~= nil
end

local function HideMemberList(_, _, _, _, _, arg4, _, _, _, _, arg9)
	return GetServerTime() - listAsked < LIST_HIDE and IsOurChannel(BaseName(arg4, arg9))
end

function Comm:GetChannelId()
	local id = GetChannelName(CHANNEL_NAME)
	if id and id > 0 then
		return id
	end
end

local function HideChannel()
	if not ChatFrame_RemoveChannel then return end
	for i = 1, NUM_CHAT_WINDOWS or 10 do
		local chatFrame = _G["ChatFrame" .. i]
		if chatFrame then
			pcall(ChatFrame_RemoveChannel, chatFrame, CHANNEL_NAME)
		end
	end
end

function Comm:JoinChannel()
	if not self:GetChannelId() and JoinTemporaryChannel then
		pcall(JoinTemporaryChannel, CHANNEL_NAME)
		C_Timer.After(2, HideChannel)
	end
end

function Comm:AskMemberList()
	if not enabled or not Compat.CanSendAddonMessages() then return end
	if not self:GetChannelId() then
		self:JoinChannel()
		return
	end
	listAsked = GetServerTime()
	ListChannelByName(CHANNEL_NAME)
end

local function Broadcast(msg)
	if not enabled then return end
	if IsInGuild() then
		Enqueue(msg, "GUILD")
	end
	local group = Compat.GetGroupChannel()
	if group then
		Enqueue(msg, group)
	end
end

local function HelloMessage()
	local count, hash = NR.Votes:GetSummary(NR.player)
	return table.concat({ "H", NR.PROTOCOL, count, hash, myClassId }, SEP)
end

function Comm:SendHello()
	lastHello = GetServerTime()
	Broadcast(HelloMessage())
end

local function ScheduleHello()
	if helloPending or GetServerTime() - lastHello < 60 then return end
	helloPending = true
	C_Timer.After(2 + math.random(0, 6), function()
		helloPending = false
		if enabled then Comm:SendHello() end
	end)
end

function Comm:Sweep()
	if not enabled then return end
	if #sweep == 0 then
		for key in pairs(peers) do
			sweep[#sweep + 1] = key
		end
	end
	local key
	repeat
		key = table.remove(sweep)
	until not key or peers[key]
	if key then
		Enqueue(HelloMessage(), "WHISPER", peers[key])
	end
end

function Comm:BroadcastVote(target, value, ts)
	if not enabled then return end
	local msg = table.concat({ "V", NR.PROTOCOL, target, value, ts, ClassIdOf(target) }, SEP)
	Broadcast(msg)

	local names = {}
	for _, name in pairs(peers) do
		names[#names + 1] = name
	end
	for i = 1, math.min(LIVE_PEERS, #names) do
		local pick = math.random(i, #names)
		names[i], names[pick] = names[pick], names[i]
		Enqueue(msg, "WHISPER", names[i])
	end
end

local function SendSnapshot(target)
	local entries = {}
	for name, vote in pairs(NR.Votes:GetVotesBy(NR.player) or {}) do
		local text = name .. "," .. vote[1] .. "," .. vote[2]
		local classId = vote[1] > 0 and ClassIdOf(name)
		if classId then
			text = text .. "," .. classId
		end
		entries[#entries + 1] = text
	end

	local budget = MAX_MESSAGE - 32
	local chunks, current, size = {}, {}, 0
	for _, entry in ipairs(entries) do
		if size + #entry + 1 > budget and #current > 0 then
			chunks[#chunks + 1] = table.concat(current, ";")
			current, size = {}, 0
		end
		current[#current + 1] = entry
		size = size + #entry + 1
	end
	chunks[#chunks + 1] = table.concat(current, ";")

	if #queue + #chunks > MAX_QUEUE then return end

	local snap = GetServerTime()
	for i, chunk in ipairs(chunks) do
		Enqueue(table.concat({ "B", NR.PROTOCOL, i, #chunks, snap, chunk }, SEP), "WHISPER", target)
	end
end

local handlers = {}

function handlers.H(sender, replyTo, count, hash, classId)
	NR.Votes:CacheClass(sender, Compat.GetClassFile(classId))
	count = tonumber(count)
	if not count or not hash then return end
	local myCount, myHash = NR.Votes:GetSummary(sender)
	if myCount == count and myHash == hash then return end
	local now = GetServerTime()
	if requested[sender] and now - requested[sender] < REQUEST_COOLDOWN then return end
	requested[sender] = now
	Enqueue(table.concat({ "R", NR.PROTOCOL }, SEP), "WHISPER", replyTo)
end

function handlers.V(sender, _, target, value, ts, classId)
	NR.Votes:ApplyRemote(sender, target, value, ts, classId)
end

function handlers.R(sender, replyTo)
	local now = GetServerTime()
	if replied[sender] and now - replied[sender] < REPLY_COOLDOWN then return end
	replied[sender] = now
	SendSnapshot(replyTo)
end

function handlers.B(sender, _, part, total, snap, payload)
	part, total, snap = tonumber(part), tonumber(total), tonumber(snap)
	if not part or not total or not snap or part < 1 or part > total or total > MAX_SNAPSHOT_PARTS then return end

	local now = GetServerTime()
	local s = snapshots[sender]
	if not s or s.snap ~= snap or now - s.lastPart > SNAPSHOT_TIMEOUT then
		s = { snap = snap, total = total, received = 0, parts = {} }
		snapshots[sender] = s
	end
	s.lastPart = now
	if s.parts[part] then return end
	s.parts[part] = payload or ""
	s.received = s.received + 1
	if s.received < s.total then return end

	snapshots[sender] = nil
	local entries = {}
	for i = 1, s.total do
		for entry in s.parts[i]:gmatch("[^;]+") do
			local name, value, ts, classId = strsplit(",", entry)
			entries[#entries + 1] = { name, value, ts, classId }
		end
	end
	NR.Votes:ApplySnapshot(sender, entries, snap)
end

function Comm:OnMessage(prefix, text, _, sender)
	if Compat.IsSecret(prefix) or Compat.IsSecret(text) or Compat.IsSecret(sender) then return end
	if prefix ~= NR.PREFIX or not enabled then return end
	local replyTo = sender
	sender = NR.NormalizeName(sender)
	if not sender or sender == NR.player then return end

	local kind, version, a, b, c, d = strsplit(SEP, text)
	if tonumber(version) ~= NR.PROTOCOL then return end
	local handler = handlers[kind]
	if not handler then return end

	AddPeer(replyTo)
	NR.Votes:Touch(sender)
	handler(sender, replyTo, a, b, c, d)
end

function Comm:Init()
	Compat.RegisterPrefix(NR.PREFIX)
	myClassId = Compat.GetClassId(select(2, UnitClass("player")))
	notFoundPattern = NotFoundPattern()
	Compat.AddChatFilter("CHAT_MSG_SYSTEM", HideNotFound)
	Compat.AddChatFilter("CHAT_MSG_CHANNEL_LIST", HideMemberList)

	NR:On("CHAT_MSG_ADDON", function(...) Comm:OnMessage(...) end)
	NR:On("CHAT_MSG_CHANNEL_LIST", OnMemberList)
	NR:On("CHAT_MSG_CHANNEL_JOIN", function(_, sender, ...)
		if enabled and IsOurChannel((select(7, ...))) then AddPeer(sender) end
	end)
	NR:On("CHAT_MSG_CHANNEL_LEAVE", function(_, sender, ...)
		if IsOurChannel((select(7, ...))) then RemovePeer(sender) end
	end)
	NR:On("CHAT_MSG_SYSTEM", function(text)
		local key = NotFoundPeer(text)
		if key then
			peers[key] = nil
			missed[key] = GetServerTime()
		end
	end)
	NR:On("GROUP_ROSTER_UPDATE", function()
		if Compat.GetGroupChannel() then ScheduleHello() end
	end)

	C_Timer.NewTicker(TICK, Flush)
	C_Timer.NewTicker(SWEEP_INTERVAL, function() Comm:Sweep() end)
	C_Timer.NewTicker(LIST_REFRESH, function() Comm:AskMemberList() end)
	C_Timer.NewTicker(HELLO_INTERVAL, function()
		if enabled then Comm:SendHello() end
	end)

	if Compat.IsTrialAccount() then
		NR:Print("trial accounts can't send addon messages, so your votes stay on this computer.")
	end

	if NR.db.settings.sync then
		C_Timer.After(10 + math.random(0, 10), function()
			if NR.db.settings.sync then Comm:Enable() end
		end)
	end
end

function Comm:Enable()
	enabled = true
	self:JoinChannel()
	C_Timer.After(3 + math.random(0, 15), function()
		if enabled then
			Comm:AskMemberList()
			Comm:SendHello()
		end
	end)
end

function Comm:Disable()
	enabled = false
	wipe(queue)
	wipe(peers)
	wipe(sweep)
	if self:GetChannelId() and LeaveChannelByName then
		LeaveChannelByName(CHANNEL_NAME)
	end
end

