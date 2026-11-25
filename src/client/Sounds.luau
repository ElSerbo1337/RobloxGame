--!strict
-- Sound effects and background music (client only, purely cosmetic).
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

-- `search`: Toolbox search terms (documentation only, not used at runtime).
type Entry = { id: string, volume: number, looped: boolean?, search: { string } }

local SOUNDS: { [string]: Entry } = {
	-- Short "plop" when a topping lands on the pizza.
	Collect = { id = "9119669065", volume = 0.5, search = { "pop", "plop", "bubble pop", "click" } },
	-- Cash register / coins when selling at the oven.
	Sell = { id = "9113728625", volume = 0.6, search = { "cash register", "coins", "purchase", "ka-ching" } },
	-- Sparkle / chime for gems.
	Gem = { id = "9116394545", volume = 0.5, search = { "sparkle", "chime", "magic", "twinkle" } },
	-- Egg shell cracking in the hatch animation.
	EggCrack = { id = "9113959343", volume = 0.7, search = { "egg crack", "crack", "shell", "break" } },
	-- Old phone ringing (delivery service).
	PhoneRing = { id = "9117304246", volume = 0.6, search = { "phone ring", "telephone", "old phone", "ringing" } },
	-- Golden topping collected (#94): bright magic shimmer, a bit "richer" than Gem.
	-- ID still empty: the local session picks one (Creator Store, creator "Roblox").
	GoldenTopping = {
		id = "",
		volume = 0.6,
		search = { "magic shimmer", "golden sparkle", "treasure", "shine", "glitter chime" },
	},
	-- Secret pet hatched (#81): long magical reveal (hatch animation and global banner).
	-- ID still empty: the local session picks one (Creator Store, creator "Roblox").
	Secret = {
		id = "",
		volume = 0.8,
		search = { "magic reveal", "mystery", "epic reveal", "choir", "legendary" },
	},
	-- Shiny pet hatched and pets merged (#80). IDs still empty: the local session picks
	-- them (Creator Store, creator "Roblox").
	Shiny = {
		id = "",
		volume = 0.7,
		search = { "sparkle", "twinkle", "magic chime", "shine", "star" },
	},
	Merge = {
		id = "",
		volume = 0.7,
		search = { "power up", "level up", "fusion", "magic whoosh", "upgrade" },
	},
	-- An equipped pet reached a new level (#90, toast in Hud). ID still empty.
	PetLevelUp = {
		id = "",
		volume = 0.6,
		search = { "level up", "ding", "achievement", "power up chime", "success" },
	},
	-- Lucky wheel (#98): short click each time a field passes the pointer, and a win jingle
	-- when it stops. IDs still empty: the local session picks them (Creator Store, creator "Roblox").
	WheelTick = {
		id = "",
		volume = 0.4,
		search = { "click", "tick", "wheel tick", "ratchet", "clack" },
	},
	WheelWin = {
		id = "",
		volume = 0.7,
		search = { "win", "prize", "reward jingle", "success", "slot win" },
	},
	-- Short fanfare for the rebirth celebration (#35).
	Rebirth = { id = "9114898444", volume = 0.7, search = { "fanfare", "victory", "level up", "celebration" } },
	-- Background music per world, looped (cheerful, light).
	Music_PizzeriaGarden = {
		id = "1839408249",
		volume = 0.25,
		looped = true,
		search = { "happy", "cheerful", "ukulele", "italian" },
	},
	-- Worlds 2-7 (#16).
	Music_Farm = {
		id = "9043699640",
		volume = 0.25,
		looped = true,
		search = { "country", "banjo", "farm", "folk" },
	},
	Music_Beach = {
		id = "9043828544",
		volume = 0.25,
		looped = true,
		search = { "tropical", "beach", "ukulele", "reggae" },
	},
	Music_Icebergs = {
		id = "9041824482",
		volume = 0.25,
		looped = true,
		search = { "winter", "snow", "bells", "calm" },
	},
	Music_Volcano = {
		id = "1839999913",
		volume = 0.25,
		looped = true,
		search = { "volcano", "drums", "adventure", "tribal" },
	},
	Music_CandyLand = {
		id = "1846441369",
		volume = 0.25,
		looped = true,
		search = { "candy", "cute", "bubbly", "playful" },
	},
	Music_Space = {
		id = "1844477817",
		volume = 0.25,
		looped = true,
		search = { "space", "synth", "ambient", "cosmic" },
	},
}

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
		newSound.SoundGroup = if entry.looped then groups.music else groups.effects
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
		elseif kind == "Gems" then
			Sounds.play("Gem")
		elseif kind == "GoldenTopping" then
			Sounds.play("GoldenTopping")
		end
	end)
end

return Sounds
