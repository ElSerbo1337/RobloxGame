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

-- Rotation that turns a cylinder (axis = X) into a flat disc (axis = Y).
ToppingLook.FLAT = CFrame.Angles(0, 0, math.rad(90))

return ToppingLook
