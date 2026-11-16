--!strict
-- Shows the shared toppings of world 1 and handles collect requests from clients.
-- Every request is validated by the game rules (range, pizza capacity) and the
-- ToppingField (topping still there), so a topping can only be taken once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local ToppingField = require(ReplicatedStorage.Shared.ToppingField)
local PlayerStates = require(script.Parent.PlayerStates)
local ToppingLook = require(script.Parent.ToppingLook)
local World1Map = require(script.Parent.World1Map)

local WORLD_ID = "PizzeriaGarden"
local DISC_DIAMETER = 3.5
local DISC_THICKNESS = 0.6
local RESPAWN_CHECK_SECONDS = 0.25

local ToppingService = {}

function ToppingService.start(layout: World1Map.Layout)
	local rng = Random.new()
	local field = ToppingField.new(GameConfig, WORLD_ID, function()
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
		local disc = ToppingLook.createDisc(topping.toppingId, DISC_DIAMETER, DISC_THICKNESS)
		disc.CFrame = CFrame.new(worldPosition(topping.x, topping.z)) * ToppingLook.FLAT
		disc:SetAttribute("SlotId", slotId)
		disc.Parent = layout.toppingsFolder
		parts[slotId] = disc
	end

	for slotId = 1, field.slotCount do
		render(slotId)
	end

	local notify = Net.event("Notify")
	Net.event("CollectTopping").OnServerEvent:Connect(function(player: Player, slotId: unknown)
		if typeof(slotId) ~= "number" then
			return
		end
		local topping = field:get(slotId)
		local state = PlayerStates.get(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if topping == nil or state == nil or root == nil then
			return -- already taken by someone else, or player not ready
		end

		local distance = (root.Position - parts[slotId].Position).Magnitude
		local result = PlayerStates.rules.collectTopping(state, topping.toppingId, distance)
		if not result.ok then
			notify:FireClient(player, result.reason)
			return
		end

		-- No yield between the check above and here, so no other request can take it meanwhile.
		field:take(slotId, os.clock())
		PlayerStates.set(player, result.state)
		render(slotId)
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
