--!strict
-- Hatch animation after the server opened an egg: the egg wobbles, cracks, flashes,
-- and the pet card jumps out (name, rarity color, bonus); with "3 öffnen" three cards
-- side by side. Tap or wait to close.
-- Settings (#76): "skip egg animation" shows the cards right away; "screen flashes off"
-- drops the white flash.
-- Rare hatches (#81): from Legendary on the screen is tinted in the rarity colour and
-- light rays turn behind the cards; a Secret pet gets a much longer, darker build-up,
-- a "GEHEIM!" title and stays longer. Tint, rays and flashes only with
-- Settings.screenFlashes(); skipping the animation also skips the Secret build-up.
-- Shiny pets (#80): the card gets a gold frame, sparkles and "✨ Shiny" with the real
-- bonus (+50 %), and a big "✨ SHINY!" title pops up (a golden flash only with
-- Settings.screenFlashes()).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local Lang = require(script.Parent.Lang)
local Sounds = require(script.Parent.Sounds)
local PetIcon = require(script.Parent.PetIcon)
local Settings = require(script.Parent.Settings)
local UiKit = require(script.Parent.UiKit)

local CARD_WIDTH = 300
local CARD_GAP = 16
-- Rarity order (GameConfig.rarities) from which rare-hatch effects play (Legendary).
local RARE_ORDER = GameConfig.rarities.Legendary.order
local RAY_COUNT = 12
-- Seconds until the cards close by themselves (normal / Secret).
local CLOSE_SECONDS = 3
local SECRET_CLOSE_SECONDS = 7
local BACKDROP_COLOR = Color3.new(0, 0, 0)
local BACKDROP_TRANSPARENCY = 0.45

local SHINY_COLOR = Color3.fromRGB(255, 215, 70)

local rules = GameRules.new(GameConfig)

type Hatched = { petId: string, shiny: boolean }

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
	backdrop.BackgroundColor3 = BACKDROP_COLOR
	backdrop.BackgroundTransparency = BACKDROP_TRANSPARENCY
	backdrop.Parent = gui

	-- Light rays behind the cards (rare hatches): thin beams fading out to their ends,
	-- the whole star turns slowly.
	local rays = Instance.new("Frame")
	rays.Name = "Rays"
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromOffset(1400, 1400)
	rays.BackgroundTransparency = 1
	rays.ZIndex = 2
	rays.Visible = false
	rays.Parent = gui
	local rayFade = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 0.35),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(0.58, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	local rayParts: { Frame } = {}
	for i = 1, RAY_COUNT do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.new(0, 70, 1, 0)
		ray.Rotation = (i - 1) * 180 / RAY_COUNT
		ray.BorderSizePixel = 0
		ray.ZIndex = 2
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Transparency = rayFade
		gradient.Parent = ray
		ray.Parent = rays
		table.insert(rayParts, ray)
	end
	local raySpin = TweenService:Create(
		rays,
		TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
		{ Rotation = 360 }
	)

	-- "GEHEIM!" above the cards for Secret pets.
	local secretTitle = UiKit.label(gui, "")
	secretTitle.AnchorPoint = Vector2.new(0.5, 1)
	secretTitle.Position = UDim2.new(0.5, 0, 0.5, -190)
	secretTitle.Size = UDim2.fromOffset(700, 80)
	secretTitle.TextColor3 = UiKit.rarityColor("Secret")
	secretTitle.TextStrokeColor3 = UiKit.DARK
	secretTitle.TextStrokeTransparency = 0
	secretTitle.ZIndex = 8
	secretTitle.Visible = false

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

	local function buildCard(hatched: Hatched, order: number): Frame
		local petId = hatched.petId
		local pet = GameConfig.pets[petId]
		local color = UiKit.rarityColor(pet.rarity)

		local card = Instance.new("Frame")
		card.LayoutOrder = order
		card.Size = UDim2.fromOffset(CARD_WIDTH, 360)
		card.BackgroundColor3 = UiKit.CREAM
		card.ZIndex = 6
		UiKit.corner(card, 28)
		local frame = UiKit.stroke(card, 5)
		if hatched.shiny and frame then
			frame.Color = SHINY_COLOR
		end

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

		local petName = UiKit.label(card, UiKit.petName(petId, nil, hatched.shiny))
		petName.Position = UDim2.fromOffset(16, 176)
		petName.Size = UDim2.new(1, -32, 0, 50)
		petName.ZIndex = 7

		local rarityText = Lang.name(GameConfig.rarities[pet.rarity])
		if hatched.shiny then
			rarityText = `{rarityText} · {Lang.t("pets.shiny")}`
		end
		local rarityName = UiKit.label(card, rarityText)
		rarityName.Position = UDim2.fromOffset(16, 228)
		rarityName.Size = UDim2.new(1, -32, 0, 36)
		rarityName.TextColor3 = color
		rarityName.TextStrokeColor3 = UiKit.DARK
		rarityName.TextStrokeTransparency = 0
		rarityName.ZIndex = 7

		local bonus = rules.petBonus({ uid = 0, petId = petId, shiny = hatched.shiny or nil })
		local bonusText = UiKit.label(card, Lang.t("egg.bonus", { bonus = UiKit.bonusText(bonus) }))
		bonusText.Position = UDim2.fromOffset(16, 270)
		bonusText.Size = UDim2.new(1, -32, 0, 40)
		bonusText.TextColor3 = Color3.fromRGB(40, 130, 40)
		bonusText.ZIndex = 7

		local hint = UiKit.label(card, Lang.t("egg.tapToClose"))
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
			raySpin:Cancel()
			rays.Visible = false
			secretTitle.Visible = false
		end
	end
	backdrop.Activated:Connect(close)

	-- (eggId, { { petId, shiny } }): one entry per opened egg.
	Net.event("EggOpened").OnClientEvent:Connect(function(eggId: string, list: { Hatched })
		local hatchedPets: { Hatched } = {}
		local petIds = {}
		local anyShiny = false
		for _, entry in if type(list) == "table" then list else {} do
			if type(entry) == "table" and GameConfig.pets[entry.petId] then
				local shiny = entry.shiny == true
				table.insert(hatchedPets, { petId = entry.petId, shiny = shiny })
				table.insert(petIds, entry.petId)
				anyShiny = anyShiny or shiny
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

		-- Rarest pet decides the effects (#81).
		local topRarity = GameConfig.rarities[GameConfig.pets[petIds[1]].rarity]
		local topRarityId = GameConfig.pets[petIds[1]].rarity
		for _, petId in petIds do
			local rarityId = GameConfig.pets[petId].rarity
			if GameConfig.rarities[rarityId].order > topRarity.order then
				topRarity = GameConfig.rarities[rarityId]
				topRarityId = rarityId
			end
		end
		local secret = topRarityId == "Secret"
		local effects = Settings.screenFlashes()
		local rareColor = UiKit.rarityColor(topRarityId)

		-- The cracking egg wears the colour of the opened egg (GameConfig look, #29).
		local eggConfig = GameConfig.eggs[eggId]
		local look = eggConfig and eggConfig.look
		egg.BackgroundColor3 = if look then Color3.fromHex(look.color) else Color3.fromRGB(255, 245, 220)
		egg.Visible = true
		egg.Rotation = 0
		egg.Size = UDim2.fromOffset(180, 230)
		crack.Visible = false
		flash.BackgroundTransparency = 1
		backdrop.BackgroundColor3 = BACKDROP_COLOR
		backdrop.BackgroundTransparency = BACKDROP_TRANSPARENCY
		raySpin:Cancel()
		rays.Visible = false
		secretTitle.Visible = false
		gui.Enabled = true

		local skip = Settings.skipEggAnimation()
		if skip then
			Sounds.play("EggCrack")
		else
			-- Wobble, getting stronger.
			for _, angle in { 8, -8, 12, -12, 16, -16 } do
				tween(egg, 0.12, { Rotation = angle }, Enum.EasingStyle.Sine).Completed:Wait()
			end
			-- Secret: the screen goes dark, the egg glows in the Secret colour and shakes
			-- much longer before it bursts (extra ~3 s of suspense).
			if secret then
				tween(backdrop, 1.2, { BackgroundTransparency = 0.1 })
				tween(egg, 2.6, { BackgroundColor3 = rareColor })
				for i, angle in { 6, -6, 10, -10, 14, -14, 18, -18, 22, -22, 26, -26 } do
					tween(egg, 0.2 - i * 0.008, { Rotation = angle }, Enum.EasingStyle.Sine).Completed:Wait()
				end
				if myId ~= playId then
					return
				end
			end
			tween(egg, 0.08, { Rotation = 0 })
			crack.Visible = true
			Sounds.play("EggCrack")
			tween(egg, 0.25, { Size = UDim2.fromOffset(200, 250) }, Enum.EasingStyle.Back).Completed:Wait()
			if myId ~= playId then
				return
			end
		end

		-- Burst: flash, egg gone, pet card jumps out.
		if not skip and effects then
			flash.BackgroundColor3 = if secret then rareColor elseif anyShiny then SHINY_COLOR else Color3.new(1, 1, 1)
			flash.BackgroundTransparency = 0
		end
		egg.Visible = false
		for i, hatched in hatchedPets do
			buildCard(hatched, i).Parent = cards
		end
		cards.Visible = true
		UiKit.pop(cards, 0.2)
		tween(flash, if secret then 1.2 else 0.5, { BackgroundTransparency = 1 })
		-- Legendary and rarer: tint the screen and turn light rays behind the cards.
		if effects and topRarity.order >= RARE_ORDER then
			backdrop.BackgroundColor3 = rareColor:Lerp(BACKDROP_COLOR, 0.35)
			tween(backdrop, 0.4, { BackgroundTransparency = if secret then 0.15 else 0.3 })
			for _, ray in rayParts do
				ray.BackgroundColor3 = rareColor:Lerp(Color3.new(1, 1, 1), 0.45)
			end
			rays.Rotation = 0
			rays.Visible = true
			raySpin:Play()
		end
		if secret or anyShiny then
			-- Secret wins the title; a Shiny Secret reads "GEHEIM! ✨ SHINY!".
			local text = if secret then Lang.t("egg.secretHatched") else Lang.t("egg.shinyHatched")
			if secret and anyShiny then
				text = `{text}  {Lang.t("egg.shinyHatched")}`
			end
			secretTitle.Text = text
			secretTitle.TextColor3 = if secret then UiKit.rarityColor("Secret") else SHINY_COLOR
			secretTitle.Visible = true
			UiKit.pop(secretTitle, 0.3)
			Sounds.play(if secret then "Secret" else "Shiny")
		end
		closable = true

		local closeSeconds = if secret
			then SECRET_CLOSE_SECONDS
			elseif anyShiny then CLOSE_SECONDS + 2
			else CLOSE_SECONDS
		task.delay(closeSeconds, function()
			if myId == playId then
				close()
			end
		end)
	end)
end

return EggAnimation
