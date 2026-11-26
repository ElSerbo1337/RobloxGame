local TestKit = require("./TestKit")
local fs = require("@lune/fs")
local SoundList = require("../src/shared/SoundList")
local WorldLooks = require("../src/shared/WorldLooks")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- All keys passed as string literals to Sounds.play / Sounds.playMusic in src/client.
local function playedKeys(): { string }
	local keys = {}
	for _, name in fs.readDir("src/client") do
		if string.match(name, "%.luau$") then
			local source = fs.readFile(`src/client/{name}`)
			for call in string.gmatch(source, "Sounds%.play[%w]*%(([^)]*)%)") do
				for key in string.gmatch(call, '"([%w_]+)"') do
					table.insert(keys, key)
				end
			end
		end
	end
	return keys
end

describe("SoundList (#112)", function()
	it("has every key the client plays", function()
		local keys = playedKeys()
		expect(#keys > 10).toBe(true)
		for _, key in keys do
			if SoundList[key] == nil then
				error(`Sounds.play("{key}") has no entry in SoundList`)
			end
		end
	end)

	it("has the new MEGA UPDATE sounds", function()
		for _, key in
			{ "Merge", "Shiny", "Secret", "QuestDone", "WheelTick", "WheelWin", "PetLevelUp", "GoldenTopping", "Badge" }
		do
			expect(SoundList[key] ~= nil).toBe(true)
			expect(SoundList[key].looped == true).toBe(false)
		end
	end)

	it("has a looped music entry for every world look, incl. the planned worlds 12-15", function()
		for _, worldId in { "DinoAge", "CrystalCave", "CloudCity", "PizzaParadise" } do
			expect(WorldLooks[worldId] ~= nil).toBe(true)
		end
		for worldId, look in WorldLooks do
			local entry = SoundList[look.music]
			if entry == nil then
				error(`music "{look.music}" of world {worldId} has no entry in SoundList`)
			end
			expect(entry.looped).toBe(true)
		end
	end)

	it("gives every entry search terms, a sane volume and a numeric or empty ID", function()
		for key, entry in SoundList do
			expect(#entry.search > 0).toBe(true)
			expect(entry.volume > 0 and entry.volume <= 1).toBe(true)
			if entry.id ~= "" and not string.match(entry.id, "^%d+$") then
				error(`sound {key}: ID must be digits or empty`)
			end
		end
	end)
end)
