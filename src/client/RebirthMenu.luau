--!strict
-- Rebirth on the client (#35):
-- * Round "Rebirth" button on the left (HUD slot "rebirth") with the number of rebirths
--   as a badge. It pulses (with a short hint) the first time a rebirth is affordable,
--   until the menu is opened once (hint "Rebirth", remembered on the server like the
--   gifts button, so it does not pulse again in the next session).
-- * Menu: rebirths, coin multiplier now -> next, price and progress, what is reset and what
--   stays, a warning while a potion runs, and a "Rebirth!" button that asks to confirm.
-- * Celebration "Rebirth 2! ×2 Münzen" when the server answers Rebirthed.
-- Reads the attributes Rebirths, RebirthOffer (JSON, see Net / RebirthService) and
-- SeenHints (GiftService). Only sends the wishes Rebirth and HintSeen; the server decides.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Sounds)
local UiKit = require(script.Parent.UiKit)

local PANEL_SIZE = Vector2.new(560, 500)
local HINT_ID = "Rebirth"
local PURPLE = Color3.fromRGB(150, 80, 220)
local SOFT = Color3.fromRGB(110, 80, 55)

type Offer = {
	rebirths: number,
	price: number,
	multiplier: number,
	nextMultiplier: number,
	progress: number,
	affordable: boolean,
	potionWarning: boolean,
}

local RebirthMenu = {}

local function readOffer(player: Player): Offer?
	local json = player:GetAttribute("RebirthOffer")
	if type(json) ~= "string" then
		return nil
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(value) ~= "table" or type(value.price) ~= "number" then
		return nil
	end
	return value :: Offer
end

-- "×1,5" / "×2" from a multiplier.
local function multiplierText(value: number): string
	local text = if value == math.floor(value) then tostring(value) else string.format("%.1f", value)
	return "×" .. (string.gsub(text, "%.", ","))
end

function RebirthMenu.start()
	local player = Players.LocalPlayer
	local rebirthEvent = Net.event("Rebirth")

	local gui = Instance.new("ScreenGui")
	gui.Name = "RebirthMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	UiKit.autoScale(gui)

	-- HUD button with badge -------------------------------------------------------
	local openButton = UiKit.sideButton("rebirth", "Rebirth", PURPLE)
	openButton.Name = "RebirthButton"

	local badge = UiKit.label(openButton, "0")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -12, 0, 12)
	badge.Size = UDim2.fromOffset(40, 40)
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = UiKit.COIN
	badge.ZIndex = 3
	badge.Visible = false
	UiKit.corner(badge, 20)
	UiKit.stroke(badge, 2)

	-- Short hint next to the button while it pulses.
	local hintBubble = UiKit.label(openButton, "Neu! Mehr Münzen")
	hintBubble.Name = "Hint"
	hintBubble.AnchorPoint = Vector2.new(0, 0.5)
	hintBubble.Position = UDim2.new(1, 12, 0.5, 0)
	hintBubble.Size = UDim2.fromOffset(190, 44)
	hintBubble.BackgroundTransparency = 0
	hintBubble.BackgroundColor3 = UiKit.CREAM
	hintBubble.ZIndex = 3
	hintBubble.Visible = false
	UiKit.corner(hintBubble, 14)
	UiKit.stroke(hintBubble, 2)

	-- Menu ------------------------------------------------------------------------
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = UiKit.CREAM
	panel.Visible = false
	UiKit.corner(panel, 24)
	UiKit.stroke(panel, 4)
	UiKit.placeMenu(gui, panel, PANEL_SIZE)

	local title = UiKit.label(panel, "Rebirth")
	title.Position = UDim2.fromOffset(24, 14)
	title.Size = UDim2.new(1, -120, 0, 48)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local closeButton = UiKit.button(panel, "X", UiKit.RED)
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	closeButton.Size = UDim2.fromOffset(72, 72)

	local count = UiKit.label(panel, "")
	count.Position = UDim2.fromOffset(24, 66)
	count.Size = UDim2.new(1, -120, 0, 28)
	count.TextXAlignment = Enum.TextXAlignment.Left
	count.TextColor3 = SOFT

	-- Multiplier now -> next.
	local multiplier = UiKit.label(panel, "")
	multiplier.Position = UDim2.fromOffset(24, 104)
	multiplier.Size = UDim2.new(1, -48, 0, 56)
	multiplier.BackgroundTransparency = 0
	multiplier.BackgroundColor3 = Color3.fromRGB(235, 220, 255)
	UiKit.corner(multiplier, 16)
	UiKit.stroke(multiplier, 2)

	local price = UiKit.label(panel, "")
	price.Position = UDim2.fromOffset(24, 172)
	price.Size = UDim2.new(1, -48, 0, 30)
	price.TextXAlignment = Enum.TextXAlignment.Left

	-- Progress bar: coins towards the price.
	local bar = Instance.new("Frame")
	bar.Name = "Progress"
	bar.Position = UDim2.fromOffset(24, 208)
	bar.Size = UDim2.new(1, -48, 0, 34)
	bar.BackgroundColor3 = Color3.fromRGB(230, 215, 190)
	UiKit.corner(bar, 17)
	UiKit.stroke(bar, 2)
	bar.Parent = panel
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = UiKit.COIN
	UiKit.corner(fill, 17)
	fill.Parent = bar
	local barText = UiKit.label(bar, "")
	barText.Size = UDim2.fromScale(1, 1)
	barText.ZIndex = 2

	local info = UiKit.label(
		panel,
		"Weg: Münzen, Münz-Upgrades, Welten, Pizza, Auftrag.\nBleibt: Pets, Gems, Gem-Upgrades, Tränke im Inventar."
	)
	info.Position = UDim2.fromOffset(24, 252)
	info.Size = UDim2.new(1, -48, 0, 56)
	info.TextColor3 = SOFT

	local warning = UiKit.label(panel, "Achtung: Dein laufender Trank endet beim Rebirth!")
	warning.Position = UDim2.fromOffset(24, 314)
	warning.Size = UDim2.new(1, -48, 0, 30)
	warning.TextColor3 = UiKit.RED
	warning.Visible = false

	local rebirthButton = UiKit.button(panel, "Rebirth!", UiKit.GREEN)
	rebirthButton.Name = "DoRebirth"
	rebirthButton.AnchorPoint = Vector2.new(0.5, 1)
	rebirthButton.Position = UDim2.new(0.5, 0, 1, -24)
	rebirthButton.Size = UDim2.fromOffset(300, 80)

	-- Confirmation, covers the whole panel.
	local confirm = Instance.new("Frame")
	confirm.Name = "Confirm"
	confirm.Size = UDim2.fromScale(1, 1)
	confirm.BackgroundColor3 = UiKit.DARK
	confirm.BackgroundTransparency = 0.35
	confirm.Active = true
	confirm.ZIndex = 10
	confirm.Visible = false
	UiKit.corner(confirm, 24)
	confirm.Parent = panel

	local confirmBox = Instance.new("Frame")
	confirmBox.AnchorPoint = Vector2.new(0.5, 0.5)
	confirmBox.Position = UDim2.fromScale(0.5, 0.5)
	confirmBox.Size = UDim2.fromOffset(460, 270)
	confirmBox.BackgroundColor3 = UiKit.CREAM
	confirmBox.ZIndex = 11
	UiKit.corner(confirmBox, 20)
	UiKit.stroke(confirmBox, 3)
	confirmBox.Parent = confirm

	local confirmText = UiKit.label(confirmBox, "")
	confirmText.Position = UDim2.fromOffset(20, 16)
	confirmText.Size = UDim2.new(1, -40, 0, 140)
	confirmText.ZIndex = 12

	local yesButton = UiKit.button(confirmBox, "Ja, Rebirth!", UiKit.GREEN)
	yesButton.Position = UDim2.new(0, 20, 1, -92)
	yesButton.Size = UDim2.new(0.5, -30, 0, 72)
	yesButton.ZIndex = 12
	local noButton = UiKit.button(confirmBox, "Nein", UiKit.RED)
	noButton.Position = UDim2.new(0.5, 10, 1, -92)
	noButton.Size = UDim2.new(0.5, -30, 0, 72)
	noButton.ZIndex = 12

	-- Celebration -------------------------------------------------------------------
	local celebration = UiKit.label(gui, "")
	celebration.Name = "Celebration"
	celebration.AnchorPoint = Vector2.new(0.5, 0.5)
	celebration.Position = UDim2.fromScale(0.5, 0.4)
	celebration.Size = UDim2.fromOffset(640, 110)
	celebration.TextColor3 = UiKit.COIN
	celebration.ZIndex = 20
	celebration.Visible = false
	local celebrationStroke = Instance.new("UIStroke")
	celebrationStroke.Color = UiKit.DARK
	celebrationStroke.Thickness = 4
	celebrationStroke.Parent = celebration

	gui.Parent = player:WaitForChild("PlayerGui")

	-- Behaviour ---------------------------------------------------------------------
	local opened = false
	local pulseTween: Tween? = nil
	local hintSeen = Net.event("HintSeen")

	-- Opened in an earlier session (or earlier in this one): remembered on the server.
	local function seen(): boolean
		local hints = player:GetAttribute("SeenHints")
		return type(hints) == "string" and table.find(string.split(hints, ","), HINT_ID) ~= nil
	end

	local function setPulsing(on: boolean)
		if on == (pulseTween ~= nil) then
			return
		end
		hintBubble.Visible = on
		if on then
			-- Same UIScale as UiKit.pop; opening the menu stops the pulse before popping.
			local scale = openButton:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			scale.Parent = openButton
			scale.Scale = 1
			local tween = TweenService:Create(
				scale,
				TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{
					Scale = 1.12,
				}
			)
			tween:Play()
			pulseTween = tween
		elseif pulseTween then
			pulseTween:Cancel()
			pulseTween = nil
			local scale = openButton:FindFirstChildOfClass("UIScale")
			if scale then
				scale.Scale = 1
			end
		end
	end

	local function refresh()
		local rebirths = (player:GetAttribute("Rebirths") :: number?) or 0
		badge.Text = tostring(rebirths)
		badge.Visible = rebirths > 0
		local offer = readOffer(player)
		if offer == nil then
			return
		end
		count.Text = if offer.rebirths == 0 then "Noch kein Rebirth" else `Rebirths: {offer.rebirths}`
		multiplier.Text = `Münzen {multiplierText(offer.multiplier)}  →  {multiplierText(offer.nextMultiplier)}`
		price.Text = `Preis: {UiKit.shortNumber(offer.price)} Münzen`
		fill.Size = UDim2.fromScale(math.clamp(offer.progress, 0, 1), 1)
		fill.Visible = offer.progress > 0
		barText.Text = `{math.floor(offer.progress * 100)} %`
		warning.Visible = offer.potionWarning
		rebirthButton.BackgroundColor3 = if offer.affordable then UiKit.GREEN else UiKit.GREY
		rebirthButton.AutoButtonColor = offer.affordable
		confirmText.Text = `Rebirth {offer.rebirths + 1} für {UiKit.shortNumber(offer.price)} Münzen?\nDanach: Münzen {multiplierText(
			offer.nextMultiplier
		)}, Start in Welt 1.` .. (if offer.potionWarning then "\nDein laufender Trank endet!" else "")
		-- First time a rebirth is possible: draw attention until the menu is opened.
		setPulsing(not opened and not seen() and offer.rebirths == 0 and offer.affordable)
	end

	local function open()
		if not opened then
			opened = true
			if not seen() then
				hintSeen:FireServer(HINT_ID)
			end
		end
		setPulsing(false)
		confirm.Visible = false
		panel.Visible = true
		UiKit.pop(panel, 0.85)
	end

	openButton.Activated:Connect(function()
		if panel.Visible then
			panel.Visible = false
		else
			open()
			UiKit.pop(openButton)
		end
	end)
	closeButton.Activated:Connect(function()
		panel.Visible = false
	end)
	rebirthButton.Activated:Connect(function()
		local offer = readOffer(player)
		UiKit.pop(rebirthButton)
		if offer and offer.affordable then
			confirm.Visible = true
			UiKit.pop(confirmBox, 0.85)
		end
	end)
	noButton.Activated:Connect(function()
		confirm.Visible = false
	end)
	yesButton.Activated:Connect(function()
		confirm.Visible = false
		rebirthEvent:FireServer()
	end)

	local celebrationId = 0
	Net.event("Rebirthed").OnClientEvent:Connect(function(rebirths: number, newMultiplier: number)
		panel.Visible = false
		celebrationId += 1
		local myId = celebrationId
		celebration.Text = `Rebirth {rebirths}! {multiplierText(newMultiplier)} Münzen`
		celebration.TextTransparency = 0
		celebrationStroke.Transparency = 0
		celebration.Visible = true
		UiKit.pop(celebration, 0.3)
		UiKit.pop(openButton, 1.4)
		Sounds.play("Rebirth")
		task.delay(3, function()
			if celebrationId ~= myId then
				return
			end
			local fade = TweenInfo.new(0.6)
			TweenService:Create(celebration, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(celebrationStroke, fade, { Transparency = 1 }):Play()
			task.delay(0.6, function()
				if celebrationId == myId then
					celebration.Visible = false
				end
			end)
		end)
	end)

	player:GetAttributeChangedSignal("Rebirths"):Connect(refresh)
	player:GetAttributeChangedSignal("RebirthOffer"):Connect(refresh)
	player:GetAttributeChangedSignal("SeenHints"):Connect(refresh)
	refresh()
end

return RebirthMenu
