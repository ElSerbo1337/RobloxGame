local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- Test config plus worlds behind rebirth tiers (#77): Icebergs and Volcano need 1
-- rebirth, Space needs 3 (rebirth 2 opens nothing new). Worlds 1-3 need none.
local config = table.clone(TestConfig)
config.worlds = table.clone(TestConfig.worlds)
for _, entry in { { "Icebergs", 1 }, { "Volcano", 1 }, { "Space", 3 } } do
	table.insert(config.worlds, {
		id = entry[1],
		displayName = entry[1],
		unlockPrice = 20000,
		requiredRebirths = entry[2],
		toppingSpawns = {},
	})
end

local rules = GameRules.new(config)

local function withRebirths(rebirths: number)
	local state = rules.newPlayerState()
	state.tutorialStep = 1000
	state.rebirths = rebirths
	return state
end

describe("rebirth menu: worlds the next rebirth opens (#77)", function()
	it("lists the worlds of the next tier, in world order", function()
		local offer = rules.rebirthOffer(withRebirths(0))

		expect(offer.opensWorlds).toEqual({ "Icebergs", "Volcano" })
	end)

	it("lists none when the next rebirth opens no world, and names the next tier", function()
		local offer = rules.rebirthOffer(withRebirths(1))

		expect(offer.opensWorlds).toEqual({})
		expect(offer.nextTier).toEqual({ rebirths = 3, worlds = { "Space" } })
	end)

	it("has no next tier while the next rebirth itself opens worlds", function()
		expect(rules.rebirthOffer(withRebirths(0)).nextTier).toBe(nil)
		expect(rules.rebirthOffer(withRebirths(2)).opensWorlds).toEqual({ "Space" })
		expect(rules.rebirthOffer(withRebirths(2)).nextTier).toBe(nil)
	end)

	it("lists nothing once every world is within reach", function()
		local offer = rules.rebirthOffer(withRebirths(3))

		expect(offer.opensWorlds).toEqual({})
		expect(offer.nextTier).toBe(nil)
	end)

	it("still shows the multiplier before and after", function()
		local offer = rules.rebirthOffer(withRebirths(1))

		expect(offer.multiplier).toBe(1.5)
		expect(offer.nextMultiplier).toBe(2)
	end)

	it("lets the opened worlds be bought right after the rebirth", function()
		local state = withRebirths(0)
		state.unlockedWorlds = { "Farm", "Beach" }
		state.coins = 1000
		expect(rules.unlockWorld(state, "Icebergs").reason).toBe("NotEnoughRebirths")

		local after = rules.rebirth(state, 0).state
		after.unlockedWorlds = { "Farm", "Beach" }
		after.coins = 20000

		expect(rules.unlockWorld(after, "Icebergs").ok).toBe(true)
	end)
end)
