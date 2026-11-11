local _, NR = ...

local Classes = {}
NR.Classes = Classes

local Compat = NR.Compat
local GUILD_SCAN_INTERVAL = 30
local CHAT_EVENTS = {
	"CHAT_MSG_SAY",
	"CHAT_MSG_YELL",
	"CHAT_MSG_EMOTE",
	"CHAT_MSG_WHISPER",
	"CHAT_MSG_CHANNEL",
	"CHAT_MSG_GUILD",
	"CHAT_MSG_OFFICER",
	"CHAT_MSG_PARTY",
	"CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID",
	"CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_INSTANCE_CHAT",
	"CHAT_MSG_INSTANCE_CHAT_LEADER",
}

local lastGuildScan = 0

local function Readable(value)
	return type(value) == "string" and value ~= "" and not Compat.IsSecret(value)
end

local function Remember(name, classFile)
	if not Readable(name) or not Readable(classFile) then return end
	name = NR.NormalizeName(name)
	if name and name:find("^[^%s%d%-]+ [^%s%d%-]+$") then
		NR.Votes:CacheClass(name, classFile)
	end
end

local function FromUnit(unit)
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return end
	local _, classFile = UnitClass(unit)
	Remember(GetUnitName(unit, true), classFile)
end

local function FromChat(_, sender, _, _, _, _, _, _, _, _, _, guid)
	if not Readable(guid) or not guid:find("^Player%-") then return end
	local _, classFile = GetPlayerInfoByGUID(guid)
	Remember(sender, classFile)
end

local function FromGroup()
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			FromUnit("raid" .. i)
		end
	else
		for i = 1, GetNumSubgroupMembers() do
			FromUnit("party" .. i)
		end
	end
end

local function FromGuild()
	local now = GetTime()
	if now - lastGuildScan < GUILD_SCAN_INTERVAL then return end
	lastGuildScan = now
	for i = 1, GetNumGuildMembers() do
		local name, _, _, _, _, _, _, _, _, _, classFile = GetGuildRosterInfo(i)
		Remember(name, classFile)
	end
end

function Classes:Init()
	NR:On("PLAYER_TARGET_CHANGED", function() FromUnit("target") end)
	NR:On("UPDATE_MOUSEOVER_UNIT", function() FromUnit("mouseover") end)
	NR:On("NAME_PLATE_UNIT_ADDED", FromUnit)
	NR:On("GROUP_ROSTER_UPDATE", FromGroup)
	NR:On("GUILD_ROSTER_UPDATE", FromGuild)
	for _, event in ipairs(CHAT_EVENTS) do
		NR:On(event, FromChat)
	end
	FromGroup()
end
