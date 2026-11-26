--!strict
-- Analytics (#114): logs funnel and custom events to Roblox AnalyticsService (Creator
-- Hub > Analytics). Which events a state change creates is decided by the game rules
-- (rules.analyticsEvents); once-only events are stored in the PlayerState so they never
-- fire twice. Behind features.analytics. Logging errors never touch the game (pcall).

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local PlayerStates = require(script.Parent.PlayerStates)

local features = Features.new(GameConfig.features)
local rules = PlayerStates.rules

local Analytics = {}

local function fields(field: string?): any
	if field == nil then
		return nil
	end
	return { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = field }
end

local function send(player: Player, event: GameRules.AnalyticsEvent)
	local ok, err = pcall(function()
		if event.kind == "Onboarding" then
			AnalyticsService:LogOnboardingFunnelStepEvent(player, event.step :: number, event.name)
		elseif event.kind == "Funnel" then
			AnalyticsService:LogFunnelStepEvent(player, event.funnel :: string, nil, event.step :: number, event.name)
		else
			AnalyticsService:LogCustomEvent(player, event.name, event.value or 1, fields(event.field))
		end
	end)
	if not ok then
		warn(`[Analytics] {event.name} für {player.Name} nicht geloggt: {err}`)
	end
end

-- A pet merge (#80): not visible from the state alone, so PetService reports it.
function Analytics.logMerge(player: Player, variant: string)
	if features.enabled("analytics") then
		send(player, { kind = "Custom", name = "PetMerge", value = 1, field = variant })
	end
end

function Analytics.start()
	if not features.enabled("analytics") then
		return
	end
	-- The last state seen per player, for events that need a before/after (quests, spins).
	local previous: { [Player]: GameRules.PlayerState } = {}
	PlayerStates.onChanged(function(player, state)
		local old = previous[player]
		previous[player] = state
		local ok, events = pcall(rules.analyticsEvents, old, state)
		if not ok or #events == 0 then
			return
		end
		local keys = {}
		for _, event in events do
			send(player, event)
			if event.key then
				table.insert(keys, event.key)
			end
		end
		local current = PlayerStates.get(player)
		if #keys > 0 and current ~= nil then
			local marked = rules.markAnalyticsLogged(current, keys).state
			previous[player] = marked
			PlayerStates.set(player, marked)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		previous[player] = nil
	end)
end

return Analytics
