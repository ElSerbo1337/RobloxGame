local TestKit = require("./TestKit")
local TestConfig = require("./fixtures/TestConfig")
local GameConfig = require("../src/shared/GameConfig")
local ToppingField = require("../src/shared/ToppingField")
local Weather = require("../src/shared/Weather")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- Seconds of [from, from + length) in which the world has weather.
local function activeSeconds(weather: any, worldId: string, from: number, length: number): number
	local count = 0
	for t = from, from + length - 1 do
		if weather.activeAt(worldId, t) then
			count += 1
		end
	end
	return count
end

describe("Weather schedule (#105)", function()
	local weather = Weather.new(TestConfig)

	it("rains for 2 of every 15 minutes in a world with weather", function()
		expect(activeSeconds(weather, "PizzeriaGarden", 1000000, 900)).toBe(120)
		expect(activeSeconds(weather, "PizzeriaGarden", 1234567, 900)).toBe(120)
	end)

	it("returns the weather id and its end, and nil for worlds without weather", function()
		local id, endsAt = weather.activeAt("PizzeriaGarden", 900 * 1000 + 30)
		expect(id).toBe("Rain")
		expect(endsAt).toBe(900 * 1000 + 120)
		expect(weather.activeAt("PizzeriaGarden", 900 * 1000 + 120)).toBe(nil)
		expect(weather.activeAt("Farm", 900 * 1000 + 30)).toBe(nil)
		expect(weather.nextStart("Farm", 0)).toBe(nil)
	end)

	it("tells when the next weather starts", function()
		expect(weather.nextStart("PizzeriaGarden", 900 * 1000 + 50)).toBe(900 * 1000 + 50)
		expect(weather.nextStart("PizzeriaGarden", 900 * 1000 + 500)).toBe(900 * 1001)
	end)

	it("lets an admin start the weather now for its full length", function()
		local now = 900 * 1000 + 300
		expect(weather.activeAt("PizzeriaGarden", now)).toBe(nil)
		local id, endsAt = weather.activeAt("PizzeriaGarden", now, now)
		expect(id).toBe("Rain")
		expect(endsAt).toBe(now + 120)
		expect(weather.activeAt("PizzeriaGarden", now + 120, now)).toBe(nil)
		-- Forcing a world without weather does nothing.
		expect(weather.activeAt("Farm", now, now)).toBe(nil)
	end)

	it("gives +20 % spawn speed only while the weather lasts", function()
		expect(weather.spawnMultiplier(true)).toBe(1.2)
		expect(weather.spawnMultiplier(false)).toBe(1)
	end)

	it("shifts the worlds, so they don't all have weather at the same time", function()
		local real = Weather.new(GameConfig)
		local starts = {}
		local now = 900 * 2000 + 7
		for _, world in GameConfig.worlds do
			local _, endsAt = real.activeAt(world.id, now)
			local start = if endsAt then endsAt - 120 else real.nextStart(world.id, now)
			expect(start ~= nil).toBe(true)
			local key = (start :: number) % 900
			expect(starts[key]).toBe(nil)
			starts[key] = true
		end
	end)
end)

describe("Weather topping bonus (#105)", function()
	local function respawnTime(multiplier: number?): number
		local field = ToppingField.new(TestConfig, "PizzeriaGarden", TestKit.sequenceRandom({ 0.5 }))
		expect(field:take(1, 100, multiplier)).toBe(true)
		local t = 100
		while #field:respawnDue(t) == 0 do
			t += 0.25
		end
		return t - 100
	end

	it("refills empty slots 20 % faster during weather (+20 % toppings)", function()
		local normal = respawnTime(nil)
		local rainy = respawnTime(Weather.new(TestConfig).spawnMultiplier(true))
		expect(normal).toBe(TestConfig.toppingField.respawnSeconds)
		expect(math.abs(rainy - normal / 1.2) < 0.25).toBe(true)
		expect(rainy < normal).toBe(true)
	end)

	it("never changes what spawns, so the golden chance stays the same", function()
		local function spawned(multiplier: number?)
			local field = ToppingField.new(TestConfig, "PizzeriaGarden", TestKit.sequenceRandom({ 0.1, 0.7, 0.3, 0.9 }))
			for slotId = 1, field.slotCount do
				field:take(slotId, 0, multiplier)
			end
			field:respawnDue(1000)
			local out = {}
			for slotId = 1, field.slotCount do
				local topping = field:get(slotId) :: any
				table.insert(out, `{topping.toppingId}:{topping.goldRoll}`)
			end
			return table.concat(out, ",")
		end
		expect(spawned(1.2)).toBe(spawned(nil))
	end)
end)

describe("Day-night cycle (#105)", function()
	local weather = Weather.new(TestConfig)

	it("runs one day every 20 minutes, starting in the morning", function()
		expect(weather.clockAt(0)).toBe(6)
		expect(weather.clockAt(600)).toBe(18)
		expect(weather.clockAt(1200)).toBe(6)
		expect(weather.clockAt(300)).toBe(12)
	end)

	it("knows the night hours", function()
		expect(weather.isNight(12)).toBe(false)
		expect(weather.isNight(20)).toBe(true)
		expect(weather.isNight(2)).toBe(true)
		expect(weather.isNight(6)).toBe(false)
	end)

	it("skips the configured worlds (space and cloud city in the real game)", function()
		expect(weather.hasDayNight("PizzeriaGarden")).toBe(true)
		expect(weather.hasDayNight("Beach")).toBe(false)
		local real = Weather.new(GameConfig)
		expect(real.hasDayNight("Space")).toBe(false)
		expect(real.hasDayNight("CloudCity")).toBe(false)
		expect(real.hasDayNight("Volcano")).toBe(true)
	end)
end)

describe("GameConfig weather (#105)", function()
	it("gives every world a weather with a known particle style", function()
		local styles = { rain = true, snow = true, dust = true, bubbles = true, sparkle = true }
		for _, world in GameConfig.worlds do
			expect(GameConfig.weathers[world.weather] ~= nil).toBe(true)
		end
		for _, kind in GameConfig.weathers do
			expect(styles[kind.style]).toBe(true)
		end
		for _, id in { "AshRain", "CrystalGlitter", "RainbowSky", "CheeseRain" } do
			expect(GameConfig.weathers[id] ~= nil).toBe(true)
		end
	end)
end)
