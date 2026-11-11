local _, NR = ...

local Compat = {}
NR.Compat = Compat

function Compat.GetRegion()
	if GetCurrentRegion then
		local ok, region = pcall(GetCurrentRegion)
		if ok and region then
			return tostring(region)
		end
	end
	return "default"
end

function Compat.GetPlayerName()
	return GetUnitName("player") or UnitName("player")
end

function Compat.GetGroupChannel()
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
	if IsInRaid() then return "RAID" end
	if IsInGroup() then return "PARTY" end
end

function Compat.AddChatFilter(event, filter)
	local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
	if add then add(event, filter) end
end

function Compat.IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

function Compat.IsTrialAccount()
	return (IsTrialAccount and IsTrialAccount()) or (IsVeteranTrialAccount and IsVeteranTrialAccount()) or false
end

function Compat.IsIgnored(fullName)
	if not (C_FriendList and C_FriendList.IsIgnored) then return false end
	local ok, ignored = pcall(C_FriendList.IsIgnored, fullName)
	if ok and ignored then return true end
	local short = fullName:match("^(.-)%-") or fullName
	ok, ignored = pcall(C_FriendList.IsIgnored, short)
	return ok and ignored == true
end

local MAX_CLASS_ID = 30
local classIds

function Compat.GetClassFile(classId)
	classId = tonumber(classId)
	if not classId or classId < 1 or classId > MAX_CLASS_ID or classId ~= math.floor(classId) then return nil end
	if C_CreatureInfo and C_CreatureInfo.GetClassInfo then
		local info = C_CreatureInfo.GetClassInfo(classId)
		return info and info.classFile
	end
	if GetClassInfo then
		local _, classFile = GetClassInfo(classId)
		return classFile
	end
end

function Compat.GetClassId(classFile)
	if type(classFile) ~= "string" then return nil end
	if not classIds then
		classIds = {}
		for id = 1, MAX_CLASS_ID do
			local file = Compat.GetClassFile(id)
			if file then classIds[file] = id end
		end
	end
	return classIds[classFile]
end

function Compat.GetNumWhoResults()
	if C_FriendList and C_FriendList.GetNumWhoResults then
		return C_FriendList.GetNumWhoResults() or 0
	end
	if GetNumWhoResults then
		return GetNumWhoResults() or 0
	end
	return 0
end

function Compat.GetWhoInfo(index)
	if C_FriendList and C_FriendList.GetWhoInfo then
		return C_FriendList.GetWhoInfo(index)
	end
	if GetWhoInfo then
		local name, guild, level, race, class, zone, classFile = GetWhoInfo(index)
		if name then
			return { fullName = name, fullGuildName = guild, level = level, raceStr = race, classStr = class, area = zone, filename = classFile }
		end
	end
end

local SUCCESS = 0
local THROTTLE_CODES = { [3] = true, [8] = true }

do
	local enum = Enum and Enum.SendAddonMessageResult
	if enum then
		SUCCESS = enum.Success or SUCCESS
		THROTTLE_CODES = {}
		if enum.AddonMessageThrottle then THROTTLE_CODES[enum.AddonMessageThrottle] = true end
		if enum.ChannelThrottle then THROTTLE_CODES[enum.ChannelThrottle] = true end
	end
end

function Compat.RegisterPrefix(prefix)
	local register = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
	if register then
		return register(prefix)
	end
end

function Compat.SendAddonMessage(prefix, message, chatType, target)
	local send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
	if not send then return false, false end
	local ok, result = pcall(send, prefix, message, chatType, target)
	if not ok then return false, false end
	if type(result) == "number" then
		return result == SUCCESS, THROTTLE_CODES[result] == true
	end
	return result ~= false, false
end

function Compat.CanSendAddonMessages()
	if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
		local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
		if ok and locked then return false end
	end
	if IsEncounterInProgress and IsEncounterInProgress() then
		return false
	end
	return true
end
