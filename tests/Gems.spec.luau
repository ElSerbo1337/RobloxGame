local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local SaveData = require("../src/shared/SaveData")
local ToppingField = require("../src/shared/ToppingField")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

local function player(coins: number, gems: number)
	local state = rules.newPlayerState()
	state.coins = coins
	state.gems = gems
	return state
end

local function withPets(state, count: number)
	for _ = 1, count do
		state = rules.openEgg(state, "TestEgg", TestKit.sequenceRandom({ 0 })).state
	end
	return state
end

-- TestConfig with gem toppings switched on (1 in 10 spawns).
local gemConfig = table.clone(TestConfig)
gemConfig.gems = table.clone(TestConfig.gems)
gemConfig.gems.toppingChance = 0.1

describe("gems", function()
	it("a new player starts with 0 gems", function()
		expect(rules.newPlayerState().gems).toBe(0)
	end)

	it("an old save without gems loads with 0 gems", function()
		local loaded = SaveData.load({ version = 2, coins = 5, pizza = {} }, rules.newPlayerState()).state

		expect(loaded.gems).toBe(0)
	end)
end)

describe("gem topping", function()
	it("spawns rarely: a gem roll below the chance makes a gem topping with 1-3 gems", function()
		-- Per spawn: gem roll, then (gem amount | kind), x, z.
		local field = ToppingField.new(
			gemConfig,
			"PizzeriaGarden",
			TestKit.sequenceRandom({
				0.05,
				0.99,
				0.1,
				0.2, -- slot 1: gem, amount roll 0.99 -> 3 gems
				0.1,
				0,
				0.3,
				0.4, -- slot 2: no gem (0.1 is not below 0.1), kind roll 0 -> Salami
				0,
				0,
				0.5,
				0.6, -- slot 3: gem, amount roll 0 -> 1 gem
				0.5,
				0.95,
				0.7,
				0.8, -- slot 4: no gem, Mozzarella
			})
		)

		expect(field:get(1)).toEqual({ toppingId = "Gem", gems = 3, x = 0.1, z = 0.2 })
		expect(field:get(2)).toEqual({ toppingId = "Salami", x = 0.3, z = 0.4 })
		expect(field:get(3)).toEqual({ toppingId = "Gem", gems = 1, x = 0.5, z = 0.6 })
		expect(field:get(4).toppingId).toBe("Mozzarella")
	end)

	it("collecting a gem topping adds its gems and leaves the pizza alone", function()
		local result = rules.collectTopping(player(0, 4), "Gem", 5, 2)

		expect(result.ok).toBe(true)
		expect(result.gemsEarned).toBe(2)
		expect(result.state.gems).toBe(6)
		expect(result.state.pizza).toEqual({})
	end)

	it("a gem topping can be collected even with a full pizza", function()
		local state = rules.collectTopping(rules.newPlayerState(), "Salami", 1).state
		state = rules.collectTopping(state, "Salami", 1).state

		local result = rules.collectTopping(state, "Gem", 1, 1)

		expect(result.ok).toBe(true)
		expect(result.state.gems).toBe(1)
	end)

	it("a gem topping must be in range, also when walking over it", function()
		expect(rules.collectTopping(player(0, 0), "Gem", 11, 1).reason).toBe("OutOfRange")

		local auto = rules.setAutoCollect(player(0, 0), true).state
		expect(rules.autoCollectTopping(auto, "Gem", 2, 3).state.gems).toBe(3)
		expect(rules.autoCollectTopping(auto, "Gem", 4, 3).reason).toBe("OutOfRange")
		expect(rules.autoCollectTopping(player(0, 0), "Gem", 1, 3).reason).toBe("AutoCollectOff")
	end)

	it("clamps the gem amount to the configured 1-3", function()
		expect(rules.collectTopping(player(0, 0), "Gem", 1, 50).state.gems).toBe(3)
		expect(rules.collectTopping(player(0, 0), "Gem", 1, nil).state.gems).toBe(1)
	end)
end)

describe("gem counter upgrades", function()
	it("are paid with gems, not coins", function()
		local result = rules.buyUpgrade(player(1000, 60), "GemShop", "PetSlots")

		expect(result.ok).toBe(true)
		expect(result.state.gems).toBe(10)
		expect(result.state.coins).toBe(1000)
	end)

	it("are rejected without enough gems, however many coins", function()
		local result = rules.buyUpgrade(player(100000, 49), "GemShop", "PetSlots")

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("NotEnoughGems")
		expect(result.state.gems).toBe(49)
	end)

	it("coin upgrades still cost coins only", function()
		local result = rules.buyUpgrade(player(10, 500), "GemShop", "PizzaSpace")

		expect(result.state.coins).toBe(0)
		expect(result.state.gems).toBe(500)
	end)

	it("are staged per shop like coin upgrades", function()
		local state = rules.buyUpgrade(player(0, 1000), "GemShop", "PetSlots").state

		expect(rules.buyUpgrade(state, "GemShop", "PetSlots").reason).toBe("ShopLevelLimit")
		expect(rules.petSlots(rules.buyUpgrade(state, "BigShop", "PetSlots").state)).toBe(5)
	end)

	it("pet slots let the player equip more pets", function()
		local state = withPets(player(100, 50), 4)
		for uid = 1, 3 do
			state = rules.equipPet(state, uid).state
		end
		expect(rules.equipPet(state, 4).reason).toBe("PetSlotsFull")

		state = rules.buyUpgrade(state, "GemShop", "PetSlots").state

		expect(rules.petSlots(state)).toBe(4)
		expect(rules.equipPet(state, 4).ok).toBe(true)
	end)

	it("inventory space lets the player own more pets", function()
		local state = withPets(player(100, 30), 5)
		expect(rules.openEgg(state, "TestEgg", TestKit.sequenceRandom({ 0 })).reason).toBe("InventoryFull")

		state = rules.buyUpgrade(state, "GemShop", "InventorySpace").state

		expect(rules.inventorySlots(state)).toBe(7)
		expect(rules.openEgg(state, "TestEgg", TestKit.sequenceRandom({ 0 })).ok).toBe(true)
	end)

	it("walk speed starts at the configured speed and grows with the upgrade", function()
		expect(rules.walkSpeed(rules.newPlayerState())).toBe(16)

		local state = rules.buyUpgrade(player(0, 40), "GemShop", "WalkSpeed").state

		expect(rules.walkSpeed(state)).toBe(20)
	end)

	it("the shop menu tells coin and gem offers apart", function()
		local offers = rules.shopOffers(player(0, 0), "GemShop")

		expect(offers[1].currency).toBe("Coins")
		expect(offers[2].currency).toBe("Gems")
		expect(offers[2].value).toBe(3)
		expect(offers[2].nextPrice).toBe(50)
		expect(offers[5].upgrade).toBe("TripleOpen")
		expect(offers[5].value).toBe(1)
	end)
end)

describe("open 3 eggs at once", function()
	local function tripleOpener(coins: number)
		return rules.buyUpgrade(player(coins, 150), "GemShop", "TripleOpen").state
	end

	it("is locked until bought", function()
		local state = player(100, 0)

		expect(rules.eggsPerOpen(state)).toBe(1)
		local result = rules.openEggs(state, "TestEgg", 3, TestKit.sequenceRandom({ 0 }))
		expect(result.ok).toBe(false)
		expect(result.reason).toBe("MultiOpenLocked")
		expect(result.state.coins).toBe(100)
	end)

	it("after buying, opens 3 eggs for 3 times the price", function()
		local state = tripleOpener(35)
		expect(rules.eggsPerOpen(state)).toBe(3)

		local result = rules.openEggs(state, "TestEgg", 3, TestKit.sequenceRandom({ 0, 0.8, 0.999 }))

		expect(result.ok).toBe(true)
		expect(result.state.coins).toBe(5)
		expect(#result.pets).toBe(3)
		expect(result.pets[1].petId).toBe("Hamster")
		expect(result.pets[2].petId).toBe("Cat")
		expect(result.pets[3].petId).toBe("Dragon")
		expect(#result.state.pets).toBe(3)
		expect(result.state.nextPetUid).toBe(4)
	end)

	it("still allows opening a single egg", function()
		local result = rules.openEggs(tripleOpener(10), "TestEgg", 1, TestKit.sequenceRandom({ 0 }))

		expect(result.ok).toBe(true)
		expect(#result.pets).toBe(1)
	end)

	it("needs coins for all 3 eggs", function()
		local result = rules.openEggs(tripleOpener(29), "TestEgg", 3, TestKit.sequenceRandom({ 0 }))

		expect(result.reason).toBe("NotEnoughCoins")
		expect(result.state.pets).toEqual({})
	end)

	it("needs free inventory slots for all 3 pets", function()
		local state = withPets(tripleOpener(100), 3)

		local result = rules.openEggs(state, "TestEgg", 3, TestKit.sequenceRandom({ 0 }))

		expect(result.reason).toBe("InventoryFull")
		expect(#result.state.pets).toBe(3)
	end)

	it("rejects other counts", function()
		local state = tripleOpener(100)
		for _, count in { 0, 2, 4, 1.5, -3 } do
			expect(rules.openEggs(state, "TestEgg", count, TestKit.sequenceRandom({ 0 })).reason).toBe("InvalidCount")
		end
	end)
end)
