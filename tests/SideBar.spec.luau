local TestKit = require("./TestKit")
local SideBarModel = require("../src/shared/SideBarModel")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function barWith(entries: { { id: string, order: number } })
	local bar = SideBarModel.new()
	for _, entry in entries do
		bar.register(entry.id, entry.order)
	end
	return bar
end

local TODAY = {
	{ id = "rebirth", order = 50 },
	{ id = "pets", order = 10 },
	{ id = "worlds", order = 60 },
	{ id = "gifts", order = 30 },
	{ id = "potions", order = 20 },
	{ id = "calendar", order = 40 },
}

describe("side bar", function()
	it("sorts the tiles by their order, whatever order they registered in", function()
		local bar = barWith(TODAY)

		local arranged = bar.arrange(10)

		expect(arranged.shown).toEqual({ "pets", "potions", "gifts", "calendar", "rebirth", "worlds" })
		expect(arranged.hidden).toEqual({})
		expect(arranged.more).toBe(false)
	end)

	it("keeps tiles with the same order in id order", function()
		local bar = barWith({ { id = "b", order = 5 }, { id = "a", order = 5 } })

		expect(bar.arrange(5).shown).toEqual({ "a", "b" })
	end)

	it("puts what does not fit behind a More tile in the last place", function()
		local bar = barWith(TODAY)

		local arranged = bar.arrange(4)

		expect(arranged.shown).toEqual({ "pets", "potions", "gifts" })
		expect(arranged.hidden).toEqual({ "calendar", "rebirth", "worlds" })
		expect(arranged.more).toBe(true)
	end)

	it("needs no More tile when the tiles fill the places exactly", function()
		local bar = barWith(TODAY)

		local arranged = bar.arrange(6)

		expect(#arranged.shown).toBe(6)
		expect(arranged.more).toBe(false)
	end)

	it("shows a red dot on a tile that reports news", function()
		local bar = barWith(TODAY)

		bar.setBadge("gifts", true)

		expect(bar.badge("gifts")).toBe(true)
		expect(bar.badge("pets")).toBe(false)
		bar.setBadge("gifts", false)
		expect(bar.badge("gifts")).toBe(false)
	end)

	it("shows a red dot on More while a hidden tile has news", function()
		local bar = barWith(TODAY)
		bar.setBadge("calendar", true)

		expect(bar.arrange(4).moreBadge).toBe(true)
		expect(bar.arrange(10).moreBadge).toBe(false)
		bar.setBadge("calendar", false)
		expect(bar.arrange(4).moreBadge).toBe(false)
	end)

	it("remembers a red dot set before the tile registered", function()
		local bar = SideBarModel.new()

		bar.setBadge("quests", true)
		bar.register("quests", 70)

		expect(bar.badge("quests")).toBe(true)
	end)

	it("refuses the same id twice", function()
		local bar = barWith({ { id = "pets", order = 10 } })

		local ok = pcall(bar.register, "pets", 20)

		expect(ok).toBe(false)
	end)

	it("lists one place at least, even on the tiniest screen", function()
		local bar = barWith(TODAY)

		local arranged = bar.arrange(1)

		expect(arranged.shown).toEqual({})
		expect(arranged.more).toBe(true)
		expect(#arranged.hidden).toBe(6)
	end)
end)
