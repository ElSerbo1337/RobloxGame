--!strict
-- Live 3D icons for the side bar tiles (#75): a ViewportFrame with an imported model
-- (ModelLibrary, e.g. a pet or the portal arch) or, when the model is missing, a simple
-- shape built from a few parts (flask, gift box, calendar ...). The view is slightly
-- tilted and sways gently, so the tiles look alive. No image upload needed.
--
--   TileIcon.build(holder, { model = "DoughHamster", shape = "pet" })
--
-- Shapes: see TileIcon.SHAPES (add one there for a new menu).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)

export type Icon = { model: string?, shape: string? }

local TileIcon = {}

local SWAY_DEGREES = 14
local SWAY_SECONDS = 4
-- Slight tilt of every icon (camera roll), so the tiles do not look stiff.
local TILT_DEGREES = 10
local UPDATE_SECONDS = 1 / 20

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

type PartSpec = {
	shape: Enum.PartType?,
	size: Vector3,
	at: Vector3,
	color: Color3,
	turn: Vector3?, -- degrees
	material: Enum.Material?,
	transparency: number?,
}

local function addPart(model: Model, spec: PartSpec)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Shape = spec.shape or Enum.PartType.Block
	part.Size = spec.size
	part.Color = spec.color
	part.Material = spec.material or Enum.Material.SmoothPlastic
	part.Transparency = spec.transparency or 0
	local turn = spec.turn or Vector3.zero
	part.CFrame = CFrame.new(spec.at) * CFrame.Angles(math.rad(turn.X), math.rad(turn.Y), math.rad(turn.Z))
	part.Parent = model
end

local BALL = Enum.PartType.Ball
local CYLINDER = Enum.PartType.Cylinder
local CREAM = rgb(255, 248, 230)
local DARK = rgb(60, 35, 20)

-- Simple fallback shapes, about 4 studs big, front towards -Z.
TileIcon.SHAPES = {
	-- Chibi pet head: big round head, ears, shiny eyes, pink cheeks.
	pet = function(model: Model)
		local fur = rgb(242, 190, 120)
		addPart(model, { shape = BALL, size = Vector3.one * 3.4, at = Vector3.new(0, 1.7, 0), color = fur })
		for _, side in { -1, 1 } do
			addPart(
				model,
				{ shape = BALL, size = Vector3.one * 1.2, at = Vector3.new(side * 1.2, 3.2, 0.2), color = fur }
			)
			addPart(
				model,
				{ shape = BALL, size = Vector3.one * 0.6, at = Vector3.new(side * 0.6, 2, -1.5), color = DARK }
			)
			addPart(model, {
				shape = BALL,
				size = Vector3.one * 0.5,
				at = Vector3.new(side * 1, 1.3, -1.45),
				color = rgb(255, 150, 160),
			})
		end
	end,
	-- Round potion flask with neck and cork.
	potion = function(model: Model)
		addPart(model, {
			shape = BALL,
			size = Vector3.one * 3,
			at = Vector3.new(0, 1.5, 0),
			color = rgb(190, 110, 255),
			material = Enum.Material.Neon,
		})
		addPart(model, {
			shape = CYLINDER,
			size = Vector3.new(1.2, 1, 1),
			at = Vector3.new(0, 3.2, 0),
			color = rgb(200, 235, 255),
			turn = Vector3.new(0, 0, 90),
			material = Enum.Material.Glass,
			transparency = 0.2,
		})
		addPart(model, {
			shape = CYLINDER,
			size = Vector3.new(0.6, 1.1, 1.1),
			at = Vector3.new(0, 4, 0),
			color = rgb(150, 96, 52),
			turn = Vector3.new(0, 0, 90),
		})
	end,
	-- Gift box with a ribbon cross and a bow.
	gift = function(model: Model)
		addPart(model, { size = Vector3.new(3, 2.4, 3), at = Vector3.new(0, 1.2, 0), color = rgb(235, 90, 140) })
		addPart(model, { size = Vector3.new(3.3, 0.5, 3.3), at = Vector3.new(0, 2.5, 0), color = rgb(245, 120, 165) })
		local ribbon = rgb(255, 210, 60)
		addPart(model, { size = Vector3.new(0.6, 2.8, 3.4), at = Vector3.new(0, 1.4, 0), color = ribbon })
		addPart(model, { size = Vector3.new(3.4, 2.8, 0.6), at = Vector3.new(0, 1.4, 0), color = ribbon })
		for _, side in { -1, 1 } do
			addPart(model, {
				shape = BALL,
				size = Vector3.one * 1,
				at = Vector3.new(side * 0.55, 3.1, 0),
				color = ribbon,
			})
		end
	end,
	-- Desk calendar: cream page, red top band, two rings.
	calendar = function(model: Model)
		addPart(model, { size = Vector3.new(3.4, 3.2, 0.5), at = Vector3.new(0, 1.6, 0), color = CREAM })
		addPart(model, { size = Vector3.new(3.4, 0.9, 0.6), at = Vector3.new(0, 3.0, -0.05), color = rgb(230, 70, 50) })
		for _, side in { -1, 1 } do
			addPart(model, {
				shape = CYLINDER,
				size = Vector3.new(0.9, 0.35, 0.35),
				at = Vector3.new(side * 0.9, 3.5, -0.1),
				color = DARK,
				turn = Vector3.new(0, 0, 90),
			})
		end
		for row = 0, 1 do
			for column = -1, 1 do
				addPart(model, {
					size = Vector3.new(0.6, 0.5, 0.1),
					at = Vector3.new(column * 0.95, 1.9 - row * 0.8, -0.3),
					color = if row == 0 and column == 0 then rgb(110, 200, 90) else rgb(240, 200, 150),
				})
			end
		end
	end,
	-- Glowing orb with a ring around it (fresh start, more coins).
	rebirth = function(model: Model)
		addPart(model, {
			shape = BALL,
			size = Vector3.one * 2.6,
			at = Vector3.new(0, 2, 0),
			color = rgb(170, 90, 230),
			material = Enum.Material.Neon,
		})
		addPart(model, {
			shape = CYLINDER,
			size = Vector3.new(0.2, 4.2, 4.2),
			at = Vector3.new(0, 2, 0),
			color = rgb(255, 200, 40),
			turn = Vector3.new(20, 0, 90),
		})
	end,
	-- Stone arch with a swirling purple centre.
	portal = function(model: Model)
		local stone = rgb(186, 176, 166)
		for _, side in { -1, 1 } do
			addPart(model, { size = Vector3.new(0.8, 3.6, 0.8), at = Vector3.new(side * 1.6, 1.8, 0), color = stone })
		end
		addPart(model, { size = Vector3.new(4, 0.8, 0.9), at = Vector3.new(0, 3.8, 0), color = stone })
		addPart(model, {
			shape = CYLINDER,
			size = Vector3.new(0.2, 2.6, 2.6),
			at = Vector3.new(0, 1.8, 0),
			color = rgb(150, 90, 230),
			turn = Vector3.new(0, 90, 0),
			material = Enum.Material.Neon,
		})
	end,
	-- Gear (settings).
	gear = function(model: Model)
		local metal = rgb(190, 180, 170)
		addPart(model, {
			shape = CYLINDER,
			size = Vector3.new(0.8, 2.8, 2.8),
			at = Vector3.new(0, 2, 0),
			color = metal,
			turn = Vector3.new(0, 90, 0),
		})
		for index = 0, 5 do
			addPart(model, {
				size = Vector3.new(0.8, 4, 0.7),
				at = Vector3.new(0, 2, 0),
				color = metal,
				turn = Vector3.new(0, 0, index * 30),
			})
		end
		addPart(model, {
			shape = CYLINDER,
			size = Vector3.new(0.9, 1, 1),
			at = Vector3.new(0, 2, 0),
			color = DARK,
			turn = Vector3.new(0, 90, 0),
		})
	end,
	-- Lucky wheel: coloured disc with a gold rim.
	wheel = function(model: Model)
		addPart(model, {
			shape = CYLINDER,
			size = Vector3.new(0.5, 4, 4),
			at = Vector3.new(0, 2, 0.1),
			color = rgb(255, 200, 40),
			turn = Vector3.new(0, 90, 0),
		})
		local colors = { rgb(230, 70, 50), rgb(110, 200, 90), rgb(60, 180, 255), rgb(240, 130, 60) }
		for index, color in colors do
			addPart(model, {
				size = Vector3.new(0.9, 3.4, 0.2),
				at = Vector3.new(0, 2, -0.2),
				color = color,
				turn = Vector3.new(0, 0, index * 45),
			})
		end
	end,
	-- Quest scroll: paper between two rods.
	quest = function(model: Model)
		addPart(model, { size = Vector3.new(2.8, 3, 0.2), at = Vector3.new(0, 2, 0), color = CREAM })
		for _, y in { 0.4, 3.6 } do
			addPart(model, {
				shape = CYLINDER,
				size = Vector3.new(3.4, 0.5, 0.5),
				at = Vector3.new(0, y, 0),
				color = rgb(150, 96, 52),
			})
		end
		for row = 0, 2 do
			addPart(model, {
				size = Vector3.new(1.8, 0.25, 0.1),
				at = Vector3.new(0.2, 2.8 - row * 0.7, -0.15),
				color = DARK,
			})
			addPart(model, {
				size = Vector3.new(0.35, 0.35, 0.1),
				at = Vector3.new(-1, 2.8 - row * 0.7, -0.15),
				color = rgb(110, 200, 90),
			})
		end
	end,
	-- Six-pointed gold star (index, badges, titles ...).
	star = function(model: Model)
		for index = 0, 2 do
			addPart(model, {
				size = Vector3.new(0.9, 4, 0.6),
				at = Vector3.new(0, 2, 0),
				color = rgb(255, 200, 40),
				turn = Vector3.new(0, 0, index * 60),
			})
		end
		addPart(
			model,
			{ shape = BALL, size = Vector3.one * 1.8, at = Vector3.new(0, 2, 0), color = rgb(255, 226, 110) }
		)
	end,
	-- Three dots ("More").
	more = function(model: Model)
		for index = -1, 1 do
			addPart(
				model,
				{ shape = BALL, size = Vector3.one * 1.2, at = Vector3.new(index * 1.5, 2, 0), color = CREAM }
			)
		end
	end,
}

type Live = { frame: ViewportFrame, camera: Camera, focus: Vector3, offset: Vector3, phase: number }
local live: { Live } = {}
local running = false

local function aim(entry: Live, angle: number)
	local orbit = CFrame.Angles(0, math.rad(angle), 0)
	local position = entry.focus + orbit:VectorToWorldSpace(entry.offset)
	entry.camera.CFrame = CFrame.lookAt(position, entry.focus) * CFrame.Angles(0, 0, math.rad(TILT_DEGREES))
end

local function startSway()
	if running then
		return
	end
	running = true
	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < UPDATE_SECONDS then
			return
		end
		local t = os.clock()
		elapsed = 0
		for index = #live, 1, -1 do
			local entry = live[index]
			if entry.frame.Parent == nil then
				table.remove(live, index)
			elseif entry.frame.Visible then
				aim(entry, math.sin((t + entry.phase) * 2 * math.pi / SWAY_SECONDS) * SWAY_DEGREES)
			end
		end
	end)
end

local function viewFor(model: Model): (ViewportFrame, Camera, Vector3, Vector3)
	local frame = Instance.new("ViewportFrame")
	frame.Name = "TileIcon"
	frame.BackgroundTransparency = 1
	frame.Ambient = rgb(200, 200, 200)
	frame.LightColor = rgb(255, 250, 240)
	frame.LightDirection = Vector3.new(-0.5, -1, 0.6)
	model.Parent = frame
	local box, boxSize = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local direction = Vector3.new(0.35, 0.3, -1).Unit
	local distance = (boxSize.Magnitude / 2) / math.tan(math.rad(camera.FieldOfView / 2)) * 1.02
	camera.Parent = frame
	frame.CurrentCamera = camera
	return frame, camera, box.Position, direction * distance
end

-- Fills `holder` with a live 3D view: the imported model `icon.model` if there is one,
-- else the shape `icon.shape` (default "star"). Returns the ViewportFrame.
function TileIcon.build(holder: GuiObject, icon: Icon): ViewportFrame
	local frame: ViewportFrame, camera: Camera, focus: Vector3, offset: Vector3
	local imported = icon.model and ModelLibrary.viewport(icon.model)
	if imported then
		frame = imported
		camera = imported.CurrentCamera :: Camera
		local model = imported:FindFirstChildOfClass("Model") :: Model
		local box = model:GetBoundingBox()
		focus = box.Position
		offset = camera.CFrame.Position - focus
	else
		local model = Instance.new("Model")
		local shape = TileIcon.SHAPES[icon.shape or "star"] or TileIcon.SHAPES.star
		shape(model)
		frame, camera, focus, offset = viewFor(model)
	end
	frame.Name = "TileIcon"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = holder.ZIndex + 1
	frame.Parent = holder
	local entry = { frame = frame, camera = camera, focus = focus, offset = offset, phase = #live * 0.7 }
	aim(entry, 0)
	table.insert(live, entry)
	startSway()
	return frame
end

return TileIcon
