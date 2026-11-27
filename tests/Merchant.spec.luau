-- Travelling merchant (#107): schedule from the clock (every 2 h for 10 min, the same on
-- every server), offers for gems (Mega potion at half price, an egg with a higher Secret
-- chance, sometimes an exclusive pet) and buy limits per visit.
local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect
local sequenceRandom = TestKit.sequenceRandom

local config = table.clone(TestConfig)
config.potions = table.clone(TestConfig.potions)
config.potions.Mega = { displayName = "Mega-Trank", price = 120, durationSeconds = 600, includes = { "Coins" } }
config.pets = table.clone(TestConfig.pets)
config.pets.Ghost = { displayName = "Geist", rarity = "Secret", bonus = 5 }
config.pets.Camel = { displayName = "Kamel", rarity = "Mythic", bonus = 2, merchantPet = true }
config.secretPets = { chance = 0.01 }
config.worlds = table.clone(TestConfig.worlds)
config.worlds[1] = table.clone(TestConfig.worlds[1])
config.worlds[1].secretPet = "Ghost"
config.travelingMerchant = {
	periodSeconds = 7200,
	durationSeconds = 600,
	announceSeconds = 120,
	potion = { potionId = "Mega", priceFactor = 0.5, limit = 2 },
	egg = { price = 50, secretMultiplier = 10, limit = 3 },
	pet = { petId = "Camel", price = 300, chance = 0.35, limit = 1 },
}
local rules = GameRules.new(config)

-- A multiple of 2 h: a visit starts exactly here.
local VISIT = 7200 * 250000
local INDEX = 250000

local function rich(gems: number?)
	local state = rules.newPlayerState()
	state.gems = gems or 10000
	return state
end

-- First visit index from INDEX on with (or without) the exclusive pet.
local function visitWithPet(wanted: boolean): number
	for index = INDEX, INDEX + 100 do
		if rules.merchantStatus(index * 7200).pet == wanted then
			return index * 7200
		end
	end
	error("no such visit")
end

local function offer(state: any, now: number, id: string): any
	for _, entry in rules.merchantOffers(state, now) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

describe("Travelling merchant schedule", function()
	it("is there for 10 minutes every 2 hours, from the clock alone", function()
		local status = rules.merchantStatus(VISIT)
		expect(status.active).toBe(true)
		expect(status.visit).toBe(INDEX)
		expect(status.startsAt).toBe(VISIT)
		expect(status.endsAt).toBe(VISIT + 600)
		expect(rules.merchantStatus(VISIT + 599).active).toBe(true)
		local gone = rules.merchantStatus(VISIT + 600)
		expect(gone.active).toBe(false)
		expect(gone.visit).toBe(INDEX + 1)
		expect(gone.startsAt).toBe(VISIT + 7200)
		expect(rules.merchantStatus(VISIT - 1).active).toBe(false)
	end)

	it("announces the visit 2 minutes before", function()
		expect(rules.merchantStatus(VISIT - 121).announce).toBe(false)
		expect(rules.merchantStatus(VISIT - 120).announce).toBe(true)
		expect(rules.merchantStatus(VISIT - 1).announce).toBe(true)
		expect(rules.merchantStatus(VISIT).announce).toBe(false)
	end)

	it("brings the exclusive pet on some visits, the same for every server", function()
		local withPet = 0
		for index = 1, 1000 do
			local status = rules.merchantStatus(index * 7200)
			expect(rules.merchantStatus(index * 7200 + 300).pet).toBe(status.pet)
			if status.pet then
				withPet += 1
			end
		end
		expect(withPet > 250 and withPet < 450).toBe(true)
	end)

	it("comes right away for 10 minutes when the admin calls it, with the pet", function()
		local now = VISIT + 1000
		local status = rules.merchantStatus(now, now - 10)
		expect(status.active).toBe(true)
		expect(status.pet).toBe(true)
		expect(status.endsAt).toBe(now + 590)
		expect(rules.merchantStatus(now + 590, now - 10).active).toBe(false)
		local forced = rules.forceMerchant(rich(), now)
		expect(forced.ok).toBe(true)
		expect(rules.merchantStatus(now, forced.state.merchantForcedAt).active).toBe(true)
	end)

	it("never comes while the feature is switched off", function()
		local off = table.clone(config)
		off.features = { travelingMerchant = false }
		local offRules = GameRules.new(off)
		expect(offRules.merchantStatus(VISIT).active).toBe(false)
		expect(offRules.buyFromMerchant(rich(), "Potion", VISIT, sequenceRandom({ 0.5 })).reason).toBe("MerchantAway")
	end)
end)

describe("Travelling merchant offers", function()
	it("sells the Mega potion at half price, the egg of the best world and sometimes the pet", function()
		local now = visitWithPet(true)
		local potion = offer(rich(), now, "Potion")
		expect(potion.price).toBe(60)
		expect(potion.potionId).toBe("Mega")
		expect(potion.left).toBe(2)
		local egg = offer(rich(), now, "Egg")
		expect(egg.eggId).toBe("TestEgg")
		expect(egg.price).toBe(50)
		expect(egg.secretChance).toBe(0.1)
		local farm = rich()
		farm.unlockedWorlds = { "Farm", "Beach" }
		expect(offer(farm, now, "Egg").eggId).toBe("FarmTestEgg")
		expect(offer(rich(), now, "Pet").petId).toBe("Camel")
		expect(offer(rich(), visitWithPet(false), "Pet")).toBe(nil)
	end)

	it("has no offers while the merchant is away", function()
		expect(#rules.merchantOffers(rich(), VISIT + 700)).toBe(0)
	end)
end)

describe("Buying from the travelling merchant", function()
	it("pays gems and puts the potion into the potion inventory", function()
		local result = rules.buyFromMerchant(rich(100), "Potion", VISIT, sequenceRandom({ 0.5 }))
		expect(result.ok).toBe(true)
		expect(result.state.gems).toBe(40)
		expect(result.state.potions.Mega).toBe(1)
	end)

	it("refuses outside the visit, without gems and for unknown offers", function()
		expect(rules.buyFromMerchant(rich(), "Potion", VISIT + 600, sequenceRandom({ 0.5 })).reason).toBe(
			"MerchantAway"
		)
		expect(rules.buyFromMerchant(rich(59), "Potion", VISIT, sequenceRandom({ 0.5 })).reason).toBe("NotEnoughGems")
		expect(rules.buyFromMerchant(rich(), "Nope", VISIT, sequenceRandom({ 0.5 })).reason).toBe("NotOffered")
		expect(rules.buyFromMerchant(rich(), "Pet", visitWithPet(false), sequenceRandom({ 0.5 })).reason).toBe(
			"NotOffered"
		)
	end)

	it("limits the buys per visit and starts again with the next visit", function()
		local state = rich()
		for _ = 1, 2 do
			local result = rules.buyFromMerchant(state, "Potion", VISIT + 10, sequenceRandom({ 0.5 }))
			expect(result.ok).toBe(true)
			state = result.state
		end
		expect(rules.buyFromMerchant(state, "Potion", VISIT + 20, sequenceRandom({ 0.5 })).reason).toBe("SoldOut")
		expect(offer(state, VISIT + 20, "Potion").left).toBe(0)
		expect(offer(state, VISIT + 7200, "Potion").left).toBe(2)
		expect(rules.buyFromMerchant(state, "Potion", VISIT + 7200, sequenceRandom({ 0.5 })).ok).toBe(true)
	end)

	it("hatches the egg with ten times the Secret chance", function()
		-- 0.05 < 0.1 (10 x 1 %): the Secret pet.
		local secret = rules.buyFromMerchant(rich(), "Egg", VISIT, sequenceRandom({ 0.05, 0.99 }))
		expect(secret.ok).toBe(true)
		expect(secret.pet.petId).toBe("Ghost")
		expect(secret.state.gems).toBe(9950)
		-- 0.2 misses the Secret roll, 0 draws the first pet of the egg.
		local normal = rules.buyFromMerchant(rich(), "Egg", VISIT, sequenceRandom({ 0.2, 0, 0.99 }))
		expect(normal.pet.petId).toBe("Hamster")
		expect(#normal.state.pets).toBe(1)
	end)

	it("sells the exclusive pet once per visit and needs a free slot", function()
		local now = visitWithPet(true)
		local result = rules.buyFromMerchant(rich(), "Pet", now, sequenceRandom({ 0.5 }))
		expect(result.ok).toBe(true)
		expect(result.pet.petId).toBe("Camel")
		expect(result.state.pets[1].petId).toBe("Camel")
		expect(result.state.gems).toBe(9700)
		expect(rules.buyFromMerchant(result.state, "Pet", now, sequenceRandom({ 0.5 })).reason).toBe("SoldOut")
		local full = rich()
		for uid = 1, rules.inventorySlots(full) do
			table.insert(full.pets, { uid = uid, petId = "Hamster" })
		end
		expect(rules.buyFromMerchant(full, "Pet", now, sequenceRandom({ 0.5 })).reason).toBe("InventoryFull")
	end)
end)

describe("Travelling merchant admin action and config", function()
	local AdminActions = require("../src/shared/AdminActions")
	local Features = require("../src/shared/Features")
	local GameConfig = require("../src/shared/GameConfig")

	it("lets the admin make the merchant appear now", function()
		local admin = AdminActions.new(rules, config, Features.new(GameConfig.features))
		local now = VISIT + 3000
		local result = admin.run(42, rich(), "spawnMerchant", {}, { now = now, random = math.random })
		expect(result.ok).toBe(true)
		expect(rules.merchantStatus(now + 5, result.state.merchantForcedAt).active).toBe(true)
		expect(rules.buyFromMerchant(result.state, "Pet", now + 5, sequenceRandom({ 0.5 })).ok).toBe(true)
	end)

	it("sells the real Mega potion and an exclusive Mythic pet that is in no egg", function()
		local merchant = GameConfig.travelingMerchant
		expect(merchant.periodSeconds).toBe(7200)
		expect(merchant.durationSeconds).toBe(600)
		expect(merchant.potion.potionId).toBe("Mega")
		expect(merchant.potion.priceFactor).toBe(0.5)
		local pet = GameConfig.pets[merchant.pet.petId]
		assert(pet, "unknown merchant pet")
		expect(pet.merchantPet).toBe(true)
		expect(pet.rarity).toBe("Mythic")
		expect(type(pet.displayNameEn)).toBe("string")
		for eggId, egg in GameConfig.eggs do
			for _, entry in egg.pets do
				assert(entry.pet ~= merchant.pet.petId, `merchant pet in egg {eggId}`)
			end
		end
	end)
end)
