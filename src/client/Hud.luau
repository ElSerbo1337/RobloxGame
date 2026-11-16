--!strict
-- HUD: coins at the top, pizza fill level and auto-collect switch at the bottom,
-- short messages in between. Reads the replicated player attributes (Coins,
-- PizzaCount, PizzaCapacity, AutoCollect) and Notify events. The switch only
-- sends a wish to the server; its look follows the replicated attribute.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)

local FONT = Enum.Font.FredokaOne
local CREAM = Color3.fromRGB(255, 248, 230)
local DARK = Color3.fromRGB(60, 35, 20)
local COIN = Color3.fromRGB(255, 200, 40)
local FULL = Color3.fromRGB(230, 70, 50)
local ON = Color3.fromRGB(110, 200, 90)
local OFF = Color3.fromRGB(190, 180, 170)

local MESSAGES: { [string]: string } = {
	PizzaFull = "Pizza voll! Ab zum Ofen.",
	OutOfRange = "Zu weit weg!",
	NotEnoughCoins = "Nicht genug Münzen!",
	WorldLocked = "Diese Welt ist noch gesperrt!",
	PreviousWorldLocked = "Erst die vorige Welt freischalten!",
	WorldUnlocked = "Neue Welt freigeschaltet!",
	InventoryFull = "Pet-Inventar voll! Lösche erst ein Pet.",
}

local Hud = {}

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1.")))
	return (string.gsub(formatted, "^%.", ""))
end

local function corner(parent: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

local function stroke(parent: Instance)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = 3
	uiStroke.Color = DARK
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uiStroke.Parent = parent
end

local function label(parent: Instance, text: string): TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Font = FONT
	textLabel.TextScaled = true
	textLabel.TextColor3 = DARK
	textLabel.Text = text
	textLabel.Parent = parent
	return textLabel
end

-- Scales the whole HUD so it stays readable on small phones and large monitors alike.
local function autoScale(gui: ScreenGui)
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = gui
	local function update()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local size = camera.ViewportSize
		uiScale.Scale = math.clamp(math.min(size.X / 1100, size.Y / 650), 0.7, 1.4)
	end
	update()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(update)
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end

local function pop(target: GuiObject)
	local uiScale = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	uiScale.Parent = target
	uiScale.Scale = 1.15
	TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Returns the coins counter, so effects (e.g. flying coins) can aim at it.
function Hud.start(): GuiObject
	local player = Players.LocalPlayer
	-- The pizza tool must stay in hand, so the hotbar is hidden.
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	autoScale(gui)

	-- Coins (top center)
	local coins = Instance.new("Frame")
	coins.Name = "Coins"
	coins.AnchorPoint = Vector2.new(0.5, 0)
	coins.Position = UDim2.new(0.5, 0, 0, 12)
	coins.Size = UDim2.fromOffset(240, 60)
	coins.BackgroundColor3 = CREAM
	corner(coins, 30)
	stroke(coins)
	coins.Parent = gui

	local coinIcon = Instance.new("Frame")
	coinIcon.Size = UDim2.fromOffset(44, 44)
	coinIcon.Position = UDim2.fromOffset(8, 8)
	coinIcon.BackgroundColor3 = COIN
	corner(coinIcon, 22)
	stroke(coinIcon)
	coinIcon.Parent = coins

	local coinsText = label(coins, "0")
	coinsText.Position = UDim2.fromOffset(62, 8)
	coinsText.Size = UDim2.new(1, -78, 0, 44)
	coinsText.TextXAlignment = Enum.TextXAlignment.Left

	-- Pizza fill level (bottom center)
	local pizza = Instance.new("Frame")
	pizza.Name = "PizzaFill"
	pizza.AnchorPoint = Vector2.new(0.5, 1)
	pizza.Position = UDim2.new(0.5, 0, 1, -16)
	pizza.Size = UDim2.fromOffset(260, 64)
	pizza.BackgroundColor3 = CREAM
	corner(pizza, 32)
	stroke(pizza)
	pizza.Parent = gui

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(8, 8)
	bar.Size = UDim2.new(0, 0, 1, -16)
	bar.BackgroundColor3 = Color3.fromRGB(240, 160, 60)
	corner(bar, 24)
	bar.Parent = pizza

	local pizzaText = label(pizza, "Pizza 0/2")
	pizzaText.Position = UDim2.fromOffset(12, 10)
	pizzaText.Size = UDim2.new(1, -24, 1, -20)
	pizzaText.ZIndex = 2

	-- Auto-collect switch (bottom center, above the pizza fill). Big for thumbs.
	local autoButton = Instance.new("TextButton")
	autoButton.Name = "AutoCollect"
	autoButton.AnchorPoint = Vector2.new(0.5, 1)
	autoButton.Position = UDim2.new(0.5, 0, 1, -92)
	autoButton.Size = UDim2.fromOffset(260, 64)
	autoButton.BackgroundColor3 = OFF
	autoButton.AutoButtonColor = true
	autoButton.Font = FONT
	autoButton.TextScaled = true
	autoButton.TextColor3 = DARK
	autoButton.Text = "Auto-Sammeln: AUS"
	corner(autoButton, 32)
	stroke(autoButton)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = autoButton
	autoButton.Parent = gui

	-- Short messages (below the coins)
	local toast = label(gui, "")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 84)
	toast.Size = UDim2.fromOffset(420, 40)
	toast.TextColor3 = CREAM
	toast.TextStrokeColor3 = DARK
	toast.TextStrokeTransparency = 0
	toast.Visible = false

	gui.Parent = player:WaitForChild("PlayerGui")

	local toastId = 0
	local function showToast(text: string, color: Color3?)
		toastId += 1
		local myId = toastId
		toast.Text = text
		toast.TextColor3 = color or CREAM
		toast.Visible = true
		pop(toast)
		task.delay(1.8, function()
			if toastId == myId then
				toast.Visible = false
			end
		end)
	end

	local lastCoins = 0
	local function updateCoins()
		local value = (player:GetAttribute("Coins") :: number?) or 0
		coinsText.Text = formatNumber(value)
		if value ~= lastCoins then
			pop(coins)
		end
		lastCoins = value
	end

	local function updatePizza()
		local count = (player:GetAttribute("PizzaCount") :: number?) or 0
		local capacity = (player:GetAttribute("PizzaCapacity") :: number?) or 1
		local isFull = count >= capacity
		pizzaText.Text = if isFull then `Pizza VOLL {count}/{capacity}` else `Pizza {count}/{capacity}`
		bar.BackgroundColor3 = if isFull then FULL else Color3.fromRGB(240, 160, 60)
		TweenService:Create(bar, TweenInfo.new(0.2), {
			Size = UDim2.new(math.clamp(count / capacity, 0, 1), -16 * math.clamp(count / capacity, 0, 1), 1, -16),
		}):Play()
	end

	local function updateAutoCollect()
		local enabled = player:GetAttribute("AutoCollect") == true
		autoButton.Text = if enabled then "Auto-Sammeln: AN" else "Auto-Sammeln: AUS"
		autoButton.BackgroundColor3 = if enabled then ON else OFF
	end

	local setAutoCollect = Net.event("SetAutoCollect")
	autoButton.Activated:Connect(function()
		setAutoCollect:FireServer(player:GetAttribute("AutoCollect") ~= true)
		pop(autoButton)
	end)

	player:GetAttributeChangedSignal("AutoCollect"):Connect(updateAutoCollect)
	player:GetAttributeChangedSignal("Coins"):Connect(updateCoins)
	player:GetAttributeChangedSignal("PizzaCount"):Connect(updatePizza)
	player:GetAttributeChangedSignal("PizzaCapacity"):Connect(updatePizza)
	updateCoins()
	updatePizza()
	updateAutoCollect()

	Net.event("Notify").OnClientEvent:Connect(function(kind: string, amount: number?)
		if kind == "Sold" and amount then
			showToast(`+{formatNumber(amount)} Münzen`, COIN)
		elseif MESSAGES[kind] then
			local color = if kind == "PizzaFull"
					or kind == "NotEnoughCoins"
					or kind == "WorldLocked"
					or kind == "InventoryFull"
				then FULL
				elseif kind == "WorldUnlocked" then COIN
				else nil
			showToast(MESSAGES[kind], color)
		end
	end)

	return coins
end

return Hud
