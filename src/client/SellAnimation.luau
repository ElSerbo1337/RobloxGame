--!strict
-- Purely visual feedback when the server reports a sale ("Sold"): a pizza flies
-- from the player into the nearest oven, then coins fly from the oven up to the
-- coins counter in the HUD. Changes nothing in the game state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)

local PIZZA_FLIGHT_SECONDS = 0.45
local COIN_FLIGHT_SECONDS = 0.6
local COIN_SIZE = 36
local MIN_COINS, MAX_COINS = 3, 10
local OVEN_OPENING_NAME = "OvenOpening"

local SellAnimation = {}

local function nearestOvenOpening(position: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, descendant in Workspace:GetDescendants() do
		if descendant.Name == OVEN_OPENING_NAME and descendant:IsA("BasePart") then
			local distance = (descendant.Position - position).Magnitude
			if distance < bestDistance then
				best = descendant
				bestDistance = distance
			end
		end
	end
	return best
end

-- A local copy of the pizza (crust + sauce) that flies into the oven and vanishes.
local function flyPizza(from: CFrame, to: Vector3)
	local crust = Instance.new("Part")
	crust.Name = "SoldPizza"
	crust.Shape = Enum.PartType.Cylinder
	crust.Size = Vector3.new(0.3, 3.4, 3.4)
	crust.Color = Color3.fromRGB(230, 180, 100)
	crust.Material = Enum.Material.SmoothPlastic
	crust.Anchored = true
	crust.CanCollide = false
	crust.CanQuery = false
	crust.CanTouch = false
	crust.CastShadow = false
	-- Cylinder axis is X; rotate so the pizza lies flat.
	local flat = CFrame.Angles(0, 0, math.rad(90))
	crust.CFrame = from * flat
	crust.Parent = Workspace

	local info = TweenInfo.new(PIZZA_FLIGHT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(crust, info, {
		CFrame = CFrame.new(to) * flat,
		Size = Vector3.new(0.1, 0.8, 0.8),
	}):Play()
	task.delay(PIZZA_FLIGHT_SECONDS, function()
		crust:Destroy()
	end)
end

local function flyCoins(layer: ScreenGui, from: Vector2, target: GuiObject, amount: number)
	local goal = target.AbsolutePosition + Vector2.new(COIN_SIZE / 2 + 8, target.AbsoluteSize.Y / 2)
	local count = math.clamp(amount, MIN_COINS, MAX_COINS)
	for index = 1, count do
		task.delay((index - 1) * 0.05, function()
			local coin = Instance.new("Frame")
			coin.AnchorPoint = Vector2.new(0.5, 0.5)
			coin.Size = UDim2.fromOffset(COIN_SIZE, COIN_SIZE)
			coin.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = coin
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 3
			stroke.Color = Color3.fromRGB(60, 35, 20)
			stroke.Parent = coin

			local scatter = Vector2.new(math.random(-60, 60), math.random(-40, 40))
			local start = from + scatter
			coin.Position = UDim2.fromOffset(start.X, start.Y)
			coin.Parent = layer

			local info = TweenInfo.new(COIN_FLIGHT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(coin, info, {
				Position = UDim2.fromOffset(goal.X, goal.Y),
				Size = UDim2.fromOffset(COIN_SIZE * 0.6, COIN_SIZE * 0.6),
			}):Play()
			task.delay(COIN_FLIGHT_SECONDS, function()
				coin:Destroy()
			end)
		end)
	end
end

-- `coinsCounter` is the HUD element the coins fly to.
function SellAnimation.start(coinsCounter: GuiObject)
	local player = Players.LocalPlayer

	-- Own layer without UIScale, so screen positions map 1:1 to pixels.
	local layer = Instance.new("ScreenGui")
	layer.Name = "SellEffects"
	layer.ResetOnSpawn = false
	layer.DisplayOrder = 10
	layer.Parent = player:WaitForChild("PlayerGui")

	Net.event("Notify").OnClientEvent:Connect(function(kind: string, amount: number?)
		if kind ~= "Sold" then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = Workspace.CurrentCamera
		if root == nil or camera == nil then
			return
		end

		local oven = nearestOvenOpening(root.Position)
		local ovenPosition = if oven then oven.Position else root.Position
		flyPizza(root.CFrame * CFrame.new(0, 1, -2), ovenPosition)

		task.delay(PIZZA_FLIGHT_SECONDS, function()
			local point, onScreen = camera:WorldToScreenPoint(ovenPosition)
			local from = if onScreen
				then Vector2.new(point.X, point.Y)
				else Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
			flyCoins(layer, from, coinsCounter, amount or 0)
		end)
	end)
end

return SellAnimation
