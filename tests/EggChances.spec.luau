-- Effective egg chances (#93): the egg preview shows the real odds of opening an egg,
-- incl. running potions (Luck, Shiny, Mega) for rarities, Shiny and Secret. Preview and
-- openEggs read the same odds, checked here at the roll boundaries.
local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local SHINY = 1 / 200
local SECRET = 1 / 20000
-- Roll offset around a boundary; preview percentages are rounded to 1e-4 %.
local EPS = 1e-5

local function chanceConfig(features: { [string]: boolean }?): any
	local config = table.clone(TestConfig)
	config.features = features
	config.shinyPets = { chance = SHINY, bonusMultiplier = 1.5 }
	config.secretPets = { chance = SECRET }
	config.rarities = table.clone(TestConfig.rarities)
	config.rarities.Secret = { displayName = "Geheim", order = 7, color = { 0, 230, 200 } }
	config.pets = table.clone(TestConfig.pets)
	config.pets.GhostPet = { displayName = "Geist", rarity = "Secret", bonus = 5 }
	config.worlds = table.clone(TestConfig.worlds)
	config.worlds[1] = table.clone(TestConfig.worlds[1])
	config.worlds[1].secretPet = "GhostPet"
	config.potions = table.clone(TestConfig.potions)
	config.potions.Luck = table.clone(TestConfig.potions.Luck)
	config.potions.Luck.rarityWeights = { Rare = 2, Mythic = 3, Secret = 2 }
	config.potions.Luck.shinyChanceMultiplier = 2
	config.potions.Shiny = { displayName = "Shiny-Trank", price = 40, durationSeconds = 600, shinyChanceMultiplier = 2 }
	config.potions.Mega = {
		displayName = "Mega-Trank",
		price = 120,
		durationSeconds = 600,
		includes = { "Coins", "Luck", "Speed" },
	}
	return config
end

local rules = GameRules.new(chanceConfig())
local offRules = GameRules.new(chanceConfig({ effectiveEggChances = false }))

local function player(r, potions: { [string]: number }?)
	local state = r.newPlayerState()
	state.coins = 10000
	state.upgrades = { InventorySpace = 2 }
	state.activePotions = potions or {}
	return state
end

local function approx(actual: number, expected: number)
	if math.abs(actual - expected) > 1e-9 then
		error(`expected {expected}, got {actual}`)
	end
end

local function petOf(preview, petId: string)
	for _, entry in preview.pets do
		if entry.petId == petId then
			return entry
		end
	end
	error(`no {petId} in preview`)
end

describe("effective egg chances: shiny", function()
	it("shows the shiny chance per pet with its bonus", function()
		local preview = rules.eggPreview("TestEgg", player(rules))
		expect(preview.shiny).toEqual({ chancePercent = 0.5, bonusMultiplier = 1.5, boosted = false })
		expect(preview.boosts).toEqual({})
	end)

	it("includes the shiny, luck and mega potion", function()
		approx(rules.eggPreview("TestEgg", player(rules, { Shiny = 600 })).shiny.chancePercent, 1)
		approx(rules.eggPreview("TestEgg", player(rules, { Shiny = 600, Luck = 600 })).shiny.chancePercent, 2)
		local mega = rules.eggPreview("TestEgg", player(rules, { Mega = 600, Shiny = 600 }))
		approx(mega.shiny.chancePercent, 2)
		expect(mega.shiny.boosted).toBe(true)
	end)

	it("equals the real shiny chance and the roll of openEggs at its boundary", function()
		local state = player(rules, { Shiny = 600 })
		local chance = rules.eggPreview("TestEgg", state).shiny.chancePercent / 100
		approx(chance, rules.shinyChance(state))
		-- Rolls: Secret, chance table, Shiny.
		local below = rules.openEgg(state, "TestEgg", TestKit.sequenceRandom({ 0.5, 0, chance - EPS }))
		local above = rules.openEgg(state, "TestEgg", TestKit.sequenceRandom({ 0.5, 0, chance + EPS }))
		expect(below.pet.shiny).toBe(true)
		expect(above.pet.shiny).toBe(nil)
	end)
end)

describe("effective egg chances: rarities and Secret", function()
	it("marks every pet row and the Secret row as boosted while luck works (also via Mega)", function()
		for _, potions in { { Luck = 600 }, { Mega = 600 } } do
			local preview = rules.eggPreview("TestEgg", player(rules, potions))
			expect(petOf(preview, "Dragon").boosted).toBe(true)
			expect(preview.secret.boosted).toBe(true)
			approx(preview.secret.chancePercent, 2 * SECRET * 100)
		end
		local plain = rules.eggPreview("TestEgg", player(rules))
		expect(petOf(plain, "Dragon").boosted).toBe(false)
		expect(plain.secret.boosted).toBe(false)
	end)

	it("shows the chances that openEggs really rolls (Secret and rarest pet)", function()
		local state = player(rules, { Mega = 600 })
		local preview = rules.eggPreview("TestEgg", state)
		local secret = preview.secret.chancePercent / 100
		expect(rules.openEgg(state, "TestEgg", TestKit.sequenceRandom({ secret - EPS, 0 })).pet.petId).toBe("GhostPet")
		expect(rules.openEgg(state, "TestEgg", TestKit.sequenceRandom({ secret + EPS, 0, 0.9 })).pet.petId).toBe(
			"Hamster"
		)
		-- Dragon is last in the table: it hatches in the top share of the second roll.
		local dragonShare = petOf(preview, "Dragon").chancePercent / 100 / (1 - secret)
		local function second(roll: number): string
			return rules.openEgg(state, "TestEgg", TestKit.sequenceRandom({ 0.5, roll, 0.9 })).pet.petId
		end
		expect(second(1 - dragonShare + EPS)).toBe("Dragon")
		expect(second(1 - dragonShare - EPS)).toBe("Cat")
	end)

	it("adds up to 100 % with luck and a Secret pet", function()
		local preview = rules.eggPreview("TestEgg", player(rules, { Luck = 600 }))
		local sum = preview.secret.chancePercent
		for _, entry in preview.pets do
			sum += entry.chancePercent
		end
		if math.abs(sum - 100) > 1e-3 then
			error(`chances add up to {sum}`)
		end
	end)
end)

describe("effective egg chances: boosts", function()
	it("lists the running potions that raise a chance, sorted", function()
		expect(rules.eggPreview("TestEgg", player(rules, { Shiny = 600 })).boosts).toEqual({ "Shiny" })
		expect(rules.eggPreview("TestEgg", player(rules, { Mega = 600 })).boosts).toEqual({ "Mega" })
		expect(rules.eggPreview("TestEgg", player(rules, { Shiny = 600, Luck = 600 })).boosts).toEqual({
			"Luck",
			"Shiny",
		})
	end)

	it("leaves out potions that do not touch eggs and expired ones", function()
		expect(rules.eggPreview("TestEgg", player(rules, { Coins = 600, Speed = 600 })).boosts).toEqual({})
		expect(rules.eggPreview("TestEgg", player(rules, { Luck = 0 })).boosts).toEqual({})
		expect(rules.eggPreview("TestEgg").boosts).toEqual({})
	end)
end)

describe("effective egg chances switched off", function()
	it("drops the shiny line, the boosts and the marks but keeps the real chances", function()
		local state = player(offRules, { Luck = 600, Shiny = 600 })
		local off = offRules.eggPreview("TestEgg", state)
		local on = rules.eggPreview("TestEgg", state)
		expect(off.shiny).toBe(nil)
		expect(off.boosts).toEqual({})
		expect(petOf(off, "Dragon").boosted).toBe(false)
		expect(off.secret.boosted).toBe(false)
		approx(petOf(off, "Dragon").chancePercent, petOf(on, "Dragon").chancePercent)
	end)
end)
