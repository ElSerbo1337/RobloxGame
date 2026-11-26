local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

local function richState(coins: number)
	local state = rules.newPlayerState()
	state.coins = coins
	return state
end

local function fixedRandom(value: number)
	return TestKit.sequenceRandom({ value })
end

describe("openEgg", function()
	it("draws pets according to the configured chances", function()
		-- Chances 70 / 29.5 / 0.5 -> boundaries at 0.70 and 0.995.
		expect(rules.openEgg(richState(10), "TestEgg", fixedRandom(0)).pet.petId).toBe("Hamster")
		expect(rules.openEgg(richState(10), "TestEgg", fixedRandom(0.69)).pet.petId).toBe("Hamster")
		expect(rules.openEgg(richState(10), "TestEgg", fixedRandom(0.71)).pet.petId).toBe("Cat")
		expect(rules.openEgg(richState(10), "TestEgg", fixedRandom(0.994)).pet.petId).toBe("Cat")
		expect(rules.openEgg(richState(10), "TestEgg", fixedRandom(0.996)).pet.petId).toBe("Dragon")
		expect(rules.openEgg(richState(10), "TestEgg", fixedRandom(0.99999)).pet.petId).toBe("Dragon")
	end)

	it("charges the egg price and adds the drawn pet to the inventory", function()
		local result = rules.openEgg(richState(25), "TestEgg", fixedRandom(0.8))

		expect(result.ok).toBe(true)
		expect(result.state.coins).toBe(15)
		expect(#result.state.pets).toBe(1)
		expect(result.state.pets[1].petId).toBe("Cat")
		expect(result.state.pets[1].uid).toBe(result.pet.uid)
	end)

	it("gives every opened pet its own uid", function()
		local state = rules.openEgg(richState(20), "TestEgg", fixedRandom(0)).state
		state = rules.openEgg(state, "TestEgg", fixedRandom(0)).state

		expect(state.pets[1].uid ~= state.pets[2].uid).toBe(true)
	end)

	it("rejects opening without enough coins and keeps the state unchanged", function()
		local result = rules.openEgg(richState(9), "TestEgg", fixedRandom(0))

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("NotEnoughCoins")
		expect(result.state.coins).toBe(9)
		expect(result.state.pets).toEqual({})
	end)

	it("rejects an egg that is not in the config", function()
		local result = rules.openEgg(richState(100), "GoldenEgg", fixedRandom(0))

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("UnknownEgg")
	end)
end)

-- Player with `count` Hamsters in the inventory (uids 1..count).
local function stateWithPets(count: number)
	local state = richState(10 * count)
	for _ = 1, count do
		state = rules.openEgg(state, "TestEgg", fixedRandom(0)).state
	end
	return state
end

describe("equipPet", function()
	it("equips an owned pet", function()
		local result = rules.equipPet(stateWithPets(1), 1)

		expect(result.ok).toBe(true)
		expect(result.state.equipped).toEqual({ 1 })
	end)

	it("limits equipped pets to the pet slots", function()
		local state = stateWithPets(4)
		for uid = 1, 3 do
			state = rules.equipPet(state, uid).state
		end

		local result = rules.equipPet(state, 4)

		expect(rules.petSlots(state)).toBe(3)
		expect(result.ok).toBe(false)
		expect(result.reason).toBe("PetSlotsFull")
		expect(result.state.equipped).toEqual({ 1, 2, 3 })
	end)

	it("rejects a pet the player does not own", function()
		local result = rules.equipPet(stateWithPets(1), 99)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("UnknownPet")
	end)

	it("does not equip the same pet twice", function()
		local state = rules.equipPet(stateWithPets(2), 1).state

		local result = rules.equipPet(state, 1)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("AlreadyEquipped")
		expect(result.state.equipped).toEqual({ 1 })
	end)
end)

describe("unequipPet", function()
	it("frees the slot so another pet can be equipped", function()
		local state = stateWithPets(4)
		for uid = 1, 3 do
			state = rules.equipPet(state, uid).state
		end

		state = rules.unequipPet(state, 2).state

		expect(state.equipped).toEqual({ 1, 3 })
		expect(rules.equipPet(state, 4).ok).toBe(true)
	end)

	it("rejects a pet that is not equipped", function()
		local result = rules.unequipPet(stateWithPets(1), 1)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("NotEquipped")
	end)
end)

describe("sellPizza with pets", function()
	local function pizzaWorth7(state)
		state = rules.collectTopping(state, "Mushroom", 1).state
		return rules.collectTopping(state, "Mozzarella", 1).state
	end

	it("multiplies the topping values by 1 + the sum of equipped pet bonuses", function()
		-- Hamster +10 % and Dragon +150 % -> x2.6; toppings worth 2 + 5 = 7 -> 18.2 -> 18
		local state = richState(20)
		state = rules.openEgg(state, "TestEgg", fixedRandom(0)).state
		state = rules.openEgg(state, "TestEgg", fixedRandom(0.999)).state
		state = rules.equipPet(state, 1).state
		state = rules.equipPet(state, 2).state
		state.coins = 0

		local result = rules.sellPizza(pizzaWorth7(state))

		expect(rules.coinMultiplier(state)).toBe(2.6)
		expect(result.coinsEarned).toBe(18)
		expect(result.state.coins).toBe(18)
	end)

	it("adds three +20 % pets up to +60 %", function()
		local state = richState(30)
		for uid = 1, 3 do
			state = rules.openEgg(state, "TestEgg", fixedRandom(0.8)).state
			state = rules.equipPet(state, uid).state
		end

		expect(rules.coinMultiplier(state)).toBe(1.6)
		-- 7 x 1.6 = 11.2 -> 11
		expect(rules.sellPizza(pizzaWorth7(state)).coinsEarned).toBe(11)
	end)

	it("counts every pet fully, whichever world the player is in (no pet cap, #57)", function()
		-- Dragon +150 % -> x2.5; toppings worth 7 -> 17.5 -> 17, in world 1 and in the Farm.
		local state = richState(20)
		state = rules.openEgg(state, "TestEgg", fixedRandom(0.999)).state
		state = rules.equipPet(state, 1).state
		state.coins = 0
		state.unlockedWorlds = { "Farm" }

		state.lastWorldId = ""
		expect(rules.sellPizza(pizzaWorth7(state)).coinsEarned).toBe(17)
		state.lastWorldId = "Farm"
		expect(rules.coinMultiplier(state)).toBe(2.5)
		expect(rules.sellPizza(pizzaWorth7(state)).coinsEarned).toBe(17)
	end)

	it("ignores pets that are owned but not equipped", function()
		local state = stateWithPets(3)
		state.coins = 0

		expect(rules.coinMultiplier(state)).toBe(1)
		expect(rules.sellPizza(pizzaWorth7(state)).coinsEarned).toBe(7)
	end)
end)

describe("eggPreview", function()
	it("lists every pet of the egg with rarity, chance in percent and bonus, rarest last", function()
		local preview = rules.eggPreview("TestEgg")

		expect(preview.price).toBe(10)
		expect(#preview.pets).toBe(3)
		expect(preview.pets[1]).toEqual({
			petId = "Hamster",
			rarity = "Common",
			chancePercent = 70,
			bonus = 0.1,
			boosted = false,
		})
		expect(preview.pets[3]).toEqual({
			petId = "Dragon",
			rarity = "Mythic",
			chancePercent = 0.5,
			bonus = 1.5,
			boosted = false,
		})
	end)
end)

describe("inventory limit", function()
	it("starts with the configured number of inventory slots", function()
		expect(rules.inventorySlots(rules.newPlayerState())).toBe(5)
	end)

	it("rejects opening an egg when the inventory is full and keeps coins and pets", function()
		local state = stateWithPets(5)
		state.coins = 100

		local result = rules.openEgg(state, "TestEgg", fixedRandom(0))

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("InventoryFull")
		expect(result.state.coins).toBe(100)
		expect(#result.state.pets).toBe(5)
	end)

	it("allows opening again after a pet was deleted", function()
		local state = rules.deletePet(stateWithPets(5), 3).state
		state.coins = 10

		local result = rules.openEgg(state, "TestEgg", fixedRandom(0))

		expect(result.ok).toBe(true)
		expect(#result.state.pets).toBe(5)
	end)
end)

describe("deletePet", function()
	it("removes the pet from the inventory", function()
		local result = rules.deletePet(stateWithPets(3), 2)

		expect(result.ok).toBe(true)
		expect(#result.state.pets).toBe(2)
		expect(result.state.pets[1].uid).toBe(1)
		expect(result.state.pets[2].uid).toBe(3)
	end)

	it("puts an equipped pet away when deleting it", function()
		local state = stateWithPets(3)
		state = rules.equipPet(state, 1).state
		state = rules.equipPet(state, 2).state

		local result = rules.deletePet(state, 1)

		expect(result.ok).toBe(true)
		expect(result.state.equipped).toEqual({ 2 })
		expect(rules.coinMultiplier(result.state)).toBe(1.1)
	end)

	it("never hands out a deleted pet's uid again", function()
		local state = rules.deletePet(stateWithPets(2), 2).state
		state.coins = 10

		local result = rules.openEgg(state, "TestEgg", fixedRandom(0))

		expect(result.pet.uid).toBe(3)
	end)

	it("rejects a pet the player does not own and keeps the state unchanged", function()
		local state = stateWithPets(1)

		local result = rules.deletePet(state, 42)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("UnknownPet")
		expect(#result.state.pets).toBe(1)
	end)

	it("does not change the old state", function()
		local state = rules.equipPet(stateWithPets(2), 1).state

		rules.deletePet(state, 1)

		expect(#state.pets).toBe(2)
		expect(state.equipped).toEqual({ 1 })
	end)
end)

describe("equipBest", function()
	-- Opens one egg per entry; 0 = Hamster (+10 %), 0.8 = Cat (+20 %), 0.999 = Dragon (+150 %).
	local function stateWithRolls(rolls: { number })
		local state = richState(10 * #rolls)
		for _, roll in rolls do
			state = rules.openEgg(state, "TestEgg", fixedRandom(roll)).state
		end
		return state
	end

	it("equips the pets with the highest bonus, up to the pet slots", function()
		-- uids: 1 Hamster, 2 Cat, 3 Dragon, 4 Hamster, 5 Cat
		local state = stateWithRolls({ 0, 0.8, 0.999, 0, 0.8 })

		local result = rules.equipBest(state)

		expect(result.ok).toBe(true)
		expect(result.state.equipped).toEqual({ 3, 2, 5 })
		expect(rules.coinMultiplier(result.state)).toBe(2.9)
	end)

	it("replaces weaker equipped pets", function()
		local state = stateWithRolls({ 0, 0, 0, 0.999 })
		for uid = 1, 3 do
			state = rules.equipPet(state, uid).state
		end

		local result = rules.equipBest(state)

		expect(result.state.equipped).toEqual({ 4, 1, 2 })
	end)

	it("keeps already equipped pets when bonuses are tied", function()
		-- Five Hamsters, 4 and 5 equipped: the best set is any three, keep 4 and 5.
		local state = stateWithRolls({ 0, 0, 0, 0, 0 })
		state = rules.equipPet(state, 5).state
		state = rules.equipPet(state, 4).state

		local result = rules.equipBest(state)

		expect(result.state.equipped).toEqual({ 4, 5, 1 })
	end)

	it("equips all pets when there are fewer pets than slots", function()
		local result = rules.equipBest(stateWithRolls({ 0, 0.8 }))

		expect(result.state.equipped).toEqual({ 2, 1 })
	end)

	it("rejects when the player has no pets", function()
		local result = rules.equipBest(rules.newPlayerState())

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("NoPets")
	end)

	it("does not change the old state", function()
		local state = stateWithRolls({ 0, 0.999 })

		rules.equipBest(state)

		expect(state.equipped).toEqual({})
	end)
end)
