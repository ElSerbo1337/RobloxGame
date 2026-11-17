--!strict
-- Eggs in the world: builds the egg stands, puts each egg (model or placeholder) on its
-- stand and opens eggs on request.
-- The client only asks ("OpenEgg"); the server checks the distance and lets the game
-- rules decide (price, chances, "3 öffnen" bought). The drawn pets are sent back for the
-- hatch animation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)

export type EggSpot = {
	eggId: string,
	-- Drum of the stand from buildStand (cylinder lying on its side, height along X).
	stand: BasePart,
}

-- Players must stand this close to the egg to open it (preview shows up a bit earlier).
local OPEN_DISTANCE = 18
-- One egg per this many seconds per player, so the hatch animation can finish.
local OPEN_COOLDOWN = 2.5

local EggService = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- Egg stand (#29): stone base, drum and trim in the egg's accent colour, a sign with name
-- and price on the front (-Z). With the imported EggStand model the parts below only
-- give collision and the sign text; the model is the look. Sizes match the model in
-- tools/blender/build_eggs.py (2 x 2 units footprint = STAND_WIDTH studs).
local STAND_WIDTH = 10
local STAND_HEIGHT = 2.2 -- top plate, where the egg sits
local DRUM_WIDTH = 8.6
local BASE_HEIGHT = 0.6
local SIGN_SIZE = Vector3.new(7.8, 1.7, 0.1)
local SIGN_OFFSET = CFrame.new(0, 1.3, -4.45) -- relative to the stand's ground center
-- Egg: as wide as the old placeholder ball, 1.3 times as tall.
local EGG_WIDTH = 5.5

local CREAM = Color3.fromRGB(255, 248, 230)
local DARK = Color3.fromRGB(60, 35, 20)

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1.")))
	return (string.gsub(formatted, "^%.", ""))
end

type Look = { color: Color3, accent: Color3, glow: boolean }

local function lookOf(eggId: string?): Look
	local egg = eggId and GameConfig.eggs[eggId]
	local look = egg and egg.look
	if look == nil then
		return { color = Color3.fromRGB(255, 245, 220), accent = Color3.fromRGB(245, 140, 50), glow = false }
	end
	return { color = Color3.fromHex(look.color), accent = Color3.fromHex(look.accent), glow = look.glow == true }
end

-- The trim colour of a stand: the accent, or the base colour for white accents.
local function trimColor(eggId: string?): Color3
	local look = lookOf(eggId)
	local _, saturation = look.accent:ToHSV()
	return if saturation < 0.15 then look.color else look.accent
end

local function buildSign(parent: Instance, ground: Vector3, eggId: string?, visible: boolean)
	local egg = eggId and GameConfig.eggs[eggId]
	local board = part({
		Name = "Sign",
		Size = SIGN_SIZE,
		CFrame = CFrame.new(ground) * SIGN_OFFSET,
		Color = CREAM,
		Material = Enum.Material.SmoothPlastic,
		Transparency = if visible then 0 else 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = parent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.3
	gui.MaxDistance = 150
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = DARK
	label.Text = if egg then `{egg.displayName}\n💰 {formatNumber(egg.price)}` else "Ei"
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label
end

-- Builds the egg stand for `eggId` standing on `ground`, front (sign) facing -Z.
-- Returns the drum: a cylinder lying on its side (height along X), its top is where
-- the egg goes (attribute EggId). Used for world 1 and by WorldMap for later worlds.
function EggService.buildStand(parent: Instance, ground: Vector3, eggId: string?): BasePart
	local folder = Instance.new("Model")
	folder.Name = "EggStandLook"
	local trim = trimColor(eggId)
	local dressed = ModelLibrary.place("EggStand", STAND_WIDTH, CFrame.new(ground), folder) ~= nil
	if dressed then
		for _, descendant in folder:GetDescendants() do
			if descendant:IsA("BasePart") and string.match(descendant.Name, "^StandTrim") then
				descendant.Color = trim
			end
		end
	else
		-- Placeholder parts in the same shape as the model.
		part({
			Name = "Base",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(BASE_HEIGHT, STAND_WIDTH, STAND_WIDTH),
			CFrame = CFrame.new(ground + Vector3.new(0, BASE_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(186, 176, 166),
			Material = Enum.Material.SmoothPlastic,
			Parent = folder,
		})
		part({
			Name = "Trim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, DRUM_WIDTH + 0.4, DRUM_WIDTH + 0.4),
			CFrame = CFrame.new(ground + Vector3.new(0, STAND_HEIGHT - 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = trim,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = folder,
		})
	end
	buildSign(folder, ground, eggId, not dressed)
	folder.Parent = parent

	local stand = part({
		Name = "EggStand",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(STAND_HEIGHT, DRUM_WIDTH, DRUM_WIDTH),
		CFrame = CFrame.new(ground + Vector3.new(0, STAND_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 244, 222),
		Material = Enum.Material.SmoothPlastic,
		Transparency = if dressed then 1 else 0,
		Parent = parent,
	})
	stand:SetAttribute("EggId", eggId)
	return stand
end

-- Egg standing on `ground`: the imported model (assets/models/eggs) if there is one,
-- otherwise a ball in the egg's colour with three spots in its accent colour.
-- "Body" is always there (preview anchor, distance checks); with a model it's invisible.
local function buildEgg(eggId: string, ground: Vector3, parent: Instance): Model
	local look = lookOf(eggId)
	local model = Instance.new("Model")
	model.Name = eggId
	model:SetAttribute("EggId", eggId)

	local body = part({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(EGG_WIDTH, EGG_WIDTH, EGG_WIDTH),
		Position = ground + Vector3.new(0, EGG_WIDTH * 0.65, 0),
		Color = look.color,
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	-- Stretch the ball into an egg shape.
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1.3, 1)
	mesh.Parent = body

	if ModelLibrary.place(eggId, EGG_WIDTH, CFrame.new(ground), model) then
		body.Transparency = 1
	else
		for i, offset in { Vector3.new(1.6, 1, -2), Vector3.new(-2.2, -0.6, -1.2), Vector3.new(0.4, 2.4, 2.2) } do
			part({
				Name = `Spot{i}`,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.4, 1.4, 1.4),
				Position = body.Position + offset * 0.95,
				Color = look.accent,
				Material = if look.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic,
				CanCollide = false,
				Parent = model,
			})
		end
	end

	model.PrimaryPart = body
	model.Parent = parent
	return model
end

function EggService.start(spots: { EggSpot })
	local folder = Instance.new("Folder")
	folder.Name = "Eggs"
	local eggs: { [string]: Model } = {}
	for _, spot in spots do
		if GameConfig.eggs[spot.eggId] == nil then
			warn(`[EggService] unknown egg "{spot.eggId}"`)
			continue
		end
		local top = spot.stand.Position + Vector3.new(0, spot.stand.Size.X / 2, 0)
		eggs[spot.eggId] = buildEgg(spot.eggId, top, folder)
	end
	folder.Parent = Workspace

	local notify = Net.event("Notify")
	local eggOpened = Net.event("EggOpened")
	local rng = Random.new()
	local lastOpen: { [Player]: number } = {}

	Net.event("OpenEgg").OnServerEvent:Connect(function(player: Player, eggId: unknown, count: unknown)
		if type(eggId) ~= "string" or eggs[eggId] == nil then
			return
		end
		-- Missing count = 1 egg; the rules reject anything but 1 or the unlocked multi-open size.
		local eggCount = if count == nil then 1 else count
		if type(eggCount) ~= "number" then
			return
		end
		local now = os.clock()
		if lastOpen[player] and now - lastOpen[player] < OPEN_COOLDOWN then
			return
		end
		local state = PlayerStates.get(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if state == nil or root == nil then
			return
		end
		local egg = eggs[eggId]
		if (root.Position - egg:GetPivot().Position).Magnitude > OPEN_DISTANCE then
			notify:FireClient(player, "OutOfRange")
			return
		end

		local result = PlayerStates.rules.openEggs(state, eggId, eggCount, function()
			return rng:NextNumber()
		end)
		if not result.ok then
			notify:FireClient(player, result.reason)
			return
		end
		lastOpen[player] = now
		PlayerStates.set(player, result.state)
		local petIds = {}
		for _, pet in result.pets do
			table.insert(petIds, pet.petId)
		end
		eggOpened:FireClient(player, eggId, table.unpack(petIds))
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastOpen[player] = nil
	end)
end

return EggService
