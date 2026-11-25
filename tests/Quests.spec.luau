local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local SaveData = require("../src/shared/SaveData")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect
local sequenceRandom = TestKit.sequenceRandom

local rules = GameRules.new(TestConfig)

-- Thursday 15.01.2026 11:00 CET (German day 20468); its week started on Monday 12.01.
local NOW = 1768431600 + 11 * 3600
local DAY = 24 * 3600
local NEXT_DAY = NOW + DAY
-- Monday 19.01.2026 00:00 CET = 18.01. 23:00 UTC.
local NEXT_MONDAY = 1768431600 + 4 * DAY
local FIRST = sequenceRandom({ 0 })

-- TestConfig with only the given quest kinds (ids from TestConfig.quests.kinds) and
-- optional feature switches.
local function configWith(kindIds: { string }?, features: { [string]: boolean }?)
	local config = table.clone(TestConfig)
	config.quests = table.clone(TestConfig.quests)
	if kindIds then
		local kinds = {}
		for _, id in kindIds do
			for _, kind in TestConfig.quests.kinds do
				if kind.id == id then
					table.insert(kinds, kind)
				end
			end
		end
		config.quests.kinds = kinds
	end
	config.features = features
	return config
end

local function rulesWith(kindIds: { string }?, features: { [string]: boolean }?)
	return GameRules.new(configWith(kindIds, features))
end

local function kindsOf(quests): { string }
	local kinds = {}
	for _, quest in quests do
		table.insert(kinds, quest.kind)
	end
	table.sort(kinds)
	return kinds
end

-- A player with fresh quests of today (made with `r`, default the full TestConfig).
local function withQuests(r: any?, state: any?, now: number?)
	local useRules = r or rules
	return useRules.refreshQuests(state or useRules.newPlayerState(), now or NOW, FIRST).state
end

-- Daily quests with all progress done (the rewards stay to be claimed).
local function allDone(r: any, state: any)
	local out = state
	for index in out.dailyQuests do
		local result = r.completeQuest(out, "Daily", index)
		if result.ok then
			out = result.state
		end
	end
	return out
end

describe("quest generation", function()
	it("a new player has no quests until they are made", function()
		local state = rules.newPlayerState()

		expect(#state.dailyQuests).toBe(0)
		expect(#state.weeklyQuests).toBe(0)
		expect(state.questDay).toBe(0)
	end)

	it("makes 3 daily and the weekly quests of different kinds for today", function()
		local result = rules.refreshQuests(rules.newPlayerState(), NOW, sequenceRandom({ 0.5, 0.1, 0.9, 0.3 }))

		expect(result.ok).toBe(true)
		local state = result.state
		expect(#state.dailyQuests).toBe(3)
		expect(#state.weeklyQuests).toBe(2)
		expect(state.questDay).toBe(20468)
		expect(state.questWeekDay).toBe(20468)
		for _, list in { state.dailyQuests, state.weeklyQuests } do
			local seen = {}
			for _, quest in list do
				expect(seen[quest.kind]).toBeNil()
				seen[quest.kind] = true
				expect(quest.progress).toBe(0)
				expect(quest.claimed).toBe(false)
			end
		end
	end)

	it("keeps the quests on the same day and makes new daily quests on the next German day", function()
		local state = withQuests()

		expect(rules.refreshQuests(state, NOW + 3600, FIRST).reason).toBe("Unchanged")
		local result = rules.refreshQuests(state, NEXT_DAY, FIRST)
		expect(result.ok).toBe(true)
		expect(result.state.questDay).toBe(20469)
		-- The weekly quests stay within the week.
		expect(result.state.weeklyQuests).toBe(state.weeklyQuests)
		expect(result.state.questWeekDay).toBe(20468)
	end)

	it("makes new weekly quests on Monday 00:00 German time, not before", function()
		local state = withQuests()

		local sunday = rules.refreshQuests(state, NEXT_MONDAY - 1, FIRST).state
		expect(sunday.weeklyQuests).toBe(state.weeklyQuests)
		local monday = rules.refreshQuests(sunday, NEXT_MONDAY, FIRST).state
		expect(monday.weeklyQuests == state.weeklyQuests).toBe(false)
		expect(monday.questWeekDay).toBe(20472)
	end)

	it("starts a new day with no rerolls used and the bonus chest closed", function()
		local state = withQuests()
		state.questRerolls = 3
		state.questBonusClaimed = true

		local result = rules.refreshQuests(state, NEXT_DAY, FIRST)

		expect(result.state.questRerolls).toBe(0)
		expect(result.state.questBonusClaimed).toBe(false)
	end)

	it("makes fewer quests when the pool is smaller", function()
		local r = rulesWith({ "SellPizzas", "PlayMinutes" })

		local state = withQuests(r)

		expect(kindsOf(state.dailyQuests)).toEqual({ "PlayMinutes", "SellPizzas" })
		-- Only SellPizzas has a weekly amount.
		expect(kindsOf(state.weeklyQuests)).toEqual({ "SellPizzas" })
	end)

	it("the admin can make new quests at once (force)", function()
		local state = withQuests()

		local result = rules.refreshQuests(state, NOW, sequenceRandom({ 0.99 }), true)

		expect(result.ok).toBe(true)
		expect(result.state.dailyQuests == state.dailyQuests).toBe(false)
		expect(result.state.weeklyQuests == state.weeklyQuests).toBe(false)
	end)

	it("draws a reward of 8 gems or 1 potion per daily quest", function()
		local r = rulesWith({ "SellPizzas" })

		-- Draws: kind, reward kind (< 0.5 = Gems).
		local gems = r.refreshQuests(r.newPlayerState(), NOW, sequenceRandom({ 0, 0.2 })).state.dailyQuests[1]
		local potion = r.refreshQuests(r.newPlayerState(), NOW, sequenceRandom({ 0, 0.7, 0.5 })).state.dailyQuests[1]

		expect(gems.reward).toEqual({ kind = "Gems", amount = 8 })
		expect(potion.reward.kind).toBe("Potion")
		expect(potion.reward.amount).toBe(1)
		expect(TestConfig.potions[potion.reward.potionId] ~= nil).toBe(true)
	end)
end)

describe("quest amounts", function()
	it("scale with the highest unlocked world", function()
		local r = rulesWith({ "CollectToppings" })
		local farm = r.newPlayerState()
		farm.unlockedWorlds = { "Farm" }

		expect(withQuests(r).dailyQuests[1].goal).toBe(4)
		expect(withQuests(r, farm).dailyQuests[1].goal).toBe(6)
		expect(withQuests(r).weeklyQuests[1].goal).toBe(20)
		expect(withQuests(r, farm).weeklyQuests[1].goal).toBe(30)
	end)

	it("ask for coins worth some minutes of income", function()
		local r = rulesWith({ "EarnCoins" })
		local rich = r.newPlayerState()
		rich.rebirths = 10 -- x6 coins

		-- 1.7 x 2 x 2 = 6.8 a minute, x 10 = 68.
		expect(withQuests(r).dailyQuests[1].goal).toBe(68)
		-- Income: avg value 1.7 x pizza 2 x 2 rounds x 6 = 40.8 a minute, x 10 = 408 -> 410.
		expect(r.incomePerMinute(rich)).toBe(40.8)
		expect(withQuests(r, rich).dailyQuests[1].goal).toBe(410)
	end)
end)

describe("quest pool and feature switches", function()
	it("never draws kinds whose feature is switched off", function()
		local r = rulesWith(nil, { petMerge = false, goldenToppings = false })

		local pool = r.questPool(r.newPlayerState(), "Daily")

		expect(table.find(pool, "MergePets")).toBeNil()
		expect(table.find(pool, "GoldenToppings")).toBeNil()
		expect(table.find(pool, "SellPizzas") ~= nil).toBe(true)
	end)

	it("draws hidden chests only once their progress source is registered", function()
		local farm = rules.newPlayerState()
		farm.unlockedWorlds = { "Farm" }

		expect(table.find(rules.questPool(farm, "Daily"), "OpenChest")).toBeNil()

		GameRules.QUEST_SOURCES.OpenChest = true
		local registered = rules.questPool(farm, "Daily")
		local chestsOff = rulesWith(nil, { hiddenChests = false }).questPool(farm, "Daily")
		local world1 = rules.questPool(rules.newPlayerState(), "Daily")
		GameRules.QUEST_SOURCES.OpenChest = nil

		expect(table.find(registered, "OpenChest") ~= nil).toBe(true)
		expect(table.find(chestsOff, "OpenChest")).toBeNil()
		-- Chests only from their world on (minWorld).
		expect(table.find(world1, "OpenChest")).toBeNil()
	end)

	it("draws lucky wheel quests (#98) only while the wheel is switched on", function()
		expect(table.find(rules.questPool(rules.newPlayerState(), "Daily"), "SpinWheel") ~= nil).toBe(true)
		local off = rulesWith(nil, { luckyWheel = false })
		expect(table.find(off.questPool(off.newPlayerState(), "Daily"), "SpinWheel")).toBeNil()
	end)

	it("draws 'unlock a world' only while the next world is in reach", function()
		local r = GameRules.new((function()
			local config = configWith({ "UnlockWorld" })
			config.worlds = table.clone(TestConfig.worlds)
			config.worlds[3] = table.clone(TestConfig.worlds[3])
			config.worlds[3].requiredRebirths = 1
			return config
		end)())
		local farm = r.newPlayerState()
		farm.unlockedWorlds = { "Farm" }

		expect(#r.questPool(r.newPlayerState(), "Daily")).toBe(1)
		expect(#r.questPool(farm, "Daily")).toBe(0) -- Beach needs a rebirth
		expect(#r.questPool(farm, "Weekly")).toBe(0) -- daily only
	end)

	it("makes no daily quests while daily quests are switched off, and refuses claims", function()
		local r = rulesWith(nil, { dailyQuests = false })

		local state = withQuests(r)

		expect(#state.dailyQuests).toBe(0)
		expect(#state.weeklyQuests).toBe(2)
		expect(r.claimQuest(state, "Daily", 1, NOW).reason).toBe("FeatureOff")
		expect(r.rerollQuest(state, 1, NOW, FIRST).reason).toBe("FeatureOff")
	end)

	it("makes nothing while both quest switches are off", function()
		local r = rulesWith(nil, { dailyQuests = false, weeklyQuests = false })

		expect(r.refreshQuests(r.newPlayerState(), NOW, FIRST).reason).toBe("Unchanged")
	end)
end)

describe("quest progress", function()
	it("collecting toppings and golden toppings counts", function()
		local r = rulesWith({ "CollectToppings", "GoldenToppings" })
		local state = withQuests(r)
		state.adminGoldenChance = 1

		local result = r.collectTopping(state, "Salami", 0, nil, 0.5)

		expect(result.ok).toBe(true)
		local byKind = {}
		for _, quest in result.state.dailyQuests do
			byKind[quest.kind] = quest.progress
		end
		expect(byKind.CollectToppings).toBe(1)
		expect(byKind.GoldenToppings).toBe(1)
		-- The old state is unchanged.
		expect(state.dailyQuests[1].progress).toBe(0)
	end)

	it("selling counts pizzas and earned coins", function()
		local r = rulesWith({ "SellPizzas", "EarnCoins" })
		local state = withQuests(r)
		state.pizza = { "Mozzarella", "Mozzarella" }

		local result = r.sellPizza(state)

		local byKind = {}
		for _, quest in result.state.dailyQuests do
			byKind[quest.kind] = quest.progress
		end
		expect(byKind.SellPizzas).toBe(1)
		expect(byKind.EarnCoins).toBe(10)
	end)

	it("opening eggs counts every egg", function()
		local r = rulesWith({ "OpenEggs" })
		local state = withQuests(r)
		state.coins = 100

		local result = r.openEggs(state, "TestEgg", 1, FIRST)

		expect(result.state.dailyQuests[1].progress).toBe(1)
	end)

	it("play time counts minutes", function()
		local r = rulesWith({ "PlayMinutes" })

		local result = r.addPlayTime(withQuests(r), 90, NOW)

		expect(result.state.dailyQuests[1].progress).toBe(1.5)
	end)

	it("a delivery counts, coin deliveries also as earned coins", function()
		local r = rulesWith({ "Deliveries", "EarnCoins" })
		local state = withQuests(r)
		state.pizza = { "Salami" }
		state.delivery = {
			order = {
				worldId = "PizzeriaGarden",
				toppings = { Salami = 1 },
				reward = "Gems",
				gems = 3,
				expiresAt = NOW + 60,
			},
		}

		local result = r.deliverOrder(state, NOW)

		expect(result.ok).toBe(true)
		local byKind = {}
		for _, quest in result.state.dailyQuests do
			byKind[quest.kind] = quest.progress
		end
		expect(byKind.Deliveries).toBe(1)
		expect(byKind.EarnCoins).toBe(0)
	end)

	it("unlocking a world counts", function()
		local r = rulesWith({ "UnlockWorld" })
		local state = withQuests(r)
		state.coins = 1500

		local result = r.unlockWorld(state, "Farm")

		expect(result.state.dailyQuests[1].progress).toBe(1)
	end)

	it("a lucky wheel spin counts", function()
		local r = rulesWith({ "SpinWheel" })

		local result = r.spinWheel(withQuests(r), NOW, sequenceRandom({ 0.3 }))

		expect(result.ok).toBe(true)
		expect(result.state.dailyQuests[1].progress).toBe(1)
	end)

	it("never goes past the goal and counts weekly quests too", function()
		local r = rulesWith({ "SellPizzas" })
		local state = withQuests(r)

		local result = r.questProgress(state, "SellPizzas", 1000)

		expect(result.ok).toBe(true)
		expect(result.state.dailyQuests[1].progress).toBe(2)
		expect(result.state.weeklyQuests[1].progress).toBe(10)
	end)

	it("later features report progress through questProgress", function()
		local state = withQuests(rulesWith({ "SellPizzas" }))

		expect(rules.questProgress(state, "OpenChest", 1).ok).toBe(true)
		expect(rules.questProgress(state, "OpenChest", 1).state).toBe(state) -- no chest quest
		expect(rules.questProgress(state, "Dance", 1).reason).toBe("UnknownQuestKind")
		for _, amount in { 0, -1, 0 / 0, math.huge } do
			expect(rules.questProgress(state, "SellPizzas", amount).reason).toBe("InvalidAmount")
		end
	end)

	it("claimed quests get no more progress", function()
		local r = rulesWith({ "SellPizzas" })
		local state = r.completeQuest(withQuests(r), "Daily", 1).state
		state = r.claimQuest(state, "Daily", 1, NOW).state

		local result = r.questProgress(state, "SellPizzas", 1)

		expect(result.state.dailyQuests[1].progress).toBe(2)
		expect(result.state.dailyQuests[1].claimed).toBe(true)
	end)
end)

describe("claiming quests", function()
	local r = rulesWith({ "SellPizzas", "PlayMinutes", "OpenEggs" })
	-- First draws: kinds, then gems for every reward (0 < 0.5).
	local state = withQuests(r)

	it("refuses unfinished and unknown quests", function()
		expect(r.claimQuest(state, "Daily", 1, NOW).reason).toBe("QuestNotDone")
		expect(r.claimQuest(state, "Daily", 9, NOW).reason).toBe("UnknownQuest")
		expect(r.claimQuest(state, "Monthly", 1, NOW).reason).toBe("UnknownQuest")
	end)

	it("pays the reward of a finished quest once", function()
		local done = r.completeQuest(state, "Daily", 1).state

		local result = r.claimQuest(done, "Daily", 1, NOW)

		expect(result.ok).toBe(true)
		expect(result.rewards).toEqual({ { kind = "Gems", amount = 8 } })
		expect(result.state.gems).toBe(8)
		expect(result.state.dailyQuests[1].claimed).toBe(true)
		expect(r.claimQuest(result.state, "Daily", 1, NOW).reason).toBe("QuestClaimed")
	end)

	it("pays potion rewards into the potion inventory", function()
		local potionState = r.refreshQuests(r.newPlayerState(), NOW, sequenceRandom({ 0, 0.9, 0.5 })).state
		local potionId = potionState.dailyQuests[1].reward.potionId
		local done = r.completeQuest(potionState, "Daily", 1).state

		local result = r.claimQuest(done, "Daily", 1, NOW)

		expect(result.state.potions[potionId]).toBe(1)
	end)

	it("pays weekly rewards", function()
		local done = r.completeQuest(state, "Weekly", 1).state

		local result = r.claimQuest(done, "Weekly", 1, NOW)

		expect(result.state.gems).toBe(30)
	end)

	it("yesterday's quests cannot be claimed any more", function()
		local done = r.completeQuest(state, "Daily", 1).state

		expect(r.claimQuest(done, "Daily", 1, NEXT_DAY).reason).toBe("QuestsExpired")
		expect(r.claimQuest(r.completeQuest(state, "Weekly", 1).state, "Weekly", 1, NEXT_MONDAY).reason).toBe(
			"QuestsExpired"
		)
	end)
end)

describe("rerolling quests", function()
	local r = rulesWith({ "SellPizzas", "PlayMinutes", "OpenEggs", "Deliveries" })
	local state = withQuests(r)

	it("replaces a quest by a kind not in today's quests, the first one free", function()
		local result = r.rerollQuest(state, 1, NOW, FIRST)

		expect(result.ok).toBe(true)
		expect(result.state.gems).toBe(0)
		expect(result.state.questRerolls).toBe(1)
		expect(kindsOf(result.state.dailyQuests)).toEqual({ "Deliveries", "OpenEggs", "PlayMinutes" })
	end)

	it("costs 10 gems after the free one", function()
		local once = r.rerollQuest(state, 1, NOW, FIRST).state
		expect(r.rerollQuest(once, 2, NOW, FIRST).reason).toBe("NotEnoughGems")
		once.gems = 15

		local result = r.rerollQuest(once, 2, NOW, FIRST)

		expect(result.ok).toBe(true)
		expect(result.state.gems).toBe(5)
		expect(r.questStatus(once, NOW).rerollPrice).toBe(10)
		expect(r.questStatus(state, NOW).rerollPrice).toBe(0)
	end)

	it("is free again on the next day", function()
		local once = r.rerollQuest(state, 1, NOW, FIRST).state
		local nextDay = r.refreshQuests(once, NEXT_DAY, FIRST).state

		expect(r.questStatus(nextDay, NEXT_DAY).rerollPrice).toBe(0)
	end)

	it("refuses finished quests and when no other kind is left", function()
		local done = r.completeQuest(state, "Daily", 1).state
		expect(r.rerollQuest(done, 1, NOW, FIRST).reason).toBe("QuestDone")

		local small = rulesWith({ "SellPizzas", "PlayMinutes", "OpenEggs" })
		expect(small.rerollQuest(withQuests(small), 1, NOW, FIRST).reason).toBe("NoOtherQuest")
		expect(r.rerollQuest(state, 1, NEXT_DAY, FIRST).reason).toBe("QuestsExpired")
	end)
end)

describe("bonus chest and streak", function()
	local r = rulesWith({ "SellPizzas", "PlayMinutes", "OpenEggs" })

	it("opens once all daily quests are done, once a day", function()
		local state = withQuests(r)
		expect(r.claimQuestBonus(state, NOW, FIRST).reason).toBe("BonusNotReady")

		local result = r.claimQuestBonus(allDone(r, state), NOW, FIRST)

		expect(result.ok).toBe(true)
		expect(result.state.gems).toBe(20)
		expect(result.rewards[1]).toEqual({ kind = "Gems", amount = 20 })
		expect(result.rewards[2].kind).toBe("Potion")
		expect(result.state.potions[result.rewards[2].potionId]).toBe(1)
		expect(result.streak).toBe(1)
		expect(result.streakChest).toBe(false)
		expect(r.claimQuestBonus(result.state, NOW, FIRST).reason).toBe("BonusClaimed")
	end)

	-- Plays `days` days in a row from `start` with every bonus chest claimed.
	local function playDays(state, start: number, days: number)
		local out = state
		local last
		for day = 0, days - 1 do
			local now = start + day * DAY
			out = r.refreshQuests(out, now, FIRST).state
			last = r.claimQuestBonus(allDone(r, out), now, FIRST)
			out = last.state
		end
		return out, last
	end

	it("pays the streak chest on the streak day in a row (TestConfig: 3) and starts over", function()
		local state, last = playDays(r.newPlayerState(), NOW, 3)

		expect(last.streak).toBe(3)
		expect(last.streakChest).toBe(true)
		-- 3 x 20 bonus + 100 streak gems; streak potion is Speed in TestConfig.
		expect(state.gems).toBe(160)
		expect(last.rewards[3]).toEqual({ kind = "Gems", amount = 100 })
		expect(last.rewards[4]).toEqual({ kind = "Potion", amount = 1, potionId = "Speed" })
		expect(r.questStatus(state, NOW + 2 * DAY).streak.days).toBe(3)

		local _, again = playDays(state, NOW + 3 * DAY, 1)
		expect(again.streak).toBe(1)
		expect(again.streakChest).toBe(false)
	end)

	it("a missed day breaks the streak", function()
		local state = playDays(r.newPlayerState(), NOW, 2)

		expect(r.questStatus(state, NOW + 2 * DAY).streak.days).toBe(2)
		expect(r.questStatus(state, NOW + 3 * DAY).streak.days).toBe(0)
		local _, last = playDays(state, NOW + 3 * DAY, 1)
		expect(last.streak).toBe(1)
	end)
end)

describe("quest status", function()
	local r = rulesWith({ "SellPizzas", "PlayMinutes", "OpenEggs" })

	it("shows the quests, what is ready and when they end", function()
		local state = r.completeQuest(withQuests(r), "Daily", 2).state

		local status = r.questStatus(state, NOW)

		expect(#status.daily).toBe(3)
		expect(status.daily[2].status).toBe("Ready")
		expect(status.daily[1].status).toBe("Running")
		expect(status.readyCount).toBe(1)
		expect(status.bonus.status).toBe("Waiting")
		expect(status.streak).toEqual({
			days = 0,
			goal = 3,
			rewards = { { kind = "Gems", amount = 100 }, { kind = "Potion", amount = 1 } },
		})
		-- 11:00 CET -> 13 hours to midnight; Thursday -> 3 days and 13 hours to Monday.
		expect(status.dailySecondsLeft).toBe(13 * 3600)
		expect(status.weeklySecondsLeft).toBe(3 * DAY + 13 * 3600)
	end)

	it("counts a ready bonus chest as ready", function()
		local status = r.questStatus(allDone(r, withQuests(r)), NOW)

		expect(status.bonus.status).toBe("Ready")
		expect(status.readyCount).toBe(4)
	end)

	it("hides outdated quests", function()
		local status = r.questStatus(withQuests(r), NEXT_MONDAY)

		expect(#status.daily).toBe(0)
		expect(#status.weekly).toBe(0)
	end)
end)

describe("quests and saving", function()
	it("are kept on rebirth", function()
		local state = withQuests()
		state.coins = 1000

		local result = rules.rebirth(state, NOW)

		expect(result.state.dailyQuests).toBe(state.dailyQuests)
		expect(result.state.questDay).toBe(state.questDay)
	end)

	it("old saves without quests load with none", function()
		local old = rules.newPlayerState()
		for _, field in { "questDay", "dailyQuests", "questRerolls", "questBonusClaimed", "questStreak" } do
			old[field] = nil
		end
		old.questStreakDay = nil
		old.questWeekDay = nil
		old.weeklyQuests = nil

		local loaded = SaveData.load(old, rules.newPlayerState())

		expect(loaded.ok).toBe(true)
		expect(loaded.state.questDay).toBe(0)
		expect(#loaded.state.dailyQuests).toBe(0)
	end)
end)

describe("quests in the real config", function()
	local GameConfig = require("../src/shared/GameConfig")
	local Texts = require("../src/shared/Texts")

	it("every quest kind has a text in both languages and a known feature switch", function()
		for _, kind in GameConfig.quests.kinds do
			local text = Texts.strings[`quests.kind.{kind.id}`]
			expect(text ~= nil and text.de ~= nil and text.en ~= nil).toBe(true)
			if kind.feature then
				expect(GameConfig.features[kind.feature] ~= nil).toBe(true)
			end
			expect(kind.daily ~= nil or kind.weekly ~= nil).toBe(true)
		end
	end)

	it("a new player gets 3 daily and 3 weekly quests from the real config", function()
		local real = GameRules.new(GameConfig)

		local state = real.refreshQuests(real.newPlayerState(), NOW, sequenceRandom({ 0.3, 0.6, 0.9, 0.1 })).state

		expect(#state.dailyQuests).toBe(3)
		expect(#state.weeklyQuests).toBe(3)
	end)
end)
