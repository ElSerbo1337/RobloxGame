--!strict
-- Loading screen (#111): which tips it shows, in which order, and when it goes away.
-- Pure Luau without Roblox API (tested in tests/LoadingTips.spec.luau). The screen
-- itself is src/first/LoadingScreen.client.luau (ReplicatedFirst). Requires nothing:
-- the screen renders `LoadingTips.textArgs` with Texts.render.
--
-- A tip belongs to the feature it explains: switched-off features get no tip. Tips
-- without a feature (e.g. the worlds) are always shown. Texts: `loading.tip.<id>` in
-- Texts.strings; the worlds tip names the number of worlds and the last world
-- (as a name argument, so English players see `displayNameEn`).

export type Tip = { id: string, feature: string? }
export type Timing = {
	minSeconds: number, -- shown at least this long, so the first tip can be read
	maxSeconds: number, -- gone after this long, even if the game is still loading
	tipSeconds: number, -- each tip stays this long
	skipAfterSeconds: number, -- from then on a tap hides the screen
	fadeSeconds: number,
}

local LoadingTips = {}

LoadingTips.TIPS = {
	{ id = "merge", feature = "petMerge" },
	{ id = "shiny", feature = "shinyPets" },
	{ id = "secret", feature = "secretPets" },
	{ id = "quests", feature = "dailyQuests" },
	{ id = "wheel", feature = "luckyWheel" },
	{ id = "codes", feature = "codes" },
	{ id = "index", feature = "petIndex" },
	{ id = "petLevels", feature = "petLevels" },
	{ id = "potions", feature = "newPotions" },
	{ id = "golden", feature = "goldenToppings" },
	{ id = "calendar", feature = "loginCalendar30" },
	{ id = "worlds" },
	{ id = "rebirth" },
} :: { Tip }

-- Tips whose feature is on (in TIPS order). Unknown feature ids raise an error, like
-- Features.enabled, so a renamed switch never silently hides a tip.
function LoadingTips.available(features: { [string]: boolean }): { string }
	local ids = {}
	for _, tip in LoadingTips.TIPS do
		if tip.feature then
			local on = features[tip.feature]
			if on == nil then
				error(`Unknown feature "{tip.feature}" for loading tip "{tip.id}"`)
			end
			if not on then
				continue
			end
		end
		table.insert(ids, tip.id)
	end
	return ids
end

-- A shuffled copy of `ids` (random() in [0, 1)), so every join starts with another tip.
function LoadingTips.shuffle(ids: { string }, random: () -> number): { string }
	local result = table.clone(ids)
	for i = #result, 2, -1 do
		local j = math.clamp(math.floor(random() * i) + 1, 1, i)
		result[i], result[j] = result[j], result[i]
	end
	return result
end

-- Index (1-based) of the tip to show `elapsed` seconds after the screen appeared;
-- the tips repeat. 0 when there are none.
function LoadingTips.tipIndex(elapsed: number, count: number, tipSeconds: number): number
	if count <= 0 then
		return 0
	end
	local step = math.floor(math.max(elapsed, 0) / math.max(tipSeconds, 0.1))
	return step % count + 1
end

-- True once the screen should fade out: the game has loaded and the minimum time is
-- over, or the time limit is reached (slow connections never stay stuck), or the
-- player tapped after `skipAfterSeconds`.
function LoadingTips.shouldHide(elapsed: number, loaded: boolean, timing: Timing, skipped: boolean?): boolean
	if elapsed >= timing.maxSeconds then
		return true
	end
	if skipped and LoadingTips.canSkip(elapsed, timing) then
		return true
	end
	return loaded and elapsed >= timing.minSeconds
end

function LoadingTips.canSkip(elapsed: number, timing: Timing): boolean
	return elapsed >= timing.skipAfterSeconds
end

-- Progress bar share 0..1: creeps towards 90 % while loading, full once loaded.
function LoadingTips.progress(elapsed: number, loaded: boolean, timing: Timing): number
	if loaded then
		return 1
	end
	return 0.9 * math.clamp(elapsed / math.max(timing.maxSeconds, 0.1), 0, 1)
end

type Named = { displayName: string, displayNameEn: string? }
type WorldsConfig = { worlds: { Named } }

-- Text key and sign arguments (see Texts.render) of tip `id`:
--   Texts.render(language, LoadingTips.textArgs(id, GameConfig))
function LoadingTips.textArgs(id: string, config: WorldsConfig): (string, { [string]: any }?)
	local key = `loading.tip.{id}`
	if id == "worlds" then
		local worlds = config.worlds
		local last = worlds[#worlds]
		return key,
			{
				count = { integer = #worlds },
				world = if last then { de = last.displayName, en = last.displayNameEn or last.displayName } else "",
			}
	end
	return key, nil
end

return LoadingTips
