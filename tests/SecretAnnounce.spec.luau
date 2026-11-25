-- Global announcement of Secret pets (#81): throttle and message checks.
local TestKit = require("./TestKit")
local GameConfig = require("../src/shared/GameConfig")
local SecretAnnounce = require("../src/shared/SecretAnnounce")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("secret announcement throttle", function()
	it("allows up to max announcements in the window, then refuses", function()
		local throttle = SecretAnnounce.throttle(2, 60)
		expect(throttle.allow(0)).toBe(true)
		expect(throttle.allow(1)).toBe(true)
		expect(throttle.allow(2)).toBe(false)
		expect(throttle.allow(59)).toBe(false)
	end)

	it("allows again once the oldest announcement left the window", function()
		local throttle = SecretAnnounce.throttle(2, 60)
		throttle.allow(0)
		throttle.allow(30)
		expect(throttle.allow(60)).toBe(true)
		expect(throttle.allow(61)).toBe(false)
		expect(throttle.allow(90)).toBe(true)
	end)

	it("uses the limits of the real config", function()
		expect(GameConfig.secretPets.announceMax >= 1).toBe(true)
		expect(GameConfig.secretPets.announceWindowSeconds >= 10).toBe(true)
	end)
end)

describe("secret announcement message", function()
	it("carries name, pet and sending server and survives parse", function()
		local message = SecretAnnounce.message("PizzaFan", "BlackHoleCat", "job-1")
		expect(message).toEqual({ name = "PizzaFan", petId = "BlackHoleCat", jobId = "job-1" })
		expect(SecretAnnounce.parse(message, GameConfig)).toEqual(message)
	end)

	it("cuts very long names", function()
		local message = SecretAnnounce.message(string.rep("x", 50), "BlackHoleCat", "job")
		expect(#message.name).toBe(32)
	end)

	it("ignores anything that is not a valid Secret pet message", function()
		expect(SecretAnnounce.parse("hi", GameConfig)).toBe(nil)
		expect(SecretAnnounce.parse({ name = "A", petId = "DoughHamster", jobId = "j" }, GameConfig)).toBe(nil)
		expect(SecretAnnounce.parse({ name = "A", petId = "Nope", jobId = "j" }, GameConfig)).toBe(nil)
		expect(SecretAnnounce.parse({ name = "", petId = "BlackHoleCat", jobId = "j" }, GameConfig)).toBe(nil)
		expect(SecretAnnounce.parse({ name = string.rep("x", 40), petId = "BlackHoleCat", jobId = "j" }, GameConfig)).toBe(
			nil
		)
		expect(SecretAnnounce.parse({ name = "A", petId = "BlackHoleCat" }, GameConfig)).toBe(nil)
		expect(SecretAnnounce.parse({ name = 5, petId = "BlackHoleCat", jobId = "j" }, GameConfig)).toBe(nil)
	end)
end)
