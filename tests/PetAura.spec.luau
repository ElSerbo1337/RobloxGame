local TestKit = require("./TestKit")
local PetAura = require("../src/shared/PetAura")
local TestConfig = require("./fixtures/TestConfig")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local RARITIES = {
	Common = { order = 1 },
	Epic = { order = 4 },
	Legendary = { order = 5 },
	Mythic = { order = 6 },
	Secret = { order = 7 },
}

describe("PetAura.level", function()
	it("gives no aura below Legendary", function()
		expect(PetAura.level("Common", RARITIES)).toBe(0)
		expect(PetAura.level("Epic", RARITIES)).toBe(0)
	end)

	it("grows from Legendary over Mythic to Secret", function()
		expect(PetAura.level("Legendary", RARITIES)).toBe(1)
		expect(PetAura.level("Mythic", RARITIES)).toBe(2)
		expect(PetAura.level("Secret", RARITIES)).toBe(3)
	end)

	it("gives no aura for an unknown rarity", function()
		expect(PetAura.level("Nope", RARITIES)).toBe(0)
		expect(PetAura.level(nil, RARITIES)).toBe(0)
	end)

	it("works with the rarities of the test config", function()
		expect(PetAura.level("Common", TestConfig.rarities)).toBe(0)
	end)
end)

describe("PetAura.particleRate", function()
	it("emits more particles for higher aura levels", function()
		expect(PetAura.particleRate(0, false)).toBe(0)
		expect(PetAura.particleRate(2, false) > PetAura.particleRate(1, false)).toBe(true)
		expect(PetAura.particleRate(3, false) > PetAura.particleRate(2, false)).toBe(true)
	end)

	it("cuts particles clearly on low graphics and drops the weakest aura", function()
		expect(PetAura.particleRate(1, true)).toBe(0)
		expect(PetAura.particleRate(3, true) <= PetAura.particleRate(3, false) / 3).toBe(true)
	end)
end)
