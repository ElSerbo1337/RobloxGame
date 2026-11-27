--!strict
-- Active bonuses at the top of the right HUD column (#75 slot LayoutOrder 1, above the
-- order card). One shared frame; each bonus gets a pill with BonusPills.pill(id, order).
-- Friends (#102, order 1) and weather (#105, order 2, client/WeatherFx). Hidden pills take no room.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Lang = require(script.Parent.Lang)
local UiKit = require(script.Parent.UiKit)

local BonusPills = {}

local FRIENDS_GREEN = Color3.fromRGB(110, 200, 90)

local holder: Frame? = nil
local function bonusFrame(): Frame
	if holder then
		return holder
	end
	local frame = Instance.new("Frame")
	frame.Name = "Bonuses"
	frame.LayoutOrder = 1
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(260, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	frame.Parent = UiKit.rightColumn()
	holder = frame
	return frame
end

-- A hidden pill (rounded, cream text on `color`, thick dark stroke like the HUD).
function BonusPills.pill(id: string, order: number, color: Color3): TextLabel
	local label = UiKit.label(bonusFrame(), "")
	label.Name = id
	label.LayoutOrder = order
	label.Visible = false
	label.Size = UDim2.fromOffset(0, 38)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.BackgroundTransparency = 0
	label.BackgroundColor3 = color
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = false
	label.TextSize = 22
	UiKit.corner(label, 19)
	UiKit.stroke(label)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = label
	return label
end

function BonusPills.start()
	local features = Features.new(GameConfig.features)
	if not features.enabled("friendsBonus") then
		return
	end
	local player = Players.LocalPlayer
	local friends = BonusPills.pill("Friends", 1, FRIENDS_GREEN)
	local function update()
		local count = player:GetAttribute("Friends") or 0
		local bonus = player:GetAttribute("FriendsBonus") or 0
		friends.Visible = count > 0 and bonus > 0
		if friends.Visible then
			local key = if count == 1 then "hud.friendsBonusOne" else "hud.friendsBonus"
			friends.Text = Lang.t(key, { count = count, percent = Lang.percent(bonus) })
		end
	end
	player:GetAttributeChangedSignal("Friends"):Connect(update)
	player:GetAttributeChangedSignal("FriendsBonus"):Connect(update)
	Lang.onLanguageChanged(update)
	update()
end

return BonusPills
