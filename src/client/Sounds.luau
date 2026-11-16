--!strict
-- Sound effects and background music (client only, purely cosmetic).
--
-- IDs come from the Roblox Creator Store (Toolbox → Audio). They could not be
-- verified from the cloud session, so they start empty; an empty ID simply stays
-- silent. Fill them in during the Studio check (docs/pc-todo.md, #15): pick sounds
-- by the creator "Roblox" (those stay public), copy the asset ID, enter it below.
--
-- Played automatically here: Collect (pizza count goes up), Sell ("Sold"),
-- Gem (gem topping / gem reward). EggCrack is played by EggAnimation; PhoneRing is
-- for the delivery phone (#13): call `Sounds.play("PhoneRing")`.
-- Music: `Sounds.playMusic(key)` (WorldAmbience picks the key per world).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Net = require(ReplicatedStorage.Shared.Net)

type Entry = { id: string, volume: number, looped: boolean? }

local SOUNDS: { [string]: Entry } = {
	-- Short "plop" when a topping lands on the pizza.
	Collect = { id = "", volume = 0.5 },
	-- Cash register / coins when selling at the oven.
	Sell = { id = "", volume = 0.6 },
	-- Sparkle / chime for gems.
	Gem = { id = "", volume = 0.5 },
	-- Egg shell cracking in the hatch animation.
	EggCrack = { id = "", volume = 0.7 },
	-- Old phone ringing (delivery service).
	PhoneRing = { id = "", volume = 0.6 },
	-- Background music per world, looped (cheerful, light).
	Music_PizzeriaGarden = { id = "", volume = 0.25, looped = true },
}

-- Several pickups within this time play only one plop.
local COLLECT_MIN_GAP = 0.06

local Sounds = {}

local instances: { [string]: Sound } = {}
local currentMusic: Sound? = nil

local function soundFor(key: string): Sound?
	local entry = SOUNDS[key]
	if entry == nil or entry.id == "" then
		return nil
	end
	local sound = instances[key]
	if sound == nil then
		local newSound = Instance.new("Sound")
		newSound.Name = key
		newSound.SoundId = if string.match(entry.id, "^%d+$") then `rbxassetid://{entry.id}` else entry.id
		newSound.Volume = entry.volume
		newSound.Looped = entry.looped == true
		newSound.Parent = SoundService
		instances[key] = newSound
		sound = newSound
	end
	return sound
end

-- Plays a one-shot sound effect; silently does nothing if its ID isn't set yet.
function Sounds.play(key: string)
	local sound = soundFor(key)
	if sound then
		SoundService:PlayLocalSound(sound)
	end
end

-- Switches the background music (nil = silence). Same key again keeps it playing.
function Sounds.playMusic(key: string?)
	local nextMusic = if key then soundFor(key) else nil
	if nextMusic == currentMusic then
		return
	end
	if currentMusic then
		currentMusic:Stop()
	end
	currentMusic = nextMusic
	if nextMusic then
		nextMusic:Play()
	end
end

function Sounds.start()
	local player = Players.LocalPlayer

	local lastCount = (player:GetAttribute("PizzaCount") :: number?) or 0
	-- The saved pizza arriving after joining is no pickup: no plop in the first seconds.
	local lastPlop = os.clock() + 2
	player:GetAttributeChangedSignal("PizzaCount"):Connect(function()
		local count = (player:GetAttribute("PizzaCount") :: number?) or 0
		if count > lastCount and os.clock() - lastPlop >= COLLECT_MIN_GAP then
			lastPlop = os.clock()
			Sounds.play("Collect")
		end
		lastCount = count
	end)

	Net.event("Notify").OnClientEvent:Connect(function(kind: string)
		if kind == "Sold" then
			Sounds.play("Sell")
		elseif kind == "Gems" or kind == "PlaytimeGems" then
			Sounds.play("Gem")
		end
	end)
end

return Sounds
