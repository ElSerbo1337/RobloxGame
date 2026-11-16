-- Server entry point (ServerScriptService.Server). Wires up the services.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)

local BarrierService = require(script.BarrierService)
local OvenService = require(script.OvenService)
local PizzaVisual = require(script.PizzaVisual)
local PlayerStates = require(script.PlayerStates)
local ToppingService = require(script.ToppingService)
local World1Map = require(script.World1Map)
local WorldMap = require(script.WorldMap)

-- Create remotes before any client asks for them.
Net.event("CollectTopping")
Net.event("SetAutoCollect")
Net.event("Notify")
Net.event("UnlockWorld")

local layout = World1Map.build()
local laterWorlds = WorldMap.buildAll()
PlayerStates.start()
PizzaVisual.start()
ToppingService.start("PizzeriaGarden", layout)
OvenService.start(layout.sellZone)
for _, world in laterWorlds do
	ToppingService.start(world.worldId, world)
	OvenService.start(world.sellZone)
end
BarrierService.start(laterWorlds)

print(`[{Constants.GAME_NAME}] Server gestartet`)
