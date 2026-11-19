--!strict
-- Balancing table (#41): plays the model player of tools/BalanceSim through every world
-- it may buy (`requiredRebirths`, #43) with the real rules and configuration, without
-- and after the first rebirth.
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
-- Worlds behind more rebirths than a run has (#43) are not entered there: "–".
local function cell(value: number, world: any, rebirths: number): string
	return if (world.requiredRebirths or 0) > rebirths then "–" else minutes(value)
end

print("| Welt | ab Rebirths | ohne Rebirth | nach 1. Rebirth |")
print("| ---- | ----------: | -----------: | --------------: |")
for index, world in GameConfig.worlds do
	print(
		`| {index} {world.displayName} | {world.requiredRebirths or 0} | {cell(result.first.worlds[index], world, 0)} | {cell(
			result.afterRebirth.worlds[index],
			world,
			1
		)} |`
	)
end
print(`| **Gesamt** | | **{minutes(result.first.total)}** | **{minutes(result.afterRebirth.total)}** |`)
print(`\nPet multiplier at the first rebirth: x{string.format("%.1f", result.rebirthPetMultiplier)}`)
-- Pet cap per world (#51): target for worlds 1-6 after a rebirth is about 1/3 of the first run.
local firstEarly, secondEarly = 0, 0
for index = 1, 6 do
	firstEarly += result.first.worlds[index]
	secondEarly += result.afterRebirth.worlds[index]
end
print(
	`Worlds 1-6: {minutes(firstEarly)} min without rebirth, {minutes(secondEarly)} min after the first rebirth`
		.. ` (ratio {string.format("%.2f", secondEarly / firstEarly)})`
)

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
