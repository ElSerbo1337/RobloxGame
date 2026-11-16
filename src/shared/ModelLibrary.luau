--!strict
-- Imported 3D models (Blender, see tools/blender/build_models.py and assets/models).
-- Models are imported once in Studio into ReplicatedStorage.GameAssets.Models (see
-- docs/pc-todo.md, #15). Rojo leaves that folder alone, it is saved with the place.
-- Every function here falls back gracefully: if a model is missing, nothing happens
-- and the callers keep their simple placeholder parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ASSETS_FOLDER = "GameAssets"
local MODELS_FOLDER = "Models"

-- Part name -> look. The Blender script names every mesh part after its colour,
-- so the look never depends on how Studio imported the materials.
-- Keep in sync with COLORS in tools/blender/build_models.py.
local PALETTE: { [string]: { color: Color3, material: Enum.Material } } = {
	Meat = { color = Color3.fromRGB(190, 38, 42), material = Enum.Material.SmoothPlastic },
	Fat = { color = Color3.fromRGB(255, 196, 186), material = Enum.Material.SmoothPlastic },
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
}

-- Extra turn around the up axis per model, in degrees, in case Studio imported a
-- model facing the wrong way (front must face -Z). Only PizzaOven has a front.
local YAW: { [string]: number } = {
	PizzaOven = 0,
}

local ModelLibrary = {}

-- Scaled, recoloured copies ready to clone, per model name and size.
local prepared: { [string]: Model } = {}

local function source(name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER)
	local models = assets and assets:FindFirstChild(MODELS_FOLDER)
	return models and models:FindFirstChild(name)
end

function ModelLibrary.has(name: string): boolean
	return source(name) ~= nil
end

-- A copy of the model, recoloured, as wide (X/Z) as `width` studs, with its pivot at
-- the bottom center. Nil if the model wasn't imported.
local function prepare(name: string, width: number): Model?
	local key = `{name}@{width}`
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
			-- Studio may add suffixes like "Meat.001"; the part name before the dot counts.
			local look = PALETTE[string.match(descendant.Name, "^[^%.]+") or descendant.Name]
			if look then
				descendant.Color = look.color
				descendant.Material = look.material
				for _, child in descendant:GetChildren() do
					if child:IsA("SurfaceAppearance") then
						child:Destroy()
					end
				end
			end
		end
	end

	local _, size = model:GetBoundingBox()
	local widest = math.max(size.X, size.Z)
	if widest <= 0 then
		return nil
	end
	model:ScaleTo(model:GetScale() * width / widest)

	-- Pivot = bottom center, facing -Z (with the per-model yaw fix).
	local box, boxSize = model:GetBoundingBox()
	local yaw = CFrame.Angles(0, math.rad(YAW[name] or 0), 0)
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

return ModelLibrary
