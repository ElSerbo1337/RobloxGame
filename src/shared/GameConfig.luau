--!strict
-- Central game configuration: every balancing number lives here.
-- Pure data, no Roblox API, so the game rules can be tested outside Roblox (Lune).
-- New worlds and toppings are added here only.

local GameConfig = {
	pizza = {
		-- Toppings a new player's pizza can hold.
		startCapacity = 2,
	},

	collect = {
		-- Max distance (studs) between player and topping for clicking/tapping it.
		range = 10,
		-- Pickup radius (studs, horizontal) when walking over toppings with auto-collect on.
		autoRadius = 4,
	},

	toppingField = {
		-- Toppings lying around per world at the same time.
		count = 60,
		-- Seconds until a collected topping reappears at a random spot.
		respawnSeconds = 5,
	},

	-- Topping id -> display name and sell value in coins.
	toppings = {
		Salami = { displayName = "Salami", value = 1 },
		Mushroom = { displayName = "Pilz", value = 2 },
		Mozzarella = { displayName = "Mozzarella", value = 5 },
		-- World 2 (Bauernhof): about 4x world 1.
		Onion = { displayName = "Zwiebel", value = 4 },
		BellPepper = { displayName = "Paprika", value = 8 },
		Corn = { displayName = "Mais", value = 12 },
		Ham = { displayName = "Schinken", value = 20 },
	},

	-- Worlds in unlock order. `unlockPrice` is paid once per player at the barrier in
	-- front of the world (0 = open from the start). `toppingSpawns` weights are relative chances.
	worlds = {
		{
			id = "PizzeriaGarden",
			displayName = "Pizzeria-Garten",
			unlockPrice = 0,
			toppingSpawns = {
				{ topping = "Salami", weight = 60 },
				{ topping = "Mushroom", weight = 30 },
				{ topping = "Mozzarella", weight = 10 },
			},
		},
		{
			id = "Farm",
			displayName = "Bauernhof",
			unlockPrice = 1500,
			toppingSpawns = {
				{ topping = "Onion", weight = 45 },
				{ topping = "BellPepper", weight = 30 },
				{ topping = "Corn", weight = 17 },
				{ topping = "Ham", weight = 8 },
			},
		},
	},
}

return GameConfig
