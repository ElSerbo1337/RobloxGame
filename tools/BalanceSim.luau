--!strict
-- Balancing simulation (#41): plays a model player through worlds 1-7 with the real game
-- rules (GameRules) and a configuration, and measures the play time spent in every world,
-- once from a new player state and once after the first rebirth.
-- Used by `lune run balance` (table in docs/balancing.md) and tests/GameConfig.spec.luau.
--
-- Model (all assumptions, see docs/balancing.md):
-- * Income: rules.incomePerMinute (config.income.roundsPerMinute rounds of a full pizza
--   with the average topping of the highest unlocked world) x the coin potion, credited
--   every tick. Gem toppings: config.gems chances on the same number of toppings.
-- * The player plays `sessionMinutes` per German day: login calendar at the start of each
--   session, play time gifts as soon as they are ready.
-- * Delivery: every call is accepted and delivered after `deliverySeconds`; the ordered
--   toppings are not sold (their sell value is taken back from the income).
-- * Potions are drunk as soon as they are owned. Gems buy pet slots first, then coin potions.
-- * Coins: next world as soon as affordable, then pizza space, eggs of the highest unlocked
--   world whose expected coin gain pays them back within `eggPaybackMinutes`, range and
--   magnet levels costing at most `comfortMinutes` of income (no effect on the income).
-- * A run ends with the rebirth (run 1) or once the next rebirth is affordable (run 2).

local GameRules = require("../src/shared/GameRules")

export type Options = {
	seed: number?,
	tickSeconds: number?,
	sessionMinutes: number?,
	deliverySeconds: number?,
	eggPaybackMinutes: number?,
	comfortMinutes: number?,
	-- Safety stop per run (minutes of play time).
	maxMinutes: number?,
	-- Called with the play time (minutes) and a short note on every purchase.
	trace: ((minutes: number, note: string) -> ())?,
}

-- Minutes spent in each world (index = world; the last world lasts until the next
-- rebirth is affordable) plus the run's total.
export type Run = { worlds: { number }, total: number }
export type Result = { first: Run, afterRebirth: Run, rebirthPetMultiplier: number }

local BalanceSim = {}

-- 2026-01-05 08:00 UTC: winter time, so a German day is exactly 24 h long throughout.
local START_TIME = 1767600000
local DAY_SECONDS = 24 * 3600

local function lcg(seed: number): () -> number
	local value = seed % 2147483647
	if value <= 0 then
		value += 2147483646
	end
	return function()
		value = (value * 48271) % 2147483647
		return value / 2147483647
	end
end

function BalanceSim.run(config: any, options: Options?): Result
	local opts: Options = options or {}
	local rules = GameRules.new(config)
	local random = lcg(opts.seed or 1)
	local tick = opts.tickSeconds or 5
	local sessionSeconds = (opts.sessionMinutes or 60) * 60
	local deliverySeconds = opts.deliverySeconds or 60
	local eggPayback = opts.eggPaybackMinutes or 10
	local comfortMinutes = opts.comfortMinutes or 5
	local maxSeconds = (opts.maxMinutes or 1500) * 60

	local shopIds = {}
	for shopId in config.shops do
		table.insert(shopIds, shopId)
	end
	table.sort(shopIds)

	local state = rules.newPlayerState()
	state.tutorialStep = 99 -- tutorial done (it takes the first minute anyway)
	local played = 0 -- seconds of play time in total
	local gemFraction = 0
	local deliverAt: number? = nil

	local function now(): number
		local day = played // sessionSeconds
		return START_TIME + day * DAY_SECONDS + (played - day * sessionSeconds)
	end

	local function apply(result: any): boolean
		if result.ok then
			state = result.state
		end
		return result.ok
	end

	local function note(text: string)
		if opts.trace then
			opts.trace(played / 60, `{text} (coins/min {math.floor(rules.incomePerMinute(state))})`)
		end
	end

	local function unlockedCount(): number
		local count = 0
		for _, world in config.worlds do
			if rules.isWorldUnlocked(state, world.id) then
				count += 1
			end
		end
		return count
	end

	local function drinkAll()
		for potionId in config.potions do
			local drunk = true
			while drunk do
				drunk = apply(rules.drinkPotion(state, potionId))
			end
		end
	end

	-- Expected gain of the coin multiplier sum when one pet of this egg joins the team.
	local function expectedPetGain(eggId: string): number
		local equipped = {}
		for _, pet in state.pets do
			if table.find(state.equipped, pet.uid) then
				table.insert(equipped, config.pets[pet.petId].bonus)
			end
		end
		local weakest = 0
		if #equipped >= rules.petSlots(state) then
			weakest = math.huge
			for _, bonus in equipped do
				weakest = math.min(weakest, bonus)
			end
		end
		local preview = rules.eggPreview(eggId, state)
		local gain = 0
		for _, entry in preview.pets do
			gain += entry.chancePercent / 100 * math.max(0, entry.bonus - weakest)
		end
		return gain
	end

	local function makeRoom()
		while #state.pets >= rules.inventorySlots(state) do
			local weakest = nil
			for _, pet in state.pets do
				if not table.find(state.equipped, pet.uid) then
					if weakest == nil or config.pets[pet.petId].bonus < config.pets[weakest.petId].bonus then
						weakest = pet
					end
				end
			end
			if weakest == nil or not apply(rules.deletePet(state, weakest.uid)) then
				return
			end
		end
	end

	local function spendGems()
		local bought = true
		while bought do
			bought = false
			for _, shopId in shopIds do
				if apply(rules.buyUpgrade(state, shopId, "PetSlots")) then
					note(`PetSlots {rules.petSlots(state)}`)
					bought = true
					apply(rules.equipBest(state))
				end
			end
		end
		-- Pet slots maxed for now (no reachable shop sells the next one): coin potions.
		local nextSlotSold = false
		for _, shopId in shopIds do
			for _, offer in rules.shopOffers(state, shopId) do
				if offer.upgrade == "PetSlots" and offer.level < offer.shopMaxLevel then
					local shop = config.shops[shopId]
					if shop.worldId == nil or rules.isWorldUnlocked(state, shop.worldId) then
						nextSlotSold = true
					end
				end
			end
		end
		if not nextSlotSold then
			for _, shopId in shopIds do
				local potionBought = true
				while potionBought do
					potionBought = apply(rules.buyPotion(state, shopId, "Coins"))
				end
			end
			drinkAll()
		end
	end

	local function spendCoins(goalPrice: number)
		local income = rules.incomePerMinute(state)
		local changed = true
		while changed do
			changed = false
			-- Pizza space first (more income), then cheap comfort upgrades.
			for _, upgradeId in { "PizzaSpace", "CollectRange", "Magnet" } do
				for _, shopId in shopIds do
					local level = rules.upgradeLevel(state, upgradeId)
					local nextLevel = config.upgrades[upgradeId].levels[level + 1]
					local affordable = nextLevel ~= nil
						and (upgradeId == "PizzaSpace" or nextLevel.price <= income * comfortMinutes)
					if affordable and apply(rules.buyUpgrade(state, shopId, upgradeId)) then
						note(`{upgradeId} {level + 1}`)
						changed = true
						income = rules.incomePerMinute(state)
					end
				end
			end
			-- Eggs of the highest unlocked world: the best expected gain per coin, if it pays back.
			local baseIncome = income / rules.petMultiplier(state)
			local bestEgg, bestRatio = nil, 0
			for _, eggId in config.worlds[unlockedCount()].eggs do
				local price = config.eggs[eggId].price
				local gainPerMinute = baseIncome * expectedPetGain(eggId)
				if price <= state.coins and price <= gainPerMinute * eggPayback then
					local ratio = gainPerMinute / price
					if ratio > bestRatio then
						bestEgg, bestRatio = eggId, ratio
					end
				end
			end
			if bestEgg then
				makeRoom()
				if apply(rules.openEgg(state, bestEgg, random)) then
					apply(rules.equipBest(state))
					note(`{bestEgg} -> pets x{rules.petMultiplier(state)}`)
					changed = true
					income = rules.incomePerMinute(state)
				end
			end
			if state.coins >= goalPrice then
				return
			end
		end
	end

	local function step()
		local t = now()
		local income = rules.incomePerMinute(state) * rules.potionCoinMultiplier(state)
		state.coins += income * tick / 60
		state.totalCoinsEarned += income * tick / 60
		local toppings = rules.pizzaCapacity(state) * config.income.roundsPerMinute * tick / 60
		local gemChance = config.gems.toppingChance * (config.gems.toppingMin + config.gems.toppingMax) / 2
		gemFraction += toppings * gemChance
		local wholeGems = math.floor(gemFraction)
		state.gems += wholeGems
		gemFraction -= wholeGems

		apply(rules.addPlayTime(state, tick, t))
		if next(state.activePotions) then
			apply(rules.tickPotions(state, tick))
		end
		played += tick
		t = now()

		-- Login calendar (once a day) and play time gifts.
		apply(rules.claimLoginReward(state, t, random))
		for index in config.gifts do
			apply(rules.claimGift(state, index, t, random))
		end

		-- Delivery: accept every call, deliver after deliverySeconds.
		if deliverAt == nil then
			if apply(rules.ringPhone(state, t, random)) and apply(rules.acceptOrder(state, t)) then
				deliverAt = t + deliverySeconds
			end
		elseif t >= deliverAt then
			local order = state.delivery.order
			if order then
				local pizza, value = {}, 0
				for toppingId, count in order.toppings do
					for _ = 1, count do
						table.insert(pizza, toppingId)
					end
					value += config.toppings[toppingId].value * count
				end
				state.pizza = pizza
				local multiplier = rules.coinMultiplier(state) * rules.potionCoinMultiplier(state)
				if apply(rules.deliverOrder(state, t)) then
					-- The ordered toppings were collected in the income stream but not sold.
					state.coins = math.max(0, state.coins - value * multiplier)
				else
					state.pizza = {}
					apply(rules.expireOrder(state, t))
				end
			end
			deliverAt = nil
		end
		drinkAll()
		spendGems()
	end

	-- Plays until `done()`; returns the minutes spent in each world (by unlock time).
	local function playRun(done: () -> boolean): Run
		local startedAt = played
		local enteredAt = { [1] = played }
		while not done() do
			if played - startedAt > maxSeconds then
				error(`BalanceSim: run did not finish within {maxSeconds / 60} minutes`)
			end
			step()
			local count = unlockedCount()
			local nextWorld = config.worlds[count + 1]
			local goal = if nextWorld then nextWorld.unlockPrice else rules.rebirthOffer(state).price
			if nextWorld and state.coins >= goal and apply(rules.unlockWorld(state, nextWorld.id)) then
				enteredAt[count + 1] = played
				note(`unlock {nextWorld.id}`)
			else
				spendCoins(goal)
			end
		end
		local worlds = {}
		for index = 1, #config.worlds do
			local nextAt = enteredAt[index + 1] or played
			table.insert(worlds, (nextAt - (enteredAt[index] or played)) / 60)
		end
		return { worlds = worlds, total = (played - startedAt) / 60 }
	end

	local function rebirthReady(): boolean
		return unlockedCount() == #config.worlds and rules.rebirthOffer(state).affordable
	end

	local first = playRun(rebirthReady)
	assert(apply(rules.rebirth(state, now())), "BalanceSim: rebirth failed")
	deliverAt = nil
	local petMultiplier = rules.petMultiplier(state)
	local afterRebirth = playRun(rebirthReady)
	return { first = first, afterRebirth = afterRebirth, rebirthPetMultiplier = petMultiplier }
end

-- Median minutes per world and of the total over `seeds` runs with different luck.
function BalanceSim.median(config: any, seeds: number, options: Options?): Result
	local runs = {}
	for seed = 1, seeds do
		local opts = table.clone(options or {})
		opts.seed = seed * 7919
		table.insert(runs, BalanceSim.run(config, opts))
	end
	local function median(values: { number }): number
		table.sort(values)
		local middle = (#values + 1) / 2
		return (values[math.floor(middle)] + values[math.ceil(middle)]) / 2
	end
	local function medianRun(key: string): Run
		local worlds = {}
		for index = 1, #config.worlds do
			local values = {}
			for _, run in runs do
				table.insert(values, run[key].worlds[index])
			end
			worlds[index] = median(values)
		end
		local totals = {}
		for _, run in runs do
			table.insert(totals, run[key].total)
		end
		return { worlds = worlds, total = median(totals) }
	end
	local pets = {}
	for _, run in runs do
		table.insert(pets, run.rebirthPetMultiplier)
	end
	return { first = medianRun("first"), afterRebirth = medianRun("afterRebirth"), rebirthPetMultiplier = median(pets) }
end

return BalanceSim
