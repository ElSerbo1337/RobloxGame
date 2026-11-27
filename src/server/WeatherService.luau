--!strict
-- Weather on the server (#105, switch features.weather). The schedule comes from the
-- clock (Shared.Weather), so nothing is saved; an admin can start a world's weather now
-- (admin action "startWeather"). Every second the current weather of each world is
-- replicated as Workspace attributes `Weather_<worldId>` (weather id) and
-- `WeatherEnds_<worldId>` (Unix seconds, for the countdown); the client shows the
-- particles and the pill. ToppingService asks spawnMultiplier for the +20 % refill.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Weather = require(ReplicatedStorage.Shared.Weather)

local weather = Weather.new(GameConfig)
local features = Features.new(GameConfig.features)
local forcedAt: { [string]: number } = {}

local WeatherService = {}

local function current(worldId: string): (string?, number?)
	if not features.enabled("weather") then
		return nil, nil
	end
	return weather.activeAt(worldId, os.time(), forcedAt[worldId])
end

-- Topping refill speed of the world right now: 1.2 while its weather lasts, else 1.
function WeatherService.spawnMultiplier(worldId: string): number
	return weather.spawnMultiplier(current(worldId) ~= nil)
end

local function publish()
	for _, world in GameConfig.worlds do
		local id, endsAt = current(world.id)
		Workspace:SetAttribute(`Weather_{world.id}`, id)
		Workspace:SetAttribute(`WeatherEnds_{world.id}`, endsAt)
	end
end

-- Admin action "startWeather": the world's weather starts now for its full length.
function WeatherService.force(worldId: string)
	forcedAt[worldId] = os.time()
	publish()
end

function WeatherService.start()
	if not features.enabled("weather") then
		return
	end
	task.spawn(function()
		while true do
			publish()
			task.wait(1)
		end
	end)
end

return WeatherService
