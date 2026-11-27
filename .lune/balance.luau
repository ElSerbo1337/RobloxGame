--!strict
-- Balancing tables (#41, whole campaign since #108): plays the model player of
-- tools/BalanceSim from a new player state to the last world with the real rules and
-- configuration (rebirths on the way), with different luck.
-- Usage: lune run balance [seeds] [variants]   (default 15 runs; medians; any second
-- argument also prints the sensitivity table)
-- The result goes into docs/balancing.md.

local process = require("@lune/process")

local BalanceSim = require("../tools/BalanceSim")
local GameConfig = require("../src/shared/GameConfig")

local seeds = tonumber(process.args[1]) or 15
local withVariants = process.args[2] ~= nil

local function hours(value: number): string
	return string.format("%.1f", value / 60)
end

local function deepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = deepClone(inner)
	end
	return copy
end

local summary = BalanceSim.summary(GameConfig, seeds)
local median = BalanceSim.medianOf
print(`Medians over {seeds} runs\n`)

-- Rebirths done when a world was unlocked the first time (median).
local rebirthsAt = {}
for index = 1, #GameConfig.worlds do
	local values = {}
	for _, campaign in summary.campaigns do
		table.insert(values, campaign.rebirthsAtUnlock[index])
	end
	rebirthsAt[index] = median(values)
end

print("| Welt | ab Rebirths | erreicht nach (h) | Rebirths dann | Zeit in der Welt (Min) |")
print("| ---- | ----------: | ----------------: | ------------: | ---------------------: |")
for index, world in GameConfig.worlds do
	local inWorld = summary.worldMinutes[index]
	print(
		`| {index} {world.displayName} | {world.requiredRebirths or 0} | {hours(summary.worldEnteredAt[index])} | {rebirthsAt[index]} | {if inWorld
			then string.format("%.0f", inWorld)
			else "–"} |`
	)
end
print(`\nTotal: {hours(summary.totalMinutes)} h, {summary.rebirths} rebirths (medians)`)

-- Rebirth runs of the median-luck campaign (the one whose total is the median).
local sorted = table.clone(summary.campaigns)
table.sort(sorted, function(a, b)
	return a.totalMinutes < b.totalMinutes
end)
local typical = sorted[math.ceil(#sorted / 2)]
print("\nRuns of the median campaign: rebirths during the run -> minutes (highest world)")
local cells, elapsed = {}, 0
for _, run in typical.runs do
	elapsed += run.minutes
	table.insert(
		cells,
		`{run.rebirths}: {string.format("%.0f", run.minutes)} (W{run.highestWorld}, {hours(elapsed)} h)`
	)
end
print(table.concat(cells, " · "))
local runMinutes = {}
for index, run in typical.runs do
	if index > 1 and index < #typical.runs then
		table.insert(runMinutes, run.minutes)
	end
end
if #runMinutes > 0 then
	table.sort(runMinutes)
	print(
		`runs 2..n-1: min {string.format("%.0f", runMinutes[1])}, median {string.format("%.0f", median(runMinutes))}, max {string.format(
			"%.0f",
			runMinutes[#runMinutes]
		)} min`
	)
end

-- Gems per source: per hour of play and per day (one day = one 60 minute session).
print("\n| Gem-Quelle | Gems pro Stunde | Gems pro Tag |")
print("| --- | ---: | ---: |")
local regular = 0
for _, source in BalanceSim.GEM_SOURCES do
	local values = {}
	for _, campaign in summary.campaigns do
		table.insert(values, campaign.gems[source] / (campaign.totalMinutes / 60))
	end
	local perHour = median(values)
	if table.find(BalanceSim.REGULAR_SOURCES, source) then
		regular += perHour
	end
	print(`| {source} | {string.format("%.1f", perHour)} | {string.format("%.0f", perHour)} |`)
end
print(
	`| **Summe** | **{string.format("%.1f", summary.gemsPerHour)}** | **{string.format("%.0f", summary.gemsPerHour)}** |`
)
print(`Regular sources ({table.concat(BalanceSim.REGULAR_SOURCES, ", ")}): {string.format("%.1f", regular)} per hour`)
print(`Final pet multiplier of the median campaign: x{string.format("%.1f", typical.petMultiplier)}`)

if withVariants then
	print("\n| Variante | Welt 15 nach (h) | Rebirths |")
	print("| -------- | ---------------: | -------: |")
	local variants = {
		{ name = "1,5 Runden/Min", rounds = 1.5 },
		{ name = "3 Runden/Min", rounds = 3 },
		{ name = "30 Min pro Tag", options = { sessionMinutes = 30 } },
		{ name = "Ei-Amortisation 5 Min", options = { eggPaybackMinutes = 5 } },
		{ name = "Ei-Amortisation 20 Min", options = { eggPaybackMinutes = 20 } },
	}
	for _, variant in variants do
		local config = deepClone(GameConfig)
		if variant.rounds then
			config.income.roundsPerMinute = variant.rounds
		end
		local result = BalanceSim.summary(config, seeds, variant.options)
		print(`| {variant.name} | {hours(result.totalMinutes)} | {result.rebirths} |`)
	end
end
