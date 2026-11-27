-- Lifetime stats, badge conditions and titles (#103).
local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local config = table.clone(TestConfig)
config.pets = table.clone(TestConfig.pets)
config.pets.Ghost = { displayName = "Geist", rarity = "Secret", bonus = 5 }
config.badges = {
	{ id = "Welcome", badgeId = 11, kind = "Welcome" },
	{ id = "Coins1K", badgeId = 12, kind = "CoinsEarned", goal = 1000 },
	{ id = "Toppings2", badgeId = 13, kind = "ToppingsCollected", goal = 2 },
	{ id = "Eggs3", badgeId = 14, kind = "EggsOpened", goal = 3 },
	{ id = "FirstMythic", badgeId = 15, kind = "Rarity", rarity = "Mythic" },
	{ id = "FirstSecret", badgeId = 0, kind = "Rarity", rarity = "Secret" },
	{ id = "FirstShiny", kind = "Shiny" },
}
config.titles = {
	{ id = "Newbie" },
	{ id = "Collector", world = 2 },
	{ id = "Chef", rebirths = 1 },
	{ id = "Legend", world = 3 },
	{ id = "WeeklyChampion", weekly = true },
}

local rules = GameRules.new(config)
local NOW = 1_800_000_000

local function player()
	local state = rules.newPlayerState()
	state.upgrades = { PizzaSpace = 3, InventorySpace = 2 }
	return state
end

local function reachedIds(state)
	local ids = {}
	for _, badge in rules.badges(state) do
		if badge.reached then
			table.insert(ids, badge.id)
		end
	end
	return ids
end

local function awardIds(state)
	local ids = {}
	for _, entry in rules.badgesToAward(state) do
		table.insert(ids, entry.id)
	end
	return ids
end

describe("lifetime counters", function()
	it("count collected toppings and opened eggs, kept on rebirth", function()
		local state = player()
		state = rules.collectTopping(state, "Salami", 0).state
		state = rules.collectTopping(state, "Mushroom", 0).state
		expect(state.toppingsCollected).toBe(2)

		state.coins = 1000
		state = rules.openEggs(state, "TestEgg", 1, TestKit.sequenceRandom({ 0.1 }), NOW).state
		state = rules.openEggs(state, "TestEgg", 1, TestKit.sequenceRandom({ 0.1 }), NOW).state
		expect(state.eggsOpened).toBe(2)

		state.coins = 1e12
		local reborn = rules.rebirth(state, NOW).state
		expect(reborn.toppingsCollected).toBe(2)
		expect(reborn.eggsOpened).toBe(2)
	end)

	it("failed actions count nothing", function()
		local state = player()
		local result = rules.openEggs(state, "TestEgg", 1, TestKit.sequenceRandom({ 0.1 }), NOW)
		expect(result.ok).toBe(false)
		expect(result.state.eggsOpened).toBe(0)
		expect(rules.collectTopping(state, "Onion", 0).state.toppingsCollected).toBe(0)
	end)

	it("remember the highest world across a rebirth", function()
		local state = player()
		state.coins = 1500
		state = rules.unlockWorld(state, "Farm").state
		expect(rules.highestWorld(state)).toBe(2)
		state.coins = 1e12
		state = rules.rebirth(state, NOW).state
		expect(#state.unlockedWorlds).toBe(0)
		expect(rules.highestWorld(state)).toBe(2)
	end)

	it("count worlds unlocked without the rule (admin, old saves)", function()
		local state = player()
		state.highestWorld = nil :: any
		state.unlockedWorlds = { "Farm", "Beach" }
		expect(rules.highestWorld(state)).toBe(3)
	end)

	it("collect everything for the profile", function()
		local state = player()
		state.totalCoinsEarned = 5000
		state.totalPlaytimeSeconds = 120
		state.rebirths = 2
		state = rules.collectTopping(state, "Salami", 0).state
		local stats = rules.lifetimeStats(state)
		expect(stats.coinsEarned).toBe(5000)
		expect(stats.toppingsCollected).toBe(1)
		expect(stats.eggsOpened).toBe(0)
		expect(stats.playtimeSeconds).toBe(120)
		expect(stats.rebirths).toBe(2)
		expect(stats.highestWorld).toBe(1)
		expect(stats.toppingIndexFound >= 1).toBe(true)
		expect(stats.petIndexTotal >= 0).toBe(true)
	end)
end)

describe("badge conditions", function()
	it("a new player only has Welcome", function()
		expect(reachedIds(player())).toEqual({ "Welcome" })
	end)

	it("counter badges unlock at their goal", function()
		local state = player()
		state.totalCoinsEarned = 999
		state.toppingsCollected = 2
		state.eggsOpened = 2
		expect(reachedIds(state)).toEqual({ "Welcome", "Toppings2" })
		state.totalCoinsEarned = 1000
		state.eggsOpened = 3
		expect(reachedIds(state)).toEqual({ "Welcome", "Coins1K", "Toppings2", "Eggs3" })
		local coins = rules.badges(state)[2]
		expect(coins.progress).toBe(1000)
		expect(coins.goal).toBe(1000)
	end)

	it("rarity badges count deleted pets (ever owned) and Shiny stars", function()
		local state = player()
		state.petsOwnedEver = { Dragon = true, Ghost = true }
		state.petIndexStars = { Cat = { Shiny = true } }
		expect(reachedIds(state)).toEqual({ "Welcome", "FirstMythic", "FirstSecret", "FirstShiny" })
	end)

	it("pets in the inventory count too (saves from before the index)", function()
		local state = player()
		state.petsOwnedEver = nil :: any
		state.petIndexStars = nil :: any
		state.pets = { { uid = 1, petId = "Dragon", shiny = true } }
		expect(reachedIds(state)).toEqual({ "Welcome", "FirstMythic", "FirstShiny" })
	end)

	it("awards only reached badges with a real id, not yet awarded", function()
		local state = player()
		state.petsOwnedEver = { Ghost = true }
		state.petIndexStars = { Cat = { Shiny = true } }
		-- FirstSecret (id 0) and FirstShiny (no id) are skipped without error.
		expect(awardIds(state)).toEqual({ "Welcome" })
		expect(rules.badgesToAward(state)[1].badgeId).toBe(11)
		local marked = rules.markBadgeAwarded(state, "Welcome")
		expect(marked.ok).toBe(true)
		expect(awardIds(marked.state)).toEqual({})
		expect(state.badgesAwarded.Welcome).toBe(nil)
	end)

	it("retroactive: old progress makes every reached badge due at once", function()
		local state = player()
		state.totalCoinsEarned = 1e6
		state.eggsOpened = 50
		expect(awardIds(state)).toEqual({ "Welcome", "Coins1K", "Eggs3" })
	end)

	it("refuses unknown badges", function()
		local result = rules.markBadgeAwarded(player(), "Nope")
		expect(result.ok).toBe(false)
		expect(result.reason).toBe("UnknownBadge")
	end)

	it("no badges in the config means an empty list", function()
		local bare = GameRules.new(TestConfig)
		expect(#bare.badges(bare.newPlayerState())).toBe(0)
		expect(#bare.badgesToAward(bare.newPlayerState())).toBe(0)
	end)
end)

describe("titles", function()
	local function unlockedIds(state, now)
		local ids = {}
		for _, title in rules.titles(state, now or NOW) do
			if title.unlocked then
				table.insert(ids, title.id)
			end
		end
		return ids
	end

	it("unlock by highest world and rebirths", function()
		local state = player()
		expect(unlockedIds(state)).toEqual({ "Newbie" })
		expect(rules.activeTitle(state, NOW)).toBe("Newbie")
		state.highestWorld = 2
		expect(unlockedIds(state)).toEqual({ "Newbie", "Collector" })
		state.rebirths = 1
		expect(unlockedIds(state)).toEqual({ "Newbie", "Collector", "Chef" })
		expect(rules.activeTitle(state, NOW)).toBe("Chef")
		state.highestWorld = 3
		expect(rules.activeTitle(state, NOW)).toBe("Legend")
	end)

	it("can choose an unlocked title, not a locked one", function()
		local state = player()
		state.highestWorld = 3
		local chosen = rules.setTitle(state, "Collector", NOW)
		expect(chosen.ok).toBe(true)
		expect(rules.activeTitle(chosen.state, NOW)).toBe("Collector")
		expect(rules.titles(chosen.state, NOW)[2].active).toBe(true)
		local locked = rules.setTitle(state, "Chef", NOW)
		expect(locked.ok).toBe(false)
		expect(locked.reason).toBe("TitleLocked")
		expect(rules.setTitle(state, "Nope", NOW).reason).toBe("UnknownTitle")
		expect(rules.setTitle(state, 5, NOW).reason).toBe("UnknownTitle")
		local auto = rules.setTitle(chosen.state, "", NOW)
		expect(rules.activeTitle(auto.state, NOW)).toBe("Legend")
	end)

	it("Weekly Champion is held until its time and then falls back", function()
		local state = player()
		local granted = rules.grantWeeklyChampion(state, NOW + 100)
		expect(granted.ok).toBe(true)
		expect(rules.activeTitle(granted.state, NOW)).toBe("WeeklyChampion")
		-- A shorter grant never cuts it.
		local again = rules.grantWeeklyChampion(granted.state, NOW + 10).state
		expect(again.weeklyChampionUntil).toBe(NOW + 100)
		local chosen = rules.setTitle(again, "WeeklyChampion", NOW).state
		expect(rules.activeTitle(chosen, NOW + 100)).toBe("Newbie")
		expect(rules.setTitle(chosen, "WeeklyChampion", NOW + 100).reason).toBe("TitleLocked")
		expect(rules.grantWeeklyChampion(state, 0 / 0).ok).toBe(false)
	end)
end)
