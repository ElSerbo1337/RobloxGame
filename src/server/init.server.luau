-- Einstiegspunkt Server (landet in ServerScriptService.Server)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

print(`[{Constants.GAME_NAME}] Server gestartet`)
