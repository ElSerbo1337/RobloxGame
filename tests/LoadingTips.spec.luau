-- Loading screen (#111): tips for the switched-on features, shuffled, one after the
-- other, and a screen that always goes away (loaded + minimum time, or time limit).
local TestKit = require("./TestKit")
local GameConfig = require("../src/shared/GameConfig")
local LoadingTips = require("../src/shared/LoadingTips")
local Texts = require("../src/shared/Texts")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local TIMING = { minSeconds = 2, maxSeconds = 12, tipSeconds = 4, skipAfterSeconds = 5, fadeSeconds = 0.5 }

local function allOn(): { [string]: boolean }
	local switches = {}
	for _, tip in LoadingTips.TIPS do
		if tip.feature then
			switches[tip.feature] = true
		end
	end
	return switches
end

describe("loading tips: which tips", function()
	it("shows every tip when all features are on", function()
		expect(#LoadingTips.available(allOn())).toBe(#LoadingTips.TIPS)
	end)

	it("leaves out the tips of switched-off features, keeps the ones without a feature", function()
		local switches = allOn()
		switches.luckyWheel = false
		switches.petMerge = false
		local ids = LoadingTips.available(switches)
		expect(table.find(ids, "wheel")).toBe(nil)
		expect(table.find(ids, "merge")).toBe(nil)
		expect(table.find(ids, "worlds") ~= nil).toBe(true)
		expect(table.find(ids, "quests") ~= nil).toBe(true)
	end)

	it("raises an error for an unknown feature id", function()
		local switches = allOn()
		switches.codes = nil :: any
		local ok = pcall(LoadingTips.available, switches)
		expect(ok).toBe(false)
	end)

	it("knows every feature of its tips in the real GameConfig", function()
		expect(#LoadingTips.available(GameConfig.features) > 0).toBe(true)
	end)

	it("covers the new features named in the ticket", function()
		local ids = LoadingTips.available(allOn())
		for _, id in
			{ "merge", "shiny", "secret", "quests", "wheel", "codes", "index", "petLevels", "potions", "worlds" }
		do
			expect({ id = id, found = table.find(ids, id) ~= nil }).toEqual({ id = id, found = true })
		end
	end)
end)

describe("loading tips: order", function()
	it("shuffles into a permutation of the same tips", function()
		local ids = { "a", "b", "c", "d" }
		local shuffled = LoadingTips.shuffle(ids, TestKit.sequenceRandom({ 0.1, 0.9, 0.5 }))
		local sorted = table.clone(shuffled)
		table.sort(sorted)
		expect(sorted).toEqual({ "a", "b", "c", "d" })
		expect(ids).toEqual({ "a", "b", "c", "d" })
	end)

	it("switches to the next tip every tipSeconds and starts over", function()
		expect(LoadingTips.tipIndex(0, 3, 4)).toBe(1)
		expect(LoadingTips.tipIndex(3.9, 3, 4)).toBe(1)
		expect(LoadingTips.tipIndex(4, 3, 4)).toBe(2)
		expect(LoadingTips.tipIndex(8.5, 3, 4)).toBe(3)
		expect(LoadingTips.tipIndex(12, 3, 4)).toBe(1)
		expect(LoadingTips.tipIndex(5, 0, 4)).toBe(0)
	end)
end)

describe("loading tips: when the screen goes away", function()
	it("stays for the minimum time even if the game loaded at once", function()
		expect(LoadingTips.shouldHide(1, true, TIMING)).toBe(false)
		expect(LoadingTips.shouldHide(2, true, TIMING)).toBe(true)
	end)

	it("waits while the game is still loading", function()
		expect(LoadingTips.shouldHide(6, false, TIMING)).toBe(false)
	end)

	it("always goes away at the time limit, even if loading never finishes", function()
		expect(LoadingTips.shouldHide(12, false, TIMING)).toBe(true)
	end)

	it("can be skipped with a tap only after skipAfterSeconds", function()
		expect(LoadingTips.canSkip(4, TIMING)).toBe(false)
		expect(LoadingTips.shouldHide(4, false, TIMING, true)).toBe(false)
		expect(LoadingTips.shouldHide(5, false, TIMING, true)).toBe(true)
	end)

	it("fills the progress bar to 90 % while loading and full once loaded", function()
		expect(LoadingTips.progress(0, false, TIMING)).toBe(0)
		expect(LoadingTips.progress(24, false, TIMING)).toBe(0.9)
		expect(LoadingTips.progress(1, true, TIMING)).toBe(1)
	end)
end)

describe("loading tips: texts", function()
	it("has a German and an English text for every tip", function()
		for _, tip in LoadingTips.TIPS do
			local key = `loading.tip.{tip.id}`
			expect({ key = key, ok = Texts.strings[key] ~= nil }).toEqual({ key = key, ok = true })
		end
		for _, key in { "loading.title", "loading.subtitle", "loading.tipLabel", "loading.loading", "loading.skip" } do
			expect({ key = key, ok = Texts.strings[key] ~= nil }).toEqual({ key = key, ok = true })
		end
	end)

	it("names the number of worlds and the last world in the player's language", function()
		local config = {
			worlds = {
				{ displayName = "Bauernhof", displayNameEn = "Farm" },
				{ displayName = "Pizza-Paradies", displayNameEn = "Pizza Paradise" },
			},
		}
		local de = Texts.render("de", LoadingTips.textArgs("worlds", config))
		local en = Texts.render("en", LoadingTips.textArgs("worlds", config))
		expect(string.find(de, "Pizza-Paradies", 1, true) ~= nil).toBe(true)
		expect(string.find(de, "2", 1, true) ~= nil).toBe(true)
		expect(string.find(en, "Pizza Paradise", 1, true) ~= nil).toBe(true)
	end)

	it("renders every tip of the real config without leftover placeholders", function()
		for _, language in { "de", "en" } :: { Texts.Language } do
			for _, id in LoadingTips.available(GameConfig.features) do
				local text = Texts.render(language, LoadingTips.textArgs(id, GameConfig :: any))
				expect({ id = id, open = string.find(text, "{", 1, true) }).toEqual({ id = id, open = nil })
			end
		end
	end)
end)

describe("loading screen: config", function()
	it("has sane timings", function()
		local timing = GameConfig.loadingScreen
		expect(timing.minSeconds > 0).toBe(true)
		expect(timing.maxSeconds > timing.minSeconds).toBe(true)
		expect(timing.skipAfterSeconds <= timing.maxSeconds).toBe(true)
		expect(timing.tipSeconds > 0).toBe(true)
		expect(timing.fadeSeconds >= 0).toBe(true)
	end)
end)
