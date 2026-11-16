--!strict
-- Test runner. Usage: `lune run test`
-- Runs every `tests/**/*.spec.luau` file and exits non-zero if any test fails.

local fs = require("@lune/fs")
local process = require("@lune/process")

local TestKit = require("../tests/TestKit")

local function collectSpecs(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			collectSpecs(path, out)
		elseif string.match(name, "%.spec%.luau$") then
			table.insert(out, path)
		end
	end
end

local specs = {}
collectSpecs("tests", specs)
table.sort(specs)

local totalPassed, totalFailed = 0, 0
for _, path in specs do
	print(path)
	-- Require paths are resolved relative to this file (.lune/).
	local loadOk, loadErr = pcall(require, "../" .. string.gsub(path, "%.luau$", ""))
	if not loadOk then
		totalFailed += 1
		print(`  FAIL could not load spec\n       {loadErr}`)
	end
	local passed, failed = TestKit.run()
	totalPassed += passed
	totalFailed += failed
end

print(`\n{totalPassed} passed, {totalFailed} failed`)
process.exit(if totalFailed > 0 then 1 else 0)
