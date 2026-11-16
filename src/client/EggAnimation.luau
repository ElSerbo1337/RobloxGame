--!strict
-- Hatch animation after the server opened an egg: the egg wobbles, cracks, flashes,
-- and the pet card jumps out (name, rarity color, bonus); with "3 öffnen" three cards
-- side by side. Tap or wait to close.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Sounds)
local PetIcon = require(script.Parent.PetIcon)
local UiKit = require(script.Parent.UiKit)

local CARD_WIDTH = 300
local CARD_GAP = 16

local EggAnimation = {}

local function tween(target: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?): Tween
	local t = TweenService:Create(target, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad), props)
	t:Play()
	return t
end

function EggAnimation.start()
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "EggAnimation"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Enabled = false
	UiKit.autoScale(gui)

	-- Dark backdrop that also catches the tap to close.
	local backdrop = Instance.new("TextButton")
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.Parent = gui

	local egg = Instance.new("Frame")
	egg.AnchorPoint = Vector2.new(0.5, 0.5)
	egg.Position = UDim2.fromScale(0.5, 0.5)
	egg.Size = UDim2.fromOffset(180, 230)
	egg.BackgroundColor3 = Color3.fromRGB(255, 245, 220)
	UiKit.corner(egg, 110)
	UiKit.stroke(egg, 5)
	egg.Parent = gui

	-- Crack line that appears before the egg bursts.
	local crack = UiKit.label(egg, "⚡")
	crack.AnchorPoint = Vector2.new(0.5, 0.5)
	crack.Position = UDim2.fromScale(0.5, 0.45)
	crack.Size = UDim2.fromOffset(120, 120)
	crack.TextColor3 = UiKit.DARK
	crack.Visible = false

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.ZIndex = 5
	flash.Parent = gui

	-- Row of pet cards (1, or 3 with "3 öffnen"), centered on screen.
	local cards = Instance.new("Frame")
	cards.AnchorPoint = Vector2.new(0.5, 0.5)
	cards.Position = UDim2.fromScale(0.5, 0.5)
	cards.Size = UDim2.fromOffset(CARD_WIDTH * 3 + CARD_GAP * 2, 360)
	cards.BackgroundTransparency = 1
	cards.ZIndex = 6
	cards.Parent = gui
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, CARD_GAP)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = cards

	local function buildCard(petId: string, order: number): Frame
		local pet = GameConfig.pets[petId]
		local color = UiKit.rarityColor(pet.rarity)

		local card = Instance.new("Frame")
		card.LayoutOrder = order
		card.Size = UDim2.fromOffset(CARD_WIDTH, 360)
		card.BackgroundColor3 = UiKit.CREAM
		card.ZIndex = 6
		UiKit.corner(card, 28)
		UiKit.stroke(card, 5)

		local petIcon = Instance.new("Frame")
		petIcon.AnchorPoint = Vector2.new(0.5, 0)
		petIcon.Position = UDim2.new(0.5, 0, 0, 24)
		petIcon.Size = UDim2.fromOffset(140, 140)
		petIcon.BackgroundColor3 = color
		petIcon.ZIndex = 7
		UiKit.corner(petIcon, 70)
		UiKit.stroke(petIcon, 4)
		petIcon.Parent = card
		-- The 3D pet (imported model) jumps out in front of its rarity-coloured circle.
		PetIcon.show(petIcon, petId, 1.2)

		local petName = UiKit.label(card, pet.displayName)
		petName.Position = UDim2.fromOffset(16, 176)
		petName.Size = UDim2.new(1, -32, 0, 50)
		petName.ZIndex = 7

		local rarityName = UiKit.label(card, GameConfig.rarities[pet.rarity].displayName)
		rarityName.Position = UDim2.fromOffset(16, 228)
		rarityName.Size = UDim2.new(1, -32, 0, 36)
		rarityName.TextColor3 = color
		rarityName.TextStrokeColor3 = UiKit.DARK
		rarityName.TextStrokeTransparency = 0
		rarityName.ZIndex = 7

		local bonusText = UiKit.label(card, `{UiKit.bonusText(pet.bonus)} Münzen`)
		bonusText.Position = UDim2.fromOffset(16, 270)
		bonusText.Size = UDim2.new(1, -32, 0, 40)
		bonusText.TextColor3 = Color3.fromRGB(40, 130, 40)
		bonusText.ZIndex = 7

		local hint = UiKit.label(card, "Tippen zum Schließen")
		hint.Position = UDim2.fromOffset(16, 318)
		hint.Size = UDim2.new(1, -32, 0, 26)
		hint.TextTransparency = 0.4
		hint.ZIndex = 7
		return card
	end

	gui.Parent = player:WaitForChild("PlayerGui")

	local playId = 0
	local closable = false
	local function close()
		if closable then
			gui.Enabled = false
		end
	end
	backdrop.Activated:Connect(close)

	-- (eggId, petId, petId?, petId?): one pet id per opened egg.
	Net.event("EggOpened").OnClientEvent:Connect(function(_eggId: string, ...: string)
		local petIds = {}
		for _, petId in { ... } do
			if GameConfig.pets[petId] then
				table.insert(petIds, petId)
			end
		end
		if #petIds == 0 then
			return
		end
		playId += 1
		local myId = playId
		closable = false

		for _, child in cards:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		cards.Visible = false

		egg.Visible = true
		egg.Rotation = 0
		egg.Size = UDim2.fromOffset(180, 230)
		crack.Visible = false
		flash.BackgroundTransparency = 1
		gui.Enabled = true

		-- Wobble, getting stronger.
		for _, angle in { 8, -8, 12, -12, 16, -16 } do
			tween(egg, 0.12, { Rotation = angle }, Enum.EasingStyle.Sine).Completed:Wait()
		end
		tween(egg, 0.08, { Rotation = 0 })
		crack.Visible = true
		Sounds.play("EggCrack")
		tween(egg, 0.25, { Size = UDim2.fromOffset(200, 250) }, Enum.EasingStyle.Back).Completed:Wait()
		if myId ~= playId then
			return
		end

		-- Burst: flash, egg gone, pet card jumps out.
		flash.BackgroundTransparency = 0
		egg.Visible = false
		for i, petId in petIds do
			buildCard(petId, i).Parent = cards
		end
		cards.Visible = true
		UiKit.pop(cards, 0.2)
		tween(flash, 0.5, { BackgroundTransparency = 1 })
		closable = true

		task.delay(3, function()
			if myId == playId then
				close()
			end
		end)
	end)
end

return EggAnimation
