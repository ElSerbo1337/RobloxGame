-- English names (#68): every displayName (and every potion/upgrade description) in the
-- real GameConfig has an English counterpart exactly as approved in
-- docs/translations-names.md (#66).
local fs = require("@lune/fs")
local TestKit = require("./TestKit")
local GameConfig = require("../src/shared/GameConfig")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function trim(text: string): string
	return (string.gsub(text, "^%s+", ""):gsub("%s+$", ""))
end

-- id -> { de, en, descDe?, descEn? } from the Markdown tables.
local function readNameList()
	local rows = {}
	local withDescription = false
	for line in string.gmatch(fs.readFile("docs/translations-names.md"), "[^\n]+") do
		if string.sub(line, 1, 3) == "## " then
			withDescription = string.find(line, "Tränke") ~= nil or string.find(line, "Upgrades") ~= nil
		elseif
			string.sub(line, 1, 2) == "| "
			and not string.find(line, "^| Id ")
			and not string.find(line, "^| %-")
		then
			local cells = {}
			for cell in string.gmatch(string.sub(line, 2), "([^|]*)|") do
				table.insert(cells, trim(cell))
			end
			rows[cells[1]] = {
				de = cells[2],
				en = cells[3],
				descDe = if withDescription then cells[4] else nil,
				descEn = if withDescription then cells[5] else nil,
			}
		end
	end
	return rows
end

-- Every config table with a displayName, with its id (field `id` or its key).
local function namedEntries()
	local found = {}
	local function walk(node: any, key: any)
		if type(node) ~= "table" then
			return
		end
		if type(node.displayName) == "string" then
			table.insert(found, { id = node.id or key, entry = node })
		end
		for childKey, child in node do
			walk(child, childKey)
		end
	end
	walk(GameConfig, nil)
	return found
end

describe("English names (#68)", function()
	it("gives every displayName in GameConfig the approved English name", function()
		local rows = readNameList()
		local entries = namedEntries()
		expect(#entries).toBe(133)
		for _, item in entries do
			local row = rows[item.id]
			expect(row ~= nil).toBe(true)
			expect(item.entry.displayName).toBe(row.de)
			expect(item.entry.displayNameEn).toBe(row.en)
		end
	end)

	it("gives every potion and upgrade description the approved English text", function()
		local rows = readNameList()
		for _, group in { GameConfig.potions, GameConfig.upgrades } do
			for id, entry in group do
				local row = rows[id]
				expect(entry.description).toBe(row.descDe)
				expect(entry.descriptionEn).toBe(row.descEn)
			end
		end
	end)
end)
