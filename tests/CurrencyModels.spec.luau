-- The coin and gem models (#49): the sell animation dresses its coins with "Coin", the
-- field gems use "Gem" (ReplicatedStorage.GameAssets.Models.<Name>), so the files must
-- exist under these names, and every part must be a palette entry in ModelLibrary
-- (otherwise Studio keeps the imported grey).
local fs = require("@lune/fs")

local TestKit = require("./TestKit")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local PARTS = {
	Coin = { "CoinGold", "CoinRim", "CoinEmboss" },
	Gem = { "GemLight", "GemMid", "GemDark", "GemShine" },
}

describe("Currency models", function()
	it("has a model (FBX) and a preview picture for the coin and the gem", function()
		local missing = {}
		for name in PARTS do
			if not fs.isFile(`assets/models/{name}.fbx`) then
				table.insert(missing, `{name}.fbx`)
			end
			if not fs.isFile(`assets/previews/{name}.png`) then
				table.insert(missing, `{name}.png`)
			end
		end
		table.sort(missing)
		expect(table.concat(missing, ", ")).toBe("")
	end)

	it("names every part after a ModelLibrary palette colour", function()
		local library = fs.readFile("src/shared/ModelLibrary.luau")
		local problems = {}
		for name, parts in PARTS do
			local model = fs.readFile(`assets/models/{name}.fbx`)
			for _, part in parts do
				if not string.find(model, part, 1, true) then
					table.insert(problems, `{name} lacks {part}`)
				end
				if not string.find(library, `\t{part} = \{`) then
					table.insert(problems, `no palette entry {part}`)
				end
			end
		end
		table.sort(problems)
		expect(table.concat(problems, ", ")).toBe("")
	end)
end)
