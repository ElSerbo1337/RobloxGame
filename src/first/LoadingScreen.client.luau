--!strict
-- Loading screen (#111, ReplicatedFirst): logo lettering, a spinning pizza and changing
-- tips (German/English) about the new features. Rules (which tips, order, when it goes
-- away) are pure in src/shared/LoadingTips.luau; timings in GameConfig.loadingScreen;
-- switch: GameConfig.features.loadingScreen (off = the normal Roblox loading screen).
--
-- It always goes away: once game:IsLoaded() and the minimum time are over, at the latest
-- after maxSeconds, and from skipAfterSeconds on with a tap. If ReplicatedStorage.Shared
-- does not arrive in time or anything here fails, the normal Roblox screen stays and
-- Roblox removes it as usual.
--
-- ReplicatedFirst runs before StarterPlayerScripts, so the client modules (Lang, UiKit)
-- are not there yet: the language is read like in src/client/Lang.luau and the colours
-- are the ones from UiKit (docs/ui-style.md).

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FONT = Enum.Font.FredokaOne
local CREAM = Color3.fromRGB(255, 248, 230)
local DARK = Color3.fromRGB(60, 35, 20)
local COIN = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(110, 200, 90)
local ORANGE = Color3.fromRGB(240, 130, 60)

local SHARED_TIMEOUT = 8

local player = Players.LocalPlayer

local sharedFolder = ReplicatedStorage:WaitForChild("Shared", SHARED_TIMEOUT)
if sharedFolder == nil then
	return
end

local loadedModules, modules = pcall(function()
	return {
		GameConfig = require(sharedFolder:WaitForChild("GameConfig", SHARED_TIMEOUT) :: ModuleScript) :: any,
		Features = require(sharedFolder:WaitForChild("Features", SHARED_TIMEOUT) :: ModuleScript) :: any,
		Texts = require(sharedFolder:WaitForChild("Texts", SHARED_TIMEOUT) :: ModuleScript) :: any,
		LoadingTips = require(sharedFolder:WaitForChild("LoadingTips", SHARED_TIMEOUT) :: ModuleScript) :: any,
		HudLayout = require(sharedFolder:WaitForChild("HudLayout", SHARED_TIMEOUT) :: ModuleScript) :: any,
	}
end)
if not loadedModules then
	warn("[LoadingScreen] shared modules missing, keeping the Roblox loading screen:", modules)
	return
end

local GameConfig = modules.GameConfig
local Texts = modules.Texts
local LoadingTips = modules.LoadingTips
local HudLayout = modules.HudLayout
local features = modules.Features.new(GameConfig.features)
if not features.enabled("loadingScreen") then
	return
end

local timing = GameConfig.loadingScreen

-- Same order as src/client/Lang.luau (Studio override, experience language, app, device).
local function readLanguage(): string
	if RunService:IsStudio() then
		local override = Workspace:GetAttribute("Language")
		if override == "de" or override == "en" then
			return override
		end
	end
	local locale = player.LocaleId
	if locale == nil or locale == "" then
		locale = LocalizationService.RobloxLocaleId
	end
	if locale == nil or locale == "" then
		locale = LocalizationService.SystemLocaleId
	end
	return Texts.languageFor(locale)
end

local language = readLanguage()
local function t(key: string, args: any?): string
	return Texts.render(language, key, args)
end

local tips = LoadingTips.shuffle(LoadingTips.available(GameConfig.features), math.random)

-- GUI ---------------------------------------------------------------------------------

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function stroke(parent: Instance, thickness: number, contextual: boolean?)
	local s = Instance.new("UIStroke")
	s.Color = DARK
	s.Thickness = thickness
	s.ApplyStrokeMode = if contextual then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function label(parent: Instance, name: string, text: string, color: Color3, outlined: boolean): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextScaled = true
	l.TextWrapped = true
	l.TextColor3 = color
	l.Text = text
	if outlined then
		stroke(l, 2, true)
	end
	l.Parent = parent
	return l
end

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.AutoLocalize = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- The whole background is a button: a tap skips once skipping is allowed.
local root = Instance.new("TextButton")
root.Name = "Background"
root.Text = ""
root.AutoButtonColor = false
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = ORANGE
root.BorderSizePixel = 0
root.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(205, 75, 40))
gradient.Parent = root

-- Soft cheese-coloured dots in the background.
for i = 1, 14 do
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	local size = 40 + (i * 37) % 70
	dot.Size = UDim2.fromOffset(size, size)
	dot.Position = UDim2.fromScale(((i * 0.37) % 1), ((i * 0.61) % 1))
	dot.BackgroundColor3 = CREAM
	dot.BackgroundTransparency = 0.82
	dot.BorderSizePixel = 0
	corner(dot, UDim.new(0.5, 0))
	dot.Parent = root
end

-- Content: built for 960 × 600 virtual pixels and scaled to the screen.
local CONTENT_W, CONTENT_H = 960, 600
local content = Instance.new("Frame")
content.Name = "Content"
content.AnchorPoint = Vector2.new(0.5, 0.5)
content.Position = UDim2.fromScale(0.5, 0.5)
content.Size = UDim2.fromOffset(CONTENT_W, CONTENT_H)
content.BackgroundTransparency = 1
content.Parent = root
local contentScale = Instance.new("UIScale")
contentScale.Parent = content

local title = label(content, "Title", t("loading.title"), CREAM, true)
title.Size = UDim2.fromOffset(CONTENT_W, 96)
local titleStroke = title:FindFirstChildOfClass("UIStroke") :: UIStroke
titleStroke.Thickness = 4

local subtitle = label(content, "Subtitle", t("loading.subtitle"), COIN, true)
subtitle.Position = UDim2.fromOffset(0, 96)
subtitle.Size = UDim2.fromOffset(CONTENT_W, 42)

-- Spinning pizza: drawn from GUI frames (always works); swapped for the imported 3D
-- model (ModelLibrary "Pizza" in a ViewportFrame) when it is already there.
local PIZZA = 230
local pizzaHolder = Instance.new("Frame")
pizzaHolder.Name = "Pizza"
pizzaHolder.AnchorPoint = Vector2.new(0.5, 0)
pizzaHolder.Position = UDim2.fromOffset(CONTENT_W / 2, 150)
pizzaHolder.Size = UDim2.fromOffset(PIZZA, PIZZA)
pizzaHolder.BackgroundTransparency = 1
pizzaHolder.Parent = content

local guiPizza = Instance.new("Frame")
guiPizza.Name = "GuiPizza"
guiPizza.Size = UDim2.fromScale(1, 1)
guiPizza.BackgroundTransparency = 1
guiPizza.Parent = pizzaHolder

local function disc(
	parent: Instance,
	name: string,
	share: number,
	x: number,
	y: number,
	color: Color3,
	outline: boolean?
)
	local d = Instance.new("Frame")
	d.Name = name
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = UDim2.fromScale(x, y)
	d.Size = UDim2.fromScale(share, share)
	d.BackgroundColor3 = color
	d.BorderSizePixel = 0
	corner(d, UDim.new(0.5, 0))
	if outline then
		stroke(d, 4)
	end
	d.Parent = parent
	return d
end

disc(guiPizza, "Crust", 1, 0.5, 0.5, Color3.fromRGB(222, 160, 80), true)
disc(guiPizza, "Sauce", 0.86, 0.5, 0.5, Color3.fromRGB(205, 55, 35))
disc(guiPizza, "Cheese", 0.78, 0.5, 0.5, Color3.fromRGB(255, 214, 110))
for i = 0, 6 do
	local angle = i * math.pi * 2 / 7
	local r = if i % 2 == 0 then 0.26 else 0.2
	disc(guiPizza, "Salami", 0.17, 0.5 + math.cos(angle) * r, 0.5 + math.sin(angle) * r, Color3.fromRGB(165, 35, 50))
end
disc(guiPizza, "Salami", 0.17, 0.5, 0.5, Color3.fromRGB(165, 35, 50))
for i = 0, 4 do
	local angle = i * math.pi * 2 / 5 + 0.6
	disc(guiPizza, "Olive", 0.06, 0.5 + math.cos(angle) * 0.33, 0.5 + math.sin(angle) * 0.33, DARK)
	disc(guiPizza, "Basil", 0.07, 0.5 + math.cos(angle + 0.4) * 0.12, 0.5 + math.sin(angle + 0.4) * 0.12, GREEN)
end

local pizzaModel: Model? = nil
task.spawn(function()
	local ok, result = pcall(function()
		local assets = ReplicatedStorage:WaitForChild("GameAssets", 3)
		if assets == nil then
			return nil
		end
		local library = require(sharedFolder:WaitForChild("ModelLibrary", 2) :: ModuleScript) :: any
		return library.viewport("Pizza")
	end)
	if not ok or result == nil or gui.Parent == nil then
		return
	end
	local view = result :: ViewportFrame
	local model = view:FindFirstChildOfClass("Model")
	if model == nil then
		view:Destroy()
		return
	end
	view.Parent = pizzaHolder
	guiPizza.Visible = false
	pizzaModel = model
end)

-- Tip card.
local card = Instance.new("Frame")
card.Name = "TipCard"
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.fromOffset(CONTENT_W / 2, 400)
card.Size = UDim2.fromOffset(820, 120)
card.BackgroundColor3 = CREAM
corner(card, UDim.new(0, 22))
stroke(card, 3)
card.Parent = content

local tipLabel = label(card, "TipLabel", t("loading.tipLabel"), ORANGE, false)
tipLabel.Position = UDim2.fromOffset(20, 8)
tipLabel.Size = UDim2.new(1, -40, 0, 30)
tipLabel.TextXAlignment = Enum.TextXAlignment.Left

local tipText = label(card, "TipText", "", DARK, false)
tipText.Position = UDim2.fromOffset(20, 40)
tipText.Size = UDim2.new(1, -40, 1, -50)
tipText.TextXAlignment = Enum.TextXAlignment.Left

-- Progress bar and status.
local bar = Instance.new("Frame")
bar.Name = "Progress"
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.fromOffset(CONTENT_W / 2, 538)
bar.Size = UDim2.fromOffset(520, 24)
bar.BackgroundColor3 = CREAM
corner(bar, UDim.new(0.5, 0))
stroke(bar, 3)
bar.Parent = content
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = GREEN
fill.BorderSizePixel = 0
corner(fill, UDim.new(0.5, 0))
fill.Parent = bar

local status = label(content, "Status", t("loading.loading"), CREAM, true)
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.fromOffset(CONTENT_W / 2, 566)
status.Size = UDim2.fromOffset(400, 30)

-- Skip hint: bottom of the screen, above the phone safe area.
local skip = label(root, "SkipHint", t("loading.skip"), CREAM, true)
skip.AnchorPoint = Vector2.new(0.5, 1)
skip.Position = UDim2.new(0.5, 0, 1, -16)
skip.Size = UDim2.fromOffset(360, 30)
skip.Visible = false
local skipScale = Instance.new("UIScale")
skipScale.Parent = skip

-- Fit the content to the screen. Small screens (phones, HudLayout.isSmallScreen) drop the
-- subtitle and shrink the pizza so the tip stays big enough to read.
local function layout()
	local camera = Workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local small = HudLayout.isSmallScreen(size.X, size.Y)
	subtitle.Visible = not small
	local pizzaTop = if small then 104 else 150
	local pizzaSize = if small then 190 else PIZZA
	pizzaHolder.Position = UDim2.fromOffset(CONTENT_W / 2, pizzaTop)
	pizzaHolder.Size = UDim2.fromOffset(pizzaSize, pizzaSize)
	card.Position = UDim2.fromOffset(CONTENT_W / 2, pizzaTop + pizzaSize + 16)
	card.Size = UDim2.fromOffset(820, if small then 150 else 120)
	local barTop = card.Position.Y.Offset + card.Size.Y.Offset + 18
	bar.Position = UDim2.fromOffset(CONTENT_W / 2, barTop)
	status.Position = UDim2.fromOffset(CONTENT_W / 2, barTop + 28)
	local height = barTop + 28 + 30
	content.Size = UDim2.fromOffset(CONTENT_W, height)
	-- 16 px margin on every side (more at the bottom for the skip hint).
	local scale = math.min((size.X - 32) / CONTENT_W, (size.Y - 80) / height)
	contentScale.Scale = math.clamp(scale, 0.3, 1.4)
	skipScale.Scale = math.clamp(math.min(size.X / 1100, size.Y / 650), 0.7, 1.4)
end

layout()
local cameraConnection: RBXScriptConnection? = nil
local function watchCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
	end
	local camera = Workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	layout()
end
watchCamera()
local cameraChanged = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)

gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- Loop ----------------------------------------------------------------------------------

local started = os.clock()
local skipped = false
local shownTip = 0
local hiding = false

local function showTip(index: number)
	if index == shownTip or index == 0 then
		return
	end
	local first = shownTip == 0
	shownTip = index
	local text = t(LoadingTips.textArgs(tips[index], GameConfig))
	if first then
		tipText.Text = text
		return
	end
	local fadeOut = TweenService:Create(tipText, TweenInfo.new(0.2), { TextTransparency = 1 })
	fadeOut:Play()
	fadeOut.Completed:Once(function()
		tipText.Text = text
		TweenService:Create(tipText, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	end)
end

root.Activated:Connect(function()
	if LoadingTips.canSkip(os.clock() - started, timing) then
		skipped = true
	end
end)

local stepConnection: RBXScriptConnection
local function finish()
	if hiding then
		return
	end
	hiding = true
	stepConnection:Disconnect()
	cameraChanged:Disconnect()
	if cameraConnection then
		cameraConnection:Disconnect()
	end
	fill.Size = UDim2.fromScale(1, 1)
	skip.Visible = false
	-- Slide up like a curtain, then remove (no CanvasGroup: viewports stay visible).
	local info = TweenInfo.new(timing.fadeSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local tween = TweenService:Create(root, info, { Position = UDim2.fromScale(0, -1.05) })
	tween:Play()
	task.delay(timing.fadeSeconds + 0.1, function()
		gui:Destroy()
	end)
end

stepConnection = RunService.RenderStepped:Connect(function()
	local elapsed = os.clock() - started
	local loaded = game:IsLoaded()
	if pizzaModel then
		pizzaModel:PivotTo(CFrame.Angles(0, elapsed * 1.6, 0))
	else
		guiPizza.Rotation = (elapsed * 70) % 360
	end
	-- A gentle bounce of the whole pizza.
	pizzaHolder.Rotation = math.sin(elapsed * 2) * 4
	showTip(LoadingTips.tipIndex(elapsed, #tips, timing.tipSeconds))
	fill.Size = UDim2.fromScale(LoadingTips.progress(elapsed, loaded, timing), 1)
	skip.Visible = LoadingTips.canSkip(elapsed, timing)
	if LoadingTips.shouldHide(elapsed, loaded, timing, skipped) then
		finish()
	end
end)

-- Last safety net: even if RenderStepped never fires (e.g. a broken frame), remove it.
task.delay(timing.maxSeconds + 3, function()
	if not hiding and gui.Parent then
		gui:Destroy()
	end
end)
