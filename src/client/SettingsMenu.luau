--!strict
-- Settings menu (#76, feature "settings"): side bar tile ⚙️ "Optionen" (order 200).
-- * Sound: music and effects volume, each a slider (0-100 %) plus a mute switch
--   (applied live through the sound groups in Sounds).
-- * Graphics High/Low (phones start on Low, see GraphicsQuality), camera shake and
--   screen flashes on/off.
-- * Skip egg animation (EggAnimation).
-- * Code field (feature "codes"): sends only the wish RedeemCode(code); the server rules
--   and the answer CodeResult(ok, reason?, rewards?) come with #99. Until then (no answer
--   within CODE_TIMEOUT) it says "Codes gibt es bald!".
-- Every change goes through Settings.set (local at once, saved on the server).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Lang = require(script.Parent.Lang)
local Settings = require(script.Parent.Settings)
local SideBar = require(script.Parent.SideBar)
local Sounds = require(script.Parent.Sounds)
local UiKit = require(script.Parent.UiKit)

local MENU_ID = "settings"
local TILE_COLOR = Color3.fromRGB(110, 140, 190)
local PANEL_SIZE = Vector2.new(620, 720)
local MIN_HEIGHT = 300
local HEADER_HEIGHT = 92
local ROW_HEIGHT = 72
local SECTION_HEIGHT = 40
local ROW_GAP = 8
local ROW_COLOR = Color3.fromRGB(255, 236, 200)
local HINT_COLOR = Color3.fromRGB(110, 80, 55)
local SWITCH_WIDTH = 120
local CODE_MAX_LENGTH = 32
local CODE_TIMEOUT = 5

local SettingsMenu = {}

function SettingsMenu.start()
	local features = Features.new(GameConfig.features)
	if not features.enabled("settings") then
		return
	end
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "SettingsMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	UiKit.autoScale(gui)

	local toggle: () -> () = function() end
	local openButton = SideBar.register({
		id = MENU_ID,
		order = 200,
		text = Lang.t("side.settings"),
		color = TILE_COLOR,
		icon = { shape = "gear" },
		open = function()
			toggle()
		end,
	})

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = UiKit.CREAM
	panel.Visible = false
	UiKit.corner(panel, 24)
	UiKit.stroke(panel, 4)
	UiKit.placeMenu(gui, panel, PANEL_SIZE, MIN_HEIGHT)

	local title = UiKit.label(panel, Lang.t("settings.title"))
	title.Position = UDim2.fromOffset(24, 18)
	title.Size = UDim2.new(1, -120, 0, 52)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local closeButton = UiKit.button(panel, "X", UiKit.RED)
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	closeButton.Size = UDim2.fromOffset(72, 72)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(12, HEADER_HEIGHT)
	list.Size = UDim2.new(1, -24, 1, -HEADER_HEIGHT - 12)
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = UiKit.DARK
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, ROW_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 4)
	listPadding.PaddingLeft = UDim.new(0, 4)
	listPadding.PaddingRight = UDim.new(0, 14)
	listPadding.PaddingBottom = UDim.new(0, 8)
	listPadding.Parent = list

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local function section(textKey: string)
		local heading = UiKit.label(list, Lang.t(textKey))
		heading.LayoutOrder = nextOrder()
		heading.Size = UDim2.new(1, 0, 0, SECTION_HEIGHT)
		heading.TextXAlignment = Enum.TextXAlignment.Left
	end

	-- A row with its name on the left; returns the row frame.
	local function row(textKey: string, nameWidth: number): Frame
		local frame = Instance.new("Frame")
		frame.LayoutOrder = nextOrder()
		frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		frame.BackgroundColor3 = ROW_COLOR
		UiKit.corner(frame, 16)
		UiKit.stroke(frame, 2)
		frame.Parent = list
		local name = UiKit.label(frame, Lang.t(textKey))
		name.Position = UDim2.fromOffset(14, 14)
		name.Size = UDim2.fromOffset(nameWidth, ROW_HEIGHT - 28)
		name.TextXAlignment = Enum.TextXAlignment.Left
		return frame
	end

	-- AN/AUS switch for a boolean setting, at the right end of `parent`.
	-- `inverted`: shows ON while the setting is false (mute switch shows "sound on").
	local function switch(parent: Frame, key: string, labels: { on: string, off: string }?, inverted: boolean?)
		local button = UiKit.button(parent, "", UiKit.GREEN)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -8, 0.5, 0)
		button.Size = UDim2.fromOffset(SWITCH_WIDTH, UiKit.MIN_TOUCH)
		local function show(value: any)
			local on = if inverted then value ~= true else value == true
			button.Text = if labels
				then (if on then labels.on else labels.off)
				else Lang.t(if on then "settings.on" else "settings.off")
			button.BackgroundColor3 = if on then UiKit.GREEN else UiKit.GREY
		end
		Settings.observe(key, show)
		button.Activated:Connect(function()
			UiKit.pop(button)
			Settings.set(key, not Settings.get(key))
		end)
		return button
	end

	-- Volume slider (0-100 %) plus mute switch.
	local function volumeRow(group: string)
		local frame = row(`settings.{group}Volume`, 120)
		local volumeKey = `{group}Volume`
		local mutedKey = `{group}Muted`

		local valueLabel = UiKit.label(frame, "")
		valueLabel.AnchorPoint = Vector2.new(1, 0.5)
		valueLabel.Position = UDim2.new(1, -SWITCH_WIDTH - 16, 0.5, 0)
		valueLabel.Size = UDim2.fromOffset(76, 32)

		-- The whole strip is the touch area; the visible track is thin.
		local hit = Instance.new("TextButton")
		hit.Name = "Slider"
		hit.Text = ""
		hit.AutoButtonColor = false
		hit.BackgroundTransparency = 1
		hit.Position = UDim2.fromOffset(146, 6)
		hit.Size = UDim2.new(1, -146 - SWITCH_WIDTH - 104, 0, ROW_HEIGHT - 12)
		hit.Parent = frame

		local track = Instance.new("Frame")
		track.AnchorPoint = Vector2.new(0, 0.5)
		track.Position = UDim2.new(0, 0, 0.5, 0)
		track.Size = UDim2.new(1, 0, 0, 16)
		track.BackgroundColor3 = UiKit.GREY
		UiKit.corner(track, 8)
		UiKit.stroke(track, 2)
		track.Parent = hit

		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = UiKit.GREEN
		UiKit.corner(fill, 8)
		fill.Parent = track

		local knob = Instance.new("Frame")
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.Position = UDim2.fromScale(1, 0.5)
		knob.Size = UDim2.fromOffset(40, 40)
		knob.BackgroundColor3 = UiKit.CREAM
		knob.ZIndex = 2
		UiKit.corner(knob, 20)
		UiKit.stroke(knob, 3)
		knob.Parent = track

		local function show()
			local percent = Settings.get(volumeKey) :: number
			local muted = Settings.get(mutedKey) == true
			fill.Size = UDim2.fromScale(percent / 100, 1)
			fill.BackgroundColor3 = if muted then UiKit.GREY else UiKit.GREEN
			knob.Position = UDim2.fromScale(percent / 100, 0.5)
			valueLabel.Text = Lang.t("settings.percent", { value = percent })
		end
		Settings.observe(volumeKey, show)
		Settings.observe(mutedKey, show)

		local dragging: InputObject? = nil
		local function setFrom(x: number)
			local width = math.max(track.AbsoluteSize.X, 1)
			local percent = math.clamp(math.round((x - track.AbsolutePosition.X) / width * 100), 0, 100)
			Settings.set(volumeKey, percent)
			-- Moving the slider means "I want to hear it".
			if Settings.get(mutedKey) == true and percent > 0 then
				Settings.set(mutedKey, false)
			end
		end
		hit.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = input
				list.ScrollingEnabled = false
				setFrom(input.Position.X)
			end
		end)
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if dragging == nil then
				return
			end
			if
				input == dragging
				or (
					dragging.UserInputType == Enum.UserInputType.MouseButton1
					and input.UserInputType == Enum.UserInputType.MouseMovement
				)
			then
				setFrom(input.Position.X)
			end
		end)
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if dragging and (input == dragging or input.UserInputType == dragging.UserInputType) then
				dragging = nil
				list.ScrollingEnabled = true
				if group == "effects" then
					Sounds.play("Collect") -- hear the new effects volume
				end
			end
		end)

		switch(frame, mutedKey, { on = "🔊", off = "🔇" }, true)
	end

	-- Hoch / Niedrig as two buttons side by side.
	local function graphicsRow()
		local frame = row("settings.graphics", 180)
		local buttons: { [string]: TextButton } = {}
		for index, choice in { "High", "Low" } do
			local button = UiKit.button(frame, Lang.t(`settings.graphics{choice}`), UiKit.GREY)
			button.AnchorPoint = Vector2.new(1, 0.5)
			button.Position = UDim2.new(1, -8 - (2 - index) * (SWITCH_WIDTH + 8), 0.5, 0)
			button.Size = UDim2.fromOffset(SWITCH_WIDTH, UiKit.MIN_TOUCH)
			button.Activated:Connect(function()
				UiKit.pop(button)
				Settings.set("graphics", choice)
			end)
			buttons[choice] = button
		end
		Settings.observe("graphics", function(value: any)
			for choice, button in buttons do
				button.BackgroundColor3 = if value == choice then UiKit.GREEN else UiKit.GREY
			end
		end)
	end

	local function switchRow(key: string)
		switch(row(`settings.{key}`, 360), key)
	end

	section("settings.sectionSound")
	volumeRow("music")
	volumeRow("effects")
	section("settings.sectionDisplay")
	graphicsRow()
	switchRow("cameraShake")
	switchRow("screenFlashes")
	section("settings.sectionGame")
	switchRow("skipEggAnimation")

	-- Code field (#99 builds the rules and answers CodeResult).
	if features.enabled("codes") then
		section("settings.sectionCodes")
		local frame = Instance.new("Frame")
		frame.LayoutOrder = nextOrder()
		frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT + 40)
		frame.BackgroundColor3 = ROW_COLOR
		UiKit.corner(frame, 16)
		UiKit.stroke(frame, 2)
		frame.Parent = list

		local box = Instance.new("TextBox")
		box.Name = "CodeBox"
		box.Position = UDim2.fromOffset(10, 6)
		box.Size = UDim2.new(1, -SWITCH_WIDTH - 60, 0, UiKit.MIN_TOUCH)
		box.BackgroundColor3 = UiKit.CREAM
		box.ClearTextOnFocus = false
		box.Font = UiKit.FONT
		box.TextScaled = true
		box.TextColor3 = UiKit.DARK
		box.PlaceholderText = Lang.t("codes.placeholder")
		box.PlaceholderColor3 = HINT_COLOR
		box.Text = ""
		UiKit.corner(box, 14)
		UiKit.stroke(box, 3)
		local boxPadding = Instance.new("UIPadding")
		boxPadding.PaddingLeft = UDim.new(0, 12)
		boxPadding.PaddingRight = UDim.new(0, 12)
		boxPadding.PaddingTop = UDim.new(0, 10)
		boxPadding.PaddingBottom = UDim.new(0, 10)
		boxPadding.Parent = box
		box.Parent = frame
		box:GetPropertyChangedSignal("Text"):Connect(function()
			if #box.Text > CODE_MAX_LENGTH then
				box.Text = string.sub(box.Text, 1, CODE_MAX_LENGTH)
			end
		end)

		local redeem = UiKit.button(frame, Lang.t("codes.redeem"), UiKit.GREEN)
		redeem.AnchorPoint = Vector2.new(1, 0)
		redeem.Position = UDim2.new(1, -8, 0, 6)
		redeem.Size = UDim2.fromOffset(SWITCH_WIDTH + 40, UiKit.MIN_TOUCH)

		local status = UiKit.label(frame, "")
		status.Position = UDim2.fromOffset(14, UiKit.MIN_TOUCH + 12)
		status.Size = UDim2.new(1, -28, 0, 30)
		status.TextXAlignment = Enum.TextXAlignment.Left
		status.TextColor3 = HINT_COLOR

		local requestId = 0
		local waiting = false
		local function showStatus(text: string, color: Color3)
			status.Text = text
			status.TextColor3 = color
		end

		local function send()
			local code = string.gsub(box.Text, "^%s*(.-)%s*$", "%1")
			if code == "" then
				showStatus(Lang.t("codes.empty"), UiKit.RED)
				return
			end
			if waiting then
				return
			end
			waiting = true
			requestId += 1
			local myId = requestId
			showStatus(Lang.t("codes.checking"), HINT_COLOR)
			Net.event("RedeemCode"):FireServer(code)
			task.delay(CODE_TIMEOUT, function()
				if waiting and requestId == myId then
					waiting = false
					showStatus(Lang.t("codes.unavailable"), HINT_COLOR)
				end
			end)
		end
		redeem.Activated:Connect(function()
			UiKit.pop(redeem)
			send()
		end)
		box.FocusLost:Connect(function(enterPressed: boolean)
			if enterPressed then
				send()
			end
		end)

		Net.event("CodeResult").OnClientEvent:Connect(function(ok: boolean, reason: string?, rewards: any)
			waiting = false
			if ok then
				Sounds.play("Gem")
				box.Text = ""
				local rewardText = if type(rewards) == "table" then UiKit.rewardsText(rewards) else ""
				showStatus(Lang.t("codes.redeemed", { rewards = rewardText }), Color3.fromRGB(40, 150, 60))
			else
				local key = `codes.{reason or ""}`
				local text = Lang.t(key)
				showStatus(if text == key then Lang.t("common.notNow") else text, UiKit.RED)
			end
		end)
	end

	gui.Parent = player:WaitForChild("PlayerGui")

	local function close()
		panel.Visible = false
	end
	UiKit.registerMenu(MENU_ID, close)
	closeButton.Activated:Connect(close)

	toggle = function()
		UiKit.pop(openButton)
		if panel.Visible then
			close()
			return
		end
		panel.Visible = true
		UiKit.menuOpened(MENU_ID)
		UiKit.pop(panel)
	end
end

return SettingsMenu
