local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local SaveData = require("../src/shared/SaveData")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

describe("SaveData.load", function()
	it("gives a new player a fresh state when nothing is saved", function()
		local result = SaveData.load(nil, rules.newPlayerState())

		expect(result.ok).toBe(true)
		expect(result.state).toEqual(rules.newPlayerState())
	end)

	it("keeps coins and pizza of a version 1 save and starts it with 0 rebirths", function()
		local saved = { version = 1, coins = 1234, pizza = { "Salami", "Mozzarella" } }

		local result = SaveData.load(saved, rules.newPlayerState())

		expect(result.ok).toBe(true)
		expect(result.state.coins).toBe(1234)
		expect(result.state.pizza).toEqual({ "Salami", "Mozzarella" })
		expect(result.state.rebirths).toBe(0)
		expect(result.state.version).toBe(rules.newPlayerState().version)
	end)

	it("fills fields that did not exist when the save was written with their defaults", function()
		local fresh = rules.newPlayerState()
		fresh.gems = 0
		fresh.unlockedWorlds = { "PizzeriaGarden" }
		local saved = { version = fresh.version, coins = 40, pizza = {}, rebirths = 3 }

		local result = SaveData.load(saved, fresh)

		expect(result.ok).toBe(true)
		expect(result.state.coins).toBe(40)
		expect(result.state.rebirths).toBe(3)
		expect(result.state.gems).toBe(0)
		expect(result.state.unlockedWorlds).toEqual({ "PizzeriaGarden" })
	end)

	it("turns the prepared rebirth multiplier of a version 3 save into a rebirth counter", function()
		local cases = {
			{ multiplier = 1, rebirths = 0 },
			{ multiplier = 1.5, rebirths = 1 },
			{ multiplier = 2, rebirths = 2 },
			{ multiplier = 0.5, rebirths = 0 },
			{ multiplier = "x", rebirths = 0 },
		}
		for _, case in cases do
			local saved = { version = 3, coins = 9, pizza = {}, rebirthMultiplier = case.multiplier }

			local result = SaveData.load(saved, rules.newPlayerState())

			expect(result.ok).toBe(true)
			expect(result.state.rebirths).toBe(case.rebirths)
			expect(result.state.rebirthMultiplier).toBe(nil)
			expect(result.state.coins).toBe(9)
		end
	end)

	it("replaces a field of the wrong type with its default", function()
		local saved = { version = 2, coins = "lots", pizza = { "Salami" }, rebirthMultiplier = 1 }

		local result = SaveData.load(saved, rules.newPlayerState())

		expect(result.ok).toBe(true)
		expect(result.state.coins).toBe(0)
		expect(result.state.pizza).toEqual({ "Salami" })
	end)

	it("refuses a save from a newer game version so it is never overwritten", function()
		local saved = { version = 99, coins = 5000, pizza = {}, rebirthMultiplier = 2 }

		local result = SaveData.load(saved, rules.newPlayerState())

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("NewerVersion")
	end)

	it("refuses saved data that is not a table", function()
		local result = SaveData.load("garbage", rules.newPlayerState())

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("Corrupt")
	end)

	it("does not change the saved data it was given", function()
		local saved = { version = 1, coins = 7, pizza = { "Salami" } }

		SaveData.load(saved, rules.newPlayerState())

		expect(saved).toEqual({ version = 1, coins = 7, pizza = { "Salami" } })
	end)
end)

local SERVER = "server-a"
local OTHER = "server-b"
local EXPIRY = 300

describe("SaveData.canTakeOver", function()
	it("allows taking over a save without a lock", function()
		expect(SaveData.canTakeOver(nil, SERVER, 1000, EXPIRY)).toBe(true)
	end)

	it("allows taking over a save locked by this server", function()
		local lock = { serverId = SERVER, time = 990 }

		expect(SaveData.canTakeOver(lock, SERVER, 1000, EXPIRY)).toBe(true)
	end)

	it("refuses a save freshly locked by another server", function()
		local lock = { serverId = OTHER, time = 1000 - EXPIRY + 1 }

		expect(SaveData.canTakeOver(lock, SERVER, 1000, EXPIRY)).toBe(false)
	end)

	it("allows taking over a lock of another server once it has expired", function()
		local lock = { serverId = OTHER, time = 1000 - EXPIRY }

		expect(SaveData.canTakeOver(lock, SERVER, 1000, EXPIRY)).toBe(true)
	end)

	it("treats a malformed lock as no lock", function()
		expect(SaveData.canTakeOver("garbage", SERVER, 1000, EXPIRY)).toBe(true)
		expect(SaveData.canTakeOver({ serverId = OTHER }, SERVER, 1000, EXPIRY)).toBe(true)
	end)
end)

describe("SaveData.claim", function()
	it("gives a new player a fresh state and a record locked by this server", function()
		local fresh = rules.newPlayerState()

		local result = SaveData.claim(nil, fresh, SERVER, 1000, EXPIRY)

		expect(result.ok).toBe(true)
		expect(result.state).toEqual(fresh)
		expect(result.record.lock).toEqual({ serverId = SERVER, time = 1000 })
		expect(result.record.version).toBe(fresh.version)
		expect(result.record.tutorialStep).toBe(fresh.tutorialStep)
	end)

	it("loads an existing save without a lock and keeps its data in the locked record", function()
		local saved = { version = 1, coins = 1234, pizza = { "Salami" } }

		local result = SaveData.claim(saved, rules.newPlayerState(), SERVER, 1000, EXPIRY)

		expect(result.ok).toBe(true)
		expect(result.state.coins).toBe(1234)
		expect(result.record.coins).toBe(1234)
		expect(result.record.version).toBe(1)
		expect(result.record.lock).toEqual({ serverId = SERVER, time = 1000 })
		expect(saved.lock).toBe(nil)
	end)

	it("refuses a save freshly locked by another server", function()
		local saved = { version = 3, coins = 50, pizza = {}, lock = { serverId = OTHER, time = 900 } }

		local result = SaveData.claim(saved, rules.newPlayerState(), SERVER, 1000, EXPIRY)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("Locked")
		expect(result.record).toBe(nil)
	end)

	it("takes over an orphaned lock of another server after it expired", function()
		local saved = { version = 3, coins = 50, pizza = {}, lock = { serverId = OTHER, time = 100 } }

		local result = SaveData.claim(saved, rules.newPlayerState(), SERVER, 1000, EXPIRY)

		expect(result.ok).toBe(true)
		expect(result.state.coins).toBe(50)
		expect(result.record.lock).toEqual({ serverId = SERVER, time = 1000 })
	end)

	it("does not claim a save it cannot read", function()
		local newer = SaveData.claim({ version = 99 }, rules.newPlayerState(), SERVER, 1000, EXPIRY)
		local corrupt = SaveData.claim("garbage", rules.newPlayerState(), SERVER, 1000, EXPIRY)

		expect(newer.ok).toBe(false)
		expect(newer.reason).toBe("NewerVersion")
		expect(newer.record).toBe(nil)
		expect(corrupt.ok).toBe(false)
		expect(corrupt.reason).toBe("Corrupt")
		expect(corrupt.record).toBe(nil)
	end)

	it("does not put the lock into the PlayerState", function()
		local result = SaveData.claim(nil, rules.newPlayerState(), SERVER, 1000, EXPIRY)

		expect(result.state.lock).toBe(nil)
	end)
end)

describe("SaveData.prepareSave", function()
	it("writes the state and renews the lock while this server holds it", function()
		local state = rules.newPlayerState()
		state.coins = 77
		local saved = { version = state.version, coins = 10, lock = { serverId = SERVER, time = 500 } }

		local result = SaveData.prepareSave(saved, state, SERVER, 1000, false)

		expect(result.ok).toBe(true)
		expect(result.record.coins).toBe(77)
		expect(result.record.lock).toEqual({ serverId = SERVER, time = 1000 })
		expect(state.lock).toBe(nil)
	end)

	it("writes the state without a lock when releasing it", function()
		local state = rules.newPlayerState()
		local saved = { version = state.version, lock = { serverId = SERVER, time = 500 } }

		local result = SaveData.prepareSave(saved, state, SERVER, 1000, true)

		expect(result.ok).toBe(true)
		expect(result.record.lock).toBe(nil)
		expect(result.record.version).toBe(state.version)
	end)

	it("refuses to save when another server holds the lock", function()
		local state = rules.newPlayerState()
		local saved = { version = state.version, lock = { serverId = OTHER, time = 999 } }

		local result = SaveData.prepareSave(saved, state, SERVER, 1000, false)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("NotOwner")
		expect(result.record).toBe(nil)
	end)

	it("refuses to save when there is no lock at all", function()
		local state = rules.newPlayerState()

		local withoutLock = SaveData.prepareSave({ version = state.version }, state, SERVER, 1000, false)
		local nothingSaved = SaveData.prepareSave(nil, state, SERVER, 1000, true)

		expect(withoutLock.ok).toBe(false)
		expect(withoutLock.reason).toBe("NotOwner")
		expect(nothingSaved.ok).toBe(false)
		expect(nothingSaved.reason).toBe("NotOwner")
	end)

	it("never replaces a save written by a newer game version", function()
		local state = rules.newPlayerState()
		local saved = { version = state.version + 1, lock = { serverId = SERVER, time = 999 } }

		local result = SaveData.prepareSave(saved, state, SERVER, 1000, false)

		expect(result.ok).toBe(false)
		expect(result.reason).toBe("NewerVersion")
	end)
end)
