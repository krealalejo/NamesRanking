local _, NR = ...

local Votes = {}
NR.Votes = Votes

local MAX_VOTES_PER_VOTER = 2000
local MAX_STORED_PER_VOTER = 2500
local LIVE_VOTES_PER_HOUR = 60
local MAX_CLOCK_SKEW = 300
local PRUNE_AFTER = 90 * 24 * 3600

local data
local liveRate = {}

local function HasRoom(list, oldValue, value)
	if not list or value == 0 or oldValue > 0 then return true end
	local active = 0
	for _, entry in pairs(list) do
		if entry[1] > 0 then active = active + 1 end
	end
	return active < MAX_VOTES_PER_VOTER
end

local function TrimRemoved(list)
	local removed, total = {}, 0
	for target, entry in pairs(list) do
		total = total + 1
		if entry[1] == 0 then removed[#removed + 1] = target end
	end
	local excess = total - MAX_STORED_PER_VOTER
	if excess <= 0 then return end
	table.sort(removed, function(a, b) return list[a][2] < list[b][2] end)
	for i = 1, math.min(excess, #removed) do
		list[removed[i]] = nil
	end
end

function Votes:Init()
	local region = NR.Compat.GetRegion()
	NR.db.regions[region] = NR.db.regions[region] or {}
	data = NR.db.regions[region]
	data.votes = data.votes or {}
	data.lastSeen = data.lastSeen or {}
	data.classCache = data.classCache or {}
	data.lastSeen[NR.player] = GetServerTime()
	self:Prune()
end

function Votes:Prune()
	local now = GetServerTime()
	for voter in pairs(data.votes) do
		if not data.lastSeen[voter] then
			data.lastSeen[voter] = now
		end
	end
	for voter, seen in pairs(data.lastSeen) do
		if voter ~= NR.player and seen < now - PRUNE_AFTER then
			data.lastSeen[voter] = nil
			data.votes[voter] = nil
		end
	end
end

function Votes:GetAll()
	return data.votes
end

function Votes:GetVotesBy(voter)
	return data.votes[voter]
end

function Votes:GetMyVote(target)
	local mine = data.votes[NR.player]
	local entry = mine and mine[target]
	return entry and entry[1] or 0
end

function Votes:Touch(voter)
	data.lastSeen[voter] = GetServerTime()
end

function Votes:CacheClass(name, classFile)
	if classFile and classFile ~= "" then
		data.classCache[name] = classFile
	end
end

function Votes:GetClass(name)
	return data and data.classCache[name]
end

local function IsValid(voter, target, value, ts)
	if not voter or not target or voter == target then return false end
	if not value or value < 0 or value > NR.MAX_VOTE or value ~= math.floor(value) then return false end
	if not ts or ts <= 0 or ts > GetServerTime() + MAX_CLOCK_SKEW then return false end
	return true
end

local function Store(voter, target, value, ts)
	local list = data.votes[voter]
	if not list then
		list = {}
		data.votes[voter] = list
	end
	list[target] = { value, ts }
	TrimRemoved(list)
	NR.Ranking:Invalidate()
	NR:Fire("VOTES_CHANGED")
end

function Votes:CastLocal(target, value)
	target = NR.NormalizeName(target)
	if not target then
		NR:Print("invalid name.")
		return false
	end
	if target == NR.player then
		NR:Print("you can't vote for yourself.")
		return false
	end
	local mine = data.votes[NR.player]
	local existing = mine and mine[target]
	local current = existing and existing[1] or 0
	if current == value then
		return false
	end
	if current > 0 and value > 0 then
		NR:Print(("you already voted for %s. Remove your vote first."):format(target))
		return false
	end
	if not HasRoom(mine, current, value) then
		NR:Print(("you've reached the limit of %d votes."):format(MAX_VOTES_PER_VOTER))
		return false
	end

	local ts = GetServerTime()
	if existing and existing[2] >= ts then
		ts = existing[2] + 1
	end
	Store(NR.player, target, value, ts)
	NR.Comm:BroadcastVote(target, value, ts)

	PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
	return true
end

function Votes:ApplyRemote(voter, target, value, ts)
	target, value, ts = NR.NormalizeName(target), tonumber(value), tonumber(ts)
	if not IsValid(voter, target, value, ts) then return false end

	local list = data.votes[voter]
	local existing = list and list[target]
	if existing and existing[2] >= ts then return false end
	if not HasRoom(list, existing and existing[1] or 0, value) then return false end

	local now = GetServerTime()
	local times = liveRate[voter] or {}
	liveRate[voter] = times
	while times[1] and times[1] < now - 3600 do
		table.remove(times, 1)
	end
	if #times >= LIVE_VOTES_PER_HOUR then return false end
	times[#times + 1] = now

	Store(voter, target, value, ts)
	return true
end

function Votes:ApplySnapshot(voter, entries, snap)
	snap = tonumber(snap)
	if not snap or snap > GetServerTime() + MAX_CLOCK_SKEW then return end

	local incoming, stored, active = {}, 0, 0
	for _, entry in ipairs(entries) do
		local target, value, ts = NR.NormalizeName(entry[1]), tonumber(entry[2]), tonumber(entry[3])
		if stored < MAX_STORED_PER_VOTER and IsValid(voter, target, value, ts) and not incoming[target]
			and (value == 0 or active < MAX_VOTES_PER_VOTER) then
			incoming[target] = { value, ts }
			stored = stored + 1
			if value > 0 then active = active + 1 end
		end
	end

	local list = data.votes[voter] or {}
	for target, entry in pairs(list) do
		if not incoming[target] and entry[2] <= snap then
			list[target] = nil
		end
	end
	for target, entry in pairs(incoming) do
		local current = list[target]
		if not current or current[2] < entry[2] then
			list[target] = entry
		end
	end
	TrimRemoved(list)
	data.votes[voter] = next(list) and list or nil

	NR.Ranking:Invalidate()
	NR:Fire("VOTES_CHANGED")
end

function Votes:GetSummary(voter)
	local list = data.votes[voter]
	if not list then return 0, "0" end
	local targets = {}
	for target in pairs(list) do
		targets[#targets + 1] = target
	end
	table.sort(targets)
	local hash = 5381
	for _, target in ipairs(targets) do
		local entry = list[target]
		local s = target .. "," .. entry[1] .. "," .. entry[2] .. ";"
		for i = 1, #s do
			hash = (hash * 33 + s:byte(i)) % 4294967296
		end
	end
	return #targets, string.format("%08x", hash)
end

function Votes:GetRecent(limit)
	local recent = {}
	for voter, list in pairs(data.votes) do
		if not NR:IsBlocked(voter) then
			for target, entry in pairs(list) do
				if entry[1] > 0 then
					recent[#recent + 1] = { voter = voter, target = target, value = entry[1], ts = entry[2] }
				end
			end
		end
	end
	table.sort(recent, function(a, b) return a.ts > b.ts end)
	for i = #recent, limit + 1, -1 do
		recent[i] = nil
	end
	return recent
end
