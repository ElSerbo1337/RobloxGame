local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local SaveData = require("../src/shared/SaveData")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect
local sequenceRandom = TestKit.sequenceRandom

local rules = GameRules.new(TestConfig)

-- A player who finished the tutorial (the phone stays quiet during it).
local function player()
	local state = rules.newPlayerState()
	state.tutorialStep = 1000
	return state
end

-- Random draws when the phone rings, in this order:
-- 1. number of toppings (min..pizza space), 2. one draw per topping (spawn weights
-- of the highest unlocked world), 3. reward kind, 4. gem base or potion (if needed).
-- World 1 weights: Salami 6, Mushroom 3, Mozzarella 1 (of 10).

describe("phone calls", function()
	it("ringing offers an order with toppings of the player's world that fits the pizza", function()
		local result = rules.ringPhone(player(), 1000, sequenceRandom({ 0, 0.1, 0.7, 0 }))

		expect(result.ok).toBe(true)
		expect(rules.deliveryCall(result.state)).toEqual({
			worldId = "PizzeriaGarden",
			toppings = { Salami = 1, Mushroom = 1 },
			reward = "Coins",
		})
	end)

	it("uses the highest unlocked world and up to the bought pizza space", function()
		local state = player()
		state.unlockedWorlds = { "Farm" }
		state.upgrades = { PizzaSpace = 3 } -- pizza holds 6
		-- Count: 2 + floor(0.99 x 5) = 6. Farm weights: Onion 3, Ham 1 (of 4).
		local result = rules.ringPhone(state, 0, sequenceRandom({ 0.99, 0.1, 0.1, 0.1, 0.1, 0.9, 0.9, 0 }))

		local call = rules.deliveryCall(result.state)
		expect(call.worldId).toBe("Farm")
		expect(call.toppings).toEqual({ Onion = 4, Ham = 2 })
	end)

	it("never asks for more toppings than the pizza holds", function()
		for _, roll in { 0, 0.5, 0.999 } do
			local call = rules.deliveryCall(rules.ringPhone(player(), 0, sequenceRandom({ roll, 0 })).state)
			local total = 0
			for _, count in call.toppings do
				total += count
			end
			expect(total).toBe(2)
		end
	end)

	it("can reward gems (3 to 7 before the speed bonus) or a potion", function()
		-- Reward roll 0.7 of 100 -> Gems (60..85); gem base 3 + floor(0.99 x 5) = 7.
		local gems = rules.deliveryCall(rules.ringPhone(player(), 0, sequenceRandom({ 0, 0, 0, 0.7, 0.99 })).state)
		expect(gems.reward).toBe("Gems")
		expect(gems.gems).toBe(7)

		-- Reward roll 0.9 -> Potion; potions sorted by id: Coins, Luck, Speed -> 0.5 picks Luck.
		local potion = rules.deliveryCall(rules.ringPhone(player(), 0, sequenceRandom({ 0, 0, 0, 0.9, 0.5 })).state)
		expect(potion.reward).toBe("Potion")
		expect(potion.potionId).toBe("Luck")
	end)
end)

-- Rolls for a Coins order "1 Salami, 1 Mushroom" with the starting pizza.
local SALAMI_MUSHROOM = { 0, 0.1, 0.7, 0 }

local function ringing(state, now: number?)
	return rules.ringPhone(state or player(), now or 1000, sequenceRandom(SALAMI_MUSHROOM)).state
end

describe("when the phone rings", function()
	it("stays quiet during the tutorial, while a call waits, during an order and before its time", function()
		local inTutorial = rules.newPlayerState()
		local waiting = ringing()
		local delivering = rules.acceptOrder(ringing(), 1000).state
		local declined = rules.declineOrder(ringing(), 1000).state -- next ring at 1120
		local cases = {
			{ state = inTutorial, now = 0, reason = "TutorialRunning" },
			{ state = waiting, now = 1000, reason = "CallWaiting" },
			{ state = delivering, now = 1000, reason = "OrderActive" },
			{ state = declined, now = 1119, reason = "PhoneNotReady" },
		}
		for _, case in cases do
			local result = rules.ringPhone(case.state, case.now, sequenceRandom(SALAMI_MUSHROOM))

			expect(result.ok).toBe(false)
			expect(result.reason).toBe(case.reason)
			expect(result.state).toBe(case.state)
		end
		expect(rules.ringPhone(declined, 1120, sequenceRandom(SALAMI_MUSHROOM)).ok).toBe(true)
	end)
end)

describe("answering the phone", function()
	it("accepting turns the call into the active order with a 3 minute time limit", function()
		local result = rules.acceptOrder(ringing(), 1000)

		expect(result.ok).toBe(true)
		expect(rules.deliveryCall(result.state)).toBeNil()
		local order = rules.activeOrder(result.state)
		expect(order.toppings).toEqual({ Salami = 1, Mushroom = 1 })
		expect(order.expiresAt).toBe(1180)
		expect(rules.orderTimeLeft(result.state, 1030)).toBe(150)
	end)

	it("declining drops the call; the phone rings again after the call interval", function()
		local result = rules.declineOrder(ringing(), 1000)

		expect(result.ok).toBe(true)
		expect(rules.deliveryCall(result.state)).toBeNil()
		expect(rules.activeOrder(result.state)).toBeNil()
	end)

	it("cannot accept or decline without a ringing phone", function()
		local state = player()
		for _, answer in { rules.acceptOrder, rules.declineOrder } do
			local result = answer(state, 1000)

			expect(result.ok).toBe(false)
			expect(result.reason).toBe("NoCall")
			expect(result.state).toBe(state)
		end
	end)
end)

-- Accepted at 1000 (time is up at 1180), with the given rolls for the order.
local function delivering(rolls: { number }?, state: any?)
	state = rules.ringPhone(state or player(), 1000, sequenceRandom(rolls or SALAMI_MUSHROOM)).state
	return rules.acceptOrder(state, 1000).state
end

local function collect(state, ...: string)
	for _, toppingId in { ... } do
		state = rules.collectTopping(state, toppingId, 1).state
	end
	return state
end

describe("delivering at the van", function()
	it("the right toppings earn the reward and use up the pizza", function()
		local state = collect(delivering(), "Mushroom", "Salami")
		state.coins = 5

		local result = rules.deliverOrder(state, 1000)

		expect(result.ok).toBe(true)
		-- (1 + 2) x coin factor 3 x speed bonus 1.5 = 13.5 -> 13
		expect(result.reward).toEqual({ reward = "Coins", amount = 13 })
		expect(result.state.coins).toBe(18)
		expect(result.state.pizza).toEqual({})
		expect(rules.activeOrder(result.state)).toBeNil()
	end)

	it("is rejected with wrong, missing or extra toppings", function()
		local cases = {
			{ "Salami", "Salami" }, -- wrong
			{ "Salami" }, -- missing
		}
		for _, pizza in cases do
			local state = collect(delivering(), table.unpack(pizza))
			local result = rules.deliverOrder(state, 1000)

			expect(result.ok).toBe(false)
			expect(result.reason).toBe("WrongToppings")
			expect(result.state).toBe(state)
		end
		-- Extra: the order (Salami + Mushroom) plus one more topping, on a bigger pizza.
		local big = player()
		big.upgrades = { PizzaSpace = 1 } -- pizza holds 3
		local state = collect(delivering({ 0, 0.1, 0.7, 0 }, big), "Salami", "Mushroom", "Mozzarella")
		expect(rules.deliverOrder(state, 1000).reason).toBe("WrongToppings")
	end)

	it("cannot deliver without an order", function()
		local state = collect(player(), "Salami")
		local result = rules.deliverOrder(state, 1000)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("NoOrder")
	end)

	it("faster delivery gives more: the bonus shrinks with the time left", function()
		local state = collect(delivering(), "Salami", "Mushroom")

		-- Half the time left: 9 x 1.25 = 11.25 -> 11; last second: 9 x (1 + 0.5 / 180) -> 9.
		expect(rules.deliverOrder(state, 1090).reward.amount).toBe(11)
		expect(rules.deliverOrder(state, 1179).reward.amount).toBe(9)
		-- The HUD shows the same value before delivering.
		expect(rules.orderReward(state, 1090)).toEqual({ reward = "Coins", amount = 11 })
	end)

	it("coin rewards grow with pet bonus and coin potion, like selling", function()
		local state = player()
		state.coins = 10
		state = rules.openEgg(state, "TestEgg", sequenceRandom({ 0.8 })).state -- Cat +20 %
		state = rules.equipPet(state, 1).state
		state.potions = { Coins = 1 }
		state = rules.drinkPotion(state, "Coins").state
		state = collect(delivering(nil, state), "Salami", "Mushroom")

		-- 3 x 1.2 x 2 x 3 x 1.5 = 32.4 -> 32
		expect(rules.deliverOrder(state, 1000).reward.amount).toBe(32)
	end)

	it("coin rewards use the same capped pet bonus as selling in the van's world (#51)", function()
		local state = player()
		state.pets = { { uid = 1, petId = "Cow" } } -- +3, capped to +1.5 in world 1
		state.equipped = { 1 }
		state = collect(delivering(nil, state), "Salami", "Mushroom")

		-- 3 x 2.5 x 3 x 1.5 = 33.75 -> 33 in world 1; 3 x 4 x 3 x 1.5 = 54 in the Farm.
		expect(rules.deliverOrder(state, 1000, "PizzeriaGarden").reward.amount).toBe(33)
		expect(rules.orderReward(state, 1000, "PizzeriaGarden")).toEqual({ reward = "Coins", amount = 33 })
		expect(rules.deliverOrder(state, 1000, "Farm").reward.amount).toBe(54)
	end)

	it("gem rewards are 3 to 10: base x speed bonus, at most 10", function()
		-- Gem base 7 (roll 0.99) and 3 (roll 0).
		local seven = collect(delivering({ 0, 0.1, 0.7, 0.7, 0.99 }), "Salami", "Mushroom")
		local three = collect(delivering({ 0, 0.1, 0.7, 0.7, 0 }), "Salami", "Mushroom")

		local fast = rules.deliverOrder(seven, 1000)
		expect(fast.reward).toEqual({ reward = "Gems", amount = 10 })
		expect(fast.state.gems).toBe(10)
		expect(rules.deliverOrder(seven, 1090).reward.amount).toBe(9) -- 7 x 1.25 = 8.75 -> 9
		expect(rules.deliverOrder(three, 1179).reward.amount).toBe(3)
	end)

	it("potion rewards land in the potion inventory, two when delivered in the first half", function()
		local state = collect(delivering({ 0, 0.1, 0.7, 0.9, 0.5 }), "Salami", "Mushroom")

		local fast = rules.deliverOrder(state, 1090)
		expect(fast.reward).toEqual({ reward = "Potion", amount = 2, potionId = "Luck" })
		expect(rules.potionCount(fast.state, "Luck")).toBe(2)
		expect(rules.deliverOrder(state, 1091).reward.amount).toBe(1)
	end)
end)

describe("running out of time", function()
	it("an order expires when its time is up; the pizza stays and the phone rings again later", function()
		local state = collect(delivering(), "Salami")

		local early = rules.expireOrder(state, 1179)
		expect(early.ok).toBe(false)
		expect(early.reason).toBe("NotExpired")

		local result = rules.expireOrder(state, 1180)
		expect(result.ok).toBe(true)
		expect(rules.activeOrder(result.state)).toBeNil()
		expect(result.state.pizza).toEqual({ "Salami" })
		expect(rules.ringPhone(result.state, 1299, sequenceRandom(SALAMI_MUSHROOM)).reason).toBe("PhoneNotReady")
		expect(rules.ringPhone(result.state, 1300, sequenceRandom(SALAMI_MUSHROOM)).ok).toBe(true)
	end)

	it("an order cannot be delivered once its time is up", function()
		local state = collect(delivering(), "Salami", "Mushroom")
		local result = rules.deliverOrder(state, 1180)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("OrderExpired")
	end)

	it("without an order nothing expires", function()
		expect(rules.expireOrder(player(), 1000).reason).toBe("NoOrder")
	end)
end)

describe("the oven during an order", function()
	it("sells only the toppings the order does not need", function()
		local big = player()
		big.upgrades = { PizzaSpace = 2 } -- pizza holds 4
		-- Order: Salami + Mushroom (count roll 0 -> 2 toppings).
		local state = collect(delivering(nil, big), "Mozzarella", "Salami", "Salami", "Mushroom")

		local result = rules.sellPizza(state)

		expect(result.ok).toBe(true)
		expect(result.coinsEarned).toBe(6) -- Mozzarella 5 + the second Salami 1
		expect(result.state.pizza).toEqual({ "Salami", "Mushroom" })
		expect(rules.deliverOrder(result.state, 1000).ok).toBe(true)
	end)

	it("keeps a pizza that holds only ordered toppings", function()
		local state = collect(delivering(), "Salami")
		local result = rules.sellPizza(state)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("OrderToppingsOnly")
		expect(result.state).toBe(state)
	end)
end)

describe("delivery and saving", function()
	it("an old save without delivery data loads with a quiet phone and no order", function()
		local loaded = SaveData.load({ version = 3, coins = 5 }, rules.newPlayerState()).state

		expect(rules.deliveryCall(loaded)).toBeNil()
		expect(rules.activeOrder(loaded)).toBeNil()
	end)

	it("an accepted order survives saving and loading", function()
		local loaded = SaveData.load(delivering(), rules.newPlayerState()).state

		expect(rules.activeOrder(loaded).toppings).toEqual({ Salami = 1, Mushroom = 1 })
		expect(rules.orderTimeLeft(loaded, 1100)).toBe(80)
	end)
end)
