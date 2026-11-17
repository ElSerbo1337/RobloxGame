--!strict
-- Barriers between worlds (glowing gates on the bridge heads, #27): handles unlock requests and keeps players out of worlds
-- they have not unlocked. Unlocking is decided by the game rules; the barrier is only
-- made passable on the unlocking player's client, so the server checks positions too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)
local WorldMap = require(script.Parent.WorldMap)

-- Max distance (studs) from the barrier for buying it; the client shows the button closer.
local UNLOCK_RANGE = 30
local CHECK_SECONDS = 0.5

local BarrierService = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Distance from a point to the closest point of the barrier part.
local function distanceToBarrier(barrier: BasePart, position: Vector3): number
	local relative = barrier.CFrame:PointToObjectSpace(position)
	local half = barrier.Size / 2
	local clamped = Vector3.new(
		math.clamp(relative.X, -half.X, half.X),
		math.clamp(relative.Y, -half.Y, half.Y),
		math.clamp(relative.Z, -half.Z, half.Z)
	)
	return (relative - clamped).Magnitude
end

local function isInside(layout: WorldMap.Layout, position: Vector3): boolean
	local offset = position - layout.boundsCenter
	return math.abs(offset.X) <= layout.boundsSize.X / 2 and math.abs(offset.Z) <= layout.boundsSize.Y / 2
end

function BarrierService.start(layouts: { WorldMap.Layout })
	local notify = Net.event("Notify")
	local byWorld: { [string]: WorldMap.Layout } = {}
	for _, layout in layouts do
		byWorld[layout.worldId] = layout
	end

	Net.event("UnlockWorld").OnServerEvent:Connect(function(player: Player, worldId: unknown)
		if typeof(worldId) ~= "string" then
			return
		end
		local layout = byWorld[worldId]
		local state = PlayerStates.get(player)
		local root = rootOf(player)
		if layout == nil or layout.barrier == nil or state == nil or root == nil then
			return
		end
		if distanceToBarrier(layout.barrier :: BasePart, root.Position) > UNLOCK_RANGE then
			notify:FireClient(player, "OutOfRange")
			return
		end

		local result = PlayerStates.rules.unlockWorld(state, worldId)
		if not result.ok then
			notify:FireClient(player, result.reason)
			return
		end
		PlayerStates.set(player, result.state)
		notify:FireClient(player, "WorldUnlocked")
	end)

	-- The barrier only blocks on the client, so a cheater could still walk through:
	-- anyone standing in a world they have not unlocked is put back in front of it.
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				local state = PlayerStates.get(player)
				local root = rootOf(player)
				if state and root then
					for _, layout in layouts do
						if
							isInside(layout, root.Position)
							and not PlayerStates.rules.isWorldUnlocked(state, layout.worldId)
						then
							local character = player.Character :: Model
							character:PivotTo(CFrame.lookAt(layout.returnPoint, layout.returnPoint - Vector3.zAxis))
							notify:FireClient(player, "WorldLocked")
							break
						end
					end
				end
			end
		end
	end)
end

return BarrierService
