--!strict
-- Purely visual feedback when the server reports a sale ("Sold"): a pizza flies
-- from the player into the nearest oven, then coins fly from the oven up to the
-- coins counter in the HUD. Changes nothing in the game state.
-- Coins (#49): a few 3D coins (Blender model "Coin", a gold stand-in disc until it is
-- imported) jump out of the oven, then coin icons (UiKit.coinIcon) fly to the counter.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local UiKit = require(script.Parent.UiKit)

local PIZZA_FLIGHT_SECONDS = 0.45
local COIN_FLIGHT_SECONDS = 0.6
local COIN_SIZE = 36
local MIN_COINS, MAX_COINS = 3, 10
local OVEN_OPENING_NAME = "OvenOpening"
local POP_COINS = 4
local POP_SECONDS = 0.5
local POP_COIN_WIDTH = 1.4

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
	-- Imported Blender pizza if available (#15); welded so it flies along.
	if ModelLibrary.dressDisc(crust, "Pizza") then
		ModelLibrary.weldLook(crust)
	end

	local info = TweenInfo.new(PIZZA_FLIGHT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(crust, info, {
		CFrame = CFrame.new(to) * flat,
		Size = Vector3.new(0.1, 0.8, 0.8),
	}):Play()
	task.delay(PIZZA_FLIGHT_SECONDS, function()
		crust:Destroy()
	end)
end

-- A 3D coin: a gold disc (cylinder axis X = the coin's face normal) dressed with the
-- imported Blender coin if available.
local function makeCoin(cframe: CFrame): Part
	local coin = Instance.new("Part")
	coin.Name = "SoldCoin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.22, POP_COIN_WIDTH, POP_COIN_WIDTH)
	coin.Color = UiKit.COIN
	coin.Material = Enum.Material.SmoothPlastic
	coin.Reflectance = 0.2
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CanTouch = false
	coin.CastShadow = false
	coin.CFrame = cframe
	coin.Parent = Workspace
	if ModelLibrary.dressDisc(coin, "Coin") then
		ModelLibrary.weldLook(coin)
	end
	return coin
end

-- Coins jump out of the oven in a small arc, spinning upright, and vanish.
local function popCoins(at: Vector3)
	for index = 1, POP_COINS do
		local angle = (index / POP_COINS) * math.pi * 2 + math.random() * 0.6
		local side = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (1.5 + math.random())
		local height = 3.5 + math.random() * 1.5
		local coin = makeCoin(CFrame.new(at))
		local started = os.clock()
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			local t = (os.clock() - started) / POP_SECONDS
			if t >= 1 then
				connection:Disconnect()
				coin:Destroy()
				return
			end
			local position = at + side * t + Vector3.new(0, height * 4 * t * (1 - t) + t, 0)
			coin.CFrame = CFrame.new(position) * CFrame.Angles(0, t * math.pi * 4 + angle, 0)
		end)
	end
end

local function flyCoins(layer: ScreenGui, from: Vector2, target: GuiObject, amount: number)
	local goal = target.AbsolutePosition + Vector2.new(COIN_SIZE / 2 + 8, target.AbsoluteSize.Y / 2)
	local count = math.clamp(amount, MIN_COINS, MAX_COINS)
	for index = 1, count do
		task.delay((index - 1) * 0.05, function()
			local coin = UiKit.coinIcon(nil, COIN_SIZE)
			coin.AnchorPoint = Vector2.new(0.5, 0.5)

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
			popCoins(ovenPosition)
			local point, onScreen = camera:WorldToScreenPoint(ovenPosition)
			local from = if onScreen
				then Vector2.new(point.X, point.Y)
				else Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
			flyCoins(layer, from, coinsCounter, amount or 0)
		end)
	end)
end

return SellAnimation
