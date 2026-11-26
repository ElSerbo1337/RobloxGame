-- Friends bonus (#102): +10 % coins per friend on the server, at most +30 %.
local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local SaveData = require("../src/shared/SaveData")
local GameRules = require("../src/shared/GameRules")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

local function approx(actual: number, expected: number)
	if math.abs(actual - expected) > 1e-9 then
		error(`expected {expected}, got {actual}`)
	end
end

local function withFriends(count: number)
	local result = rules.setFriendsOnServer(rules.newPlayerState(), count)
	expect(result.ok).toBe(true)
	return result.state
end

describe("friends bonus (#102)", function()
	it("starts with no friends and no bonus", function()
		local state = rules.newPlayerState()
		expect(state.friendsOnServer).toBe(0)
		expect(rules.friendsCount(state)).toBe(0)
		expect(rules.friendsBonus(state)).toBe(0)
	end)

	it("gives +10 % per friend on the server, capped at +30 %", function()
		approx(rules.friendsBonus(withFriends(1)), 0.1)
		approx(rules.friendsBonus(withFriends(2)), 0.2)
		approx(rules.friendsBonus(withFriends(3)), 0.3)
		approx(rules.friendsBonus(withFriends(7)), 0.3)
	end)

	it("multiplies the coin multiplier (sell, delivery, income)", function()
		local alone = rules.newPlayerState()
		local before = rules.coinMultiplier(alone)
		approx(rules.coinMultiplier(withFriends(2)), before * 1.2)
		approx(rules.coinMultiplier(withFriends(5)), before * 1.3)
	end)

	it("setFriendsOnServer refuses invalid counts and keeps the old state", function()
		local state = rules.newPlayerState()
		for _, bad in { -1, 1.5, 0 / 0, math.huge } do
			local result = rules.setFriendsOnServer(state, bad)
			expect(result.ok).toBe(false)
			expect(result.reason).toBe("InvalidFriends")
			expect(result.state).toBe(state)
		end
		local result = rules.setFriendsOnServer(state, 2)
		expect(state.friendsOnServer).toBe(0)
		expect(result.state.friendsOnServer).toBe(2)
	end)

	it("an admin simulation wins over the real count until it is set back to 0", function()
		local state = withFriends(1)
		state.adminFriends = 3
		expect(rules.friendsCount(state)).toBe(3)
		approx(rules.friendsBonus(state), 0.3)
		state.adminFriends = 0
		expect(rules.friendsCount(state)).toBe(1)
	end)

	it("is 0 without the config or with features.friendsBonus off", function()
		local noConfig = table.clone(TestConfig)
		noConfig.friendsBonus = nil
		local off = table.clone(TestConfig)
		off.features = { friendsBonus = false }
		for _, config in { noConfig, off } do
			local other = GameRules.new(config)
			local state = other.setFriendsOnServer(other.newPlayerState(), 3).state
			expect(other.friendsBonus(state)).toBe(0)
		end
	end)

	it("old saves get the field on load", function()
		local saved = table.clone(rules.newPlayerState())
		saved.friendsOnServer = nil
		local loaded = SaveData.load(saved, rules.newPlayerState()).state
		expect(loaded.friendsOnServer).toBe(0)
	end)
end)
