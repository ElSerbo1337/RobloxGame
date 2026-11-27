--!strict
-- All sound effects and music tracks (#112), used by client/Sounds. Shared so the tests
-- can check every key that is played or used as world music exists here.
--
-- IDs come from the Roblox Creator Store (Toolbox → Audio). An empty ID stays silent.
-- `search`: Toolbox search terms (documentation only); the list "Sound-IDs suchen" in
-- docs/pc-todo.md is the to-do list for entering the missing IDs.

export type Entry = { id: string, volume: number, looped: boolean?, search: { string } }

local SoundList: { [string]: Entry } = {
	-- Thunder rumble of the thunderstorm weather (#105); plays with or without the
	-- lightning flash. ID still empty: the local session picks one (Creator Store).
	Thunder = { id = "", volume = 0.6, search = { "thunder", "thunder rumble", "storm", "lightning strike" } },
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
	-- A quest got done (#97). ID still empty: the local session picks one (Creator Store,
	-- creator "Roblox").
	QuestDone = {
		id = "",
		volume = 0.6,
		search = { "quest complete", "success", "achievement", "level complete", "ding" },
	},
	-- Badge earned (#103 plays it on the badge toast). ID still empty: the local session
	-- picks one (Creator Store, creator "Roblox").
	Badge = {
		id = "",
		volume = 0.7,
		search = { "achievement", "unlock", "badge", "trophy", "success fanfare" },
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
	-- World 8 (#82). ID still empty: the local session picks one (Creator Store, creator
	-- "Roblox"); calm and a bit mysterious, but still cheerful.
	Music_Atlantis = {
		id = "",
		volume = 0.25,
		looped = true,
		search = { "underwater", "ocean", "aquatic", "harp", "dreamy" },
	},
	-- World 9 (#83). ID still empty: the local session picks one (Creator Store, creator
	-- "Roblox"); adventurous but light, with drums and marimba.
	Music_JungleTemple = {
		id = "",
		volume = 0.25,
		looped = true,
		search = { "jungle", "tropical", "adventure", "drums", "marimba" },
	},
	-- World 10 (#84). ID still empty: the local session picks one (Creator Store, creator
	-- "Roblox"); warm, adventurous, a bit oriental, but still cheerful.
	Music_DesertPyramids = {
		id = "",
		volume = 0.25,
		looped = true,
		search = { "desert", "egypt", "arabian", "oud", "adventure" },
	},
	-- World 11 (#85). ID still empty: the local session picks one (Creator Store, creator
	-- "Roblox"); playfully spooky, not scary (harpsichord, pizzicato, organ).
	Music_HauntedCastle = {
		id = "",
		volume = 0.25,
		looped = true,
		search = { "spooky", "halloween", "playful", "harpsichord", "pizzicato" },
	},
	-- Worlds 12-15 (planned, #72): entries already prepared, IDs still empty.
	Music_DinoAge = {
		id = "",
		volume = 0.25,
		looped = true,
		search = { "prehistoric", "dinosaur", "tribal drums", "adventure", "jungle" },
	},
	Music_CrystalCave = {
		id = "",
		volume = 0.25,
		looped = true,
		search = { "crystal", "cave", "glockenspiel", "magical", "chimes" },
	},
	Music_CloudCity = {
		id = "",
		volume = 0.25,
		looped = true,
		search = { "sky", "dreamy", "airy", "flute", "light ambient" },
	},
	Music_PizzaParadise = {
		id = "",
		volume = 0.25,
		looped = true,
		search = { "italian", "mandolin", "happy", "festive", "tarantella" },
	},
}

return SoundList
