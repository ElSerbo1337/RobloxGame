--!strict
-- Game rules: pure Luau, no Roblox API. Works on a PlayerState table and returns
-- a result with success/failure reason plus the new state. Old states are never
-- mutated. The Roblox layer only calls these functions; it never changes a
-- PlayerState by itself.
--
-- Usage: local rules = GameRules.new(GameConfig)

export type PlayerState = {
	version: number,
	coins: number,
	-- Topping ids currently on the pizza, in collection order.
	pizza: { string },
}

export type Result = {
	ok: boolean,
	-- Set when ok == false: "UnknownTopping" | "OutOfRange" | "PizzaFull" | "PizzaEmpty"
	reason: string?,
	state: PlayerState,
}

export type SellResult = Result & { coinsEarned: number }

local STATE_VERSION = 1

local GameRules = {}

function GameRules.new(config: any)
	local rules = {}

	local function fail(state: PlayerState, reason: string): Result
		return { ok = false, reason = reason, state = state }
	end

	function rules.newPlayerState(): PlayerState
		return { version = STATE_VERSION, coins = 0, pizza = {} }
	end

	function rules.pizzaCapacity(_state: PlayerState): number
		return config.pizza.startCapacity
	end

	function rules.collectRange(_state: PlayerState): number
		return config.collect.range
	end

	-- `distance` is measured by the server between the player and the topping.
	function rules.collectTopping(state: PlayerState, toppingId: string, distance: number): Result
		if config.toppings[toppingId] == nil then
			return fail(state, "UnknownTopping")
		end
		if distance > rules.collectRange(state) then
			return fail(state, "OutOfRange")
		end
		if #state.pizza >= rules.pizzaCapacity(state) then
			return fail(state, "PizzaFull")
		end

		local newState = table.clone(state)
		newState.pizza = table.clone(state.pizza)
		table.insert(newState.pizza, toppingId)
		return { ok = true, state = newState }
	end

	-- Sells every topping on the pizza at once.
	function rules.sellPizza(state: PlayerState): SellResult
		if #state.pizza == 0 then
			return { ok = false, reason = "PizzaEmpty", state = state, coinsEarned = 0 }
		end

		local earned = 0
		for _, toppingId in state.pizza do
			earned += config.toppings[toppingId].value
		end

		local newState = table.clone(state)
		newState.pizza = {}
		newState.coins = state.coins + earned
		return { ok = true, state = newState, coinsEarned = earned }
	end

	return rules
end

return GameRules
