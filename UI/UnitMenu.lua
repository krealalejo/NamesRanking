local _, NR = ...

local UnitMenu = {}
NR.UnitMenu = UnitMenu

local MENU_TAGS = {
	"MENU_UNIT_PLAYER",
	"MENU_UNIT_PARTY",
	"MENU_UNIT_RAID_PLAYER",
	"MENU_UNIT_ENEMY_PLAYER",
	"MENU_UNIT_TARGET",
}

local function ResolveTarget(contextData)
	local unit = contextData and contextData.unit
	if not unit or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return nil end
	local name = GetUnitName(unit, true)
	if type(name) ~= "string" or NR.Compat.IsSecret(name) then return nil end
	name = NR.NormalizeName(name)
	if not name or name == NR.player then return nil end
	local _, classFile = UnitClass(unit)
	if type(classFile) == "string" and not NR.Compat.IsSecret(classFile) then
		NR.Votes:CacheClass(name, classFile)
	end
	return name
end

local function AddVoteEntries(_, root, contextData)
	local name = ResolveTarget(contextData)
	if not name then return end
	local mine = NR.Votes:GetMyVote(name)

	root:CreateDivider()
	root:CreateTitle("Names Ranking")
	for value = 1, NR.MAX_VOTE do
		local radio = root:CreateRadio(
			("Vote %d"):format(value),
			function(data) return NR.Votes:GetMyVote(name) == data end,
			function(data) NR.Votes:CastLocal(name, data) end,
			value)
		radio:SetEnabled(mine == 0 or mine == value)
	end
	local remove = root:CreateButton("Remove vote", function()
		NR.Votes:CastLocal(name, 0)
	end)
	remove:SetEnabled(mine > 0)
end

function UnitMenu:Init()
	if not (Menu and Menu.ModifyMenu) then return end
	for _, tag in ipairs(MENU_TAGS) do
		Menu.ModifyMenu(tag, AddVoteEntries)
	end
end
