--!strict
-- Sound effects and background music (client only, purely cosmetic).
-- The list of all sounds (IDs, volume, search terms) lives in shared/SoundList (#112).
--
-- IDs come from the Roblox Creator Store (Toolbox → Audio). They could not be
-- verified from the cloud session, so they start empty; an empty ID simply stays
-- silent. Every entry carries `search`: the Toolbox search terms to find a fitting
-- sound. The local session picks sounds by the creator "Roblox" (those stay public)
-- and enters the asset IDs here, see docs/pc-todo.md (#23, done in A7).
--
-- Played automatically here: Collect (pizza count goes up), Sell ("Sold"),
-- Gem (gem topping / gem reward), Sell also for a delivered order, GoldenTopping
-- (golden topping collected, #94). EggCrack is played by
-- EggAnimation; PhoneRing by DeliveryMenu while the delivery phone rings (#14).
-- Music: `Sounds.playMusic(key)` (WorldAmbience picks the key per world).
-- Volume (#76): looped entries play in the SoundGroup "Music", all others in "Effects";
-- their volume follows the player's settings (Settings.volume, slider + mute).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Net = require(ReplicatedStorage.Shared.Net)
local Settings = require(script.Parent.Settings)
local SoundList = require(ReplicatedStorage.Shared.SoundList)

-- Several pickups within this time play only one plop.
local COLLECT_MIN_GAP = 0.06

local Sounds = {}

local instances: { [string]: Sound } = {}
local currentMusic: Sound? = nil

local function soundGroup(name: string): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Parent = SoundService
	return group
end

local groups = { music = soundGroup("Music"), effects = soundGroup("Effects") }

local function applyVolumes()
	for name, group in groups do
		group.Volume = Settings.volume(name)
	end
end
applyVolumes()
Settings.changed:Connect(function(key: string)
	if string.find(key, "Volume$") or string.find(key, "Muted$") then
		applyVolumes()
	end
end)

local function soundFor(key: string): Sound?
	local entry = SoundList[key]
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
		newSound.SoundGroup = if entry.looped == true then groups.music else groups.effects
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
		if kind == "Sold" or kind == "Delivered" then
			Sounds.play("Sell")
		elseif kind == "Gems" or kind == "SecretChest" then
			Sounds.play("Gem")
		elseif kind == "GoldenTopping" then
			Sounds.play("GoldenTopping")
		end
	end)
end

return Sounds
