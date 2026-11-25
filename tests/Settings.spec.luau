local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameRules = require("../src/shared/GameRules")
local SaveData = require("../src/shared/SaveData")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local rules = GameRules.new(TestConfig)

describe("settings (#76)", function()
	it("a new player has no saved settings and gets the defaults", function()
		local state = rules.newPlayerState()
		expect(state.settings).toEqual({})
		local resolved = rules.settings(state, false)
		expect(resolved.musicVolume).toBe(100)
		expect(resolved.musicMuted).toBe(false)
		expect(resolved.effectsVolume).toBe(100)
		expect(resolved.effectsMuted).toBe(false)
		expect(resolved.graphics).toBe("High")
		expect(resolved.cameraShake).toBe(true)
		expect(resolved.screenFlashes).toBe(true)
		expect(resolved.skipEggAnimation).toBe(false)
	end)

	it("phones start on low graphics", function()
		expect(rules.settings(rules.newPlayerState(), true).graphics).toBe("Low")
	end)

	it("an explicit choice beats the phone default", function()
		local state = rules.setSetting(rules.newPlayerState(), "graphics", "High").state
		expect(rules.settings(state, true).graphics).toBe("High")
	end)

	it("stores a valid value without changing the old state", function()
		local old = rules.newPlayerState()
		local result = rules.setSetting(old, "musicVolume", 40)
		expect(result.ok).toBe(true)
		expect(result.state.settings).toEqual({ musicVolume = 40 })
		expect(old.settings).toEqual({})
		expect(rules.settings(result.state, false).musicVolume).toBe(40)
	end)

	it("keeps other settings when one changes", function()
		local state = rules.setSetting(rules.newPlayerState(), "musicMuted", true).state
		state = rules.setSetting(state, "skipEggAnimation", true).state
		expect(state.settings).toEqual({ musicMuted = true, skipEggAnimation = true })
	end)

	it("accepts 0 and 100 as volume", function()
		expect(rules.setSetting(rules.newPlayerState(), "effectsVolume", 0).ok).toBe(true)
		local state = rules.setSetting(rules.newPlayerState(), "effectsVolume", 0).state
		expect(rules.setSetting(state, "effectsVolume", 100).ok).toBe(true)
	end)

	it("refuses unknown keys", function()
		local result = rules.setSetting(rules.newPlayerState(), "coins", 100)
		expect(result.ok).toBe(false)
		expect(result.reason).toBe("UnknownSetting")
		expect(rules.setSetting(rules.newPlayerState(), 5, true).reason).toBe("UnknownSetting")
		expect(rules.setSetting(rules.newPlayerState(), nil, true).reason).toBe("UnknownSetting")
	end)

	it("refuses invalid values", function()
		local state = rules.newPlayerState()
		for _, case in
			{
				{ "musicVolume", 101 },
				{ "musicVolume", -1 },
				{ "musicVolume", 50.5 },
				{ "musicVolume", 0 / 0 },
				{ "musicVolume", math.huge },
				{ "musicVolume", "50" },
				{ "musicMuted", 1 },
				{ "musicMuted", nil },
				{ "graphics", "Ultra" },
				{ "graphics", true },
				{ "cameraShake", "false" },
			}
		do
			local result = rules.setSetting(state, case[1], case[2])
			expect(result.ok).toBe(false)
			expect(result.reason).toBe("InvalidValue")
			expect(result.state).toBe(state)
		end
	end)

	it("the same value again is unchanged", function()
		local state = rules.setSetting(rules.newPlayerState(), "cameraShake", false).state
		expect(rules.setSetting(state, "cameraShake", false).reason).toBe("Unchanged")
	end)

	it("ignores invalid or unknown saved values", function()
		local resolved = GameRules.resolveSettings(
			{ musicVolume = 500, graphics = "Ultra", cheat = true, effectsMuted = true },
			false
		)
		expect(resolved.musicVolume).toBe(100)
		expect(resolved.graphics).toBe("High")
		expect(resolved.cheat).toBe(nil)
		expect(resolved.effectsMuted).toBe(true)
		expect(GameRules.resolveSettings(nil, true).graphics).toBe("Low")
	end)

	it("every setting has a valid default", function()
		for key, spec in GameRules.SETTINGS do
			expect(GameRules.isValidSetting(key, spec.default)).toBe(true)
			if spec.touchDefault ~= nil then
				expect(GameRules.isValidSetting(key, spec.touchDefault)).toBe(true)
			end
		end
	end)

	it("survives saving and loading (rejoin)", function()
		local state = rules.setSetting(rules.newPlayerState(), "musicVolume", 30).state
		state = rules.setSetting(state, "graphics", "Low").state
		local loaded = SaveData.load(state, rules.newPlayerState())
		expect(loaded.ok).toBe(true)
		expect(loaded.state.settings).toEqual({ musicVolume = 30, graphics = "Low" })
	end)

	it("old saves without settings get the empty table", function()
		local saved = rules.newPlayerState()
		saved.settings = nil :: any
		expect(SaveData.load(saved, rules.newPlayerState()).state.settings).toEqual({})
	end)

	it("is kept on rebirth", function()
		local state = rules.setSetting(rules.newPlayerState(), "skipEggAnimation", true).state
		state.coins = 1e12
		local reborn = rules.rebirth(state, 0)
		expect(reborn.ok).toBe(true)
		expect(reborn.state.settings).toEqual({ skipEggAnimation = true })
	end)
end)
