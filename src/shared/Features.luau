--!strict
-- Feature switches of the MEGA UPDATE (#73). Pure Luau without Roblox API, tested
-- in Lune (tests/Features.spec.luau); usable from server and client alike.
--
-- The switches themselves live in GameConfig.features (one boolean per feature).
-- A switched-off feature shows no UI (client checks `enabled`) and its server
-- handlers refuse every request (wrap them with `guard`). Switching a feature off
-- needs a publish; nothing is replicated at runtime.
--
--   local features = Features.new(GameConfig.features)
--   if features.enabled("luckyWheel") then buildWheelButton() end
--   Net.SpinWheel.OnServerEvent:Connect(features.guard("luckyWheel", function(player) ... end))
--
-- Unknown ids raise an error immediately, so a typo never silently hides a feature.

export type Switches = { [string]: boolean }

export type Features = {
	enabled: (id: string) -> boolean,
	guard: (id: string, handler: (...any) -> ...any) -> (...any) -> ...any,
	ids: () -> { string },
}

local Features = {}

function Features.new(switches: Switches): Features
	local frozen: Switches = table.clone(switches)

	local function check(id: string)
		if frozen[id] == nil then
			error(`Unknown feature "{id}" – add it to GameConfig.features`, 3)
		end
	end

	local function enabled(id: string): boolean
		check(id)
		return frozen[id] == true
	end

	-- The guarded handler returns nothing while the feature is off.
	local function guard(id: string, handler: (...any) -> ...any): (...any) -> ...any
		check(id)
		return function(...: any): ...any
			if frozen[id] ~= true then
				return
			end
			return handler(...)
		end
	end

	local function ids(): { string }
		local list = {}
		for id in frozen do
			table.insert(list, id)
		end
		table.sort(list)
		return list
	end

	return {
		enabled = enabled,
		guard = guard,
		ids = ids,
	}
end

return Features
