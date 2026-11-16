-- Client entry point (StarterPlayerScripts.Client)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

local Barriers = require(script.Barriers)
local Hud = require(script.Hud)
local SellAnimation = require(script.SellAnimation)
local ShopMenu = require(script.ShopMenu)
local ToppingInput = require(script.ToppingInput)

local coinsCounter = Hud.start()
SellAnimation.start(coinsCounter)
ToppingInput.start()
Barriers.start()
ShopMenu.start()

print(`[{Constants.GAME_NAME}] Client gestartet`)
