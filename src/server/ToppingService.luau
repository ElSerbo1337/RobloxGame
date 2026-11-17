--!strict
-- Shows the shared toppings of one world, handles collect requests from clients and
-- picks up toppings players walk over while auto-collect is on.
-- Started once per world; each instance only answers requests for its own world.
-- Rarely a slot holds a gem topping instead; it gives gems and never needs pizza space.
-- Every request is validated by the game rules (range, pizza capacity) and the
-- ToppingField (topping still there), so a topping can only be taken once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local ToppingField = require(ReplicatedStorage.Shared.ToppingField)
local PlayerStates = require(script.Parent.PlayerStates)
local MagnetPull = require(script.Parent.MagnetPull)
local ToppingLook = require(script.Parent.ToppingLook)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local DISC_DIAMETER = 3.5
local DISC_THICKNESS = 0.6
local RESPAWN_CHECK_SECONDS = 0.25
local AUTO_COLLECT_CHECK_SECONDS = 0.1
-- Toppings this far above/below the player's root part are not "walked over".
local AUTO_COLLECT_MAX_HEIGHT = 6
local FULL_NOTICE_SECONDS = 3

type PlayerState = GameRules.PlayerState

-- What ToppingService needs from a world's map (WorldMap layouts).
export type Layout = {
	toppingAreaCenter: Vector3,
	toppingAreaSize: Vector2,
	toppingsFolder: Folder,
}

-- The auto-collect switch is per player, not per world: hook it up only once.
local autoCollectSwitchConnected = false

local ToppingService = {}

function ToppingService.start(worldId: string, layout: Layout)
	local rng = Random.new()
	local field = ToppingField.new(GameConfig, worldId, function()
		return rng:NextNumber()
	end)
	local parts: { [number]: BasePart } = {}

	local function worldPosition(x: number, z: number): Vector3
		local size = layout.toppingAreaSize
		return layout.toppingAreaCenter + Vector3.new((x - 0.5) * size.X, DISC_THICKNESS / 2 + 0.1, (z - 0.5) * size.Y)
	end

	local function render(slotId: number)
		if parts[slotId] then
			parts[slotId]:Destroy()
			parts[slotId] = nil
		end
		local topping = field:get(slotId)
		if topping == nil then
			return
		end
		local disc
		if topping.gems then
			disc = ToppingLook.createGem(topping.gems)
			disc.CFrame = CFrame.new(worldPosition(topping.x, topping.z) + Vector3.new(0, disc.Size.Y * 0.6, 0))
				* ToppingLook.GEM_TILT
		else
			disc = ToppingLook.createDisc(topping.toppingId, DISC_DIAMETER, DISC_THICKNESS)
			disc.CFrame = CFrame.new(worldPosition(topping.x, topping.z)) * ToppingLook.FLAT
			-- Imported Blender model if available (#15), otherwise the coloured disc stays.
			ModelLibrary.dressDisc(disc, topping.toppingId)
		end
		disc:SetAttribute("SlotId", slotId)
		disc:SetAttribute("WorldId", worldId)
		disc.Parent = layout.toppingsFolder
		parts[slotId] = disc
	end

	for slotId = 1, field.slotCount do
		render(slotId)
	end

	local notify = Net.event("Notify")
	local lastFullNotice: { [Player]: number } = {}

	-- "Pizza voll!" at most every FULL_NOTICE_SECONDS, so walking over toppings doesn't spam it.
	local function notifyFull(player: Player)
		local now = os.clock()
		if now - (lastFullNotice[player] or -math.huge) >= FULL_NOTICE_SECONDS then
			lastFullNotice[player] = now
			notify:FireClient(player, "PizzaFull")
		end
	end

	-- Asks the game rules whether `player` may take the topping in `slotId` and takes it.
	-- `distanceTo` measures the player's distance to the topping part for that rule.
	local function tryCollect(
		player: Player,
		slotId: number,
		rule: (PlayerState, string, number, number?) -> GameRules.GemResult,
		distanceTo: (BasePart, BasePart) -> number
	): GameRules.GemResult?
		local topping = field:get(slotId)
		local state = PlayerStates.get(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if topping == nil or state == nil or root == nil then
			return nil -- already taken by someone else, or player not ready
		end

		local result = rule(state, topping.toppingId, distanceTo(root, parts[slotId]), topping.gems)
		if result.ok then
			if rule == PlayerStates.rules.autoCollectTopping then
				MagnetPull.fly(parts[slotId], root)
			end
			-- No yield between the check above and here, so no other request can take it meanwhile.
			field:take(slotId, os.clock())
			PlayerStates.set(player, result.state)
			render(slotId)
			if result.gemsEarned > 0 then
				notify:FireClient(player, "Gems", result.gemsEarned)
			elseif PlayerStates.rules.isPizzaFull(result.state) then
				notifyFull(player)
			end
		end
		return result
	end

	local function directDistance(root: BasePart, part: BasePart): number
		return (root.Position - part.Position).Magnitude
	end

	-- Walking over: only the horizontal distance counts, so jumping doesn't matter.
	local function groundDistance(root: BasePart, part: BasePart): number
		local offset = root.Position - part.Position
		return Vector2.new(offset.X, offset.Z).Magnitude
	end

	Net.event("CollectTopping").OnServerEvent:Connect(function(player: Player, slotId: unknown, toppingWorld: unknown)
		if typeof(slotId) ~= "number" or toppingWorld ~= worldId then
			return -- malformed, or meant for another world's ToppingService
		end
		local result = tryCollect(player, slotId, PlayerStates.rules.collectTopping, directDistance)
		if result and not result.ok then
			if result.reason == "PizzaFull" then
				notifyFull(player)
			else
				notify:FireClient(player, result.reason)
			end
		end
	end)

	if not autoCollectSwitchConnected then
		autoCollectSwitchConnected = true
		Net.event("SetAutoCollect").OnServerEvent:Connect(function(player: Player, enabled: unknown)
			local state = PlayerStates.get(player)
			if typeof(enabled) ~= "boolean" or state == nil then
				return
			end
			PlayerStates.set(player, PlayerStates.rules.setAutoCollect(state, enabled).state)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastFullNotice[player] = nil
	end)

	-- Auto-collect: every player with the switch on picks up toppings they walk over.
	task.spawn(function()
		while true do
			task.wait(AUTO_COLLECT_CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				local state = PlayerStates.get(player)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if state and state.autoCollect and root then
					local radius = PlayerStates.rules.autoCollectRadius(state)
					for slotId, part in parts do
						if
							math.abs(root.Position.Y - part.Position.Y) <= AUTO_COLLECT_MAX_HEIGHT
							and groundDistance(root, part) <= radius
						then
							local result =
								tryCollect(player, slotId, PlayerStates.rules.autoCollectTopping, groundDistance)
							if result and result.reason == "PizzaFull" then
								-- Keep looking: gem toppings still fit with a full pizza.
								notifyFull(player)
							end
						end
					end
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(RESPAWN_CHECK_SECONDS)
			for _, slotId in field:respawnDue(os.clock()) do
				render(slotId)
			end
		end
	end)
end

return ToppingService
