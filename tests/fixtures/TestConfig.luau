-- Small, stable game config for tests, so balancing changes in GameConfig don't break them.
return {
	pizza = { startCapacity = 2 },
	collect = { range = 10 },
	toppingField = { count = 4, respawnSeconds = 5 },
	toppings = {
		Salami = { displayName = "Salami", value = 1 },
		Mushroom = { displayName = "Pilz", value = 2 },
		Mozzarella = { displayName = "Mozzarella", value = 5 },
	},
	worlds = {
		{
			id = "PizzeriaGarden",
			displayName = "Pizzeria-Garten",
			toppingSpawns = {
				{ topping = "Salami", weight = 6 },
				{ topping = "Mushroom", weight = 3 },
				{ topping = "Mozzarella", weight = 1 },
			},
		},
	},
}
