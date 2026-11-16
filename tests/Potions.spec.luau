local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local SaveData = require("../src/shared/SaveData")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

local function player(gems: number)
	local state = rules.newPlayerState()
	state.gems = gems
	return state
end

describe("buying potions", function()
	it("a new player owns no potions", function()
		expect(rules.potionCount(rules.newPlayerState(), "Coins")).toBe(0)
	end)

	it("buying a potion at the gem counter pays gems and puts it into the potion inventory", function()
		local result = rules.buyPotion(player(30), "GemShop", "Coins")

		expect(result.ok).toBe(true)
		expect(result.state.gems).toBe(10)
		expect(rules.potionCount(result.state, "Coins")).toBe(1)
	end)

	it("buying again adds to the potions already owned", function()
		local state = rules.buyPotion(player(100), "GemShop", "Speed").state
		local result = rules.buyPotion(state, "GemShop", "Speed")

		expect(rules.potionCount(result.state, "Speed")).toBe(2)
		expect(result.state.gems).toBe(70)
	end)

	it("is rejected without enough gems, an unknown potion or shop, or where it is not sold", function()
		local cases = {
			{ shop = "GemShop", potion = "Luck", gems = 24, reason = "NotEnoughGems" },
			{ shop = "GemShop", potion = "Invisibility", gems = 100, reason = "UnknownPotion" },
			{ shop = "NoShop", potion = "Coins", gems = 100, reason = "UnknownShop" },
			{ shop = "SmallShop", potion = "Coins", gems = 100, reason = "NotOffered" },
		}
		for _, case in cases do
			local state = player(case.gems)
			local result = rules.buyPotion(state, case.shop, case.potion)

			expect(result.ok).toBe(false)
			expect(result.reason).toBe(case.reason)
			expect(result.state).toBe(state)
		end
	end)

	it("is rejected in a shop of a world the player has not unlocked", function()
		local result = rules.buyPotion(player(100), "BeachShop", "Coins")

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("WorldLocked")
	end)
end)

-- A player who owns `count` of a potion.
local function owning(potionId: string, count: number)
	local state = player(1000)
	for _ = 1, count do
		state = rules.buyPotion(state, "GemShop", potionId).state
	end
	state.gems = 0
	return state
end

describe("drinking potions", function()
	it("drinking takes the potion from the inventory and runs it for 10 minutes", function()
		local result = rules.drinkPotion(owning("Coins", 2), "Coins")

		expect(result.ok).toBe(true)
		expect(rules.potionCount(result.state, "Coins")).toBe(1)
		expect(rules.potionTimeLeft(result.state, "Coins")).toBe(600)
		expect(rules.potionTimeLeft(result.state, "Speed")).toBe(0)
	end)

	it("is rejected without that potion in the inventory, or for an unknown potion", function()
		local state = owning("Coins", 1)
		for potionId, reason in { Speed = "NoPotion", Invisibility = "UnknownPotion" } do
			local result = rules.drinkPotion(state, potionId)

			expect(result.ok).toBe(false)
			expect(result.reason).toBe(reason)
			expect(result.state).toBe(state)
		end
	end)

	it("counts down with passing time and ends when its time is up", function()
		local state = rules.drinkPotion(owning("Speed", 1), "Speed").state

		local later = rules.tickPotions(state, 599)
		expect(rules.potionTimeLeft(later.state, "Speed")).toBe(1)
		expect(later.expired).toEqual({})

		local ended = rules.tickPotions(later.state, 1)
		expect(rules.potionTimeLeft(ended.state, "Speed")).toBe(0)
		expect(ended.expired).toEqual({ "Speed" })
	end)

	it("drinking the same kind again extends the time instead of resetting it", function()
		local state = rules.drinkPotion(owning("Luck", 2), "Luck").state
		state = rules.tickPotions(state, 200).state

		local result = rules.drinkPotion(state, "Luck")

		expect(rules.potionTimeLeft(result.state, "Luck")).toBe(1000)
	end)

	it("different kinds run side by side", function()
		local both = rules.buyPotion(player(100), "GemShop", "Coins").state
		both = rules.buyPotion(both, "GemShop", "Speed").state
		both = rules.drinkPotion(both, "Coins").state
		both = rules.tickPotions(both, 100).state
		both = rules.drinkPotion(both, "Speed").state

		expect(rules.potionTimeLeft(both, "Coins")).toBe(500)
		expect(rules.potionTimeLeft(both, "Speed")).toBe(600)
	end)

	it("rejects an invalid amount of time", function()
		local state = rules.drinkPotion(owning("Coins", 1), "Coins").state
		for _, seconds in { -5, 0 / 0, math.huge } do
			local result = rules.tickPotions(state, seconds)

			expect(result.ok).toBe(false)
			expect(result.reason).toBe("InvalidTime")
		end
	end)
end)

-- Drinks `potionId` (bought for free) and returns the state.
local function drinking(state, potionId: string)
	state = table.clone(state)
	state.potions = table.clone(state.potions)
	state.potions[potionId] = (state.potions[potionId] or 0) + 1
	return rules.drinkPotion(state, potionId).state
end

describe("coin potion", function()
	local function withPizza(state)
		state = rules.collectTopping(state, "Mozzarella", 1).state
		return rules.collectTopping(state, "Mushroom", 1).state
	end

	it("doubles the coins from selling while it runs", function()
		local state = withPizza(drinking(rules.newPlayerState(), "Coins"))

		expect(rules.sellPizza(state).coinsEarned).toBe(14)
	end)

	it("stacks with pet bonuses: toppings x pets x potion", function()
		local state = rules.newPlayerState()
		state.coins = 10
		state = rules.openEgg(state, "TestEgg", TestKit.sequenceRandom({ 0.8 })).state -- Cat +20 %
		state = rules.equipPet(state, 1).state
		state = withPizza(drinking(state, "Coins"))

		-- 7 x 1.2 x 2 = 16.8 -> 16
		expect(rules.sellPizza(state).coinsEarned).toBe(16)
	end)

	it("pays normal coins again once its time is up", function()
		local state = rules.tickPotions(drinking(rules.newPlayerState(), "Coins"), 600).state

		expect(rules.sellPizza(withPizza(state)).coinsEarned).toBe(7)
	end)
end)

describe("speed potion", function()
	it("makes the player walk faster while it runs, on top of the walk speed upgrade", function()
		local state = player(40)
		expect(rules.walkSpeed(drinking(state, "Speed"))).toBe(24)

		state = rules.buyUpgrade(state, "GemShop", "WalkSpeed").state -- 20
		expect(rules.walkSpeed(drinking(state, "Speed"))).toBe(30)
	end)

	it("ends after its time", function()
		local state = rules.tickPotions(drinking(rules.newPlayerState(), "Speed"), 600).state

		expect(rules.walkSpeed(state)).toBe(16)
	end)
end)

describe("luck potion", function()
	-- TestEgg: Hamster 70 (Common), Cat 29.5 (Rare), Dragon 0.5 (Mythic).
	-- With luck: 70, 59, 1.5 -> total 130.5.
	it("shifts egg chances towards rarer pets", function()
		local lucky = drinking(player(0), "Luck")
		lucky.coins = 10

		-- Roll 0.55: without luck 0.55 x 100 = 55 -> Hamster; with luck 0.55 x 130.5 = 71.8 -> Cat.
		local plain = player(0)
		plain.coins = 10
		expect(rules.openEgg(plain, "TestEgg", TestKit.sequenceRandom({ 0.55 })).pet.petId).toBe("Hamster")
		expect(rules.openEgg(lucky, "TestEgg", TestKit.sequenceRandom({ 0.55 })).pet.petId).toBe("Cat")
		-- Roll 0.99: 0.99 x 130.5 = 129.2 -> past 70 + 59 = 129 -> Dragon (without luck: Cat).
		expect(rules.openEgg(plain, "TestEgg", TestKit.sequenceRandom({ 0.99 })).pet.petId).toBe("Cat")
		expect(rules.openEgg(lucky, "TestEgg", TestKit.sequenceRandom({ 0.99 })).pet.petId).toBe("Dragon")
	end)

	it("shows the shifted chances in the egg preview", function()
		local preview = rules.eggPreview("TestEgg", drinking(player(0), "Luck"))

		expect(preview.pets[1]).toEqual({ petId = "Hamster", rarity = "Common", chancePercent = 53.6398, bonus = 0.1 })
		expect(preview.pets[2].chancePercent).toBe(45.2107)
		expect(preview.pets[3].chancePercent).toBe(1.1494)
		-- Without a state (or without the potion) the configured chances stay.
		expect(rules.eggPreview("TestEgg").pets[3].chancePercent).toBe(0.5)
	end)

	it("ends after its time", function()
		local state = rules.tickPotions(drinking(player(0), "Luck"), 600).state
		state.coins = 10

		expect(rules.openEgg(state, "TestEgg", TestKit.sequenceRandom({ 0.99 })).pet.petId).toBe("Cat")
	end)
end)

describe("potions and saving", function()
	it("an old save without potions loads with an empty potion inventory and nothing running", function()
		local loaded = SaveData.load({ version = 3, coins = 5, gems = 7 }, rules.newPlayerState()).state

		expect(loaded.potions).toEqual({})
		expect(loaded.activePotions).toEqual({})
		expect(loaded.gems).toBe(7)
	end)

	it("owned potions and the time left of running potions survive saving and loading", function()
		local state = rules.buyPotion(player(100), "GemShop", "Coins").state
		state = rules.buyPotion(state, "GemShop", "Luck").state
		state = rules.tickPotions(rules.drinkPotion(state, "Luck").state, 120).state

		local loaded = SaveData.load(state, rules.newPlayerState()).state

		expect(rules.potionCount(loaded, "Coins")).toBe(1)
		expect(rules.potionTimeLeft(loaded, "Luck")).toBe(480)
	end)
end)

describe("potion offers", function()
	it("lists what a shop's gem counter sells with price and how many the player owns", function()
		local state = rules.buyPotion(player(100), "GemShop", "Speed").state

		expect(rules.potionOffers(state, "GemShop")).toEqual({
			{ potionId = "Coins", displayName = "Münz-Trank", price = 20, durationSeconds = 600, owned = 0 },
			{ potionId = "Luck", displayName = "Glücks-Trank", price = 25, durationSeconds = 600, owned = 0 },
			{ potionId = "Speed", displayName = "Speed-Trank", price = 15, durationSeconds = 600, owned = 1 },
		})
		expect(rules.potionOffers(state, "SmallShop")).toEqual({})
	end)
end)
