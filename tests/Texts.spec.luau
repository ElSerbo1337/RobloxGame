local TestKit = require("./TestKit")
local Texts = require("../src/shared/Texts")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function sortedPlaceholders(text: string): { string }
	local names = Texts.placeholders(text)
	table.sort(names)
	return names
end

describe("Texts catalogue", function()
	it("has a non-empty German and English text for every key", function()
		local count = 0
		for key, entry in Texts.strings do
			count += 1
			expect({ key = key, ok = type(entry.de) == "string" and entry.de ~= "" }).toEqual({ key = key, ok = true })
			expect({ key = key, ok = type(entry.en) == "string" and entry.en ~= "" }).toEqual({ key = key, ok = true })
		end
		expect(count > 0).toBe(true)
	end)

	it("uses the same placeholders in both languages", function()
		for key, entry in Texts.strings do
			expect({ key = key, names = sortedPlaceholders(entry.en) }).toEqual({
				key = key,
				names = sortedPlaceholders(entry.de),
			})
		end
	end)

	it("finds placeholders once each", function()
		expect(sortedPlaceholders("{a} und {b}, wieder {a}")).toEqual({ "a", "b" })
		expect(sortedPlaceholders("ohne")).toEqual({})
	end)
end)

describe("Texts.format", function()
	it("fills placeholders in the chosen language", function()
		expect(Texts.format("de", "hud.pizza", { count = 3, capacity = 10 })).toBe("Pizza 3/10")
		expect(Texts.format("en", "hud.pizzaFull", { count = 10, capacity = 10 })).toBe("Pizza FULL 10/10")
	end)

	it("keeps the German texts as before", function()
		expect(Texts.format("de", "hud.autoCollectOff")).toBe("Auto-Sammeln: AUS")
		expect(Texts.format("de", "notify.NotEnoughCoins")).toBe("Nicht genug Münzen!")
		expect(Texts.format("de", "notify.sold", { amount = "1,5 Mio" })).toBe("+1,5 Mio Münzen")
		expect(Texts.format("de", "side.potions")).toBe("Tränke")
	end)

	it("leaves unknown placeholders visible and returns the key for unknown keys", function()
		expect(Texts.format("en", "hud.pizza", { count = 1 })).toBe("Pizza 1/{capacity}")
		expect(Texts.format("en", "no.such.key")).toBe("no.such.key")
	end)

	it("does not treat % in values as patterns", function()
		expect(Texts.format("en", "notify.sold", { amount = "50%" })).toBe("+50% coins")
	end)
end)

describe("Texts.languageFor", function()
	it("picks German for every de locale", function()
		expect(Texts.languageFor("de-de")).toBe("de")
		expect(Texts.languageFor("de-AT")).toBe("de")
		expect(Texts.languageFor("de_CH")).toBe("de")
		expect(Texts.languageFor("DE")).toBe("de")
	end)

	it("falls back to English for everything else", function()
		expect(Texts.languageFor("en-us")).toBe("en")
		expect(Texts.languageFor("es-es")).toBe("en")
		expect(Texts.languageFor("fr")).toBe("en")
		expect(Texts.languageFor("dex")).toBe("en")
		expect(Texts.languageFor("")).toBe("en")
		expect(Texts.languageFor(nil)).toBe("en")
	end)
end)

describe("Texts.shortNumber", function()
	it("writes German numbers as before", function()
		expect(Texts.shortNumber("de", 0)).toBe("0")
		expect(Texts.shortNumber("de", 999)).toBe("999")
		expect(Texts.shortNumber("de", 1234)).toBe("1.234")
		expect(Texts.shortNumber("de", 999999)).toBe("999.999")
		expect(Texts.shortNumber("de", 1500000)).toBe("1,5 Mio")
		expect(Texts.shortNumber("de", 2000000000)).toBe("2 Mrd")
		expect(Texts.shortNumber("de", 3.45e12)).toBe("3,4 Bio")
		expect(Texts.shortNumber("de", 123e9)).toBe("123 Mrd")
	end)

	it("writes English numbers with commas and M/B/T", function()
		expect(Texts.shortNumber("en", 0)).toBe("0")
		expect(Texts.shortNumber("en", 1234)).toBe("1,234")
		expect(Texts.shortNumber("en", 999999)).toBe("999,999")
		expect(Texts.shortNumber("en", 1500000)).toBe("1.5M")
		expect(Texts.shortNumber("en", 1999999)).toBe("1.9M")
		expect(Texts.shortNumber("en", 2000000000)).toBe("2B")
		expect(Texts.shortNumber("en", 3e12)).toBe("3T")
		expect(Texts.shortNumber("en", 3.45e12)).toBe("3.4T")
		expect(Texts.shortNumber("en", 123e9)).toBe("123B")
	end)
end)

describe("Texts.integer", function()
	it("groups thousands per language without short form", function()
		expect(Texts.integer("de", 2500000)).toBe("2.500.000")
		expect(Texts.integer("en", 2500000)).toBe("2,500,000")
		expect(Texts.integer("en", 12.7)).toBe("12")
	end)
end)

describe("Texts.name (#68)", function()
	it("picks the name and description in the chosen language", function()
		local potion = {
			displayName = "Speed-Trank",
			displayNameEn = "Speed Potion",
			description = "Schneller laufen",
			descriptionEn = "Walk faster",
		}
		expect(Texts.name("de", potion)).toBe("Speed-Trank")
		expect(Texts.name("en", potion)).toBe("Speed Potion")
		expect(Texts.description("de", potion)).toBe("Schneller laufen")
		expect(Texts.description("en", potion)).toBe("Walk faster")
		expect(Texts.description("en", { displayName = "X" })).toBe("")
	end)
end)

describe("Texts.render (3D signs, #71)", function()
	it("keeps the German sign texts exactly as before", function()
		expect(Texts.render("de", "sign.sell")).toBe("VERKAUFEN")
		expect(Texts.render("de", "sign.ovenWorld", { world = "Pilzwald" })).toBe("Ofen (Pilzwald) – hier verkaufen")
		expect(Texts.render("de", "sign.gate", { world = "Pilzwald", price = { integer = 1500000 } })).toBe(
			"🔒 Pilzwald\n1.500.000 Münzen"
		)
		expect(Texts.render("de", "sign.gateRebirths", {
			world = "Vulkan",
			condition = { key = "unlock.rebirthsMany", args = { count = 3 } },
			price = { integer = 2500 },
		})).toBe("🔒 Vulkan\nAb 3 Rebirths\n2.500 Münzen")
	end)

	it("formats arguments in the player's language", function()
		expect(Texts.render("en", "sign.sell")).toBe("SELL")
		expect(Texts.render("en", "sign.gateRebirths", {
			world = "Vulkan",
			condition = { key = "unlock.rebirthsOne", args = { count = 1 } },
			price = { integer = 2500 },
		})).toBe("🔒 Vulkan\nFrom 1 rebirth\n2,500 coins")
		expect(Texts.render("en", "sign.egg", { egg = "Ei", price = 1500000 })).toBe("Ei\n💰 1.5M")
		expect(Texts.render("de", "sign.egg", { egg = "Ei", price = 1500000 })).toBe("Ei\n💰 1,5 Mio")
	end)

	it("shows GameConfig names in the player's language (#68)", function()
		local world = Texts.nameArg({ displayName = "Süßigkeitenland", displayNameEn = "Candy Land" })
		expect(Texts.render("de", "sign.ovenWorld", { world = world })).toBe(
			"Ofen (Süßigkeitenland) – hier verkaufen"
		)
		expect(Texts.render("en", "sign.ovenWorld", { world = world })).toBe("Oven (Candy Land) – sell here")
		expect(Texts.render("en", "sign.name", { name = world })).toBe("Candy Land")
	end)

	it("has a title for every leaderboard", function()
		local GameConfig = require("../src/shared/GameConfig")
		for _, board in GameConfig.leaderboards.boards do
			expect({ id = board.id, de = Texts.render("de", `board.{board.id}`) }).toEqual({
				id = board.id,
				de = board.title,
			})
		end
	end)
end)
