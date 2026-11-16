-- Client entry point (StarterPlayerScripts.Client)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

local Hud = require(script.Hud)
local ToppingInput = require(script.ToppingInput)

Hud.start()
ToppingInput.start()

print(`[{Constants.GAME_NAME}] Client gestartet`)
