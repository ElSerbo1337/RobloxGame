--!strict
-- Imported 3D models (Blender, see tools/blender/build_models.py and assets/models).
-- Models are imported once in Studio into ReplicatedStorage.GameAssets.Models (see
-- docs/pc-todo.md, #15). Rojo leaves that folder alone, it is saved with the place.
-- Every function here falls back gracefully: if a model is missing, nothing happens
-- and the callers keep their simple placeholder parts.
-- Models may also sit in subfolders of Models (e.g. Models/Pets, Models/Deco).
-- Pets (tools/blender/build_pets.py) carry their colour in the part name instead of a
-- palette entry: "Pet_F2D49B" or "Pet_FF7A1A_Neon" (materials: Neon, Glass, Metal).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(script.Parent.GameConfig)

local ASSETS_FOLDER = "GameAssets"
local MODELS_FOLDER = "Models"

-- Part name -> look. The Blender script names every mesh part after its colour,
-- so the look never depends on how Studio imported the materials.
-- Keep in sync with COLORS in tools/blender/build_models.py.
local PALETTE: { [string]: { color: Color3, material: Enum.Material } } = {
	-- Salami (#24): wine red with cream fat bits and a thin darker casing.
	Meat = { color = Color3.fromRGB(150, 28, 46), material = Enum.Material.SmoothPlastic },
	Fat = { color = Color3.fromRGB(246, 228, 196), material = Enum.Material.SmoothPlastic },
	Casing = { color = Color3.fromRGB(98, 22, 34), material = Enum.Material.SmoothPlastic },
	Cap = { color = Color3.fromRGB(214, 168, 120), material = Enum.Material.SmoothPlastic },
	Stem = { color = Color3.fromRGB(252, 242, 222), material = Enum.Material.SmoothPlastic },
	Cheese = { color = Color3.fromRGB(255, 250, 236), material = Enum.Material.SmoothPlastic },
	Basil = { color = Color3.fromRGB(60, 160, 60), material = Enum.Material.SmoothPlastic },
	Dough = { color = Color3.fromRGB(240, 190, 105), material = Enum.Material.SmoothPlastic },
	Crust = { color = Color3.fromRGB(214, 140, 60), material = Enum.Material.SmoothPlastic },
	Sauce = { color = Color3.fromRGB(214, 52, 34), material = Enum.Material.SmoothPlastic },
	Melt = { color = Color3.fromRGB(255, 214, 92), material = Enum.Material.SmoothPlastic },
	Stone = { color = Color3.fromRGB(186, 176, 166), material = Enum.Material.Slate },
	Dome = { color = Color3.fromRGB(226, 112, 62), material = Enum.Material.SmoothPlastic },
	Arch = { color = Color3.fromRGB(150, 78, 58), material = Enum.Material.SmoothPlastic },
	Mouth = { color = Color3.fromRGB(52, 26, 18), material = Enum.Material.SmoothPlastic },
	Glow = { color = Color3.fromRGB(255, 150, 40), material = Enum.Material.Neon },
	Chimney = { color = Color3.fromRGB(150, 78, 58), material = Enum.Material.SmoothPlastic },
	Wood = { color = Color3.fromRGB(150, 96, 52), material = Enum.Material.Wood },
	Leaves = { color = Color3.fromRGB(96, 196, 82), material = Enum.Material.SmoothPlastic },
	LeavesLight = { color = Color3.fromRGB(140, 220, 96), material = Enum.Material.SmoothPlastic },
	Berry = { color = Color3.fromRGB(235, 60, 70), material = Enum.Material.SmoothPlastic },
	-- Worlds 2-7 (#16)
	Hay = { color = Color3.fromRGB(232, 196, 96), material = Enum.Material.SmoothPlastic },
	Twine = { color = Color3.fromRGB(176, 128, 60), material = Enum.Material.SmoothPlastic },
	Petal = { color = Color3.fromRGB(255, 206, 40), material = Enum.Material.SmoothPlastic },
	Seed = { color = Color3.fromRGB(110, 70, 35), material = Enum.Material.SmoothPlastic },
	BarnRed = { color = Color3.fromRGB(204, 62, 52), material = Enum.Material.SmoothPlastic },
	Gable = { color = Color3.fromRGB(204, 62, 52), material = Enum.Material.SmoothPlastic },
	DoorCross = { color = Color3.fromRGB(204, 62, 52), material = Enum.Material.SmoothPlastic },
	Trim = { color = Color3.fromRGB(250, 246, 236), material = Enum.Material.SmoothPlastic },
	Pole = { color = Color3.fromRGB(250, 246, 236), material = Enum.Material.SmoothPlastic },
	Roof = { color = Color3.fromRGB(92, 72, 64), material = Enum.Material.SmoothPlastic },
	PalmTrunk = { color = Color3.fromRGB(196, 150, 92), material = Enum.Material.Wood },
	PalmLeaf = { color = Color3.fromRGB(64, 182, 84), material = Enum.Material.SmoothPlastic },
	Coconut = { color = Color3.fromRGB(120, 80, 45), material = Enum.Material.SmoothPlastic },
	Canvas = { color = Color3.fromRGB(240, 84, 84), material = Enum.Material.SmoothPlastic },
	Pine = { color = Color3.fromRGB(44, 128, 96), material = Enum.Material.SmoothPlastic },
	Snow = { color = Color3.fromRGB(246, 250, 255), material = Enum.Material.SmoothPlastic },
	Ice = { color = Color3.fromRGB(150, 214, 255), material = Enum.Material.Glass },
	Coal = { color = Color3.fromRGB(42, 42, 48), material = Enum.Material.SmoothPlastic },
	Carrot = { color = Color3.fromRGB(255, 140, 40), material = Enum.Material.SmoothPlastic },
	-- Volcano (#24): lighter rock so the world stays readable.
	Basalt = { color = Color3.fromRGB(112, 86, 80), material = Enum.Material.Basalt },
	Lava = { color = Color3.fromRGB(255, 128, 36), material = Enum.Material.Neon },
	Charcoal = { color = Color3.fromRGB(88, 66, 60), material = Enum.Material.SmoothPlastic },
	CandyPink = { color = Color3.fromRGB(255, 92, 162), material = Enum.Material.SmoothPlastic },
	CandyWhite = { color = Color3.fromRGB(255, 246, 250), material = Enum.Material.SmoothPlastic },
	Stick = { color = Color3.fromRGB(255, 246, 250), material = Enum.Material.SmoothPlastic },
	CandyRed = { color = Color3.fromRGB(232, 42, 62), material = Enum.Material.SmoothPlastic },
	Wrapper = { color = Color3.fromRGB(120, 200, 242), material = Enum.Material.SmoothPlastic },
	Frosting = { color = Color3.fromRGB(255, 182, 216), material = Enum.Material.SmoothPlastic },
	MoonRock = { color = Color3.fromRGB(152, 152, 168), material = Enum.Material.Slate },
	Base = { color = Color3.fromRGB(152, 152, 168), material = Enum.Material.Slate },
	Crater = { color = Color3.fromRGB(112, 112, 128), material = Enum.Material.Slate },
	PlanetBody = { color = Color3.fromRGB(150, 110, 232), material = Enum.Material.SmoothPlastic },
	PlanetRing = { color = Color3.fromRGB(255, 202, 120), material = Enum.Material.SmoothPlastic },
	Crystal = { color = Color3.fromRGB(110, 255, 212), material = Enum.Material.Neon },
	Hull = { color = Color3.fromRGB(240, 240, 246), material = Enum.Material.SmoothPlastic },
	Fin = { color = Color3.fromRGB(232, 62, 62), material = Enum.Material.SmoothPlastic },
	-- Stations (#28): phone, delivery van, portal, shop stand
	PhoneRed = { color = Color3.fromRGB(220, 50, 45), material = Enum.Material.SmoothPlastic },
	Dial = { color = Color3.fromRGB(252, 242, 222), material = Enum.Material.SmoothPlastic },
	DialHoles = { color = Color3.fromRGB(60, 35, 20), material = Enum.Material.SmoothPlastic },
	Receiver = { color = Color3.fromRGB(60, 35, 20), material = Enum.Material.SmoothPlastic },
	Cord = { color = Color3.fromRGB(60, 35, 20), material = Enum.Material.SmoothPlastic },
	Brass = { color = Color3.fromRGB(232, 184, 72), material = Enum.Material.SmoothPlastic },
	VanBody = { color = Color3.fromRGB(255, 248, 230), material = Enum.Material.SmoothPlastic },
	VanRed = { color = Color3.fromRGB(230, 70, 50), material = Enum.Material.SmoothPlastic },
	VanStripe = { color = Color3.fromRGB(255, 150, 40), material = Enum.Material.SmoothPlastic },
	Windows = { color = Color3.fromRGB(150, 214, 255), material = Enum.Material.Glass },
	Lamp = { color = Color3.fromRGB(255, 236, 150), material = Enum.Material.Neon },
	Grille = { color = Color3.fromRGB(50, 45, 45), material = Enum.Material.SmoothPlastic },
	Tire = { color = Color3.fromRGB(50, 45, 45), material = Enum.Material.SmoothPlastic },
	Hubcap = { color = Color3.fromRGB(200, 200, 210), material = Enum.Material.SmoothPlastic },
	PizzaBox = { color = Color3.fromRGB(222, 178, 118), material = Enum.Material.SmoothPlastic },
	BoxLogo = { color = Color3.fromRGB(214, 52, 34), material = Enum.Material.SmoothPlastic },
	LogoDots = { color = Color3.fromRGB(255, 214, 92), material = Enum.Material.SmoothPlastic },
	ArchStone = { color = Color3.fromRGB(170, 160, 178), material = Enum.Material.Slate },
	Keystone = { color = Color3.fromRGB(232, 184, 72), material = Enum.Material.SmoothPlastic },
	-- Default colour; the portal recolours it to its world's colour (GameConfig worlds[].color).
	PortalGlow = { color = Color3.fromRGB(255, 150, 60), material = Enum.Material.Neon },
	CounterTop = { color = Color3.fromRGB(250, 235, 200), material = Enum.Material.SmoothPlastic },
	CounterPanels = { color = Color3.fromRGB(220, 60, 50), material = Enum.Material.SmoothPlastic },
	Posts = { color = Color3.fromRGB(150, 96, 52), material = Enum.Material.Wood },
	AwningRed = { color = Color3.fromRGB(220, 60, 50), material = Enum.Material.Fabric },
	AwningWhite = { color = Color3.fromRGB(255, 250, 240), material = Enum.Material.Fabric },
	SignBoard = { color = Color3.fromRGB(250, 235, 200), material = Enum.Material.SmoothPlastic },
	SignCrust = { color = Color3.fromRGB(214, 140, 60), material = Enum.Material.SmoothPlastic },
	SignSauce = { color = Color3.fromRGB(214, 52, 34), material = Enum.Material.SmoothPlastic },
	SignSalami = { color = Color3.fromRGB(190, 38, 42), material = Enum.Material.SmoothPlastic },
	SignText = { color = Color3.fromRGB(220, 60, 50), material = Enum.Material.SmoothPlastic },
	CounterOven = { color = Color3.fromRGB(226, 112, 62), material = Enum.Material.SmoothPlastic },
	CounterOvenGlow = { color = Color3.fromRGB(255, 150, 40), material = Enum.Material.Neon },
	CounterBoxes = { color = Color3.fromRGB(222, 178, 118), material = Enum.Material.SmoothPlastic },
}

-- Materials a pet part can ask for with a name suffix ("Pet_FF7A1A_Neon").
local PET_MATERIALS: { [string]: Enum.Material } = {
	Neon = Enum.Material.Neon,
	Glass = Enum.Material.Glass,
	Metal = Enum.Material.SmoothPlastic,
}

-- Extra turn around the up axis per model, in degrees, in case Studio imported a
-- model facing the wrong way (front must face -Z). Models whose front matters only.
-- Blender's front (+Y) arrives in Studio as +Z, so models built facing +Y need 180.
local YAW: { [string]: number } = {
	-- The imported oven's mouth faced +Z (away from the sell zone) in Studio.
	PizzaOven = 180,
	Barn = 180,
	Snowman = 180,
	-- Stations (#28), all built facing Blender +Y.
	Telephone = 180,
	DeliveryVan = 180,
	PortalArch = 180,
	PizzaStand = 180,
}
-- Same fix for every pet (all pets are built facing Blender +Y, like the oven).
local PET_YAW = 180

local ModelLibrary = {}

-- Scaled, recoloured copies ready to clone, per model name and size.
local prepared: { [string]: Model } = {}

local function source(name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER)
	local models = assets and assets:FindFirstChild(MODELS_FOLDER)
	if models == nil then
		return nil
	end
	local direct = models:FindFirstChild(name)
	if direct then
		return direct
	end
	-- Models sorted into subfolders (Models/Pets/...): only folders are searched, so a
	-- part called like a model (e.g. "Leaves" inside "Tree") never counts.
	for _, child in models:GetDescendants() do
		if child.Name == name and child.Parent and child.Parent:IsA("Folder") then
			return child
		end
	end
	return nil
end

-- Colour and material of a part: palette entry by name, or the colour in a pet part
-- name ("Pet_F2D49B_Neon"). Studio may add suffixes like ".001"; they are ignored.
local function lookFor(partName: string): { color: Color3, material: Enum.Material }?
	local base = string.match(partName, "^[^%.]+") or partName
	local palette = PALETTE[base]
	if palette then
		return palette
	end
	local hex = string.match(base, "^Pet_(%x%x%x%x%x%x)")
	if hex == nil then
		return nil
	end
	local suffix = string.match(base, "^Pet_%x+_(%a+)$")
	return {
		color = Color3.fromHex(hex),
		material = (suffix and PET_MATERIALS[suffix]) or Enum.Material.SmoothPlastic,
	}
end

local function isPet(name: string): boolean
	return GameConfig.pets[name] ~= nil
end

function ModelLibrary.has(name: string): boolean
	return source(name) ~= nil
end

-- A copy of the model, recoloured, as wide (X/Z) as `width` studs (with `fitAll`: as
-- big in its largest dimension), with its pivot at the bottom center. Nil if the
-- model wasn't imported.
local function prepare(name: string, width: number, fitAll: boolean?): Model?
	local key = `{name}@{width}{if fitAll then "a" else ""}`
	if prepared[key] then
		return prepared[key]
	end
	local original = source(name)
	if original == nil then
		return nil
	end

	local model: Model
	if original:IsA("Model") then
		model = original:Clone()
	elseif original:IsA("BasePart") then
		model = Instance.new("Model")
		original:Clone().Parent = model
	else
		return nil
	end
	model.Name = name

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			local look = lookFor(descendant.Name)
			if look then
				descendant.Color = look.color
				descendant.Material = look.material
				descendant.Transparency = if look.material == Enum.Material.Glass then 0.35 else 0
				descendant.Reflectance = if string.find(descendant.Name, "_Metal") then 0.25 else 0
				for _, child in descendant:GetChildren() do
					if child:IsA("SurfaceAppearance") then
						child:Destroy()
					end
				end
			end
		end
	end

	local _, size = model:GetBoundingBox()
	local widest = if fitAll then math.max(size.X, size.Y, size.Z) else math.max(size.X, size.Z)
	if widest <= 0 then
		return nil
	end
	model:ScaleTo(model:GetScale() * width / widest)

	-- Pivot = bottom center, facing -Z (with the per-model yaw fix).
	local box, boxSize = model:GetBoundingBox()
	local yaw = CFrame.Angles(0, math.rad(YAW[name] or (if isPet(name) then PET_YAW else 0)), 0)
	model.WorldPivot = CFrame.new(box.Position - Vector3.new(0, boxSize.Y / 2, 0)) * yaw:Inverse()

	prepared[key] = model
	return model
end

-- Places a copy of the model with its bottom center at `cframe` (Y axis up).
-- Parts are anchored; with `collide` players bump into it. Nil if not imported.
function ModelLibrary.place(name: string, width: number, cframe: CFrame, parent: Instance, collide: boolean?): Model?
	local template = prepare(name, width)
	if template == nil then
		return nil
	end
	local model = template:Clone()
	model:PivotTo(cframe)
	if collide then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = true
			end
		end
	end
	model.Parent = parent
	return model
end

-- Replaces a placeholder built from parts with the model (stations, #28): places the
-- model inside `container` and makes the placeholder parts named in `hide` invisible.
-- Hidden parts keep their collision, attributes and children (signs, particles), so the
-- station works exactly as before. Changes nothing and returns nil if not imported.
function ModelLibrary.dressPlaceholder(
	container: Instance,
	name: string,
	width: number,
	cframe: CFrame,
	hide: { string }
): Model?
	local model = ModelLibrary.place(name, width, cframe, container)
	if model == nil then
		return nil
	end
	model.Name = "Look"
	local hidden: { [string]: boolean } = {}
	for _, partName in hide do
		hidden[partName] = true
	end
	for _, child in container:GetChildren() do
		if child:IsA("BasePart") and hidden[child.Name] then
			child.Transparency = 1
			child.CastShadow = false
		end
	end
	return model
end

-- Rotation that turns a cylinder disc (axis = X, see ToppingLook.FLAT) upright.
local DISC_UP = CFrame.Angles(0, 0, math.rad(-90))

-- Dresses a placeholder disc (cylinder, axis X = up) with the model: the model sits on
-- the disc's bottom, the disc becomes invisible but stays the part the game works with
-- (attributes, clicks, distance checks). Anchored discs get anchored model parts,
-- loose discs (the pizza in the hand) get welded ones. Set the disc's CFrame first.
-- Returns false (and changes nothing) if the model wasn't imported.
function ModelLibrary.dressDisc(disc: BasePart, name: string, width: number?): boolean
	local template = prepare(name, width or disc.Size.Y)
	if template == nil then
		return false
	end
	local model = template:Clone()
	model.Name = "Look"
	local upright = disc.CFrame * DISC_UP
	model:PivotTo(upright * CFrame.new(0, -disc.Size.X / 2, 0))
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not disc.Anchored then
			descendant.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = disc
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	model.Parent = disc
	disc.Transparency = 1
	return true
end

-- For effects that move a dressed disc (MagnetPull): welds the anchored model parts
-- of a copy to it, so moving the disc moves the model. Call once the copy is in the
-- Workspace at its final starting spot.
function ModelLibrary.weldLook(disc: BasePart)
	local look = disc:FindFirstChild("Look")
	if look == nil then
		return
	end
	for _, descendant in look:GetDescendants() do
		if descendant:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = disc
			weld.Part1 = descendant
			weld.Parent = descendant
			descendant.Anchored = false
		end
	end
end

-- A loose copy of a pet model (anchored, not collidable, not parented) whose largest
-- dimension is `size` studs, pivot at its bottom center facing -Z. Nil if not imported.
function ModelLibrary.pet(petId: string, size: number): Model?
	local template = prepare(petId, size, true)
	return if template then template:Clone() else nil
end

-- A ViewportFrame (fills its parent) showing the model from the front, slightly from
-- above and from the right, like the preview renders. Works without uploading images:
-- it only needs the imported model. Nil if the model wasn't imported.
function ModelLibrary.viewport(name: string): ViewportFrame?
	local template = prepare(name, 4, true)
	if template == nil then
		return nil
	end
	local frame = Instance.new("ViewportFrame")
	frame.Name = "ModelView"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Ambient = Color3.fromRGB(200, 200, 200)
	frame.LightColor = Color3.fromRGB(255, 250, 240)
	frame.LightDirection = Vector3.new(-0.5, -1, 0.6)

	local model = template:Clone()
	model:PivotTo(CFrame.new())
	model.Parent = frame
	local box, boxSize = model:GetBoundingBox()

	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	-- Model front is -Z: look from -Z, a bit from the right and from above.
	local direction = Vector3.new(0.4, 0.3, -1).Unit
	local distance = (boxSize.Magnitude / 2) / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
	camera.CFrame = CFrame.lookAt(box.Position + direction * distance, box.Position)
	camera.Parent = frame
	frame.CurrentCamera = camera
	return frame
end

return ModelLibrary
