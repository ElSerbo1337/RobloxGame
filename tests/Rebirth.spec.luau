local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local SaveData = require("../src/shared/SaveData")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect
local sequenceRandom = TestKit.sequenceRandom

local rules = GameRules.new(TestConfig)

-- TestConfig rebirth: start price 1000, x3 per rebirth, +0.5 coin multiplier per rebirth.

-- A player who finished the tutorial, has `coins` and reached world 2.
local function player(coins: number)
	local state = rules.newPlayerState()
	state.tutorialStep = 1000
	state.coins = coins
	state.unlockedWorlds = { "Farm" }
	return state
end

describe("rebirth offer", function()
	it("shows price, current and next multiplier and the progress towards the price", function()
		local offer = rules.rebirthOffer(player(250))

		expect(offer.rebirths).toBe(0)
		expect(offer.price).toBe(1000)
		expect(offer.multiplier).toBe(1)
		expect(offer.nextMultiplier).toBe(1.5)
		expect(offer.progress).toBe(0.25)
		expect(offer.affordable).toBe(false)
		expect(offer.potionWarning).toBe(false)
	end)

	it("is affordable with enough coins; progress never goes past 1", function()
		local offer = rules.rebirthOffer(player(5000))

		expect(offer.affordable).toBe(true)
		expect(offer.progress).toBe(1)
	end)

	it("warns while a potion is running", function()
		local state = player(0)
		state.activePotions = { Coins = 120 }

		expect(rules.rebirthOffer(state).potionWarning).toBe(true)
	end)

	it("gets more expensive with every rebirth", function()
		local state = player(0)
		state.rebirths = 2

		local offer = rules.rebirthOffer(state)
		expect(offer.price).toBe(9000)
		expect(offer.multiplier).toBe(2)
		expect(offer.nextMultiplier).toBe(2.5)
	end)
end)

describe("doing a rebirth", function()
	it("is rejected with too few coins and changes nothing", function()
		local state = player(999)

		local result = rules.rebirth(state, 0)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("NotEnoughCoins")
		expect(result.state).toBe(state)
	end)

	it("counts the rebirth and resets coins, coin upgrades, worlds, pizza and last world", function()
		local state = player(1500)
		state.upgrades = { PizzaSpace = 2, CollectRange = 1, Magnet = 1, PetSlots = 1, WalkSpeed = 2 }
		state.pizza = { "Salami", "Ham" }
		state.lastWorldId = "Farm"

		local result = rules.rebirth(state, 0)

		expect(result.ok).toBe(true)
		local after = result.state
		expect(after.rebirths).toBe(1)
		expect(after.coins).toBe(0)
		expect(after.upgrades).toEqual({ PetSlots = 1, WalkSpeed = 2 })
		expect(after.unlockedWorlds).toEqual({})
		expect(after.pizza).toEqual({})
		expect(after.lastWorldId).toBe("")
		expect(rules.spawnWorld(after)).toBe(nil)
	end)

	it("keeps pets, gems, gem upgrades, potion inventory and the tutorial", function()
		local state = player(1000)
		state.pets = { { uid = 1, petId = "Cat" }, { uid = 2, petId = "Dragon" } }
		state.nextPetUid = 3
		state.equipped = { 2 }
		state.gems = 77
		state.upgrades = { InventorySpace = 1, TripleOpen = 1 }
		state.potions = { Luck = 2, Speed = 1 }
		state.autoCollect = true

		local after = rules.rebirth(state, 0).state

		expect(after.pets).toEqual(state.pets)
		expect(after.nextPetUid).toBe(3)
		expect(after.equipped).toEqual({ 2 })
		expect(after.gems).toBe(77)
		expect(after.upgrades).toEqual({ InventorySpace = 1, TripleOpen = 1 })
		expect(after.potions).toEqual({ Luck = 2, Speed = 1 })
		expect(after.tutorialStep).toBe(1000)
		expect(after.autoCollect).toBe(true)
	end)

	it("ends running potions but keeps the potions in the inventory", function()
		local state = player(1000)
		state.activePotions = { Coins = 300, Speed = 20 }
		state.potions = { Coins = 1 }

		local after = rules.rebirth(state, 0).state

		expect(after.activePotions).toEqual({})
		expect(rules.potionCoinMultiplier(after)).toBe(1)
		expect(after.potions).toEqual({ Coins = 1 })
	end)

	it("cancels a ringing call and a running order; the phone rings again after a call interval", function()
		local state = player(1000)
		state = rules.ringPhone(state, 0, sequenceRandom({ 0, 0, 0, 0 })).state
		state = rules.acceptOrder(state, 10).state
		state.coins = 1000

		local after = rules.rebirth(state, 50).state

		expect(rules.activeOrder(after)).toBe(nil)
		expect(rules.deliveryCall(after)).toBe(nil)
		expect(rules.ringPhone(after, 50 + 119, sequenceRandom({ 0, 0, 0, 0 })).reason).toBe("PhoneNotReady")
		expect(rules.ringPhone(after, 50 + 120, sequenceRandom({ 0, 0, 0, 0 })).ok).toBe(true)

		local ringing = rules.ringPhone(player(1000), 0, sequenceRandom({ 0, 0, 0, 0 })).state
		expect(rules.deliveryCall(rules.rebirth(ringing, 5).state)).toBe(nil)
	end)

	it("pays the rising price: the second rebirth costs 3000", function()
		local state = rules.rebirth(player(1000), 0).state
		state.coins = 2999
		expect(rules.rebirth(state, 0).reason).toBe("NotEnoughCoins")

		state.coins = 3000
		local result = rules.rebirth(state, 0)
		expect(result.ok).toBe(true)
		expect(result.state.rebirths).toBe(2)
		expect(rules.rebirthMultiplier(result.state)).toBe(2)
	end)

	it("does not change the old state", function()
		local state = player(1000)
		state.pizza = { "Salami" }

		rules.rebirth(state, 0)

		expect(state.coins).toBe(1000)
		expect(state.pizza).toEqual({ "Salami" })
		expect(state.rebirths).toBe(0)
	end)
end)

describe("rebirth multiplier", function()
	local function reborn(times: number)
		-- Only world 1 (Salami, Mushroom, Mozzarella), so delivery draws are easy to follow.
		local state = player(0)
		state.unlockedWorlds = {}
		state.rebirths = times
		return state
	end

	it("is 1 + 0.5 per rebirth and part of the coin multiplier (times the pet bonus)", function()
		expect(rules.rebirthMultiplier(reborn(0))).toBe(1)
		expect(rules.rebirthMultiplier(reborn(1))).toBe(1.5)
		expect(rules.rebirthMultiplier(reborn(3))).toBe(2.5)

		local state = reborn(2)
		state.pets = { { uid = 1, petId = "Cat" } }
		state.equipped = { 1 }
		-- (1 + 0.2) x 2
		expect(rules.coinMultiplier(state)).toBe(2.4)
	end)

	it("multiplies what selling at the oven pays", function()
		local state = reborn(1)
		state.pizza = { "Mozzarella", "Mushroom" } -- 5 + 2 = 7

		local result = rules.sellPizza(state)

		-- 7 x 1.5 = 10.5 -> 10
		expect(result.coinsEarned).toBe(10)
		expect(result.state.coins).toBe(10)
	end)

	it("multiplies the coin reward of a delivery", function()
		local function deliveredCoins(rebirths: number): number
			local state = reborn(rebirths)
			-- 2 toppings, both Salami (value 1), reward Coins.
			state = rules.ringPhone(state, 0, sequenceRandom({ 0, 0, 0, 0 })).state
			state = rules.acceptOrder(state, 0).state
			state.pizza = { "Salami", "Salami" }
			return rules.deliverOrder(state, 90).reward.amount
		end

		-- Half the time left: 2 x coinFactor 3 x speed 1.25 = 7.5 -> 7; x 2 after two rebirths = 15.
		expect(deliveredCoins(0)).toBe(7)
		expect(deliveredCoins(2)).toBe(15)
	end)

	it("does not touch gem rewards", function()
		local function deliveredGems(rebirths: number): number
			local state = reborn(rebirths)
			-- Reward roll 0.7 -> Gems, base 3 + floor(0 x 5) = 3.
			state = rules.ringPhone(state, 0, sequenceRandom({ 0, 0, 0, 0.7, 0 })).state
			state = rules.acceptOrder(state, 0).state
			state.pizza = { "Salami", "Salami" }
			return rules.deliverOrder(state, 90).reward.amount
		end

		expect(deliveredGems(3)).toBe(deliveredGems(0))
	end)
end)

describe("rebirth button hint", function()
	it("a new player has not opened the rebirth button yet (it pulses once affordable)", function()
		expect(rules.hasSeenHint(rules.newPlayerState(), "Rebirth")).toBe(false)
	end)

	it("opening the button once is remembered after saving and loading", function()
		local result = rules.markHintSeen(player(5000), "Rebirth")

		expect(result.ok).toBe(true)
		local loaded = SaveData.load(result.state, rules.newPlayerState()).state
		expect(rules.hasSeenHint(loaded, "Rebirth")).toBe(true)
	end)

	it("stays remembered after a rebirth", function()
		local seen = rules.markHintSeen(player(5000), "Rebirth").state

		local result = rules.rebirth(seen, 0)

		expect(result.ok).toBe(true)
		expect(rules.hasSeenHint(result.state, "Rebirth")).toBe(true)
	end)
end)
