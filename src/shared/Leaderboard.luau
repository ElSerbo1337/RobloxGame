--!strict
-- Leaderboard display: pure Luau, no Roblox API. Turns the top entries of a board
-- (read by the server from an ordered DataStore) into rows with rank, name and the
-- value in German format.

export type Format = "Number" | "Duration"
export type Entry = { name: string, value: number }
export type Row = { rank: number, name: string, value: string }

local Leaderboard = {}

-- 1234567 -> "1.234.567"
local function germanNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1.")))
	return (string.gsub(formatted, "^%.", ""))
end

-- "Number": German thousands separators; "Duration": seconds as "3 Std. 5 Min."
-- (under an hour only minutes).
function Leaderboard.formatValue(format: Format, value: number): string
	if format == "Duration" then
		local minutes = math.floor(value / 60)
		local hours = math.floor(minutes / 60)
		if hours == 0 then
			return `{minutes} Min.`
		end
		return `{germanNumber(hours)} Std. {minutes % 60} Min.`
	end
	return germanNumber(value)
end

-- Entries in rank order (best first) -> rows numbered from 1.
function Leaderboard.rows(entries: { Entry }, format: Format): { Row }
	local rows = {}
	for rank, entry in entries do
		table.insert(rows, { rank = rank, name = entry.name, value = Leaderboard.formatValue(format, entry.value) })
	end
	return rows
end

return Leaderboard
