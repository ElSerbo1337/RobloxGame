--!strict
-- The pizza every player holds in their hand (a Tool), showing the collected toppings.
-- Purely visual: the toppings shown always mirror the server's PlayerState.

local Players = game:GetService("Players")

local PlayerStates = require(script.Parent.PlayerStates)
local ToppingLook = require(script.Parent.ToppingLook)

local PIZZA_DIAMETER = 3.4
local PIZZA_THICKNESS = 0.3
local TOPPING_DIAMETER = 0.9
local TOPPING_RING_RADIUS = 0.95
-- Hand holds the pizza at its rim, pizza lying flat. Adjust here if it looks wrong in Studio.
local GRIP = CFrame.new(0, 0, PIZZA_DIAMETER / 2 - 0.2) * CFrame.Angles(0, 0, -math.pi / 2)

local PizzaVisual = {}

local function weldedDisc(handle: BasePart, offset: CFrame, disc: BasePart, parent: Instance)
	disc.Anchored = false
	disc.Massless = true
	disc.CFrame = handle.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = disc
	weld.Parent = disc
	disc.Parent = parent
end

local function buildTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Pizza"
	tool.CanBeDropped = false
	tool.Grip = GRIP

	-- Cylinders have their axis on X, so local +X is "up" on the pizza.
	local handle = ToppingLook.createDisc("Crust", PIZZA_DIAMETER, PIZZA_THICKNESS)
	handle.Name = "Handle"
	handle.Color = Color3.fromRGB(230, 180, 100)
	handle.Anchored = false
	handle.Massless = true
	handle.Parent = tool

	local sauce = ToppingLook.createDisc("Sauce", PIZZA_DIAMETER - 0.5, 0.1)
	sauce.Color = Color3.fromRGB(200, 55, 35)
	weldedDisc(handle, CFrame.new(PIZZA_THICKNESS / 2, 0, 0), sauce, tool)

	local toppings = Instance.new("Folder")
	toppings.Name = "Toppings"
	toppings.Parent = tool

	return tool
end

local function showToppings(player: Player, pizza: { string })
	local character = player.Character
	local tool = character and character:FindFirstChild("Pizza")
	if tool == nil then
		return
	end
	local handle = tool:FindFirstChild("Handle") :: BasePart
	local folder = tool:FindFirstChild("Toppings") :: Folder
	folder:ClearAllChildren()

	local count = #pizza
	for index, toppingId in pizza do
		local angle = 2 * math.pi * index / count
		local radius = if count == 1 then 0 else TOPPING_RING_RADIUS
		local offset = CFrame.new(PIZZA_THICKNESS / 2 + 0.15, radius * math.cos(angle), radius * math.sin(angle))
		weldedDisc(handle, offset, ToppingLook.createDisc(toppingId, TOPPING_DIAMETER, 0.15), folder)
	end
end

function PizzaVisual.start()
	local function onCharacterAdded(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local tool = buildTool()
		tool.Parent = player:WaitForChild("Backpack")
		humanoid:EquipTool(tool)
		local state = PlayerStates.get(player)
		if state then
			showToppings(player, state.pizza)
		end
	end

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	PlayerStates.onChanged(function(player, state)
		showToppings(player, state.pizza)
	end)
end

return PizzaVisual
