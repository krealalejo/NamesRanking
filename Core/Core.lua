local ADDON_NAME, NR = ...

NR.VERSION = "1.6.0"
NR.PROTOCOL = 2
NR.PREFIX = "NRnk"
NR.MAX_VOTE = 3

local eventFrame = CreateFrame("Frame")
local handlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do
		list[i](...)
	end
end)

function NR:On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		eventFrame:RegisterEvent(event)
	end
	table.insert(handlers[event], fn)
end

local listeners = {}
local queued = {}

function NR:Listen(name, fn)
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], fn)
end

function NR:Fire(name)
	if queued[name] then return end
	queued[name] = true
	C_Timer.After(0.1, function()
		queued[name] = nil
		for _, fn in ipairs(listeners[name] or {}) do
			fn()
		end
	end)
end

function NR:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Names Ranking:|r " .. tostring(msg))
end

local function Line(msg)
	DEFAULT_CHAT_FRAME:AddMessage("  " .. msg)
end

function NR.NormalizeName(name)
	if type(name) ~= "string" then return nil end
	name = strtrim((name:gsub("%s+", " ")):match("^[^%-]*"))
	if name == "" then return nil end
	return name
end

function NR.ColoredName(name)
	local classFile = NR.Votes:GetClass(name)
	local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	if color and color.colorStr then
		return "|c" .. color.colorStr .. name .. "|r"
	end
	return name
end

function NR.Ago(ts)
	local diff = math.max(0, GetServerTime() - ts)
	if diff < 60 then return "just now" end
	if diff < 3600 then return math.floor(diff / 60) .. "m ago" end
	if diff < 86400 then return math.floor(diff / 3600) .. "h ago" end
	return math.floor(diff / 86400) .. "d ago"
end

function NR:IsBlocked(voter)
	if voter == NR.player then return false end
	if NR.db.settings.blocked[voter] then return true end
	return NR.Compat.IsIgnored(voter)
end

NR:On("ADDON_LOADED", function(name)
	if name ~= ADDON_NAME then return end
	NamesRankingDB = NamesRankingDB or {}
	local db = NamesRankingDB
	db.version = db.version or 1
	db.regions = db.regions or {}
	db.settings = db.settings or {}
	if db.settings.sync == nil then db.settings.sync = true end
	db.settings.blocked = db.settings.blocked or {}
	if db.version < 2 then
		db.regions = {}
		db.settings.blocked = {}
		db.version = 2
	end
	db.log = nil
	db.settings.debug = nil
	NR.db = db
end)

NR:On("PLAYER_LOGIN", function()
	NR.player = NR.NormalizeName(NR.Compat.GetPlayerName())
	NR.Votes:Init()
	NR.Ranking:Init()
	NR.Comm:Init()
	NR.WhoHook:Init()
	NR.Leaderboard:Init()
	NR.MinimapButton:Init()
end)

local commands = {}

function commands.help()
	NR:Print("v" .. NR.VERSION .. " commands:")
	Line("/nr - open or close the leaderboard")
	Line("/nr vote <Name> <1-3> - vote without the /who window (0 removes your vote)")
	Line("/nr top [N] - print the top N names in your chat (default 10)")
	Line("/nr sync on|off - share votes with other players or keep them local")
	Line("/nr block <Name> - ignore that player's votes (/nr unblock <Name> to undo)")
	Line("/nr status - show sync status")
end

local function FromTyped(text)
	return (text:lower():gsub("(%S)(%S*)", function(first, others)
		return first:upper() .. others
	end))
end

function commands.vote(rest)
	local name, value = rest:match("^(.-)%s+(%d)$")
	value = tonumber(value)
	if not name or name == "" or not value or value > NR.MAX_VOTE then
		NR:Print("usage: /nr vote <Name> <1-3>  (0 removes your vote)")
		return
	end
	NR.Votes:CastLocal(FromTyped(name), value)
end

function commands.top(rest)
	local list = NR.Ranking:GetList()
	if #list == 0 then
		NR:Print("no votes yet.")
		return
	end
	local n = math.min(math.max(tonumber(rest) or 10, 1), 50, #list)
	NR:Print(("top %d names:"):format(n))
	for i = 1, n do
		local entry = list[i]
		Line(("%d. %s - %d points (%d votes)"):format(i, NR.ColoredName(entry.name), entry.points, entry.votes))
	end
end

function commands.sync(rest)
	rest = rest:lower()
	if rest == "on" then
		NR.db.settings.sync = true
		NR.Comm:Enable()
		NR:Print("sync enabled.")
	elseif rest == "off" then
		NR.db.settings.sync = false
		NR.Comm:Disable()
		NR:Print("sync disabled. Your votes stay on this computer.")
	else
		NR:Print("sync is " .. (NR.db.settings.sync and "on" or "off") .. ". Use /nr sync on|off.")
	end
end

local function SetBlocked(rest, blocked)
	local name = NR.NormalizeName(FromTyped(rest))
	if not name then
		NR:Print("usage: /nr " .. (blocked and "block" or "unblock") .. " <Name>")
		return
	end
	NR.db.settings.blocked[name] = blocked or nil
	NR.Ranking:Invalidate()
	NR:Fire("VOTES_CHANGED")
	NR:Print(name .. (blocked and "'s votes are now ignored." or "'s votes count again."))
end

function commands.block(rest) SetBlocked(rest, true) end
function commands.unblock(rest) SetBlocked(rest, false) end

function commands.status()
	local status = NR.Comm:GetStatus()
	NR:Print(("v%s | sync %s | channel %s | addon users online %d | guild %s | group %s | queued messages %d | voters %d | last message %s"):format(
		NR.VERSION,
		NR.db.settings.sync and "on" or "off",
		status.channel and ("#" .. status.channel) or "none",
		status.online,
		status.guild and "yes" or "no",
		status.group or "none",
		status.queue,
		NR.Ranking:GetVoterCount(),
		status.last and NR.Ago(status.last) or "never"))
end

SLASH_NAMESRANKING1 = "/nr"
SLASH_NAMESRANKING2 = "/namesranking"
SlashCmdList.NAMESRANKING = function(msg)
	local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()
	if cmd == "" then
		NR.Leaderboard:Toggle()
		return
	end
	local command = commands[cmd] or commands.help
	command(rest or "")
end
