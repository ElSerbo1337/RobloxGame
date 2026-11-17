--!strict
-- Balancing table (#41): plays the model player of tools/BalanceSim through worlds 1-7
-- with the real rules and configuration, without and after the first rebirth.
-- Usage: lune run balance [seeds]   (default 51 runs with different luck; medians)
-- The result goes into docs/balancing.md.

local process = require("@lune/process")

local BalanceSim = require("../tools/BalanceSim")
local GameConfig = require("../src/shared/GameConfig")

local seeds = tonumber(process.args[1]) or 51

local function minutes(value: number): string
	return string.format("%.1f", value)
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

local result = BalanceSim.median(GameConfig, seeds)
print(`Medians over {seeds} runs (minutes of play time)\n`)
print("| Welt | ohne Rebirth | nach 1. Rebirth |")
print("| ---- | -----------: | --------------: |")
for index, world in GameConfig.worlds do
	print(
		`| {index} {world.displayName} | {minutes(result.first.worlds[index])} | {minutes(
			result.afterRebirth.worlds[index]
		)} |`
	)
end
print(`| **Gesamt** | **{minutes(result.first.total)}** | **{minutes(result.afterRebirth.total)}** |`)
print(`\nPet multiplier at the first rebirth: x{string.format("%.1f", result.rebirthPetMultiplier)}`)

-- Sensitivity: the same prices with slower/faster players and shorter sessions.
print("\n| Variante | Welt 1–7 je Welt | Gesamt ohne Rebirth | Gesamt nach 1. Rebirth |")
print("| -------- | ---------------- | ------------------: | ---------------------: |")
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
	local run = BalanceSim.median(config, seeds, variant.options)
	local perWorld = {}
	for index = 1, #config.worlds do
		table.insert(perWorld, string.format("%.0f", run.first.worlds[index]))
	end
	print(
		`| {variant.name} | {table.concat(perWorld, " / ")} | {minutes(run.first.total)} | {minutes(
			run.afterRebirth.total
		)} |`
	)
end
