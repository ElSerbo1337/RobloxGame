--!strict
-- Look of a golden topping (#94): gold glitter and a warm glow on a part. Used by the
-- client for golden toppings on the field (per player, see GoldenGlitter) and by the
-- server for golden toppings on the pizza in hand (PizzaVisual). Purely visual.

local GoldenLook = {}

GoldenLook.NAME = "GoldenGlitter"
-- Field topping parts with a gold roll carry this tag and the attribute GoldRoll; the
-- client shows the glitter where GoldRoll < its own GoldenChance attribute.
GoldenLook.FIELD_TAG = "GoldRoll"
GoldenLook.COLOR = Color3.fromRGB(255, 205, 60)

-- Built-in Roblox sparkle texture (no asset upload needed).
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

-- Adds the glitter to `part` (once). `scale` 1 = topping on the field (3.5 studs).
function GoldenLook.apply(part: BasePart, scale: number?)
	if part:FindFirstChild(GoldenLook.NAME) then
		return
	end
	local size = scale or 1
	local folder = Instance.new("Folder")
	folder.Name = GoldenLook.NAME

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = SPARKLE_TEXTURE
	sparkles.Color = ColorSequence.new(GoldenLook.COLOR, Color3.fromRGB(255, 250, 200))
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.7 * size),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Lifetime = NumberRange.new(0.6, 1.2)
	sparkles.Rate = 8
	sparkles.Speed = NumberRange.new(0.5 * size, 1.5 * size)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Rotation = NumberRange.new(0, 360)
	sparkles.RotSpeed = NumberRange.new(-90, 90)
	sparkles.Parent = part

	local light = Instance.new("PointLight")
	light.Color = GoldenLook.COLOR
	light.Brightness = 1.5
	light.Range = 6 * size
	light.Parent = part

	-- Keep track of what was added so `remove` takes exactly that away again.
	local sparklesRef = Instance.new("ObjectValue")
	sparklesRef.Name = "Sparkles"
	sparklesRef.Value = sparkles
	sparklesRef.Parent = folder
	local lightRef = Instance.new("ObjectValue")
	lightRef.Name = "Light"
	lightRef.Value = light
	lightRef.Parent = folder
	folder.Parent = part
end

function GoldenLook.remove(part: BasePart)
	local folder = part:FindFirstChild(GoldenLook.NAME)
	if folder == nil then
		return
	end
	for _, ref in folder:GetChildren() do
		if ref:IsA("ObjectValue") and ref.Value then
			ref.Value:Destroy()
		end
	end
	folder:Destroy()
end

return GoldenLook
