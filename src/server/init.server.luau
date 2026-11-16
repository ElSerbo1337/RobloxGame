-- Server entry point (ServerScriptService.Server). Wires up the services.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)

local OvenService = require(script.OvenService)
local PizzaVisual = require(script.PizzaVisual)
local PlayerStates = require(script.PlayerStates)
local ToppingService = require(script.ToppingService)
local World1Map = require(script.World1Map)

-- Create remotes before any client asks for them.
Net.event("CollectTopping")
Net.event("SetAutoCollect")
Net.event("Notify")

local layout = World1Map.build()
PlayerStates.start()
PizzaVisual.start()
ToppingService.start(layout)
OvenService.start(layout.sellZone)

print(`[{Constants.GAME_NAME}] Server gestartet`)
