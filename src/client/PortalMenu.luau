--!strict
-- Portal menu: opens when the server says the player stands in a portal, closes when
-- they walk out (or tap X). Lists every world; unlocked ones are big green buttons,
-- locked ones are grey with their price (worlds behind rebirths also "Ab X Rebirths",
-- #43) and cannot be chosen. Buttons only send the wish (Teleport); the server checks
-- again and moves the character.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local Lang = require(script.Parent.Lang)
local UiKit = require(script.Parent.UiKit)

type PortalEntry = GameRules.PortalEntry

local PANEL_SIZE = Vector2.new(520, 440)
local ROW_HEIGHT = 84
-- The world list scrolls: the panel may get as short as title + one row.
local MIN_PANEL_HEIGHT = 84 + ROW_HEIGHT + 16
local PURPLE = Color3.fromRGB(150, 90, 230)
local GREY = Color3.fromRGB(170, 165, 160)
local HERE = Color3.fromRGB(240, 170, 60)

local PortalMenu = {}

-- "Ab 1 Rebirth" / "Ab 3 Rebirths" (#43).
local function rebirthsText(count: number): string
	return Lang.t(if count == 1 then "unlock.rebirthsOne" else "unlock.rebirthsMany", { count = count })
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
	panel.BackgroundColor3 = UiKit.CREAM
	UiKit.corner(panel, 24)
	UiKit.stroke(panel, 4)
	UiKit.placeMenu(gui, panel, PANEL_SIZE, MIN_PANEL_HEIGHT)

	local title = UiKit.label(panel, Lang.t("portal.title"))
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
			if not entry.unlocked and not entry.enoughRebirths then
				-- Behind rebirths (#43): the condition first, the price below.
				text = Lang.t("portal.lockedRebirths", {
					world = entry.displayName,
					condition = rebirthsText(entry.requiredRebirths),
					price = Lang.integer(entry.unlockPrice),
				})
				color = GREY
			elseif not entry.unlocked then
				text = Lang.t("portal.locked", { world = entry.displayName, price = Lang.integer(entry.unlockPrice) })
				color = GREY
			elseif here then
				text = Lang.t("portal.here", { world = entry.displayName })
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

	-- The server re-sends PortalOpen on every state change while the player stands in the
	-- portal. Once closed ("X" or another menu opening), it stays closed until the player
	-- leaves the portal (PortalClose).
	local dismissed = false

	local function close()
		if gui.Enabled then
			gui.Enabled = false
			dismissed = true
		end
	end
	UiKit.registerMenu("portal", close)

	Net.event("PortalOpen").OnClientEvent:Connect(function(currentWorldId: string, entries: { PortalEntry })
		if dismissed then
			return
		end
		local wasOpen = gui.Enabled
		render(currentWorldId, entries)
		gui.Enabled = true
		if not wasOpen then
			UiKit.menuOpened("portal")
			UiKit.pop(panel, 0.85)
		end
	end)

	Net.event("PortalClose").OnClientEvent:Connect(function()
		gui.Enabled = false
		dismissed = false
	end)

	closeButton.Activated:Connect(close)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return PortalMenu
