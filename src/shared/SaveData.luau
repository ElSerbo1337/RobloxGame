--!strict
-- Save data: pure Luau, no Roblox API. Turns what the DataStore returned into a
-- current PlayerState (versioned, with migrations) and a PlayerState into
-- something storable. The Roblox layer only stores/loads; it never patches
-- saved data by itself.
--
-- Adding a field to PlayerState: add it to rules.newPlayerState(); load() fills
-- it in for old saves automatically. Only when an existing field changes its
-- meaning/shape: bump GameRules' state version and add a migration step below.

export type LoadResult = {
	ok: boolean,
	-- Set when ok == false: "Corrupt" | "NewerVersion". The state is then a fresh
	-- PlayerState to play with, and the Roblox layer must NOT save it.
	reason: string?,
	state: any,
}

local SaveData = {}

-- MIGRATIONS[v] upgrades a save from version v to v + 1 (mutates a private copy).
local MIGRATIONS: { [number]: (save: { [string]: any }) -> () } = {
	[1] = function(save)
		-- v2: rebirth multiplier, prepared for the rebirth system.
		save.rebirthMultiplier = 1
	end,
	[2] = function(save)
		-- v3: new-player tutorial. Players who saved before it existed already know
		-- the game, so it counts as finished for them (new players start at step 1).
		-- Any number past the last step means finished (math.huge cannot be stored as JSON).
		save.tutorialStep = 1000
	end,
}

-- `fresh` is a brand-new PlayerState (rules.newPlayerState()); it provides the
-- current version and defaults for every field the save does not have yet.
function SaveData.load(saved: any, fresh: any): LoadResult
	if saved == nil then
		return { ok = true, state = fresh }
	end
	if type(saved) ~= "table" then
		return { ok = false, reason = "Corrupt", state = fresh }
	end

	local save = table.clone(saved)
	local version = if type(save.version) == "number" then save.version else 1
	if version > fresh.version then
		-- Written by a newer server; loading it here would lose data on save.
		return { ok = false, reason = "NewerVersion", state = fresh }
	end
	while version < fresh.version do
		local migrate = MIGRATIONS[version]
		if migrate then
			migrate(save)
		end
		version += 1
	end

	local state = table.clone(fresh)
	for key, default in fresh do
		local value = save[key]
		if value ~= nil and type(value) == type(default) then
			state[key] = value
		end
	end
	state.version = fresh.version
	return { ok = true, state = state }
end

return SaveData
