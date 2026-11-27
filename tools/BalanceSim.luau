--!strict
-- Balancing simulation (#41, extended to the whole campaign in #108): plays a model player
-- with the real game rules (GameRules) and a configuration from a new player state until
-- the last world is unlocked, with as many rebirths as the player wants on the way, and
-- measures the play time per world and per rebirth run plus the gem income per source.
-- Used by `lune run balance` (tables in docs/balancing.md) and tests/BalanceSim.spec.luau.
--
-- Model (all assumptions, see docs/balancing.md):
-- * Income: rules.incomePerMinute (config.income.roundsPerMinute rounds of a full pizza
--   with the average topping of the highest unlocked world) x golden toppings (#94) x the
--   coin potion, credited every tick. Gem toppings: config.gems chances on the same number
--   of toppings.
-- * The player plays `sessionMinutes` per German day: login calendar at the start of each
--   session, play time gifts as soon as they are ready, the free lucky wheel spins (#98)
--   and the hidden chests (#100) of every unlocked chest world once a day.
-- * Delivery: every call is accepted and delivered after `deliverySeconds`; the ordered
--   toppings are not sold (their sell value is taken back from the income).
-- * Quests (#97) are not played: their expected gems (all done every day,
--   BalanceSim.questGemsPerDay) are paid after half of each day's session.
-- * Potions are drunk as soon as they are owned. Gems buy pet slots first, then coin potions.
-- * Coins: next world as soon as affordable, then pizza space, eggs of the highest unlocked
--   world whose expected coin gain pays them back within `eggPaybackMinutes`, range and
--   magnet levels costing at most `comfortMinutes` of income (no effect on the income).
-- * Pets: equipped pets gain levels (#90); 5 equal pets are merged into Gold / Rainbow (#80)
--   whenever that does not lower the pet multiplier. Shiny and Secret pets are left out.
-- * Rebirth: as soon as it is affordable, unless the next world it may buy costs at most the
--   rebirth price (then that world first). Worlds behind more rebirths (`requiredRebirths`,
--   #43) are never entered before.
-- * The campaign ends when the last world (or `targetWorld`) is unlocked.

local GameRules = require("../src/shared/GameRules")

export type Options = {
	seed: number?,
	tickSeconds: number?,
	sessionMinutes: number?,
	deliverySeconds: number?,
	eggPaybackMinutes: number?,
	comfortMinutes: number?,
	-- World index whose unlock ends the campaign (default: the last world).
	targetWorld: number?,
	-- Safety stop (minutes of play time).
	maxMinutes: number?,
	-- Called with the play time (minutes) and a short note on every purchase.
	trace: ((minutes: number, note: string) -> ())?,
}

-- One rebirth run: minutes from its start to the rebirth (or the campaign end), the
-- rebirths the player had during it, the highest world it reached and the pet multiplier
-- at its end.
export type Run = { minutes: number, rebirths: number, highestWorld: number, petMultiplier: number }

export type Campaign = {
	-- Minutes of play time when the world was unlocked the first time (world 1: 0).
	worldEnteredAt: { number },
	-- Minutes from the first unlock of a world to the first unlock of the next one.
	worldMinutes: { number },
	-- Coins per minute (without potions) right before the world was unlocked the first time.
	incomeAtUnlock: { number },
	-- Rebirths done when the world was unlocked the first time.
	rebirthsAtUnlock: { number },
	runs: { Run },
	-- Rebirths done when the last world was unlocked.
	rebirths: number,
	totalMinutes: number,
	-- Gems earned per source (Toppings, Delivery, Gifts, Calendar, Wheel, Chests) and in total.
	gems: { [string]: number },
	gemsTotal: number,
	petMultiplier: number,
}

local BalanceSim = {}

BalanceSim.GEM_SOURCES = { "Toppings", "Delivery", "Gifts", "Calendar", "Wheel", "Chests", "Quests" }
-- Gem sources that are not bound to a German day (#72: "regular sources", 20-40 an hour);
-- wheel, chests and quests pay a fixed amount once a day.
BalanceSim.REGULAR_SOURCES = { "Toppings", "Delivery", "Gifts", "Calendar" }

-- Expected gems a day from quests (#97) when all daily quests and their bonus chest are
-- done every day (streak chest every `streakDays` days) and all weekly quests every week.
function BalanceSim.questGemsPerDay(config: any): number
	local quests = config.quests
	if quests == nil then
		return 0
	end
	local function expected(rewards: { any }): number
		local total, gemsSum = 0, 0
		for _, reward in rewards do
			local weight = reward.weight or 1
			total += weight
			if reward.kind == "Gems" then
				gemsSum += weight * reward.amount
			end
		end
		return if total > 0 then gemsSum / total else 0
	end
	local function fixed(rewards: { any }): number
		local sum = 0
		for _, reward in rewards do
			if reward.kind == "Gems" then
				sum += reward.amount
			end
		end
		return sum
	end
	return quests.dailyCount * expected(quests.dailyRewards)
		+ fixed(quests.bonusRewards)
		+ fixed(quests.streakRewards) / quests.streakDays
		+ quests.weeklyCount * expected(quests.weeklyRewards) / 7
end

-- 2026-01-05 08:00 UTC: winter time, so a German day is exactly 24 h long for ~80 days.
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

function BalanceSim.campaign(config: any, options: Options?): Campaign
	local opts: Options = options or {}
	-- Secret pets (#81) are a 1 in 20,000 jackpot, not part of the expected curve: left out,
	-- so their extra roll per egg does not shift the simulated luck.
	-- Shiny pets (#80) are left out for the same reason.
	if config.secretPets or config.shinyPets then
		config = table.clone(config)
		config.secretPets = nil
		config.shinyPets = nil
	end
	local rules = GameRules.new(config)
	local random = lcg(opts.seed or 1)
	local tick = opts.tickSeconds or 10
	local sessionSeconds = (opts.sessionMinutes or 60) * 60
	local deliverySeconds = opts.deliverySeconds or 60
	local eggPayback = opts.eggPaybackMinutes or 10
	local comfortMinutes = opts.comfortMinutes or 5
	local targetWorld = opts.targetWorld or #config.worlds
	local maxSeconds = (opts.maxMinutes or 6000) * 60

	local shopIds = {}
	for shopId in config.shops do
		table.insert(shopIds, shopId)
	end
	table.sort(shopIds)

	local chestWorlds = if config.hiddenChests then config.hiddenChests.worlds else {}
	-- Quests are not played in the model: their expected gems come once a day.
	local questGems = BalanceSim.questGemsPerDay(config)
	local questDay = -1
	local questFraction = 0
	local goldenExtra = if config.goldenToppings then config.goldenToppings.valueMultiplier - 1 else 0

	local state = rules.newPlayerState()
	state.tutorialStep = 99 -- tutorial done (it takes the first minute anyway)
	local played = 0 -- seconds of play time in total
	local gemFraction = 0
	local deliverAt: number? = nil
	local gems: { [string]: number } = {}
	for _, source in BalanceSim.GEM_SOURCES do
		gems[source] = 0
	end

	local function now(): number
		-- A day covers play time (0, session]: the last tick of a day still counts there
		-- (so the 60 minute gift is claimed), the next one starts the next day.
		local day = math.max(0, played - 1) // sessionSeconds
		return START_TIME + day * DAY_SECONDS + (played - day * sessionSeconds)
	end

	local function apply(result: any): boolean
		if result.ok then
			state = result.state
		end
		return result.ok
	end

	-- Applies a reward action and books the gems it paid to `source`.
	local function applyGems(source: string, result: any): boolean
		local before = state.gems
		local ok = apply(result)
		gems[source] += math.max(0, state.gems - before)
		return ok
	end

	local function note(text: string)
		if opts.trace then
			opts.trace(played / 60, `{text} (r{state.rebirths}, coins/min {math.floor(rules.incomePerMinute(state))})`)
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

	local function income(): number
		local golden = if goldenExtra > 0 then 1 + rules.goldenChance(state) * goldenExtra else 1
		return rules.incomePerMinute(state) * golden
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
				table.insert(equipped, rules.petBonus(pet))
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
					if weakest == nil or rules.petBonus(pet) < rules.petBonus(weakest) then
						weakest = pet
					end
				end
			end
			if weakest == nil or not apply(rules.deletePet(state, weakest.uid)) then
				return
			end
		end
	end

	-- Merges equal pets (#80) as long as it does not lower the pet multiplier.
	local function mergeAll()
		local merged = true
		while merged do
			merged = false
			for _, group in rules.mergeGroups(state.pets) do
				if group.have >= group.need then
					local before = rules.petMultiplier(state)
					local saved = state
					if apply(rules.mergePets(state, group.petId, group.variant, now())) then
						apply(rules.equipBest(state))
						if rules.petMultiplier(state) < before then
							state = saved
						else
							merged = true
							note(`merge {group.petId} -> {group.target}`)
							break
						end
					end
				end
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
		local perMinute = income()
		local changed = true
		while changed do
			changed = false
			-- Pizza space first (more income), then cheap comfort upgrades.
			for _, upgradeId in { "PizzaSpace", "CollectRange", "Magnet" } do
				for _, shopId in shopIds do
					local level = rules.upgradeLevel(state, upgradeId)
					local nextLevel = config.upgrades[upgradeId].levels[level + 1]
					local affordable = nextLevel ~= nil
						and (upgradeId == "PizzaSpace" or nextLevel.price <= perMinute * comfortMinutes)
					if affordable and apply(rules.buyUpgrade(state, shopId, upgradeId)) then
						note(`{upgradeId} {level + 1}`)
						changed = true
						perMinute = income()
					end
				end
			end
			-- Eggs of the highest unlocked world: the best expected gain per coin, if it pays back.
			local baseIncome = perMinute / rules.petMultiplier(state)
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
					mergeAll()
					note(`{bestEgg} -> pets x{rules.petMultiplier(state)}`)
					changed = true
					perMinute = income()
				end
			end
			if state.coins >= goalPrice then
				return
			end
		end
	end

	local function step()
		local coins = income() * rules.potionCoinMultiplier(state) * tick / 60
		state.coins += coins
		state.totalCoinsEarned += coins
		local toppings = rules.pizzaCapacity(state) * config.income.roundsPerMinute * tick / 60
		local gemChance = config.gems.toppingChance * (config.gems.toppingMin + config.gems.toppingMax) / 2
		gemFraction += toppings * gemChance
		local wholeGems = math.floor(gemFraction)
		state.gems += wholeGems
		gems.Toppings += wholeGems
		gemFraction -= wholeGems

		-- The tick (played, played + tick] counts on the day of its end.
		played += tick
		local t = now()
		apply(rules.addPlayTime(state, tick, t))
		if config.petLevels then
			apply(rules.addPetXp(state, tick))
		end
		if next(state.activePotions) then
			apply(rules.tickPotions(state, tick))
		end

		-- Quest gems once a day, after half a session (quests take some play time).
		local day = rules.dayNumber(t)
		if day ~= questDay and rules.dailyPlaytime(state, t) >= sessionSeconds / 2 then
			questDay = day
			questFraction += questGems
			local whole = math.floor(questFraction)
			questFraction -= whole
			state.gems += whole
			gems.Quests += whole
		end

		-- Login calendar (once a day), play time gifts, free wheel spins and hidden chests.
		applyGems("Calendar", rules.claimLoginReward(state, t, random))
		for index in config.gifts do
			applyGems("Gifts", rules.claimGift(state, index, t, random))
		end
		if config.luckyWheel then
			applyGems("Wheel", rules.spinWheel(state, t, random, true))
		end
		for _, worldId in chestWorlds do
			if rules.isWorldUnlocked(state, worldId) then
				applyGems("Chests", rules.openSecretChest(state, worldId, t))
			end
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
				if applyGems("Delivery", rules.deliverOrder(state, t)) then
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

	local enteredAt = { [1] = 0 }
	local incomeAtUnlock = { [1] = 0 }
	local rebirthsAtUnlock = { [1] = 0 }
	local runs: { Run } = {}
	local runStartedAt = 0
	local highest = 1

	while unlockedCount() < targetWorld do
		if played > maxSeconds then
			error(`BalanceSim: world {targetWorld} not reached within {maxSeconds / 60} minutes`)
		end
		step()
		local count = unlockedCount()
		local nextWorld = config.worlds[count + 1]
		if nextWorld and not rules.hasRebirthsFor(state, nextWorld.id) then
			nextWorld = nil -- needs more rebirths (#43): play on towards the rebirth
		end
		local offer = rules.rebirthOffer(state)
		local incomeBefore = income()
		if nextWorld and state.coins >= nextWorld.unlockPrice and apply(rules.unlockWorld(state, nextWorld.id)) then
			count += 1
			incomeAtUnlock[count] = incomeAtUnlock[count] or incomeBefore
			rebirthsAtUnlock[count] = rebirthsAtUnlock[count] or state.rebirths
			highest = math.max(highest, count)
			enteredAt[count] = enteredAt[count] or played / 60
			note(`unlock {nextWorld.id}`)
		elseif offer.affordable and (nextWorld == nil or nextWorld.unlockPrice > offer.price) then
			table.insert(runs, {
				minutes = (played - runStartedAt) / 60,
				rebirths = state.rebirths,
				highestWorld = count,
				petMultiplier = rules.petMultiplier(state),
			})
			assert(apply(rules.rebirth(state, now())), "BalanceSim: rebirth failed")
			runStartedAt = played
			deliverAt = nil
			note("rebirth")
		else
			spendCoins(if nextWorld then math.min(nextWorld.unlockPrice, offer.price) else offer.price)
		end
	end
	table.insert(runs, {
		minutes = (played - runStartedAt) / 60,
		rebirths = state.rebirths,
		highestWorld = highest,
		petMultiplier = rules.petMultiplier(state),
	})

	local worldMinutes = {}
	for index = 1, targetWorld - 1 do
		worldMinutes[index] = enteredAt[index + 1] - enteredAt[index]
	end
	local gemsTotal = 0
	for _, amount in gems do
		gemsTotal += amount
	end
	return {
		worldEnteredAt = enteredAt,
		worldMinutes = worldMinutes,
		incomeAtUnlock = incomeAtUnlock,
		rebirthsAtUnlock = rebirthsAtUnlock,
		runs = runs,
		rebirths = state.rebirths,
		totalMinutes = played / 60,
		gems = gems,
		gemsTotal = gemsTotal,
		petMultiplier = rules.petMultiplier(state),
	}
end

local function median(values: { number }): number
	local sorted = table.clone(values)
	table.sort(sorted)
	local middle = (#sorted + 1) / 2
	return (sorted[math.floor(middle)] + sorted[math.ceil(middle)]) / 2
end
BalanceSim.medianOf = median

-- Campaigns over `seeds` different lucks, plus the median of the main numbers.
export type Summary = {
	campaigns: { Campaign },
	worldEnteredAt: { number },
	worldMinutes: { number },
	totalMinutes: number,
	rebirths: number,
	gemsPerHour: number,
}

function BalanceSim.summary(config: any, seeds: number, options: Options?): Summary
	local campaigns = {}
	for seed = 1, seeds do
		local opts = table.clone(options or {})
		opts.seed = seed * 7919
		table.insert(campaigns, BalanceSim.campaign(config, opts))
	end
	local function medianOf(get: (Campaign) -> number): number
		local values = {}
		for _, campaign in campaigns do
			table.insert(values, get(campaign))
		end
		return median(values)
	end
	local worlds = #campaigns[1].worldEnteredAt
	local entered, perWorld = {}, {}
	for index = 1, worlds do
		entered[index] = medianOf(function(c)
			return c.worldEnteredAt[index]
		end)
		if index < worlds then
			perWorld[index] = medianOf(function(c)
				return c.worldMinutes[index]
			end)
		end
	end
	return {
		campaigns = campaigns,
		worldEnteredAt = entered,
		worldMinutes = perWorld,
		totalMinutes = medianOf(function(c)
			return c.totalMinutes
		end),
		rebirths = medianOf(function(c)
			return c.rebirths
		end),
		gemsPerHour = medianOf(function(c)
			return c.gemsTotal / (c.totalMinutes / 60)
		end),
	}
end

return BalanceSim
