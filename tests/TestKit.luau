--!strict
-- Minimal test framework for Lune. Spec files register tests via `describe`/`it`;
-- the runner (`.lune/test.luau`) executes them and reports the results.

type TestCase = { name: string, fn: () -> () }

local TestKit = {}

local registered: { TestCase } = {}
local prefixStack: { string } = {}

function TestKit.describe(name: string, body: () -> ())
	table.insert(prefixStack, name)
	body()
	table.remove(prefixStack)
end

function TestKit.it(name: string, fn: () -> ())
	local fullName = table.concat(prefixStack, " > ")
	if fullName ~= "" then
		fullName ..= " > "
	end
	table.insert(registered, { name = fullName .. name, fn = fn })
end

local function format(value: any): string
	if type(value) ~= "table" then
		return if type(value) == "string" then `"{value}"` else tostring(value)
	end
	local parts = {}
	for key, inner in value do
		table.insert(parts, `{tostring(key)}={format(inner)}`)
	end
	table.sort(parts)
	return "{" .. table.concat(parts, ", ") .. "}"
end

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

function TestKit.expect(actual: any)
	local function fail(message: string)
		error(message, 3)
	end
	return {
		toBe = function(expected: any)
			if actual ~= expected then
				fail(`expected {format(expected)}, got {format(actual)}`)
			end
		end,
		toEqual = function(expected: any)
			if not deepEqual(actual, expected) then
				fail(`expected {format(expected)}, got {format(actual)}`)
			end
		end,
		toBeNil = function()
			if actual ~= nil then
				fail(`expected nil, got {format(actual)}`)
			end
		end,
		toBeTruthy = function()
			if not actual then
				fail(`expected truthy value, got {format(actual)}`)
			end
		end,
	}
end

-- Returns a fake random source that yields the given numbers in order (then repeats the last).
function TestKit.sequenceRandom(values: { number }): () -> number
	local index = 0
	return function()
		index = math.min(index + 1, #values)
		return values[index]
	end
end

function TestKit.run(): (number, number)
	local passed, failed = 0, 0
	for _, case in registered do
		local ok, err = pcall(case.fn)
		if ok then
			passed += 1
			print(`  ok   {case.name}`)
		else
			failed += 1
			print(`  FAIL {case.name}\n       {err}`)
		end
	end
	table.clear(registered)
	return passed, failed
end

return TestKit
