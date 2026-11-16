--!strict
-- Small UI helpers and the shared look (colors, font) for all game UI.
-- The rules behind it are written down in docs/ui-style.md; new UI uses UiKit.
-- Everything is sized for touch: buttons are at least 60 px high.

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UiKit = {}

UiKit.FONT = Enum.Font.FredokaOne
UiKit.CREAM = Color3.fromRGB(255, 248, 230)
UiKit.DARK = Color3.fromRGB(60, 35, 20)
UiKit.COIN = Color3.fromRGB(255, 200, 40)
UiKit.GREEN = Color3.fromRGB(110, 200, 90)
UiKit.RED = Color3.fromRGB(230, 70, 50)
UiKit.GEM = Color3.fromRGB(60, 230, 255)
UiKit.ORANGE = Color3.fromRGB(240, 130, 60)
UiKit.GREY = Color3.fromRGB(190, 180, 170)
-- Smallest tappable size (px, before UIScale) for anything the player presses.
UiKit.MIN_TOUCH = 60

function UiKit.corner(parent: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

function UiKit.stroke(parent: Instance, thickness: number?)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = thickness or 3
	uiStroke.Color = UiKit.DARK
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uiStroke.Parent = parent
end

function UiKit.label(parent: Instance, text: string): TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Font = UiKit.FONT
	textLabel.TextScaled = true
	textLabel.TextColor3 = UiKit.DARK
	textLabel.Text = text
	textLabel.Parent = parent
	return textLabel
end

-- Big rounded button; use `.Activated` (works for mouse and touch).
function UiKit.button(parent: Instance, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = color
	button.Font = UiKit.FONT
	button.TextScaled = true
	button.TextColor3 = UiKit.CREAM
	button.Text = text
	UiKit.corner(button, 18)
	UiKit.stroke(button)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = button
	local textStroke = Instance.new("UIStroke")
	textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textStroke.Color = UiKit.DARK
	textStroke.Thickness = 2
	textStroke.Parent = button
	button.Parent = parent
	return button
end

-- Round icon button (HUD side buttons like "Pets"): a circle `size` px wide.
function UiKit.roundButton(parent: Instance, text: string, color: Color3, size: number?): TextButton
	local button = UiKit.button(parent, text, color)
	local diameter = math.max(size or 96, UiKit.MIN_TOUCH)
	button.Size = UDim2.fromOffset(diameter, diameter)
	local round = button:FindFirstChildOfClass("UICorner") :: UICorner
	round.CornerRadius = UDim.new(0.5, 0)
	return button
end

-- Scales a ScreenGui so it stays readable on small phones and large monitors alike.
function UiKit.autoScale(gui: ScreenGui)
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

function UiKit.pop(target: GuiObject, from: number?)
	local uiScale = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	uiScale.Parent = target
	uiScale.Scale = from or 1.15
	TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Short number for small labels: 999.999 stays as is, then "1,5 Mio", "12 Mrd", "3,4 Bio".
function UiKit.shortNumber(value: number): string
	local units = { { 1e12, "Bio" }, { 1e9, "Mrd" }, { 1e6, "Mio" } }
	for _, unit in units do
		if value >= unit[1] then
			local scaled = value / unit[1]
			local text = if scaled >= 100
				then tostring(math.floor(scaled))
				else string.format("%.1f", math.floor(scaled * 10) / 10)
			text = string.gsub(string.gsub(text, "%.0$", ""), "%.", ",")
			return `{text} {unit[2]}`
		end
	end
	local text = tostring(math.floor(value))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1.")))
	return (string.gsub(formatted, "^%.", ""))
end

function UiKit.rarityColor(rarityId: string): Color3
	local color = GameConfig.rarities[rarityId].color
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- "+25 %" from a bonus of 0.25.
function UiKit.bonusText(bonus: number): string
	return `+{math.round(bonus * 100)} %`
end

-- "0,5 %" / "28 %" from a chance in percent.
function UiKit.chanceText(percent: number): string
	local text = if percent >= 10 or percent == math.floor(percent)
		then tostring(math.round(percent))
		else string.format("%.1f", percent)
	return (string.gsub(text, "%.", ",")) .. " %"
end

return UiKit
