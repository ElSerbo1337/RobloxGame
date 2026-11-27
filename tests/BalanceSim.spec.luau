local TestKit = require("./TestKit")
local GameConfig = require("../src/shared/GameConfig")
local GameRules = require("../src/shared/GameRules")
local BalanceSim = require("../tools/BalanceSim")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- The whole campaign with the real configuration (#108): from a new player to world 15,
-- with all rebirths on the way. Medians over a few lucks (`lune run balance` uses more,
-- the table is in docs/balancing.md).
local summary = BalanceSim.summary(GameConfig, 5)
local median = BalanceSim.medianOf

local function format(value: number): string
	return string.format("%.1f", value)
end

describe("balancing simulation: ~40 h to world 15 (#108)", function()
	it("reaches world 15 after about 40 h of active play (34-46 h)", function()
		local hours = summary.totalMinutes / 60
		if hours < 34 or hours > 46 then
			error(`world 15 after {format(hours)} h`)
		end
	end)

	it("needs about 30 rebirths on the way (25-35)", function()
		expect(summary.rebirths >= 25 and summary.rebirths <= 35).toBe(true)
	end)

	it("enters every world in order and spends time in each of them", function()
		for index = 2, #GameConfig.worlds do
			expect(summary.worldEnteredAt[index] > summary.worldEnteredAt[index - 1]).toBe(true)
		end
		for index = 1, #GameConfig.worlds - 1 do
			expect(summary.worldMinutes[index] > 0).toBe(true)
		end
	end)

	it("never enters a world before its rebirth tier (1-4: 0, 5-6: 1, 7-8: 2, ... 15: 10)", function()
		for _, campaign in summary.campaigns do
			for index, world in GameConfig.worlds do
				expect(campaign.rebirthsAtUnlock[index] >= (world.requiredRebirths or 0)).toBe(true)
			end
		end
	end)

	it("spreads the worlds over the campaign: world 8 after 5-12 h, world 12 after 17-29 h", function()
		local world8 = summary.worldEnteredAt[8] / 60
		local world12 = summary.worldEnteredAt[12] / 60
		if world8 < 5 or world8 > 12 or world12 < 17 or world12 > 29 then
			error(`world 8 after {format(world8)} h, world 12 after {format(world12)} h`)
		end
	end)
end)

describe("balancing simulation: a rebirth every ~45-90 min (#108)", function()
	-- Runs between two rebirths (without the first run and the last, unfinished one).
	local runs = {}
	for _, campaign in summary.campaigns do
		for index, run in campaign.runs do
			if index > 1 and index < #campaign.runs then
				table.insert(runs, run.minutes)
			end
		end
	end

	it("takes 45-90 min per rebirth run in the median", function()
		local value = median(runs)
		if value < 45 or value > 90 then
			error(`median run {format(value)} min`)
		end
	end)

	it("keeps at least 80 % of all runs within 35-120 min (luck of eggs and merges)", function()
		local inside = 0
		for _, minutes in runs do
			if minutes >= 35 and minutes <= 120 then
				inside += 1
			end
		end
		if inside / #runs < 0.8 then
			error(`{inside} of {#runs} runs within 35-120 min`)
		end
	end)

	it("reaches the first rebirth in world 4 after about an hour (45-100 min)", function()
		local first = {}
		for _, campaign in summary.campaigns do
			table.insert(first, campaign.runs[1].minutes)
			expect(campaign.runs[1].highestWorld).toBe(4)
		end
		local value = median(first)
		if value < 45 or value > 100 then
			error(`first run {format(value)} min`)
		end
	end)
end)

describe("balancing simulation: quick start (#108)", function()
	it("pays the first upgrade (15 coins) after about 3 rounds of the starting pizza", function()
		local world = GameConfig.worlds[1]
		local totalWeight, weightedValue = 0, 0
		for _, spawn in world.toppingSpawns do
			totalWeight += spawn.weight
			weightedValue += spawn.weight * GameConfig.toppings[spawn.topping].value
		end
		local coinsPerRound = weightedValue / totalWeight * GameConfig.pizza.startCapacity
		expect(GameConfig.upgrades.PizzaSpace.levels[1].price).toBe(15)
		expect(math.ceil(GameConfig.upgrades.PizzaSpace.levels[1].price / coinsPerRound)).toBe(3)
	end)

	it("plays worlds 1-3 of the first run in at most 10 / 15 / 25 min", function()
		local limits = { 10, 15, 25 }
		for index, limit in limits do
			local minutes = summary.worldMinutes[index]
			if minutes > limit then
				error(`{GameConfig.worlds[index].id}: {format(minutes)} min (at most {limit})`)
			end
		end
	end)
end)

describe("balancing simulation: gem economy (#108)", function()
	local function perHour(sources: { string }): number
		local values = {}
		for _, campaign in summary.campaigns do
			local sum = 0
			for _, source in sources do
				sum += campaign.gems[source]
			end
			table.insert(values, sum / (campaign.totalMinutes / 60))
		end
		return median(values)
	end

	it("earns about 20-40 gems an hour from regular sources (toppings, delivery, gifts, calendar)", function()
		local value = perHour(BalanceSim.REGULAR_SOURCES)
		if value < 20 or value > 40 then
			error(`{format(value)} gems an hour from regular sources`)
		end
	end)

	it("adds about 45 gems a day from daily quests (plus the weekly quests)", function()
		local quests = GameConfig.quests
		local weekly = BalanceSim.questGemsPerDay({
			quests = {
				dailyCount = 0,
				dailyRewards = quests.dailyRewards,
				bonusRewards = {},
				streakRewards = {},
				streakDays = 1,
				weeklyCount = quests.weeklyCount,
				weeklyRewards = quests.weeklyRewards,
			},
		})
		local daily = BalanceSim.questGemsPerDay(GameConfig) - weekly
		if daily < 40 or daily > 50 then
			error(`{format(daily)} gems a day from daily quests`)
		end
		expect(weekly > 0 and weekly < 20).toBe(true)
	end)

	it("pays the wheel and the hidden chests on top, together less than the quests", function()
		local extras = perHour({ "Wheel", "Chests" })
		expect(extras > 0).toBe(true)
		expect(extras < BalanceSim.questGemsPerDay(GameConfig)).toBe(true)
	end)

	it("buys every pet slot level on the way to world 15", function()
		-- Gems first go into pet slots in the model; all 8 levels (11 slots) are affordable.
		local rules = GameRules.new(GameConfig)
		local total = 0
		for _, level in GameConfig.upgrades.PetSlots.levels do
			total += level.price
		end
		local gems = {}
		for _, campaign in summary.campaigns do
			table.insert(gems, campaign.gemsTotal)
		end
		expect(median(gems) > total).toBe(true)
		expect(rules.petSlots(rules.newPlayerState())).toBe(GameConfig.petSlots.start)
	end)
end)
