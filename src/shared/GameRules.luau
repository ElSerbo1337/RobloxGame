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
	-- HUD switch: collect toppings by walking over them. Free from the start.
	autoCollect: boolean,
	-- Multiplies coins earned from selling; raised by rebirths (not built yet).
	rebirthMultiplier: number,
}

export type Result = {
	ok: boolean,
	-- Set when ok == false: "UnknownTopping" | "OutOfRange" | "PizzaFull" | "PizzaEmpty" | "AutoCollectOff"
	reason: string?,
	state: PlayerState,
}

export type SellResult = Result & { coinsEarned: number }

-- Bump together with a migration step in SaveData when a field changes shape.
local STATE_VERSION = 2

local GameRules = {}

function GameRules.new(config: any)
	local rules = {}

	local function fail(state: PlayerState, reason: string): Result
		return { ok = false, reason = reason, state = state }
	end

	function rules.newPlayerState(): PlayerState
		return { version = STATE_VERSION, coins = 0, pizza = {}, autoCollect = false, rebirthMultiplier = 1 }
	end

	function rules.pizzaCapacity(_state: PlayerState): number
		return config.pizza.startCapacity
	end

	function rules.collectRange(_state: PlayerState): number
		return config.collect.range
	end

	function rules.isPizzaFull(state: PlayerState): boolean
		return #state.pizza >= rules.pizzaCapacity(state)
	end

	-- Pickup radius around the player while auto-collect is on (the magnet will grow it later).
	function rules.autoCollectRadius(_state: PlayerState): number
		return config.collect.autoRadius
	end

	local function addTopping(state: PlayerState, toppingId: string, distance: number, range: number): Result
		if config.toppings[toppingId] == nil then
			return fail(state, "UnknownTopping")
		end
		if distance > range then
			return fail(state, "OutOfRange")
		end
		if rules.isPizzaFull(state) then
			return fail(state, "PizzaFull")
		end

		local newState = table.clone(state)
		newState.pizza = table.clone(state.pizza)
		table.insert(newState.pizza, toppingId)
		return { ok = true, state = newState }
	end

	-- Player clicked/tapped a topping. `distance` is measured by the server
	-- between the player and the topping.
	function rules.collectTopping(state: PlayerState, toppingId: string, distance: number): Result
		return addTopping(state, toppingId, distance, rules.collectRange(state))
	end

	-- Player walked over a topping with auto-collect switched on.
	function rules.autoCollectTopping(state: PlayerState, toppingId: string, distance: number): Result
		if not state.autoCollect then
			return fail(state, "AutoCollectOff")
		end
		return addTopping(state, toppingId, distance, rules.autoCollectRadius(state))
	end

	function rules.setAutoCollect(state: PlayerState, enabled: boolean): Result
		local newState = table.clone(state)
		newState.autoCollect = enabled
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
