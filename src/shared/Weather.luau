--!strict
-- Weather schedule and day-night clock (#105): pure Luau without Roblox API, tested in
-- Lune (tests/Weather.spec.luau). Everything comes from the clock (`now`, Unix seconds),
-- so all servers and clients agree without sending anything; only an admin start
-- (`forcedAt`) is passed in by the server.
--
--   local weather = Weather.new(GameConfig)
--   weather.activeAt("Volcano", now, forcedAt?)  -- weather id and end time, or nil
--   weather.spawnMultiplier(isActive)           -- 1.2 while the weather lasts, else 1
--   weather.clockAt(now)                        -- Lighting.ClockTime of the day cycle
--   weather.isNight(clock)                      -- lanterns and fireflies on
--
-- Config: config.weather { periodSeconds, durationSeconds, spawnBonus }, config.dayNight
-- { cycleSeconds, nightStarts, nightEnds, skipWorlds }, world entries `weather = "<id>"`.

local Weather = {}

-- Shifts each world's window by its index, so neighbouring worlds don't rain together.
-- Coprime with 900, so worlds 1-15 all start at different times of the 15 minutes.
local OFFSET_STEP = 211

export type Weather = {
	weatherOf: (worldId: string) -> string?,
	activeAt: (worldId: string, now: number, forcedAt: number?) -> (string?, number?),
	nextStart: (worldId: string, now: number) -> number?,
	spawnMultiplier: (active: boolean) -> number,
	clockAt: (now: number) -> number,
	isNight: (clock: number) -> boolean,
	hasDayNight: (worldId: string) -> boolean,
}

function Weather.new(config: any): Weather
	local schedule = config.weather
	local cycle = config.dayNight
	local index: { [string]: number } = {}
	local kind: { [string]: string } = {}
	for i, world in config.worlds do
		index[world.id] = i
		if world.weather and config.weathers and config.weathers[world.weather] then
			kind[world.id] = world.weather
		end
	end

	local self = {} :: Weather

	function self.weatherOf(worldId: string): string?
		return if schedule then kind[worldId] else nil
	end

	local function offset(worldId: string): number
		return ((index[worldId] - 1) * OFFSET_STEP) % schedule.periodSeconds
	end

	-- The world's weather id and when it ends, or nil while the sky is clear.
	-- `forcedAt`: an admin started the weather then (it lasts durationSeconds from there).
	function self.activeAt(worldId: string, now: number, forcedAt: number?): (string?, number?)
		local id = self.weatherOf(worldId)
		if id == nil then
			return nil, nil
		end
		local duration = schedule.durationSeconds
		local phase = (now - offset(worldId)) % schedule.periodSeconds
		local endsAt = if phase < duration then now - phase + duration else nil
		if forcedAt and now >= forcedAt and now < forcedAt + duration then
			endsAt = math.max(endsAt or 0, forcedAt + duration)
		end
		if endsAt then
			return id, endsAt
		end
		return nil, nil
	end

	-- When the world's next scheduled weather starts (now while it is running).
	function self.nextStart(worldId: string, now: number): number?
		if self.weatherOf(worldId) == nil then
			return nil
		end
		local phase = (now - offset(worldId)) % schedule.periodSeconds
		if phase < schedule.durationSeconds then
			return now
		end
		return now - phase + schedule.periodSeconds
	end

	-- Topping respawn speed: +spawnBonus while the weather lasts. Only the delay changes,
	-- never what spawns, so the golden chance (#94) stays the same.
	function self.spawnMultiplier(active: boolean): number
		return if active and schedule then 1 + schedule.spawnBonus else 1
	end

	-- Clock hour 0-24 of the shared day: a cycle starts at 6:00 (morning).
	function self.clockAt(now: number): number
		local phase = (now % cycle.cycleSeconds) / cycle.cycleSeconds
		return (6 + phase * 24) % 24
	end

	function self.isNight(clock: number): boolean
		return clock >= cycle.nightStarts or clock < cycle.nightEnds
	end

	function self.hasDayNight(worldId: string): boolean
		return cycle ~= nil and not (cycle.skipWorlds and cycle.skipWorlds[worldId])
	end

	return self
end

return Weather
