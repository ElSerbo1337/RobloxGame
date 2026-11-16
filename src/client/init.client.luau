-- Client entry point (StarterPlayerScripts.Client)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

local Hud = require(script.Hud)
local SellAnimation = require(script.SellAnimation)
local ToppingInput = require(script.ToppingInput)

local coinsCounter = Hud.start()
SellAnimation.start(coinsCounter)
ToppingInput.start()

print(`[{Constants.GAME_NAME}] Client gestartet`)
