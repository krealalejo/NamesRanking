local _, NR = ...

local Ranking = {}
NR.Ranking = Ranking

local list, byName = {}, {}
local dirty = true

function Ranking:Init()
	dirty = true
end

function Ranking:Invalidate()
	dirty = true
end

local function ByScore(a, b)
	if a.points ~= b.points then return a.points > b.points end
	if a.threes ~= b.threes then return a.threes > b.threes end
	if a.votes ~= b.votes then return a.votes > b.votes end
	return a.name < b.name
end

local function Rebuild()
	local totals = {}
	for voter, votes in pairs(NR.Votes:GetAll()) do
		if not NR:IsBlocked(voter) then
			for target, entry in pairs(votes) do
				local value = entry[1]
				if value > 0 then
					local total = totals[target]
					if not total then
						total = { name = target, points = 0, votes = 0, threes = 0 }
						totals[target] = total
					end
					total.points = total.points + value
					total.votes = total.votes + 1
					if value == NR.MAX_VOTE then
						total.threes = total.threes + 1
					end
				end
			end
		end
	end

	local sorted = {}
	for _, total in pairs(totals) do
		sorted[#sorted + 1] = total
	end
	table.sort(sorted, ByScore)
	for i, total in ipairs(sorted) do
		total.rank = i
	end

	list, byName = sorted, totals
	dirty = false
end

function Ranking:GetList()
	if dirty then Rebuild() end
	return list
end

function Ranking:GetEntry(name)
	if dirty then Rebuild() end
	return byName[name]
end

