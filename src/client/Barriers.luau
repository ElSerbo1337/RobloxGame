--!strict
-- World barriers on this client: a barrier the local player unlocked becomes see-through
-- and passable (only here, other players still bump into it). Near a locked barrier a
-- big tap-friendly button offers to unlock the world; the server decides.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local SignCulling = require(script.Parent.SignCulling)

local TAG = "WorldBarrier"
-- Show the unlock button within this many studs of a locked barrier (server allows 30).
local SHOW_DISTANCE = 22

local FONT = Enum.Font.FredokaOne
local DARK = Color3.fromRGB(60, 35, 20)
local GREEN = Color3.fromRGB(90, 200, 90)
local GRAY = Color3.fromRGB(170, 160, 150)

local Barriers = {}

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1.")))
	return (string.gsub(formatted, "^%.", ""))
end

local function unlockedWorlds(player: Player): { [string]: boolean }
	local set = {}
	local list = player:GetAttribute("UnlockedWorlds")
	if typeof(list) == "string" then
		for worldId in string.gmatch(list, "[^,]+") do
			set[worldId] = true
		end
	end
	return set
end

local function distanceTo(barrier: BasePart, position: Vector3): number
	local relative = barrier.CFrame:PointToObjectSpace(position)
	local half = barrier.Size / 2
	local clamped = Vector3.new(
		math.clamp(relative.X, -half.X, half.X),
		math.clamp(relative.Y, -half.Y, half.Y),
		math.clamp(relative.Z, -half.Z, half.Z)
	)
	return (relative - clamped).Magnitude
end

local function buildButton(player: Player): (ScreenGui, TextButton)
	local gui = Instance.new("ScreenGui")
	gui.Name = "BarrierUnlock"
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local button = Instance.new("TextButton")
	button.Name = "Unlock"
	button.AnchorPoint = Vector2.new(0.5, 1)
	-- Above the pizza fill bar, clear of the phone joystick (left) and jump button (right).
	button.Position = UDim2.new(0.5, 0, 1, -100)
	button.Size = UDim2.fromOffset(340, 96)
	button.BackgroundColor3 = GREEN
	button.AutoButtonColor = true
	button.Font = FONT
	button.TextScaled = true
	button.TextColor3 = DARK
	button.Text = ""
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 28)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = DARK
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = button
	button.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
	return gui, button
end

function Barriers.start()
	local player = Players.LocalPlayer
	local unlockWorld = Net.event("UnlockWorld")
	local gui, button = buildButton(player)
	local nearest: BasePart? = nil

	local function applyAccess(barrier: Instance)
		if not barrier:IsA("BasePart") then
			return
		end
		local open = unlockedWorlds(player)[barrier:GetAttribute("WorldId") :: string] == true
		barrier.CanCollide = not open
		barrier.Transparency = if open then 1 else 0.2
		local priceSign = barrier:FindFirstChild("PriceSign")
		if priceSign and priceSign:IsA("BillboardGui") then
			SignCulling.setHidden(priceSign, "unlocked", open)
		end
	end

	local function applyAll()
		for _, barrier in CollectionService:GetTagged(TAG) do
			applyAccess(barrier)
		end
	end

	CollectionService:GetInstanceAddedSignal(TAG):Connect(applyAccess)
	player:GetAttributeChangedSignal("UnlockedWorlds"):Connect(applyAll)
	applyAll()

	button.Activated:Connect(function()
		if nearest then
			unlockWorld:FireServer(nearest:GetAttribute("WorldId"))
		end
	end)

	-- Show the button only near a barrier this player has not unlocked yet.
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local unlocked = unlockedWorlds(player)
		local found: BasePart? = nil
		if root then
			for _, barrier in CollectionService:GetTagged(TAG) do
				if
					barrier:IsA("BasePart")
					and barrier:IsDescendantOf(Workspace)
					and not unlocked[barrier:GetAttribute("WorldId") :: string]
					and distanceTo(barrier, root.Position) <= SHOW_DISTANCE
				then
					found = barrier
					break
				end
			end
		end
		nearest = found
		gui.Enabled = found ~= nil
		if found then
			local price = (found:GetAttribute("UnlockPrice") :: number?) or 0
			local coins = (player:GetAttribute("Coins") :: number?) or 0
			button.Text = `🔓 {found:GetAttribute("WorldName")} freischalten\n{formatNumber(price)} Münzen`
			button.BackgroundColor3 = if coins >= price then GREEN else GRAY
		end
	end)

	-- Same scaling as the HUD, so the button stays big on phones and not huge on monitors.
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = gui
	local function rescale()
		local camera = Workspace.CurrentCamera
		if camera then
			local size = camera.ViewportSize
			uiScale.Scale = math.clamp(math.min(size.X / 1100, size.Y / 650), 0.8, 1.4)
		end
	end
	rescale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
end

return Barriers
