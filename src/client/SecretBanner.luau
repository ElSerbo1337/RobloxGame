--!strict
-- Global Secret pet banner (#81): when someone on any server hatches a Secret pet, the
-- server sends "SecretAnnounce" (player name, pet id). A wide pill in the Secret colour
-- slides in below the toasts (HudLayout.BELOW_TOP_BAR) with the pet's 3D icon and
-- "🌟 Name hat Pet geschlüpft! (Geheim)" in the player's language, then slides out.
-- Several announcements wait in a short queue (at most MAX_QUEUE, older ones dropped).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Lang = require(script.Parent.Lang)
local PetIcon = require(script.Parent.PetIcon)
local Sounds = require(script.Parent.Sounds)
local UiKit = require(script.Parent.UiKit)

local SHOW_SECONDS = 6
local MAX_QUEUE = 3
local WIDTH = 560
local MIN_WIDTH = 340
local HEIGHT = 64

local SecretBanner = {}

function SecretBanner.start()
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "SecretBanner"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	UiKit.autoScale(gui)

	local top = HudLayout.BELOW_TOP_BAR
	local banner = Instance.new("Frame")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, -HEIGHT - 20)
	-- Between the side bar and the right column (bonuses, order), so on phones the
	-- banner never covers them; never narrower than MIN_WIDTH.
	banner.Size = UDim2.new(1, -2 * (HudLayout.RIGHT_COLUMN_WIDTH + HudLayout.MARGIN + 8), 0, HEIGHT)
	banner.BackgroundColor3 = UiKit.rarityColor("Secret")
	banner.Visible = false
	UiKit.corner(banner, HEIGHT / 2)
	UiKit.stroke(banner, 4)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(MIN_WIDTH, HEIGHT)
	constraint.MaxSize = Vector2.new(WIDTH, HEIGHT)
	constraint.Parent = banner
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 90, 255)),
		ColorSequenceKeypoint.new(0.5, UiKit.rarityColor("Secret")),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 90, 255)),
	})
	gradient.Parent = banner
	banner.Parent = gui

	local icon = Instance.new("Frame")
	icon.Position = UDim2.fromOffset(8, 6)
	icon.Size = UDim2.fromOffset(HEIGHT - 12, HEIGHT - 12)
	icon.BackgroundColor3 = UiKit.CREAM
	UiKit.corner(icon, (HEIGHT - 12) / 2)
	UiKit.stroke(icon, 2)
	icon.Parent = banner

	local text = UiKit.label(banner, "")
	text.Position = UDim2.fromOffset(HEIGHT + 2, 6)
	text.Size = UDim2.new(1, -(HEIGHT + 18), 1, -12)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeColor3 = UiKit.DARK
	text.TextStrokeTransparency = 0

	gui.Parent = player:WaitForChild("PlayerGui")

	local queue: { { name: string, petId: string } } = {}
	local showing = false

	local function showNext()
		local item = table.remove(queue, 1)
		if item == nil then
			showing = false
			return
		end
		showing = true
		local pet = GameConfig.pets[item.petId]
		text.Text = Lang.t("announce.secret", { player = item.name, pet = Lang.name(pet) })
		for _, child in icon:GetChildren() do
			if not child:IsA("UICorner") and not child:IsA("UIStroke") then
				child:Destroy()
			end
		end
		PetIcon.show(icon, item.petId, 1.3)
		banner.Position = UDim2.new(0.5, 0, 0, -HEIGHT - 20)
		banner.Visible = true
		-- The hatching player already hears it in the hatch animation.
		if item.name ~= player.DisplayName then
			Sounds.play("Secret")
		end
		TweenService:Create(banner, TweenInfo.new(0.45, Enum.EasingStyle.Back), {
			Position = UDim2.new(0.5, 0, 0, top),
		}):Play()
		-- The colours run along the banner while it is shown.
		gradient.Offset = Vector2.new(-1, 0)
		TweenService:Create(gradient, TweenInfo.new(SHOW_SECONDS, Enum.EasingStyle.Linear), {
			Offset = Vector2.new(1, 0),
		}):Play()
		task.delay(SHOW_SECONDS, function()
			local out = TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
				Position = UDim2.new(0.5, 0, 0, -HEIGHT - 20),
			})
			out:Play()
			out.Completed:Wait()
			banner.Visible = false
			showNext()
		end)
	end

	Net.event("SecretAnnounce").OnClientEvent:Connect(function(name: unknown, petId: unknown)
		if type(name) ~= "string" or type(petId) ~= "string" then
			return
		end
		local pet = GameConfig.pets[petId]
		if pet == nil or pet.rarity ~= "Secret" then
			return
		end
		table.insert(queue, { name = name, petId = petId })
		while #queue > MAX_QUEUE do
			table.remove(queue, 1)
		end
		if not showing then
			showNext()
		end
	end)
end

return SecretBanner
