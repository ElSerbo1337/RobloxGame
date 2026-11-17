--!strict
-- New-player tutorial: a card under the coins tells the current step, a bouncing
-- arrow and a glowing line point at where to go. Only shows what the server
-- replicates (attributes TutorialStep, TutorialProgress, TutorialGoal, ...);
-- the steps move on through the real actions in the game rules.
-- Targets are tagged "TutorialTarget" by the server (see TutorialService).
-- The card has no buttons and does not block taps on the world.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)
local UiKit = require(script.Parent.UiKit)

local TAG = "TutorialTarget"
local ARROW_HEIGHT = 7
-- Seconds between searches for the nearest topping.
local RETARGET_SECONDS = 0.25
-- Gem toppings never go on the pizza, so the arrow skips them.
local GEM_TOPPING = GameConfig.gems.toppingId

local Tutorial = {}

local function stepText(stepId: string, progress: number, goal: number): string
	if stepId == "CollectToppings" then
		return `Sammle {goal} Beläge ein ({progress}/{goal}) – tippe sie an oder lauf mit Auto-Sammeln drüber!`
	elseif stepId == "SellPizza" then
		return "Lauf in die Zone am Ofen und verkaufe deine Pizza!"
	elseif stepId == "BuyUpgrade" then
		return "Kauf im Shop dein erstes Upgrade! Zu wenig Münzen? Sammeln und verkaufen."
	elseif stepId == "OpenEgg" then
		return "Öffne am Ei dein erstes Pet! Pets bringen mehr Münzen."
	end
	return ""
end

local function findTarget(stepId: string): Instance?
	for _, target in CollectionService:GetTagged(TAG) do
		if target:GetAttribute("TutorialStep") == stepId then
			return target
		end
	end
	return nil
end

-- Where the arrow should point: the target part, or the nearest topping in a folder.
local function targetPosition(target: Instance, from: Vector3?): Vector3?
	if target:IsA("BasePart") then
		return target.Position
	end
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, child in target:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= GEM_TOPPING then
			local distance = if from then (child.Position - from).Magnitude else 0
			if distance < bestDistance then
				best, bestDistance = child.Position, distance
			end
		end
	end
	return best
end

function Tutorial.start()
	local player = Players.LocalPlayer

	-- Card (top left under the Roblox menu, clear of messages and the egg preview)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Tutorial"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	UiKit.autoScale(gui)

	local card = Instance.new("Frame")
	card.Name = "Card"
	UiKit.place(card, "tutorialCard")
	card.BackgroundColor3 = UiKit.CREAM
	card.Active = false
	card.Visible = false
	UiKit.corner(card, 20)
	UiKit.stroke(card)
	card.Parent = gui

	local header = UiKit.label(card, "")
	header.Position = UDim2.fromOffset(16, 6)
	header.Size = UDim2.new(1, -32, 0, 26)
	header.TextColor3 = Color3.fromRGB(230, 120, 30)
	header.TextXAlignment = Enum.TextXAlignment.Left

	local body = UiKit.label(card, "")
	body.Position = UDim2.fromOffset(16, 34)
	body.Size = UDim2.new(1, -32, 1, -42)
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left

	gui.Parent = player:WaitForChild("PlayerGui")

	-- Arrow in the world: a bouncing marker above the target and a line from the player.
	local anchor = Instance.new("Attachment")
	anchor.Name = "TutorialTarget"
	anchor.Parent = Workspace.Terrain

	local marker = Instance.new("BillboardGui")
	marker.Name = "TutorialArrow"
	marker.Size = UDim2.fromOffset(90, 90)
	marker.AlwaysOnTop = true
	marker.LightInfluence = 0
	marker.Adornee = anchor
	marker.Enabled = false
	marker.ResetOnSpawn = false
	local arrow = UiKit.label(marker, "▼")
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.TextColor3 = UiKit.COIN
	arrow.TextStrokeColor3 = UiKit.DARK
	arrow.TextStrokeTransparency = 0
	marker.Parent = gui.Parent

	local beam = Instance.new("Beam")
	beam.Name = "TutorialLine"
	beam.Attachment1 = anchor
	beam.Color = ColorSequence.new(UiKit.COIN)
	beam.Transparency = NumberSequence.new(0.35)
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Width0 = 0.6
	beam.Width1 = 0.6
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = Workspace.Terrain

	local function rootPart(): BasePart?
		local character = player.Character
		return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	end

	local function attachBeam()
		local root = rootPart()
		if root == nil then
			return
		end
		local start = root:FindFirstChild("TutorialLineStart") :: Attachment?
		if start == nil then
			local newStart = Instance.new("Attachment")
			newStart.Name = "TutorialLineStart"
			newStart.Position = Vector3.new(0, -1.5, 0)
			newStart.Parent = root
			start = newStart
		end
		beam.Attachment0 = start
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart")
		attachBeam()
	end)
	attachBeam()

	local currentStep = ""
	local hideToken = 0

	local function update()
		local stepId = (player:GetAttribute("TutorialStep") :: string?) or ""
		local number = (player:GetAttribute("TutorialNumber") :: number?) or 0
		local total = (player:GetAttribute("TutorialTotal") :: number?) or 0
		local progress = (player:GetAttribute("TutorialProgress") :: number?) or 0
		local goal = (player:GetAttribute("TutorialGoal") :: number?) or 0

		if stepId == "" then
			if currentStep ~= "" then
				-- Just finished: say well done, then hide for good.
				header.Text = "Tutorial geschafft!"
				body.Text = "Viel Spaß beim Pizza-Belegen! Neue Welten warten hinter den Barrieren."
				UiKit.pop(card)
				hideToken += 1
				local myToken = hideToken
				task.delay(4, function()
					if hideToken == myToken then
						card.Visible = false
					end
				end)
			end
			currentStep = ""
			marker.Enabled = false
			beam.Enabled = false
			return
		end

		hideToken += 1
		card.Visible = true
		header.Text = `Tutorial – Schritt {number}/{total}`
		body.Text = stepText(stepId, progress, goal)
		if stepId ~= currentStep then
			UiKit.pop(card)
		end
		currentStep = stepId
	end

	for _, name in { "TutorialStep", "TutorialNumber", "TutorialTotal", "TutorialProgress", "TutorialGoal" } do
		player:GetAttributeChangedSignal(name):Connect(update)
	end
	update()

	-- Keep the arrow on the target (the nearest topping moves as toppings are taken).
	local sinceRetarget = math.huge
	local hasTarget = false
	RunService.Heartbeat:Connect(function(dt)
		if currentStep == "" then
			return
		end
		sinceRetarget += dt
		if sinceRetarget >= RETARGET_SECONDS then
			sinceRetarget = 0
			local target = findTarget(currentStep)
			local root = rootPart()
			local position = if target then targetPosition(target, root and root.Position) else nil
			hasTarget = position ~= nil
			if position then
				anchor.WorldPosition = position
			end
		end
		marker.Enabled = hasTarget
		beam.Enabled = hasTarget and beam.Attachment0 ~= nil
		marker.StudsOffset = Vector3.new(0, ARROW_HEIGHT + math.sin(os.clock() * 5) * 0.8, 0)
	end)
end

return Tutorial
