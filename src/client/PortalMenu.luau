--!strict
-- Portal menu: opens when the server says the player stands in a portal, closes when
-- they walk out (or tap X). Lists every world; unlocked ones are big green buttons,
-- locked ones are grey with their price and cannot be chosen. Buttons only send the
-- wish (Teleport); the server checks again and moves the character.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local UiKit = require(script.Parent.UiKit)

type PortalEntry = GameRules.PortalEntry

local PANEL_SIZE = Vector2.new(520, 440)
local ROW_HEIGHT = 84
local PURPLE = Color3.fromRGB(150, 90, 230)
local GREY = Color3.fromRGB(170, 165, 160)
local HERE = Color3.fromRGB(240, 170, 60)

local PortalMenu = {}

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1.")))
	return (string.gsub(formatted, "^%.", ""))
end

function PortalMenu.start()
	local player = Players.LocalPlayer
	local teleport = Net.event("Teleport")

	local gui = Instance.new("ScreenGui")
	gui.Name = "PortalMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Enabled = false
	UiKit.autoScale(gui)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
	panel.BackgroundColor3 = UiKit.CREAM
	UiKit.corner(panel, 24)
	UiKit.stroke(panel, 4)
	panel.Parent = gui

	local title = UiKit.label(panel, "🌀 Teleport")
	title.Position = UDim2.fromOffset(20, 12)
	title.Size = UDim2.new(1, -120, 0, 52)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local closeButton = UiKit.button(panel, "X", UiKit.RED)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -12, 0, 10)
	closeButton.Size = UDim2.fromOffset(64, 64)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Worlds"
	list.Position = UDim2.fromOffset(16, 84)
	list.Size = UDim2.new(1, -32, 1, -100)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 10
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local padding = Instance.new("UIPadding")
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = list

	local function clear()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function render(currentWorldId: string, entries: { PortalEntry })
		clear()
		for index, entry in entries do
			local here = entry.worldId == currentWorldId
			local text, color
			if not entry.unlocked then
				text = `🔒 {entry.displayName} – {formatNumber(entry.unlockPrice)} Münzen`
				color = GREY
			elseif here then
				text = `📍 {entry.displayName} (du bist hier)`
				color = HERE
			else
				text = `{index}. {entry.displayName}`
				color = PURPLE
			end
			local row = UiKit.button(list, text, color)
			row.LayoutOrder = index
			row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
			row.TextXAlignment = Enum.TextXAlignment.Left
			if entry.unlocked and not here then
				row.Activated:Connect(function()
					UiKit.pop(row)
					teleport:FireServer(entry.worldId)
				end)
			else
				-- Greyed out / current world: not selectable.
				row.AutoButtonColor = false
				row.Active = false
				if not entry.unlocked then
					row.TextTransparency = 0.25
				end
			end
		end
	end

	Net.event("PortalOpen").OnClientEvent:Connect(function(currentWorldId: string, entries: { PortalEntry })
		local wasOpen = gui.Enabled
		render(currentWorldId, entries)
		gui.Enabled = true
		if not wasOpen then
			UiKit.pop(panel, 0.85)
		end
	end)

	Net.event("PortalClose").OnClientEvent:Connect(function()
		gui.Enabled = false
	end)

	closeButton.Activated:Connect(function()
		gui.Enabled = false
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return PortalMenu
