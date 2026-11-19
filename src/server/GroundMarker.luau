--!strict
-- Flat floor marking for a zone (#60): a thin, slightly see-through plate with a glowing
-- neon rim and a word written on top ("VERKAUFEN", "SHOP"). Purely visual: players walk
-- over it, clicks and the camera pass through. Zone detection keeps using the zone part.

local GroundMarker = {}

-- Heights above the ground surface: above every thin ground layer from IslandPlan (#46,
-- highest top 0.5 for streams), rim slightly above the plate so no faces share a plane.
local PLATE_TOP = 0.65
local PLATE_THICKNESS = 0.1
local RIM_TOP = 0.72
local RIM_THICKNESS = 0.12
local RIM_WIDTH = 0.5
local PIXELS_PER_STUD = 25

local CREAM = Color3.fromRGB(255, 248, 230)
local DARK = Color3.fromRGB(60, 35, 20)

local function decal(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- Builds the marking centred on `groundCf` (on the ground surface, -Z = side players
-- come from, so the text reads from there) with footprint `width` (X) × `depth` (Z).
function GroundMarker.build(
	parent: Instance,
	groundCf: CFrame,
	width: number,
	depth: number,
	color: Color3,
	text: string
): Model
	local model = Instance.new("Model")
	model.Name = "GroundMarker"

	-- Turned by 180° so the SurfaceGui's top edge points away from the players.
	local plate = decal({
		Name = "MarkerPlate",
		Size = Vector3.new(width, PLATE_THICKNESS, depth),
		CFrame = groundCf * CFrame.new(0, PLATE_TOP - PLATE_THICKNESS / 2, 0) * CFrame.Angles(0, math.pi, 0),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.35,
		Parent = model,
	})

	local rimColor = color:Lerp(Color3.new(1, 1, 1), 0.45)
	local y = RIM_TOP - RIM_THICKNESS / 2
	for _, edge in
		{
			{ x = 0, z = (depth - RIM_WIDTH) / 2, sx = width, sz = RIM_WIDTH },
			{ x = 0, z = -(depth - RIM_WIDTH) / 2, sx = width, sz = RIM_WIDTH },
			{ x = (width - RIM_WIDTH) / 2, z = 0, sx = RIM_WIDTH, sz = depth - 2 * RIM_WIDTH },
			{ x = -(width - RIM_WIDTH) / 2, z = 0, sx = RIM_WIDTH, sz = depth - 2 * RIM_WIDTH },
		}
	do
		decal({
			Name = "MarkerRim",
			Size = Vector3.new(edge.sx, RIM_THICKNESS, edge.sz),
			CFrame = groundCf * CFrame.new(edge.x, y, edge.z),
			Color = rimColor,
			Material = Enum.Material.Neon,
			Parent = model,
		})
	end

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Adornee = plate
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.85, 0.5)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = CREAM
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = DARK
	stroke.Thickness = 4
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = plate

	model.Parent = parent
	return model
end

return GroundMarker
