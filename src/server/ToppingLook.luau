--!strict
-- How each topping looks in the world and on the pizza (placeholder art until Blender models exist).

export type Look = { color: Color3, material: Enum.Material }

local LOOKS: { [string]: Look } = {
	Salami = { color = Color3.fromRGB(190, 45, 40), material = Enum.Material.SmoothPlastic },
	Mushroom = { color = Color3.fromRGB(215, 190, 160), material = Enum.Material.SmoothPlastic },
	Mozzarella = { color = Color3.fromRGB(250, 248, 235), material = Enum.Material.SmoothPlastic },
	-- World 2 (Bauernhof)
	Onion = { color = Color3.fromRGB(200, 140, 200), material = Enum.Material.SmoothPlastic },
	BellPepper = { color = Color3.fromRGB(60, 170, 60), material = Enum.Material.SmoothPlastic },
	Corn = { color = Color3.fromRGB(255, 215, 50), material = Enum.Material.SmoothPlastic },
	Ham = { color = Color3.fromRGB(240, 150, 160), material = Enum.Material.SmoothPlastic },
	-- World 3 (Strand)
	Tuna = { color = Color3.fromRGB(170, 95, 90), material = Enum.Material.SmoothPlastic },
	Shrimp = { color = Color3.fromRGB(255, 140, 100), material = Enum.Material.SmoothPlastic },
	Pineapple = { color = Color3.fromRGB(255, 225, 90), material = Enum.Material.SmoothPlastic },
	-- World 4 (Eisberge): frosty look
	FrozenPeas = { color = Color3.fromRGB(120, 210, 120), material = Enum.Material.Glass },
	Salmon = { color = Color3.fromRGB(250, 130, 95), material = Enum.Material.SmoothPlastic },
	IcebergLettuce = { color = Color3.fromRGB(190, 240, 170), material = Enum.Material.Glass },
}

local FALLBACK: Look = { color = Color3.fromRGB(255, 0, 255), material = Enum.Material.Neon }

local ToppingLook = {}

-- A flat disc lying on the ground (cylinder axis pointing up).
function ToppingLook.createDisc(toppingId: string, diameter: number, thickness: number): Part
	local look = LOOKS[toppingId] or FALLBACK
	local part = Instance.new("Part")
	part.Name = toppingId
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(thickness, diameter, diameter)
	part.Color = look.color
	part.Material = look.material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- A gem topping: a glowing turquoise diamond standing on its tip, bigger for more gems.
function ToppingLook.createGem(gems: number): Part
	local size = 1.6 + 0.4 * gems
	local part = Instance.new("Part")
	part.Name = "Gem"
	part.Size = Vector3.new(size, size, size)
	part.Color = Color3.fromRGB(60, 230, 255)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = part.Color
	light.Range = 10
	light.Brightness = 2
	light.Parent = part
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(200, 250, 255)
	sparkles.Parent = part
	return part
end

-- Tilts a cube so it stands on a corner, like a diamond.
ToppingLook.GEM_TILT = CFrame.Angles(math.rad(45), 0, math.rad(35))

-- Rotation that turns a cylinder (axis = X) into a flat disc (axis = Y).
ToppingLook.FLAT = CFrame.Angles(0, 0, math.rad(90))

return ToppingLook
