--!strict
-- Potions outside the shop (buying happens at the gem counter, see ShopService):
-- * Drinking: a wish from the client (DrinkPotion); the game rules decide.
-- * Time: running potions only count down while the player is online. The server
--   credits the passed time through rules.tickPotions every few seconds, or right
--   when a potion's time is up, so effects end on time.
-- * Replication: Potions and ActivePotions attributes (JSON, see Net) for the potion
--   menu, the HUD timers and the egg preview.
-- The effects themselves live in the rules: sellPizza (coins), openEggs (luck) and
-- rules.walkSpeed (speed; GemService applies it to the humanoid on every change).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)

type PlayerState = GameRules.PlayerState

-- How often the server looks at running potions, and the most time it lets pass
-- before crediting it (also how often the HUD timers get re-synced).
local CHECK_SECONDS = 1
local MAX_UNCREDITED_SECONDS = 5

local PotionService = {}

local function replicate(player: Player, state: PlayerState)
	player:SetAttribute("Potions", HttpService:JSONEncode(state.potions))
	player:SetAttribute("ActivePotions", HttpService:JSONEncode(state.activePotions))
end

function PotionService.start()
	local potionNotify = Net.event("PotionNotify")
	-- When each player's running potions were last credited (os.clock()).
	local lastTick: { [Player]: number } = {}

	PlayerStates.onChanged(replicate)
	for _, player in Players:GetPlayers() do
		local state = PlayerStates.get(player)
		if state then
			replicate(player, state)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTick[player] = nil
	end)

	Net.event("DrinkPotion").OnServerEvent:Connect(function(player: Player, potionId: unknown)
		if type(potionId) ~= "string" then
			return
		end
		local state = PlayerStates.get(player)
		if state == nil then
			return
		end
		local result = PlayerStates.rules.drinkPotion(state, potionId)
		if result.ok then
			PlayerStates.set(player, result.state)
			potionNotify:FireClient(player, "Drunk", potionId)
		else
			potionNotify:FireClient(player, result.reason, potionId)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local state = PlayerStates.get(player)
				local since = lastTick[player]
				if state == nil or next(state.activePotions) == nil or since == nil then
					-- Nothing running (or still loading): time without potions is not credited.
					lastTick[player] = now
					continue
				end
				local passed = now - since
				local soonest = math.huge
				for _, left in state.activePotions do
					soonest = math.min(soonest, left)
				end
				if passed < MAX_UNCREDITED_SECONDS and passed < soonest then
					continue
				end
				lastTick[player] = now
				local result = PlayerStates.rules.tickPotions(state, passed)
				if result.ok then
					PlayerStates.set(player, result.state)
					for _, potionId in result.expired do
						potionNotify:FireClient(player, "Expired", potionId)
					end
				end
			end
		end
	end)
end

return PotionService
