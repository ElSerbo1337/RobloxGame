-- Store page of the MEGA UPDATE (#115): icon and thumbnails in Roblox sizes, German and
-- English, rendered by tools/blender/render_mega.py; title and description in
-- docs/store/mega-update.md within Roblox's limits and without Robux promises.
local fs = require("@lune/fs")

local TestKit = require("./TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local DIR = "docs/store/mega"
local THUMBNAILS = { "Thumbnail1_Pets", "Thumbnail2_Atlantis", "Thumbnail3_PizzaParadise", "Thumbnail4_WheelQuests" }

-- Width and height from the PNG header (IHDR right after the 8-byte signature).
local function pngSize(path: string): (number, number)
	local data = fs.readFile(path)
	assert(string.sub(data, 2, 4) == "PNG", `{path} is not a PNG`)
	return string.unpack(">I4I4", data, 17)
end

describe("Store images (#115)", function()
	it("has a 512 x 512 icon", function()
		local w, h = pngSize(`{DIR}/Icon.png`)
		expect(`{w}x{h}`).toBe("512x512")
	end)

	it("has every thumbnail in German and English at 1920 x 1080", function()
		local wrong = {}
		for _, name in THUMBNAILS do
			for _, lang in { "de", "en" } do
				local path = `{DIR}/{name}_{lang}.png`
				if not fs.isFile(path) then
					table.insert(wrong, `{path} missing`)
				else
					local w, h = pngSize(path)
					if w ~= 1920 or h ~= 1080 then
						table.insert(wrong, `{path} is {w}x{h}`)
					end
				end
			end
		end
		expect(table.concat(wrong, ", ")).toBe("")
	end)
end)

describe("Store texts (#115)", function()
	local text = fs.readFile("docs/store/mega-update.md")
	local blocks = {}
	for block in string.gmatch(text, "```text\n(.-)\n```") do
		table.insert(blocks, block)
	end

	it("has title and description in German and English", function()
		expect(#blocks).toBe(4)
	end)

	it("keeps titles within 50 and descriptions within 1000 characters", function()
		for i, block in blocks do
			local limit = if i % 2 == 1 then 50 else 1000
			expect(utf8.len(block) <= limit).toBe(true)
		end
	end)

	it("promises no Robux", function()
		for _, block in blocks do
			expect(string.find(string.lower(block), "robux", 1, true)).toBe(nil)
		end
	end)
end)
