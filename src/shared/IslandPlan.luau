--!strict
-- Geometry of the flying islands (#27), as plain data: the spawn island, then world 1,
-- 2, ... in a chain along -Z, joined by bridges. Pure Luau without Roblox API, so it is
-- tested with Lune and the same plan feeds the Blender preview renders
-- (tools/blender/render_islands.py via .lune/export-islands.luau).
--
-- The server turns every PartSpec into a Part (src/server/IslandBuilder.luau):
--   shape     "Block" | "Wedge" | "Ball" | "Cylinder" (Roblox shapes, cylinder axis = X)
--   size      { x, y, z } in studs
--   cframe    { x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 } (CFrame.new order;
--             columns are the right, up and back vectors)
--   color     { r, g, b } 0-255, material = Enum.Material name
--   role      what the part is for: Ground, Cliff, Rim, Wall (invisible), Path, Field,
--             Water, Waterfall, Terrace, Step, Bridge, Rope, Glow, Gate, Barrier, Landmark,
--             Fountain, Board, Deco, UpdateBoard, Countdown (spawn marketplace signs, #106)
-- Stations are ground points with a yaw: yaw 0 faces -Z (front = (-sin yaw, 0, -cos yaw)).
-- Local floor-plan coordinates (GameConfig.islands.layout): x = right of the main path,
-- z = towards the front, where the bridge arrives.

export type PartSpec = {
	name: string,
	shape: string,
	size: { number },
	cframe: { number },
	color: { number },
	material: string,
	collide: boolean,
	transparency: number?,
	role: string?,
	-- Scripted world decoration (#82, theme.deco): counted against the theme's part
	-- budget and left out when the feature switch worldDeco is off.
	deco: boolean?,
	-- Optional detail: hidden on graphics "Low" (tag GraphicsDetail, #76). Never collides.
	detail: boolean?,
}

export type ModelSpec = { model: string, width: number, position: { number }, yaw: number, collide: boolean }

-- `clear` (spawn island, #106): radius kept free of trees and deco around a spot that a
-- later ticket builds on (lucky wheel, merchant stand, new leaderboards).
export type Station = { position: { number }, yaw: number, clear: number? }

export type Island = {
	-- "spawn", "world" or "event" (event island, #77)
	kind: string,
	worldIndex: number?,
	eventIndex: number?,
	center: { number },
	-- Rim points { x, z } (world coordinates), counter-clockwise seen from above.
	outline: { { number } },
	parts: { PartSpec },
	models: { ModelSpec },
	stations: { [string]: Station },
	field: { center: { number }, size: { number } }?,
	-- Middle of the bridge openings on the rim (world coordinates).
	openings: { front: { number }?, back: { number }? },
}

export type Bridge = { fromZ: number, toZ: number, parts: { PartSpec } }

export type Gate = { parts: { PartSpec }, barrier: PartSpec, returnPoint: { number } }

local IslandPlan = {}

-- ------------------------------------------------------------------ vector helpers

type V = { number }

local function v(x: number, y: number, z: number): V
	return { x, y, z }
end
local function add(a: V, b: V): V
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end
local function sub(a: V, b: V): V
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end
local function scale(a: V, k: number): V
	return { a[1] * k, a[2] * k, a[3] * k }
end
local function dot(a: V, b: V): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end
local function cross(a: V, b: V): V
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end
local function length(a: V): number
	return math.sqrt(dot(a, a))
end
local function unit(a: V): V
	local l = length(a)
	return if l > 0 then scale(a, 1 / l) else { 0, 0, 0 }
end

-- CFrame from position and rotation columns (right, up, back).
local function matrix(p: V, right: V, up: V, back: V): { number }
	return {
		p[1],
		p[2],
		p[3],
		right[1],
		up[1],
		back[1],
		right[2],
		up[2],
		back[2],
		right[3],
		up[3],
		back[3],
	}
end

-- CFrame.new(p) * CFrame.Angles(0, yaw, 0)
local function yawed(p: V, yaw: number): { number }
	local c, s = math.cos(yaw), math.sin(yaw)
	return matrix(p, { c, 0, -s }, { 0, 1, 0 }, { s, 0, c })
end

-- Block whose local Z runs along `dir` (local Y stays as close to world up as possible).
local function along(p: V, dir: V): { number }
	local back = unit(dir)
	local right = unit(cross({ 0, 1, 0 }, back))
	local up = cross(back, right)
	return matrix(p, right, up, back)
end

-- Upright cylinder (Roblox cylinders lie along X): CFrame.Angles(0, 0, pi / 2).
local function upright(p: V): { number }
	return matrix(p, { 0, 1, 0 }, { -1, 0, 0 }, { 0, 0, 1 })
end

-- Against z-fighting (#46): cliff rings stagger tops and outer faces in cycles, and thin ground layers keep their tops at least 0.1 studs apart.
local CLIFF_FACE_STEP = 0.03
local CLIFF_OUTSET = 0.06
local THIN = { -- top above the ground surface
	ToppingArea = 0.1,
	FieldRow = 0.2,
	LavaCrack = 0.2,
	PathPlate = 0.3,
	Pond = 0.4,
	Stream = 0.5,
}

-- Deterministic pseudo-random number in [0, 1) for decoration jitter.
local function noise(a: number, b: number): number
	local x = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return x - math.floor(x)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- ------------------------------------------------------------------ part makers

type Props = {
	name: string,
	color: { number },
	material: string?,
	collide: boolean?,
	transparency: number?,
	role: string?,
	deco: boolean?,
	detail: boolean?,
}

local function spec(shape: string, size: V, cframe: { number }, props: Props): PartSpec
	return {
		name = props.name,
		shape = shape,
		size = size,
		cframe = cframe,
		color = props.color,
		material = props.material or "SmoothPlastic",
		collide = props.collide ~= false and props.detail ~= true,
		transparency = props.transparency,
		role = props.role,
		deco = props.deco,
		detail = props.detail,
	}
end

-- Flat-topped slab of triangle a-b-c (thickness below the triangle), from two wedges
-- (the classic Roblox triangle technique).
local function triangle(out: { PartSpec }, a: V, b: V, c: V, thickness: number, props: Props)
	local ab, ac, bc = sub(b, a), sub(c, a), sub(c, b)
	local abd, acd, bcd = dot(ab, ab), dot(ac, ac), dot(bc, bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = sub(b, a), sub(c, a), sub(c, b)
	local right = unit(cross(ac, ab))
	local up = unit(cross(bc, right))
	local back = unit(bc)
	local height = math.abs(dot(ab, up))
	if height < 1e-3 then
		return
	end
	-- Shift down so the upper face of the slab is the triangle itself.
	local upwards = if right[2] >= 0 then right else scale(right, -1)
	local shift = scale(upwards, -thickness / 2)
	local w1 = math.abs(dot(ab, back))
	local w2 = math.abs(dot(ac, back))
	if w1 > 1e-3 then
		table.insert(
			out,
			spec("Wedge", v(thickness, height, w1), matrix(add(scale(add(a, b), 0.5), shift), right, up, back), props)
		)
	end
	if w2 > 1e-3 then
		table.insert(
			out,
			spec(
				"Wedge",
				v(thickness, height, w2),
				matrix(add(scale(add(a, c), 0.5), shift), scale(right, -1), up, scale(back, -1)),
				props
			)
		)
	end
end

-- Block from p to q (along the line), `width` across and `height` up, centered on the line.
local function beam(p: V, q: V, width: number, height: number, props: Props): PartSpec
	local dir = sub(q, p)
	return spec("Block", v(width, height, length(dir)), along(scale(add(p, q), 0.5), dir), props)
end

local function disc(center: V, diameter: number, height: number, props: Props): PartSpec
	return spec("Cylinder", v(height, diameter, diameter), upright(center), props)
end

local function ball(center: V, diameter: number, props: Props): PartSpec
	return spec("Ball", v(diameter, diameter, diameter), yawed(center, 0), props)
end

-- ------------------------------------------------------------------ rim styles

-- One rim edge p -> q (ground points) in a world's own style (theme.rimStyle; the
-- default "Hedge" is built in shell): "Fence" (farm: posts and two rails), "Rocks"
-- (beach: round boulders), "IceEdge" (icebergs: ice blocks with crystal spikes),
-- "Basalt" (volcano: basalt columns), "Peppermint" (candy land: icing with standing
-- peppermints and gumdrops), "Moonbase" (space: low panels with glowing post tips) or
-- "CoralReef" (Atlantis: pale reef rocks with coral knobs, #82) or "Sandstone" (Desert
-- Pyramids: low sandstone blocks of uneven height, #84).
-- `inward` points into the island; everything stays low so the view stays open.
local function rimPiece(parts: { PartSpec }, style: string, p: V, q: V, inward: V, i: number, theme: any)
	local dir = sub(q, p)
	local len = length(dir)
	local inset = scale(inward, 1.6)
	if style == "Fence" then
		local post = add(p, inset)
		table.insert(
			parts,
			disc(add(post, v(0, 1.6, 0)), 0.9, 3.2, { name = "FencePost", color = theme.wood, role = "Rim" })
		)
		table.insert(
			parts,
			ball(
				add(post, v(0, 3.3, 0)),
				1.1,
				{ name = "FencePostCap", color = theme.wood, collide = false, role = "Rim" }
			)
		)
		for _, h in { 1.2, 2.5 } do
			local a, b = add(p, add(inset, v(0, h, 0))), add(q, add(inset, v(0, h, 0)))
			table.insert(parts, beam(a, b, 0.35, 0.5, { name = "FenceRail", color = theme.rim, role = "Rim" }))
		end
	elseif style == "Rocks" then
		local stones = math.max(1, math.floor(len / 5 + 0.5))
		for k = 1, stones do
			local t = (k - 0.5) / stones
			local d = 2.6 + noise(i, k) * 1.8
			local at = add(add(p, scale(dir, t)), add(inset, v(0, d * 0.3, 0)))
			table.insert(
				parts,
				ball(at, d, {
					name = "RimRock",
					color = if (i + k) % 3 == 0 then theme.cliffLight else theme.rim,
					role = "Rim",
				})
			)
		end
	elseif style == "CoralReef" then
		-- Atlantis (#82): low reef of pale rocks with a coral knob in the theme's
		-- coral colours (theme.corals) on every second rock.
		local corals = theme.corals or { theme.rim }
		local stones = math.max(1, math.floor(len / 5 + 0.5))
		for k = 1, stones do
			local t = (k - 0.5) / stones
			local d = 2.4 + noise(i, k) * 1.4
			local at = add(add(p, scale(dir, t)), add(inset, v(0, d * 0.25, 0)))
			table.insert(parts, ball(at, d, { name = "ReefRock", color = theme.cliffLight, role = "Rim" }))
			if (i + k) % 2 == 0 then
				table.insert(
					parts,
					ball(add(at, v(0, d * 0.45, 0)), d * 0.55, {
						name = "ReefCoral",
						color = corals[(i + k) % #corals + 1],
						collide = false,
						role = "Rim",
					})
				)
			end
		end
	elseif style == "MossyStones" then
		-- Jungle temple (#83): low, squarish weathered stone blocks with a moss cushion
		-- (theme.moss) on every second one.
		local stones = math.max(1, math.floor(len / 4.5 + 0.5))
		local seg = len / stones
		for k = 1, stones do
			local t = (k - 0.5) / stones
			local h = 1.6 + noise(i, k) * 1.2
			local at = add(add(p, scale(dir, t)), add(inset, v(0, h / 2, 0)))
			local tilt = (noise(k, i) - 0.5) * 0.3
			table.insert(
				parts,
				spec("Block", v(2.6, h, seg * 0.86), along(at, add(dir, v(0, 0, tilt))), {
					name = "MossyStone",
					color = if (i + k) % 3 == 0 then theme.cliffLight else theme.rim,
					role = "Rim",
				})
			)
			if (i + k) % 2 == 0 then
				table.insert(
					parts,
					spec("Ball", v(2.4, 0.9, seg * 0.6), along(add(at, v(0, h / 2, 0)), dir), {
						name = "MossCushion",
						color = theme.moss or theme.grass,
						collide = false,
						role = "Rim",
					})
				)
			end
		end
	elseif style == "Sandstone" then
		-- Desert Pyramids (#84): a low wall of sandstone blocks along the edge, of uneven
		-- height, every third one lighter and every fifth one a little sunk and tilted.
		local blocks = math.max(1, math.floor(len / 5 + 0.5))
		local seg = len / blocks
		for k = 1, blocks do
			local t = (k - 0.5) / blocks
			local h = 1.4 + noise(i, k) * 1.4
			local sunk = (i + k) % 5 == 0
			local at = add(add(p, scale(dir, t)), add(inset, v(0, h / 2 - (if sunk then 0.5 else 0), 0)))
			local cf = along(at, if sunk then add(unit(dir), v(0, 0.12, 0)) else dir)
			table.insert(
				parts,
				spec("Block", v(1.8, h, seg * 0.9), cf, {
					name = "Sandstone",
					color = if (i + k) % 3 == 0 then theme.cliffLight else theme.rim,
					role = "Rim",
				})
			)
		end
	elseif style == "IceEdge" then
		local h = 1.8 + noise(i, 3) * 1.4
		local center = add(scale(add(p, q), 0.5), add(inset, v(0, h / 2, 0)))
		table.insert(
			parts,
			spec("Block", v(2, h, len + 0.4), along(center, dir), { name = "IceRim", color = theme.rim, role = "Rim" })
		)
		table.insert(
			parts,
			spec(
				"Block",
				v(2.3, 0.5, len + 0.6),
				along(add(center, v(0, h / 2 + 0.2, 0)), dir),
				{ name = "IceRimSnow", color = theme.snow or { 248, 252, 255 }, collide = false, role = "Rim" }
			)
		)
		if i % 3 == 0 then
			-- Crystal spike leaning outwards a little.
			local foot = add(p, add(inset, v(0, h, 0)))
			local tip = add(foot, add(scale(inward, -0.8), v(0, 3.2 + noise(i, 9) * 1.6, 0)))
			table.insert(
				parts,
				beam(foot, tip, 0.9, 0.9, {
					name = "IceSpike",
					color = theme.ice,
					material = "Glass",
					collide = false,
					transparency = 0.15,
					role = "Rim",
				})
			)
		end
	elseif style == "Basalt" then
		-- Columns of different heights, a little apart.
		local columns = math.max(1, math.floor(len / 4 + 0.5))
		local tones = { theme.rim, theme.cliff, theme.cliffLight }
		for k = 1, columns do
			local t = (k - 0.5) / columns
			local h = 1.8 + noise(i, k + 4) * 1.8
			local d = 1.9 + noise(k, i) * 0.6
			local at = add(add(p, scale(dir, t)), add(inset, v(0, h / 2, 0)))
			table.insert(
				parts,
				disc(at, d, h, {
					name = "BasaltColumn",
					color = tones[(i + k) % #tones + 1],
					role = "Rim",
				})
			)
		end
	elseif style == "Peppermint" then
		-- Low icing along the edge ...
		local frosting = theme.frosting or { 255, 246, 250 }
		table.insert(
			parts,
			spec(
				"Block",
				v(1.8, 1.1, len + 0.4),
				along(add(scale(add(p, q), 0.5), add(inset, v(0, 0.55, 0))), dir),
				{ name = "Icing", color = frosting, role = "Rim" }
			)
		)
		local at = add(p, inset)
		if i % 2 == 0 then
			-- ... a peppermint standing on its edge, facing out of the island ...
			local back = cross(inward, { 0, 1, 0 })
			local center = add(at, v(0, 1.8, 0))
			table.insert(
				parts,
				spec("Cylinder", v(0.8, 3.4, 3.4), matrix(center, inward, { 0, 1, 0 }, back), {
					name = "Peppermint",
					color = theme.rim,
					role = "Rim",
				})
			)
			table.insert(
				parts,
				spec("Cylinder", v(0.9, 1.4, 1.4), matrix(center, inward, { 0, 1, 0 }, back), {
					name = "PeppermintCenter",
					color = frosting,
					collide = false,
					role = "Rim",
				})
			)
		else
			-- ... or a gumdrop (short drum with a round top).
			local candy = theme.candy or { theme.rim }
			local color = candy[math.floor(noise(i, 21) * #candy) + 1]
			table.insert(
				parts,
				disc(add(at, v(0, 0.8, 0)), 2.6, 1.6, { name = "Gumdrop", color = color, role = "Rim" })
			)
			table.insert(
				parts,
				ball(add(at, v(0, 1.6, 0)), 2.6, { name = "GumdropTop", color = color, collide = false, role = "Rim" })
			)
		end
	elseif style == "Moonbase" then
		-- Low white panel with a see-through strip on top; every third corner a post with a
		-- small glowing tip.
		local center = add(scale(add(p, q), 0.5), add(inset, v(0, 0.7, 0)))
		table.insert(
			parts,
			spec(
				"Block",
				v(1, 1.4, len + 0.3),
				along(center, dir),
				{ name = "MoonPanel", color = theme.rim, role = "Rim" }
			)
		)
		table.insert(
			parts,
			spec("Block", v(0.6, 0.4, len + 0.3), along(add(center, v(0, 0.9, 0)), dir), {
				name = "MoonPanelStrip",
				color = theme.water,
				material = "Glass",
				collide = false,
				transparency = 0.3,
				role = "Rim",
			})
		)
		if i % 3 == 0 then
			local post = add(p, inset)
			table.insert(
				parts,
				spec("Block", v(0.8, 2.6, 0.8), yawed(add(post, v(0, 1.3, 0)), 0), {
					name = "MoonPost",
					color = theme.woodDark,
					role = "Rim",
				})
			)
			table.insert(
				parts,
				ball(add(post, v(0, 2.9, 0)), 0.7, {
					name = "MoonPostTip",
					color = theme.glow,
					material = "Neon",
					collide = false,
					role = "Rim",
				})
			)
		end
	end
end

-- ------------------------------------------------------------------ outlines

local SEGMENTS = 48

-- Radius of the superellipse |x/r|^n + |z/r|^n = 1 in the direction `angle`.
local function superRadius(angle: number, n: number, r: number): number
	local c, s = math.abs(math.cos(angle)), math.abs(math.sin(angle))
	return r / ((c ^ n + s ^ n) ^ (1 / n))
end

type Shape = {
	center: V,
	radius: number,
	exponent: number,
	wobble: number,
	seed: number,
	openFront: boolean,
	openBack: boolean,
	openingHalf: number,
}

-- Rounded, irregular rim: a superellipse that wobbles inwards, flat and straight where the
-- bridges arrive (front = +Z, back = -Z). Returns the points and which edges are openings.
local function roundOutline(shape: Shape): ({ { number } }, { [number]: boolean })
	local cx, cz, r = shape.center[1], shape.center[3], shape.radius
	local points: { { number } } = {}
	local openingEdges: { [number]: boolean } = {}
	local insertedFront, insertedBack = false, false
	for i = 0, SEGMENTS - 1 do
		local angle = i / SEGMENTS * math.pi * 2
		local c, s = math.cos(angle), math.sin(angle)
		local radius = superRadius(angle, shape.exponent, r)
		-- No wobble near the bridge axis, so the openings stay straight.
		local fade = math.clamp((math.abs(c) - 0.12) / 0.25, 0, 1)
		local w = 0.55 + 0.25 * math.sin(3 * angle + shape.seed) + 0.2 * math.sin(7 * angle + 2 * shape.seed)
		radius *= 1 - shape.wobble * w * fade
		local x, z = c * radius, s * radius
		local nearFront = shape.openFront and s > 0 and math.abs(x) < shape.openingHalf + 1.5
		local nearBack = shape.openBack and s < 0 and math.abs(x) < shape.openingHalf + 1.5
		if s > 0 and c < 0 and shape.openFront and not insertedFront then
			-- Passed the front axis: insert the opening (right corner, then left corner).
			table.insert(points, { cx + shape.openingHalf, cz + r })
			openingEdges[#points] = true
			table.insert(points, { cx - shape.openingHalf, cz + r })
			insertedFront = true
		end
		if s < 0 and c > 0 and shape.openBack and not insertedBack then
			table.insert(points, { cx - shape.openingHalf, cz - r })
			openingEdges[#points] = true
			table.insert(points, { cx + shape.openingHalf, cz - r })
			insertedBack = true
		end
		if not nearFront and not nearBack then
			table.insert(points, { cx + x, cz + z })
		end
	end
	return points, openingEdges
end

function IslandPlan.isInsideOutline(outline: { { number } }, x: number, z: number): boolean
	local inside = false
	local j = #outline
	for i = 1, #outline do
		local xi, zi = outline[i][1], outline[i][2]
		local xj, zj = outline[j][1], outline[j][2]
		if (zi > z) ~= (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi then
			inside = not inside
		end
		j = i
	end
	return inside
end

-- ------------------------------------------------------------------ plan

export type Plan = {
	worldCenter: (index: number) -> { number },
	worldIndexAt: (x: number, z: number) -> number?,
	spawnIsland: () -> Island,
	worldIsland: (index: number) -> Island,
	eventCenter: (slot: number) -> { number },
	eventIndexAt: (x: number, z: number) -> number?,
	eventIsland: (slot: number) -> Island,
	bridges: () -> { Bridge },
	gate: (index: number) -> Gate,
	hasFallen: (y: number) -> boolean,
	isInsideOutline: (outline: { { number } }, x: number, z: number) -> boolean,
}

-- `eventWorlds` (optional, #77): GameConfig.eventWorlds, built beside the spawn island.
function IslandPlan.new(config: any, worlds: { any }, eventWorlds: { any }?): Plan
	local eventWorlds: { any } = eventWorlds or {}
	local groundY: number = config.groundY
	local half: number = config.worldHalfSize
	local spawnRadius: number = config.spawnRadius
	local bridgeLength: number = config.bridgeLength
	local bridgeWidth: number = config.bridgeWidth
	local wallHeight: number = config.wallHeight
	local pathWidth: number = config.pathWidth
	local spacing = 2 * half + bridgeLength
	local defaultTheme = config.themes.PizzeriaGarden

	local plan = {} :: Plan

	function plan.worldCenter(index: number): { number }
		return v(0, groundY, -spacing * (index - 1))
	end

	local spawnCenter = v(0, groundY, half + bridgeLength + spawnRadius)

	function plan.worldIndexAt(x: number, z: number): number?
		for index = 1, #worlds do
			local c = plan.worldCenter(index)
			if math.abs(x - c[1]) <= half and math.abs(z - c[3]) <= half then
				return index
			end
		end
		return nil
	end

	function plan.hasFallen(y: number): boolean
		return y < config.fallY
	end

	plan.isInsideOutline = IslandPlan.isInsideOutline

	local function themeOf(worldId: string?): any
		return (worldId and config.themes[worldId]) or defaultTheme
	end

	-- Ground fan, rock cliff, rim hedge and invisible walls of an outline.
	local function shell(
		island: Island,
		openingEdges: { [number]: boolean },
		theme: any,
		cliffDepth: number,
		rimGaps: { V }
	)
		local parts = island.parts
		local center = island.center
		local outline = island.outline
		local count = #outline
		local function point(i: number, y: number): V
			local p = outline[(i - 1) % count + 1]
			return v(p[1], y, p[2])
		end

		-- Ground: one triangle per rim edge, fanned from the center.
		for i = 1, count do
			triangle(
				parts,
				v(center[1], groundY, center[3]),
				point(i, groundY),
				point(i + 1, groundY),
				2,
				{ name = "Ground", color = theme.grass, role = "Ground" }
			)
		end

		-- Rock cliff: rings that step inwards towards the bottom, like an upside-down cone.
		-- `cycle`: blocks per stagger cycle (deeper rings converge, so blocks further apart
		-- overlap); `drop`: top step per block of the cycle.
		local layers = {
			{ k = 1.0, top = -0.9, h = 6, d = 5, cycle = 3, drop = 0.15 },
			{ k = 0.93, top = -6, h = 8, d = 10, cycle = 4, drop = 0.12 },
			{ k = 0.8, top = -13, h = 9, d = 16, cycle = 5, drop = 0.1 },
			{ k = 0.62, top = -21, h = 9, d = 18, cycle = 7, drop = 0.08 },
			{ k = 0.42, top = -29, h = 8, d = 16, cycle = 9, drop = 0.08 },
			{ k = 0.22, top = -36, h = 7, d = 12, cycle = 16, drop = 0.06 },
		}
		local tones = { theme.cliff, theme.cliffDark, theme.cliffLight }
		for li, layer in layers do
			local vertical = cliffDepth
			for i = 1, count do
				local p, q = point(i, 0), point(i + 1, 0)
				local a = v(lerp(center[1], p[1], layer.k), 0, lerp(center[3], p[3], layer.k))
				local b = v(lerp(center[1], q[1], layer.k), 0, lerp(center[3], q[3], layer.k))
				local dir = sub(b, a)
				local len = length(dir)
				if len > 0.01 then
					local inward = unit(cross(dir, { 0, 1, 0 }))
					-- Outline is counter-clockwise seen from above (+Y), so this points inwards
					-- when its dot with (center - edge) is positive.
					local mid = scale(add(a, b), 0.5)
					if dot(inward, sub(v(center[1], 0, center[3]), mid)) < 0 then
						inward = scale(inward, -1)
					end
					-- Neighbours overlap, so the blocks of a ring step their tops down and their outer
					-- faces out in cycles (no coplanar, differently coloured faces = no z-fighting).
					-- The cycles split the ring evenly, so the last and the first blocks differ too.
					local cycles = math.max(1, math.floor(count / layer.cycle))
					local j = i - 1
					local step = j - math.ceil(math.floor(j * cycles / count) * count / cycles)
					-- The outermost ring sits slightly outside the outline, covering the ground's
					-- side faces instead of sharing their plane.
					local outward = (if li == 1 then CLIFF_OUTSET else 0) + step * CLIFF_FACE_STEP
					local h = layer.h * vertical * (0.8 + 0.45 * noise(i, li))
					local depth = layer.d * math.min(1, half / 100 + 0.3)
					local drop = step * layer.drop
					local y = groundY + layer.top * vertical - drop - h / 2
					local blockCenter = add(v(mid[1], y, mid[3]), scale(inward, depth / 2 - outward))
					table.insert(
						parts,
						spec("Block", v(depth, h, len + 1.2), along(blockCenter, dir), {
							name = "Cliff",
							color = tones[math.floor(noise(li, i) * 3) + 1],
							collide = li == 1,
							role = "Cliff",
						})
					)
				end
			end
		end

		local function gapNear(p: V, q: V): boolean
			for _, gap in rimGaps do
				local t = math.clamp(dot(sub(gap, p), sub(q, p)) / math.max(dot(sub(q, p), sub(q, p)), 1e-6), 0, 1)
				local closest = add(p, scale(sub(q, p), t))
				if length(sub(v(gap[1], 0, gap[3]), v(closest[1], 0, closest[3]))) < 4.5 then
					return true
				end
			end
			return false
		end

		-- Low hedge along the rim and the invisible wall right on it; both leave the openings.
		for i = 1, count do
			if not openingEdges[i] then
				local p, q = point(i, groundY), point(i + 1, groundY)
				local dir = sub(q, p)
				local inward = unit(cross(dir, { 0, 1, 0 }))
				local mid = scale(add(p, q), 0.5)
				if dot(inward, sub(v(center[1], groundY, center[3]), mid)) < 0 then
					inward = scale(inward, -1)
				end
				local style = theme.rimStyle or "Hedge"
				if theme.rim and not gapNear(p, q) and style ~= "Hedge" then
					rimPiece(parts, style, p, q, inward, i, theme)
				elseif theme.rim and not gapNear(p, q) then
					local hedgeCenter = add(mid, add(scale(inward, 1.6), v(0, 1.1, 0)))
					table.insert(
						parts,
						spec("Block", v(1.8, 2.4, length(dir) + 0.6), along(hedgeCenter, dir), {
							name = "Hedge",
							color = theme.rim,
							role = "Rim",
						})
					)
					if i % 2 == 0 then
						local corner = add(p, add(scale(inward, 1.6), v(0, 2.3, 0)))
						table.insert(
							parts,
							ball(corner, 3, { name = "HedgeBall", color = theme.rim, collide = false, role = "Rim" })
						)
					end
				end
				local wallCenter = add(mid, v(0, (wallHeight - 1) / 2, 0))
				table.insert(
					parts,
					spec("Block", v(1, wallHeight + 1, length(dir) + 0.5), along(wallCenter, dir), {
						name = "IslandWall",
						color = { 255, 255, 255 },
						transparency = 1,
						role = "Wall",
					})
				)
			end
		end
	end

	-- Square stone plates (Plattenweg) along a straight line, two plates wide.
	local function plates(parts: { PartSpec }, from: V, to: V, width: number, theme: any, seed: number)
		local dir = sub(to, from)
		local len = length(dir)
		local forward = unit(dir)
		local side = unit(cross({ 0, 1, 0 }, forward))
		local columns = math.max(1, math.floor(width / 5.5 + 0.5))
		local size = width / columns
		local rows = math.max(1, math.floor(len / size + 0.5))
		local step = len / rows
		for row = 0, rows - 1 do
			for col = 0, columns - 1 do
				local offset = (col + 0.5) * size - width / 2
				local p = add(from, add(scale(forward, (row + 0.5) * step), scale(side, offset)))
				local yaw = math.atan2(-forward[1], -forward[3]) + (noise(row + seed, col) - 0.5) * 0.12
				table.insert(
					parts,
					spec(
						"Block",
						v(size - 0.5, 0.3, step - 0.5),
						yawed(v(p[1], groundY + THIN.PathPlate - 0.15, p[3]), yaw),
						{
							name = "PathPlate",
							color = if (row + col) % 2 == 0 then theme.path else theme.pathDark,
							collide = false,
							role = "Path",
						}
					)
				)
			end
		end
	end

	-- Round pond with a stream to the rim and a waterfall down the cliff (direction ±X).
	local function pond(island: Island, at: V, radius: number, theme: any): V
		local parts = island.parts
		table.insert(
			parts,
			disc(v(at[1], groundY + THIN.Pond - 0.15, at[3]), radius * 2, 0.3, {
				name = "Pond",
				color = theme.water,
				material = "Glass",
				collide = false,
				transparency = 0.15,
				role = "Water",
			})
		)
		for i = 1, 14 do
			local a = i / 14 * math.pi * 2
			local d = 1.6 + noise(i, at[1]) * 1.2
			table.insert(
				parts,
				ball(v(at[1] + math.cos(a) * radius, groundY + 0.2, at[3] + math.sin(a) * radius), d, {
					name = "PondStone",
					color = theme.cliffLight,
					collide = false,
					role = "Deco",
				})
			)
		end
		-- Stream towards the nearer side of the island.
		local sideX = if at[1] >= island.center[1] then 1 else -1
		local x = at[1]
		while IslandPlan.isInsideOutline(island.outline, x + sideX, at[3]) do
			x += sideX
		end
		local rimX = x
		local startX = at[1] + sideX * (radius - 1)
		table.insert(
			parts,
			beam(
				v(startX, groundY + THIN.Stream - 0.15, at[3]),
				v(rimX + sideX * 0.6, groundY + THIN.Stream - 0.15, at[3]),
				4.5,
				0.3,
				{
					name = "Stream",
					color = theme.water,
					material = "Glass",
					collide = false,
					transparency = 0.15,
					role = "Water",
				}
			)
		)
		local fallHeight = 46
		table.insert(
			parts,
			spec(
				"Block",
				v(0.8, fallHeight, 4.5),
				yawed(v(rimX + sideX * 1.1, groundY - fallHeight / 2 + 0.2, at[3]), 0),
				{
					name = "Waterfall",
					color = theme.waterfall or { 170, 225, 255 },
					material = "Glass",
					collide = false,
					transparency = 0.2,
					role = "Waterfall",
				}
			)
		)
		return v(rimX, groundY, at[3])
	end

	-- Round trees and bushes around the rim, clear of everything that matters.
	local function scatterTrees(
		island: Island,
		keepOut: (x: number, z: number, r: number) -> boolean,
		seed: number,
		theme: any
	)
		-- Tree models of the world's theme (default: round trees), picked deterministically.
		local kinds: { string } = theme.trees or { "RoundTree" }
		local outline = island.outline
		local center = island.center
		for ring, inset in { 9, 20 } do
			for i, p in outline do
				if ring == 1 or i % 2 == 0 then
					local dx, dz = p[1] - center[1], p[2] - center[3]
					local d = math.sqrt(dx * dx + dz * dz)
					local x = p[1] - dx / d * inset + (noise(i, seed + ring) - 0.5) * 4
					local z = p[2] - dz / d * inset + (noise(seed + ring, i) - 0.5) * 4
					local width = (10 + noise(i * 3, seed) * 6) * (theme.treeScale or 1)
					local r = width / 2
					if IslandPlan.isInsideOutline(outline, x, z) and not keepOut(x, z, r) then
						-- Not too close to the trees already placed.
						local free = true
						for _, other in island.models do
							local ox, oz = other.position[1], other.position[3]
							if math.sqrt((ox - x) ^ 2 + (oz - z) ^ 2) < (other.width + width) * 0.42 then
								free = false
								break
							end
						end
						if free then
							table.insert(island.models, {
								model = kinds[math.floor(noise(i * 5, seed + ring) * #kinds) + 1],
								width = width,
								position = v(x, groundY, z),
								yaw = noise(i, seed * 7) * math.pi * 2,
								collide = true,
							})
						end
					end
				end
			end
		end
	end

	local function flowers(island: Island, at: V, count: number, spread: number, theme: any, seed: number)
		for i = 1, count do
			local x = at[1] + (noise(i, seed) - 0.5) * spread
			local z = at[3] + (noise(seed, i) - 0.5) * spread
			local colors = theme.flowers
			table.insert(
				island.parts,
				ball(v(x, groundY + (if theme.flowerStems == false then 0.35 else 0.9), z), 1.1, {
					name = "Flower",
					color = colors[math.floor(noise(i * 2, seed) * #colors) + 1],
					collide = false,
					role = "Deco",
				})
			)
			if theme.flowerStems == false then
				continue
			end
			table.insert(
				island.parts,
				spec("Block", v(0.3, 0.9, 0.3), yawed(v(x, groundY + 0.4, z), 0), {
					name = "FlowerStem",
					color = theme.rim,
					collide = false,
					role = "Deco",
				})
			)
		end
	end

	-- Raised round grass terrace with steps towards the main path.
	local function terrace(island: Island, at: V, radius: number, height: number, theme: any)
		local parts = island.parts
		table.insert(
			parts,
			disc(v(at[1], groundY + (height - 0.6) / 2, at[3]), radius * 2, height - 0.6, {
				name = "TerraceRock",
				color = theme.cliffLight,
				role = "Terrace",
			})
		)
		table.insert(
			parts,
			disc(v(at[1], groundY + height - 0.4, at[3]), radius * 2 + 0.8, 0.8, {
				name = "TerraceGrass",
				color = theme.grassLight,
				role = "Terrace",
			})
		)
		local toPath = if at[1] > island.center[1] then -1 else 1
		local steps = math.ceil(height / 1.2)
		for k = 1, steps do
			local h = height * (steps - k + 1) / (steps + 1)
			local x = at[1] + toPath * (radius - 0.5 + (k - 0.5) * 2.4)
			table.insert(
				parts,
				spec("Block", v(2.4, h, 7), yawed(v(x, groundY + h / 2, at[3]), 0), {
					name = "TerraceStep",
					color = if k % 2 == 0 then theme.path else theme.pathDark,
					role = "Step",
				})
			)
		end
	end

	-- World 1 landmark: a giant pizza on a stone pedestal, tilted towards the path.
	local function giantPizza(parts: { PartSpec }, at: V, baseY: number, theme: any)
		local stone = { 190, 180, 170 }
		table.insert(
			parts,
			disc(v(at[1], baseY + 3, at[3]), 9, 6, { name = "Pedestal", color = stone, role = "Landmark" })
		)
		table.insert(
			parts,
			disc(v(at[1], baseY + 6.4, at[3]), 11, 0.8, { name = "PedestalTop", color = stone, role = "Landmark" })
		)
		-- Disc tilted 25 degrees around Z (towards +X, the main path from the left terrace).
		local tilt = math.rad(25) * (if at[1] < 0 then -1 else 1)
		local c, s = math.cos(tilt), math.sin(tilt)
		-- Upright cylinder rotated by `tilt` around Z: right (cylinder axis) = (c*0 - ..).
		local axis = { -s, c, 0 }
		local function layer(offset: number, diameter: number, thickness: number, color: { number }, name: string)
			local p = add(v(at[1], baseY + 13, at[3]), scale(axis, offset))
			table.insert(
				parts,
				spec("Cylinder", v(thickness, diameter, diameter), matrix(p, axis, { -c, -s, 0 }, { 0, 0, 1 }), {
					name = name,
					color = color,
					role = "Landmark",
				})
			)
		end
		layer(0, 20, 1.4, { 214, 140, 60 }, "PizzaCrust")
		layer(0.5, 17.5, 0.8, { 214, 52, 34 }, "PizzaSauce")
		layer(0.8, 15.5, 0.6, { 255, 214, 92 }, "PizzaCheese")
		-- Salami slices on the cheese.
		for i = 1, 7 do
			local a = i / 7 * math.pi * 2
			local r = if i % 2 == 0 then 4.5 else 2.2
			local inPlane = add(scale({ -c, -s, 0 }, math.cos(a) * r), scale({ 0, 0, 1 }, math.sin(a) * r))
			local p = add(add(v(at[1], baseY + 13, at[3]), scale(axis, 1.15)), inPlane)
			table.insert(
				parts,
				spec("Cylinder", v(0.3, 3, 3), matrix(p, axis, { -c, -s, 0 }, { 0, 0, 1 }), {
					name = "PizzaSalami",
					color = { 150, 28, 46 },
					role = "Landmark",
				})
			)
		end
		-- Support from the pedestal to the pizza.
		table.insert(
			parts,
			disc(v(at[1], baseY + 9, at[3]), 2.2, 6, { name = "PizzaStand", color = theme.wood, role = "Landmark" })
		)
	end

	-- Rotation about the world Z axis by `a` (blades of the windmill face +Z, the front).
	local function rolled(p: V, a: number): { number }
		local c, s = math.cos(a), math.sin(a)
		return matrix(p, { c, s, 0 }, { -s, c, 0 }, { 0, 0, 1 })
	end

	-- World 2 landmark: a windmill (stone tower, red cap, four sails facing the front).
	local function windmill(parts: { PartSpec }, at: V, baseY: number, theme: any)
		local stone = theme.cliffLight
		local white = { 250, 246, 236 }
		local red = { 204, 62, 52 }
		for k, layer in { { 11, 6 }, { 9.6, 6 }, { 8.4, 6 } } do
			local y = baseY + (k - 1) * 6 + layer[2] / 2
			table.insert(
				parts,
				disc(v(at[1], y, at[3]), layer[1], layer[2], {
					name = "MillTower",
					color = if k % 2 == 0 then white else stone,
					role = "Landmark",
				})
			)
		end
		-- Door and two windows on the front side.
		local front = at[3] + 4.9
		table.insert(
			parts,
			spec("Block", v(3, 4.2, 1), yawed(v(at[1], baseY + 2.1, front + 0.5), 0), {
				name = "MillDoor",
				color = theme.wood,
				role = "Landmark",
			})
		)
		for _, h in { 8.5, 14 } do
			table.insert(
				parts,
				spec("Block", v(1.6, 1.6, 0.6), yawed(v(at[1], baseY + h, at[3] + 4.6 - (h - 8.5) * 0.11), 0), {
					name = "MillWindow",
					color = { 90, 60, 40 },
					collide = false,
					role = "Landmark",
				})
			)
		end
		-- Cap: three shrinking red discs, a ball on top.
		for k, d in { 9.6, 7.4, 4.8 } do
			table.insert(
				parts,
				disc(v(at[1], baseY + 18.6 + (k - 1) * 1.5, at[3]), d, 1.6, {
					name = "MillCap",
					color = red,
					role = "Landmark",
				})
			)
		end
		table.insert(
			parts,
			ball(v(at[1], baseY + 22.6, at[3]), 2, { name = "MillCapTop", color = red, role = "Landmark" })
		)
		-- Hub and four sails (lattice frame + cream sail), tilted 20 degrees.
		local hub = v(at[1], baseY + 16, at[3] + 5.6)
		table.insert(
			parts,
			spec("Cylinder", v(2.4, 2.2, 2.2), matrix(hub, { 0, 0, 1 }, { 0, 1, 0 }, { -1, 0, 0 }), {
				name = "MillHub",
				color = theme.wood,
				role = "Landmark",
			})
		)
		for k = 0, 3 do
			local a = math.rad(20) + k * math.pi / 2
			local dir = v(-math.sin(a), math.cos(a), 0)
			table.insert(
				parts,
				spec("Block", v(0.7, 15, 0.5), rolled(add(add(hub, v(0, 0, 0.8)), scale(dir, 8)), a), {
					name = "MillArm",
					color = theme.wood,
					collide = false,
					role = "Landmark",
				})
			)
			local side = v(math.cos(a), math.sin(a), 0)
			table.insert(
				parts,
				spec(
					"Block",
					v(3.4, 11, 0.25),
					rolled(add(add(hub, v(0, 0, 0.6)), add(scale(dir, 9), scale(side, 2))), a),
					{
						name = "MillSail",
						color = white,
						collide = false,
						role = "Landmark",
					}
				)
			)
		end
	end

	-- World 3 landmark: a striped lighthouse with a glowing lamp.
	local function lighthouse(parts: { PartSpec }, at: V, baseY: number, theme: any)
		local red = { 226, 64, 56 }
		local white = { 250, 246, 236 }
		table.insert(
			parts,
			disc(
				v(at[1], baseY + 1, at[3]),
				12,
				2,
				{ name = "LighthouseBase", color = theme.cliffLight, role = "Landmark" }
			)
		)
		local y = baseY + 2
		for k = 1, 5 do
			local d = 8.6 - (k - 1) * 0.55
			table.insert(
				parts,
				disc(v(at[1], y + 2.2, at[3]), d, 4.4, {
					name = "LighthouseTower",
					color = if k % 2 == 1 then red else white,
					role = "Landmark",
				})
			)
			y += 4.4
		end
		table.insert(
			parts,
			disc(
				v(at[1], y + 0.4, at[3]),
				9.4,
				0.8,
				{ name = "LighthouseGallery", color = { 70, 70, 80 }, role = "Landmark" }
			)
		)
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			table.insert(
				parts,
				disc(v(at[1] + math.cos(a) * 4.3, y + 1.6, at[3] + math.sin(a) * 4.3), 0.35, 1.8, {
					name = "LighthouseRail",
					color = { 70, 70, 80 },
					collide = false,
					role = "Landmark",
				})
			)
		end
		table.insert(
			parts,
			disc(v(at[1], y + 2.6, at[3]), 5, 3.6, {
				name = "LighthouseLantern",
				color = { 200, 236, 255 },
				material = "Glass",
				collide = false,
				transparency = 0.35,
				role = "Landmark",
			})
		)
		table.insert(
			parts,
			ball(v(at[1], y + 2.6, at[3]), 2.4, {
				name = "LighthouseLamp",
				color = { 255, 226, 120 },
				material = "Neon",
				collide = false,
				role = "Glow",
			})
		)
		for k, d in { 6, 4.2, 2.4 } do
			table.insert(
				parts,
				disc(v(at[1], y + 4.8 + (k - 1) * 1.1, at[3]), d, 1.2, {
					name = "LighthouseRoof",
					color = red,
					role = "Landmark",
				})
			)
		end
	end

	-- World 4 landmark: an iceberg peak of leaning ice shards with snow on top.
	local function icePeak(parts: { PartSpec }, at: V, baseY: number, theme: any)
		table.insert(
			parts,
			disc(v(at[1], baseY + 1.2, at[3]), 20, 2.4, { name = "IceMound", color = theme.snow, role = "Landmark" })
		)
		local shards = {
			-- offset x, offset z, width, height, lean x, lean z
			{ 0, 0, 7, 28, 0.6, -0.4 },
			{ -4.5, 2, 5, 19, -3, 1.5 },
			{ 4.5, 1.5, 5, 17, 3, 1 },
			{ 1.5, -4.5, 5.5, 21, 1, -3 },
			{ -2.5, 4.5, 4, 12, -1.5, 3 },
			{ 5.5, -3, 3.5, 11, 3, -1.5 },
		}
		for k, s in shards do
			local foot = v(at[1] + s[1], baseY + 1.5, at[3] + s[2])
			local tip = v(at[1] + s[1] + s[5], baseY + s[4], at[3] + s[2] + s[6])
			table.insert(
				parts,
				beam(foot, tip, s[3], s[3], {
					name = "IceShard",
					color = if k % 2 == 1 then theme.ice else theme.iceDark,
					role = "Landmark",
				})
			)
			-- Snow cap on the tip.
			table.insert(
				parts,
				ball(add(tip, v(0, -0.6, 0)), s[3] * 0.9, {
					name = "IceShardSnow",
					color = theme.snow,
					collide = false,
					role = "Landmark",
				})
			)
		end
		-- Glowing crystals at the foot.
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2 + 0.4
			local foot = v(at[1] + math.cos(a) * 8, baseY + 2.2, at[3] + math.sin(a) * 8)
			table.insert(
				parts,
				beam(foot, add(foot, v(math.cos(a) * 1.2, 3.2, math.sin(a) * 1.2)), 1.1, 1.1, {
					name = "IceCrystalGlow",
					color = { 150, 225, 255 },
					material = "Glass",
					collide = false,
					transparency = 0.1,
					role = "Landmark",
				})
			)
		end
	end

	-- World 5 landmark (#47): a dark basalt cone tapering in thin layers, a glowing crater,
	-- three neon lava streams down the flanks and smoke (VolcanoSmoke, emitter added by the
	-- island builder) rising from the crater.
	local function volcano(parts: { PartSpec }, at: V, baseY: number, theme: any)
		local tones = theme.basalt
		-- Concave volcano profile: wide skirt at the foot, steeper towards the crater.
		local LAYERS, HEIGHT = 11, 22
		local BASE_R, TOP_R = 14.5, 6
		local layerH = HEIGHT / LAYERS
		local function radius(k: number): number
			return TOP_R + (BASE_R - TOP_R) * (1 - (k - 1) / (LAYERS - 1)) ^ 1.7
		end
		for k = 1, LAYERS do
			table.insert(
				parts,
				disc(v(at[1], baseY + (k - 0.5) * layerH, at[3]), 2 * radius(k), layerH, {
					name = "VolcanoRock",
					color = tones[(k - 1) % #tones + 1],
					role = "Landmark",
				})
			)
		end
		local y = baseY + HEIGHT
		-- Crater: a dark rim ring and the lava pool inside (the only light).
		local darkest = theme.basaltDark
		table.insert(
			parts,
			disc(
				v(at[1], y + 0.4, at[3]),
				2 * TOP_R,
				0.8,
				{ name = "VolcanoCrater", color = darkest, role = "Landmark" }
			)
		)
		table.insert(
			parts,
			disc(v(at[1], y + 0.85, at[3]), 2 * TOP_R - 2.4, 0.3, {
				name = "VolcanoLava",
				color = theme.glow,
				material = "Neon",
				collide = false,
				role = "Glow",
			})
		)
		-- Smoke source: an invisible part just above the lava pool.
		table.insert(
			parts,
			spec("Block", v(2, 0.4, 2), yawed(v(at[1], y + 2, at[3]), 0), {
				name = "VolcanoSmoke",
				color = { 90, 86, 86 },
				collide = false,
				transparency = 1,
				role = "Smoke",
			})
		)
		-- Lava streams: over the crater rim, then from layer edge to layer edge (resting
		-- on the outer top corners, shifted out by half their thickness) down to the ground.
		local THICK = 0.3
		local lavaProps =
			{ name = "LavaStream", color = theme.glow, material = "Neon", collide = false, role = "Landmark" }
		-- Corners in (r, height) from the crater rim down to the ground.
		local corners = { { TOP_R - 0.3, y + 0.8 } }
		for k = LAYERS, 1, -1 do
			table.insert(corners, { radius(k), baseY + k * layerH })
		end
		table.insert(corners, { BASE_R + 0.8, baseY + 0.1 })
		for _, angle in { 15, -60, 200 } do
			local a = math.rad(angle)
			local out = v(math.cos(a), 0, math.sin(a))
			local function at2(r: number, height: number): V
				return add(v(at[1], height, at[3]), scale(out, r))
			end
			table.insert(parts, beam(at2(TOP_R - 1.4, y + 0.85), at2(TOP_R, y + 0.85), 1.4, 0.2, lavaProps))
			for i = 1, #corners - 1 do
				local p, q = corners[i], corners[i + 1]
				local dr, dy = q[1] - p[1], q[2] - p[2]
				local len = math.sqrt(dr * dr + dy * dy)
				local nr, ny = -dy / len, dr / len -- outward normal (dy < 0)
				local off = THICK / 2
				table.insert(
					parts,
					beam(
						at2(p[1] + nr * off, p[2] + ny * off),
						at2(q[1] + nr * off, q[2] + ny * off),
						1.4 - 0.03 * i,
						THICK,
						lavaProps
					)
				)
			end
		end
		-- Boulders around the foot (behind and beside the volcano).
		for k = 0, 4 do
			local a = math.rad(-170 + k * 40)
			table.insert(
				parts,
				ball(v(at[1] + math.cos(a) * 15.5, baseY + 0.8, at[3] + math.sin(a) * 15.5), 3 + noise(k, 5), {
					name = "VolcanoBoulder",
					color = tones[k % #tones + 1],
					role = "Landmark",
				})
			)
		end
	end

	-- World 6 landmark: a three-tier layer cake with icing drips, candles and a cherry.
	local function cake(parts: { PartSpec }, at: V, baseY: number, theme: any)
		local frosting = theme.frosting or { 255, 246, 250 }
		local candy = theme.candy or { theme.rim }
		table.insert(
			parts,
			disc(v(at[1], baseY + 0.5, at[3]), 25, 1, { name = "CakePlate", color = frosting, role = "Landmark" })
		)
		local y = baseY + 1
		local tiers = { { 21.5, 6.5, theme.cliff }, { 15.5, 6, theme.cliffLight }, { 10, 5.5, theme.cliff } }
		for k, tier in tiers do
			local d, h = tier[1], tier[2]
			table.insert(
				parts,
				disc(v(at[1], y + h / 2, at[3]), d, h, { name = "CakeTier", color = tier[3], role = "Landmark" })
			)
			local icing = candy[(k - 1) % #candy + 1]
			table.insert(
				parts,
				disc(
					v(at[1], y + h + 0.4, at[3]),
					d + 0.6,
					0.8,
					{ name = "CakeIcing", color = icing, role = "Landmark" }
				)
			)
			-- Drips down the side.
			local drips = math.floor(d * 0.6)
			for j = 1, drips do
				local a = j / drips * math.pi * 2
				table.insert(
					parts,
					ball(
						v(at[1] + math.cos(a) * (d / 2), y + h - 0.4 - noise(j, k) * 0.6, at[3] + math.sin(a) * (d / 2)),
						1.2,
						{
							name = "CakeDrip",
							color = icing,
							collide = false,
							role = "Landmark",
						}
					)
				)
			end
			y += h + 0.8
		end
		-- Cherry on top, three candles around it (small flames, no light).
		table.insert(
			parts,
			ball(v(at[1], y + 1.3, at[3]), 2.8, { name = "CakeCherry", color = { 220, 30, 50 }, role = "Landmark" })
		)
		for k = 0, 2 do
			local a = k / 3 * math.pi * 2 + 0.5
			local p = v(at[1] + math.cos(a) * 3, y, at[3] + math.sin(a) * 3)
			table.insert(
				parts,
				disc(add(p, v(0, 1.5, 0)), 0.7, 3, {
					name = "CakeCandle",
					color = candy[k % #candy + 2] or frosting,
					collide = false,
					role = "Landmark",
				})
			)
			table.insert(
				parts,
				ball(add(p, v(0, 3.4, 0)), 0.7, {
					name = "CakeFlame",
					color = { 255, 214, 92 },
					material = "Neon",
					collide = false,
					role = "Landmark",
				})
			)
		end
	end

	-- World 7 landmark: a rocket on its launch pad next to a service tower.
	local function rocket(parts: { PartSpec }, at: V, baseY: number, theme: any)
		local white = { 244, 246, 252 }
		local red = { 226, 62, 70 }
		table.insert(
			parts,
			disc(
				v(at[1], baseY + 0.75, at[3]),
				18,
				1.5,
				{ name = "LaunchPad", color = theme.woodDark, role = "Landmark" }
			)
		)
		table.insert(
			parts,
			disc(
				v(at[1], baseY + 1.6, at[3]),
				11,
				0.2,
				{ name = "LaunchPadMark", color = { 255, 206, 70 }, collide = false, role = "Landmark" }
			)
		)
		local foot = baseY + 1.5
		table.insert(
			parts,
			disc(
				v(at[1], foot + 1, at[3]),
				3.6,
				2,
				{ name = "RocketNozzle", color = { 90, 92, 110 }, role = "Landmark" }
			)
		)
		table.insert(
			parts,
			disc(v(at[1], foot + 9.5, at[3]), 6, 15, { name = "RocketBody", color = white, role = "Landmark" })
		)
		table.insert(
			parts,
			disc(v(at[1], foot + 13.5, at[3]), 6.2, 1.2, { name = "RocketBand", color = red, role = "Landmark" })
		)
		for k, d in { 5.2, 4, 2.7, 1.3 } do
			table.insert(
				parts,
				disc(v(at[1], foot + 17 + (k - 1) * 1.3 + 0.65, at[3]), d, 1.3, {
					name = "RocketNose",
					color = red,
					role = "Landmark",
				})
			)
		end
		-- Round window facing the path (+X) and the front (+Z).
		local look = unit(v(1, 0, 1))
		table.insert(
			parts,
			spec(
				"Cylinder",
				v(0.4, 2.2, 2.2),
				matrix(add(v(at[1], foot + 11, at[3]), scale(look, 3)), look, { 0, 1, 0 }, cross(look, { 0, 1, 0 })),
				{
					name = "RocketWindow",
					color = theme.water,
					material = "Glass",
					transparency = 0.2,
					role = "Landmark",
				}
			)
		)
		-- Four fins.
		for k = 0, 3 do
			local a = k * math.pi / 2 + math.pi / 4
			local out = v(math.cos(a), 0, math.sin(a))
			table.insert(
				parts,
				spec(
					"Block",
					v(0.5, 5, 2.6),
					along(add(v(at[1], foot + 3.5, at[3]), scale(out, 3.6)), out),
					{ name = "RocketFin", color = red, role = "Landmark" }
				)
			)
		end
		-- Service tower beside the rocket (towards the back), with an arm to the hull.
		local tower = v(at[1] - 1, foot, at[3] - 8)
		for _, c in { { -1.5, -1.5 }, { 1.5, -1.5 }, { -1.5, 1.5 }, { 1.5, 1.5 } } do
			table.insert(
				parts,
				spec("Block", v(0.6, 20, 0.6), yawed(add(tower, v(c[1], 10, c[2])), 0), {
					name = "TowerLeg",
					color = theme.wood,
					role = "Landmark",
				})
			)
		end
		for h = 4, 20, 4 do
			table.insert(
				parts,
				spec("Block", v(3.6, 0.4, 3.6), yawed(add(tower, v(0, h, 0)), 0), {
					name = "TowerDeck",
					color = theme.woodDark,
					collide = false,
					role = "Landmark",
				})
			)
		end
		table.insert(
			parts,
			beam(add(tower, v(0.5, 14, 1.5)), v(at[1], foot + 14, at[3] - 2.8), 0.8, 0.6, {
				name = "TowerArm",
				color = theme.woodDark,
				collide = false,
				role = "Landmark",
			})
		)
		-- Small lamps on the pad edge (glowing, no light of their own).
		for k = 0, 3 do
			local a = k * math.pi / 2
			table.insert(
				parts,
				ball(v(at[1] + math.cos(a) * 8.2, baseY + 1.8, at[3] + math.sin(a) * 8.2), 0.8, {
					name = "PadLamp",
					color = theme.glow,
					material = "Neon",
					collide = false,
					role = "Landmark",
				})
			)
		end
	end

	-- World 8 landmark (#82): a sunken temple on the terrace - a round stone floor with a
	-- ring of columns (two of them broken), an architrave over the front pair and a giant
	-- glowing pearl in an open clam shell in the middle (the island's only Glow part there).
	local function sunkenTemple(parts: { PartSpec }, at: V, baseY: number, theme: any)
		local stone = theme.ruin or theme.cliffLight
		local stoneDark = theme.ruinDark or theme.cliff
		table.insert(
			parts,
			disc(v(at[1], baseY + 0.6, at[3]), 22, 1.2, { name = "TempleFloor", color = stone, role = "Landmark" })
		)
		table.insert(
			parts,
			disc(v(at[1], baseY + 1.5, at[3]), 15, 0.6, { name = "TempleStep", color = stoneDark, role = "Landmark" })
		)
		local floorTop = baseY + 1.2
		local columns = 8
		for k = 1, columns do
			local angle = (k - 0.5) / columns * math.pi * 2
			local p = v(at[1] + math.cos(angle) * 9, floorTop, at[3] + math.sin(angle) * 9)
			local broken = k == 3 or k == 6
			local height = if broken then 4 + noise(k, 3) * 2 else 11
			table.insert(
				parts,
				spec("Block", v(2.4, 0.8, 2.4), yawed(add(p, v(0, 0.4, 0)), angle), {
					name = "TempleColumnBase",
					color = stoneDark,
					role = "Landmark",
				})
			)
			table.insert(
				parts,
				disc(add(p, v(0, 0.8 + height / 2, 0)), 1.6, height, {
					name = "TempleColumn",
					color = stone,
					role = "Landmark",
				})
			)
			if not broken then
				table.insert(
					parts,
					spec("Block", v(2.6, 0.8, 2.6), yawed(add(p, v(0, 0.8 + height + 0.4, 0)), angle), {
						name = "TempleCapital",
						color = stoneDark,
						role = "Landmark",
					})
				)
			end
		end
		-- Architrave over the two columns facing the path (+X side, k = 1 and 8).
		local a1, a2 = (0.5 / columns) * math.pi * 2, (7.5 / columns) * math.pi * 2
		local top = floorTop + 0.8 + 11 + 0.8
		table.insert(
			parts,
			beam(
				v(at[1] + math.cos(a1) * 9, top + 0.6, at[3] + math.sin(a1) * 9),
				v(at[1] + math.cos(a2) * 9, top + 0.6, at[3] + math.sin(a2) * 9),
				2.8,
				1.2,
				{ name = "TempleArchitrave", color = stone, role = "Landmark" }
			)
		)
		-- Open clam shell with the pearl.
		local shell = theme.shell or { 255, 214, 226 }
		table.insert(
			parts,
			spec("Ball", v(7, 1.6, 6), yawed(v(at[1], floorTop + 1.4, at[3]), 0), {
				name = "TempleClam",
				color = shell,
				role = "Landmark",
			})
		)
		table.insert(
			parts,
			spec("Ball", v(7, 1.4, 6), along(v(at[1] - 1.6, floorTop + 3.6, at[3]), v(0.55, 1, 0)), {
				name = "TempleClamLid",
				color = shell,
				collide = false,
				role = "Landmark",
			})
		)
		table.insert(
			parts,
			ball(v(at[1] + 0.4, floorTop + 3, at[3]), 2.6, {
				name = "TemplePearl",
				color = theme.glow or { 230, 248, 255 },
				material = "Neon",
				collide = false,
				role = "Glow",
			})
		)
	end

	-- World 9 landmark (#83): a stepped jungle temple on the terrace - three stone tiers, a
	-- stair facing the path (+X), a small shrine with four pillars and a roof on top and a
	-- glowing jade gem inside (the only Glow part), moss cushions and lianas hanging down
	-- the tiers. The hidden chest (#100) sits behind it (theme.secretChest).
	local function steppedTemple(parts: { PartSpec }, at: V, baseY: number, theme: any)
		local stone = theme.ruin or theme.cliffLight
		local stoneDark = theme.ruinDark or theme.cliff
		local moss = theme.moss or theme.grass
		local tierH = 3
		local sizes = { 18, 14, 10 }
		for k, size in sizes do
			table.insert(
				parts,
				spec("Block", v(size, tierH, size), yawed(v(at[1], baseY + tierH * (k - 0.5), at[3]), 0), {
					name = "TempleTier",
					color = if k % 2 == 1 then stone else stoneDark,
					role = "Landmark",
				})
			)
		end
		local top = baseY + tierH * #sizes
		-- Stair up the +X face: blocks of rising height, each a bit narrower (no z-fighting).
		local steps = 6
		for k = 1, steps do
			local outer = 13 - (k - 1) * 8 / steps
			local h = tierH * #sizes * k / steps
			table.insert(
				parts,
				spec(
					"Block",
					v(outer - 5, h, 5 - k * 0.04),
					yawed(v(at[1] + (outer + 5) / 2, baseY + h / 2, at[3]), 0),
					{ name = "TempleStair", color = stoneDark, role = "Landmark" }
				)
			)
		end
		-- Shrine: four pillars, a roof slab and a small capstone, the jade gem in the middle.
		for _, c in { { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } } do
			table.insert(
				parts,
				spec("Block", v(1.4, 5, 1.4), yawed(v(at[1] + c[1], top + 2.5, at[3] + c[2]), 0), {
					name = "ShrinePillar",
					color = stone,
					role = "Landmark",
				})
			)
		end
		table.insert(
			parts,
			spec("Block", v(9, 1, 9), yawed(v(at[1], top + 5.5, at[3]), 0), {
				name = "ShrineRoof",
				color = stoneDark,
				role = "Landmark",
			})
		)
		table.insert(
			parts,
			spec("Block", v(5, 1.2, 5), yawed(v(at[1], top + 6.6, at[3]), math.pi / 4), {
				name = "ShrineCap",
				color = stone,
				role = "Landmark",
			})
		)
		table.insert(
			parts,
			spec("Ball", v(2.2, 3, 2.2), yawed(v(at[1], top + 2, at[3]), 0), {
				name = "JadeGem",
				color = theme.glow or { 120, 255, 150 },
				material = "Neon",
				collide = false,
				role = "Glow",
			})
		)
		-- Moss on the tier corners and lianas hanging over the tier edges.
		for k, size in sizes do
			local y = baseY + tierH * k
			for c = 0, 3 do
				local a = c * math.pi / 2 + math.pi / 4
				local r = size / 2 * 1.3
				if (k + c) % 2 == 0 then
					table.insert(
						parts,
						spec(
							"Ball",
							v(3.2, 1.1, 3.2),
							yawed(v(at[1] + math.cos(a) * r, y, at[3] + math.sin(a) * r), a),
							{
								name = "TempleMoss",
								color = moss,
								collide = false,
								role = "Landmark",
							}
						)
					)
				end
			end
		end
		for c, z in { -6, -2, 3, 6.5 } do
			local x = at[1] - 9.15
			local len = 3 + noise(c, 5) * 4
			table.insert(
				parts,
				beam(v(x, baseY + tierH + 0.2, at[3] + z), v(x - 0.1, baseY + tierH - len, at[3] + z + 0.3), 0.3, 0.3, {
					name = "TempleLiana",
					color = moss,
					collide = false,
					role = "Landmark",
				})
			)
			local zFront = at[3] + (if c % 2 == 0 then 7.15 else -7.15)
			table.insert(
				parts,
				beam(
					v(at[1] + z, baseY + tierH * 2 + 0.2, zFront),
					v(at[1] + z + 0.3, baseY + tierH * 2 - math.min(len, 2.8), zFront),
					0.3,
					0.3,
					{ name = "TempleLiana", color = moss, collide = false, role = "Landmark" }
				)
			)
		end
	end

	-- World 10 landmark (#84): a big step pyramid on the terrace - five sandstone tiers, a
	-- dark entrance facing the path (+X), a golden capstone that glows (the only Glow part
	-- there) and two obelisks with golden tips beside the entrance.
	local function greatPyramid(parts: { PartSpec }, at: V, baseY: number, theme: any)
		local stone = theme.ruin or theme.cliffLight
		local stoneDark = theme.ruinDark or theme.cliff
		local gold = theme.gold or { 255, 200, 70 }
		local tiers = { 22, 18, 14, 10, 6 }
		local tierHeight = 3
		for k, width in tiers do
			table.insert(
				parts,
				spec("Block", v(width, tierHeight, width), yawed(v(at[1], baseY + (k - 0.5) * tierHeight, at[3]), 0), {
					name = "PyramidTier",
					color = if k % 2 == 0 then stoneDark else stone,
					role = "Landmark",
				})
			)
		end
		local top = baseY + #tiers * tierHeight
		table.insert(
			parts,
			spec("Block", v(3, 3, 3), yawed(v(at[1], top + 1.5, at[3]), math.pi / 4), {
				name = "PyramidCapstone",
				color = gold,
				material = "Neon",
				collide = false,
				role = "Glow",
			})
		)
		-- Entrance: a dark doorway on the front of the lowest tier with a lintel above.
		table.insert(
			parts,
			spec("Block", v(0.4, 4.2, 3.2), yawed(v(at[1] + 11.05, baseY + 2.1, at[3]), 0), {
				name = "PyramidDoor",
				color = { 70, 50, 34 },
				collide = false,
				role = "Landmark",
			})
		)
		table.insert(
			parts,
			spec("Block", v(1, 1, 4.6), yawed(v(at[1] + 11.3, baseY + 4.7, at[3]), 0), {
				name = "PyramidLintel",
				color = stoneDark,
				role = "Landmark",
			})
		)
		for _, side in { -1, 1 } do
			local o = v(at[1] + 13.5, baseY, at[3] + side * 6)
			table.insert(
				parts,
				spec("Block", v(1.6, 9, 1.6), yawed(add(o, v(0, 4.5, 0)), 0), {
					name = "Obelisk",
					color = stone,
					role = "Landmark",
				})
			)
			table.insert(
				parts,
				spec("Block", v(1.1, 1.1, 1.1), yawed(add(o, v(0, 9.5, 0)), math.pi / 4), {
					name = "ObeliskTip",
					color = gold,
					collide = false,
					role = "Landmark",
				})
			)
		end
	end

	local LANDMARKS = {
		SteppedTemple = steppedTemple,
		GiantPizza = giantPizza,
		Windmill = windmill,
		Lighthouse = lighthouse,
		IcePeak = icePeak,
		Volcano = volcano,
		Cake = cake,
		Rocket = rocket,
		SunkenTemple = sunkenTemple,
		GreatPyramid = greatPyramid,
	}

	local function localToWorld(center: V, p: { number }): V
		return v(center[1] + p[1], groundY, center[3] + p[2])
	end

	-- Yaw that turns a -Z-facing station so its front looks along (dx, dz).
	local function facing(dx: number, dz: number): number
		return math.atan2(-dx, -dz)
	end

	local function newIsland(kind: string, center: V): Island
		return {
			kind = kind,
			center = center,
			outline = {},
			parts = {},
			models = {},
			stations = {},
			openings = {},
		}
	end

	-- ---------------------------------------------------------------- spawn marketplace

	-- Point `x` studs to the right and `z` studs to the back of a station (yaw 0 = -Z).
	local function offset(p: V, yaw: number, x: number, y: number, z: number): V
		local c, s = math.cos(yaw), math.sin(yaw)
		return v(p[1] + c * x + s * z, p[2] + y, p[3] - s * x + c * z)
	end

	-- Sign on two posts (#106): a cream panel `PanelName` (the server puts the text on its
	-- front, local -Z) and a coloured title strip `TitleName` on top. All parts carry
	-- `role`, so the server can hide the whole sign (feature off, countdown over).
	local function signStand(
		island: Island,
		station: Station,
		prefix: string,
		role: string,
		size: { number },
		stripColor: { number },
		theme: any
	)
		local p, yaw = station.position, station.yaw
		local width, height = size[1], size[2]
		local bottom = 2.4
		for _, side in { -1, 1 } do
			table.insert(
				island.parts,
				disc(
					offset(p, yaw, side * (width / 2 + 0.2), (bottom + height + 1.2) / 2, 0.2),
					0.9,
					bottom + height + 1.2,
					{
						name = `{prefix}Post`,
						color = theme.wood,
						role = role,
					}
				)
			)
		end
		table.insert(
			island.parts,
			spec("Block", v(width, height, 0.6), yawed(offset(p, yaw, 0, bottom + height / 2, 0), yaw), {
				name = `{prefix}Panel`,
				color = { 255, 248, 230 },
				role = role,
			})
		)
		table.insert(
			island.parts,
			spec("Block", v(width + 1, 1.6, 0.9), yawed(offset(p, yaw, 0, bottom + height + 0.8, 0), yaw), {
				name = `{prefix}Title`,
				color = stripColor,
				role = role,
			})
		)
	end

	-- Wooden bench facing the station's front (seat, backrest, two legs).
	local function bench(island: Island, p: V, yaw: number, theme: any)
		local wood = theme.wood
		table.insert(
			island.parts,
			spec("Block", v(5, 0.4, 1.6), yawed(offset(p, yaw, 0, 1.4, 0), yaw), {
				name = "BenchSeat",
				color = wood,
				role = "Deco",
			})
		)
		table.insert(
			island.parts,
			spec("Block", v(5, 1.4, 0.3), yawed(offset(p, yaw, 0, 2.3, 0.75), yaw), {
				name = "BenchBack",
				color = wood,
				role = "Deco",
			})
		)
		for _, side in { -1, 1 } do
			table.insert(
				island.parts,
				spec("Block", v(0.4, 1.2, 1.4), yawed(offset(p, yaw, side * 2.1, 0.6, 0), yaw), {
					name = "BenchLeg",
					color = theme.cliffDark,
					role = "Deco",
				})
			)
		end
	end

	-- Lantern: thin post, glowing lamp (role Glow: the server adds a small light), cap.
	local function lantern(island: Island, p: V, theme: any)
		table.insert(
			island.parts,
			disc(v(p[1], groundY + 3, p[3]), 0.6, 6, { name = "LanternPost", color = { 70, 60, 55 }, role = "Deco" })
		)
		table.insert(
			island.parts,
			ball(v(p[1], groundY + 6.6, p[3]), 1.4, {
				name = "LanternLamp",
				color = { 255, 214, 140 },
				material = "Neon",
				collide = false,
				role = "Glow",
			})
		)
		table.insert(
			island.parts,
			disc(v(p[1], groundY + 7.45, p[3]), 1.6, 0.3, {
				name = "LanternCap",
				color = { 70, 60, 55 },
				collide = false,
				role = "Deco",
			})
		)
	end

	-- Marketplace on the spawn island (#106): update board, countdown sign, benches around
	-- the fountain, lanterns, paths to the reserved wheel and merchant spots.
	local function marketplace(island: Island, layout: any, theme: any)
		local stations = island.stations
		local c = island.center
		signStand(island, stations.UpdateBoard, "UpdateBoard", "UpdateBoard", { 9, 7 }, { 240, 130, 60 }, theme)
		signStand(island, stations.Countdown, "Countdown", "Countdown", { 9, 3.5 }, { 60, 150, 70 }, theme)

		local f = stations.Fountain.position
		for _, degrees in layout.benchAngles do
			local a = math.rad(degrees)
			local p = v(f[1] + math.cos(a) * layout.benchRadius, groundY, f[3] + math.sin(a) * layout.benchRadius)
			bench(island, p, facing(f[1] - p[1], f[3] - p[3]), theme)
		end
		for _, spot in layout.lanterns do
			lantern(island, localToWorld(c, spot), theme)
		end

		-- Short paths from the main path to the wheel and the merchant spot.
		for i, name in { "Wheel", "Merchant" } do
			local station = stations[name]
			local p = station.position
			local side = if p[1] > c[1] then 1 else -1
			local stop = (station.clear or 9) - 2
			plates(
				island.parts,
				v(c[1] + side * pathWidth / 2, groundY, p[3]),
				v(p[1] - side * stop, groundY, p[3]),
				5.5,
				theme,
				60 + i * 10
			)
		end
	end

	-- ---------------------------------------------------------------- spawn island

	function plan.spawnIsland(): Island
		local island = newIsland("spawn", spawnCenter)
		local theme = defaultTheme
		local layout = config.spawnLayout
		local openings
		island.outline, openings = roundOutline({
			center = spawnCenter,
			radius = spawnRadius,
			exponent = 2.4,
			wobble = 0.08,
			seed = 5,
			openFront = false,
			openBack = true,
			openingHalf = bridgeWidth / 2,
		})
		island.openings.back = v(spawnCenter[1], groundY, spawnCenter[3] - spawnRadius)

		local c = spawnCenter
		local stations = island.stations
		stations.Spawn = { position = localToWorld(c, layout.spawn), yaw = 0 }
		stations.Fountain = { position = localToWorld(c, layout.fountain), yaw = 0 }
		local portal = localToWorld(c, layout.portal)
		stations.Portal = { position = portal, yaw = facing(c[1] - portal[1], c[3] - portal[3]) }
		-- Update board and Christmas countdown face the spawn (#106); reserved spots face
		-- the middle of the island.
		local spawnAt = stations.Spawn.position
		for name, spot in { UpdateBoard = layout.updateBoard, Countdown = layout.countdown } do
			local p = localToWorld(c, spot)
			stations[name] = { position = p, yaw = facing(spawnAt[1] - p[1], spawnAt[3] - p[3]) }
		end
		for name, spot in layout.reserved do
			local p = localToWorld(c, spot)
			stations[name] = { position = p, yaw = facing(c[1] - p[1], c[3] - p[3]), clear = spot[3] }
		end
		for i, spot in layout.boards do
			local p = localToWorld(c, spot)
			local yaw = facing(c[1] - p[1], c[3] - p[3])
			stations[`Board{i}`] = { position = p, yaw = yaw }
			-- Leaderboard: two posts, a cream panel (the server puts the text on its front,
			-- local -Z) and an orange title strip.
			local rightX, rightZ = math.cos(yaw), -math.sin(yaw)
			for _, s in { -1, 1 } do
				table.insert(
					island.parts,
					disc(v(p[1] + rightX * s * 6.2, groundY + 5, p[3] + rightZ * s * 6.2), 1.2, 10, {
						name = "BoardPost",
						color = theme.wood,
						role = "Board",
					})
				)
			end
			table.insert(
				island.parts,
				spec("Block", v(12, 7.5, 0.8), yawed(v(p[1], groundY + 6.2, p[3]), yaw), {
					name = "BoardPanel",
					color = { 255, 248, 230 },
					role = "Board",
				})
			)
			table.insert(
				island.parts,
				spec("Block", v(13.2, 1.8, 1.2), yawed(v(p[1], groundY + 10.6, p[3]), yaw), {
					name = "BoardTitle",
					color = { 240, 130, 60 },
					role = "Board",
				})
			)
		end

		local pondAt = localToWorld(c, layout.pond)
		local gap = pond(island, pondAt, 6, theme)
		shell(island, openings, theme, 0.75, { gap })

		-- Paths: ring around the fountain, then on to the spawn, the bridge and the portal.
		local fountain = stations.Fountain.position
		local ringRadius = 15
		for i = 1, 16 do
			local a1, a2 = (i - 1) / 16 * math.pi * 2, i / 16 * math.pi * 2
			plates(
				island.parts,
				v(fountain[1] + math.cos(a1) * ringRadius, groundY, fountain[3] + math.sin(a1) * ringRadius),
				v(fountain[1] + math.cos(a2) * ringRadius, groundY, fountain[3] + math.sin(a2) * ringRadius),
				5.5,
				theme,
				i
			)
		end
		plates(
			island.parts,
			v(c[1], groundY, c[3] - spawnRadius),
			v(c[1], groundY, fountain[3] - ringRadius - 2.75),
			pathWidth,
			theme,
			40
		)
		plates(
			island.parts,
			v(c[1], groundY, fountain[3] + ringRadius + 2.75),
			add(stations.Spawn.position, v(0, 0, 5)),
			8,
			theme,
			50
		)
		plates(
			island.parts,
			v(fountain[1] - ringRadius - 2.75, groundY, portal[3]),
			add(portal, v(6, 0, 0)),
			6,
			theme,
			60
		)

		-- Pizza fountain: stone basin with water, a pedestal and a pizza dish on top.
		local stone = { 200, 190, 180 }
		local f = fountain
		table.insert(
			island.parts,
			disc(v(f[1], groundY + 1.1, f[3]), 22, 2.2, { name = "Basin", color = stone, role = "Fountain" })
		)
		table.insert(
			island.parts,
			disc(v(f[1], groundY + 2.05, f[3]), 19.5, 0.4, {
				name = "FountainWater",
				color = theme.water,
				material = "Glass",
				collide = false,
				transparency = 0.15,
				role = "Water",
			})
		)
		table.insert(
			island.parts,
			disc(v(f[1], groundY + 4.5, f[3]), 3.6, 5, { name = "Column", color = stone, role = "Fountain" })
		)
		table.insert(
			island.parts,
			disc(
				v(f[1], groundY + 7.3, f[3]),
				11,
				0.9,
				{ name = "PizzaDish", color = { 214, 140, 60 }, role = "Fountain" }
			)
		)
		table.insert(
			island.parts,
			disc(
				v(f[1], groundY + 7.8, f[3]),
				9.4,
				0.3,
				{ name = "PizzaDishSauce", color = { 214, 52, 34 }, collide = false, role = "Fountain" }
			)
		)
		table.insert(
			island.parts,
			disc(
				v(f[1], groundY + 8.0, f[3]),
				8.2,
				0.25,
				{ name = "PizzaDishCheese", color = { 255, 214, 92 }, collide = false, role = "Fountain" }
			)
		)
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			table.insert(
				island.parts,
				disc(v(f[1] + math.cos(a) * 2.6, groundY + 8.15, f[3] + math.sin(a) * 2.6), 1.8, 0.2, {
					name = "PizzaDishSalami",
					color = { 150, 28, 46 },
					collide = false,
					role = "Fountain",
				})
			)
			-- Water pouring from the dish into the basin.
			table.insert(
				island.parts,
				spec(
					"Block",
					v(0.7, 5.2, 0.7),
					yawed(v(f[1] + math.cos(a + 0.6) * 5.6, groundY + 4.6, f[3] + math.sin(a + 0.6) * 5.6), 0),
					{
						name = "FountainJet",
						color = { 170, 225, 255 },
						material = "Glass",
						collide = false,
						transparency = 0.25,
						role = "Water",
					}
				)
			)
		end
		table.insert(
			island.parts,
			ball(v(f[1], groundY + 9.6, f[3]), 1.6, {
				name = "FountainSpout",
				color = { 170, 225, 255 },
				material = "Glass",
				collide = false,
				transparency = 0.3,
				role = "Water",
			})
		)

		local function keepOut(x: number, z: number, r: number): boolean
			if math.abs(x - c[1]) < pathWidth / 2 + r + 1 then
				return true
			end
			if math.sqrt((x - f[1]) ^ 2 + (z - f[3]) ^ 2) < ringRadius + 4 + r then
				return true
			end
			for _, station in stations do
				local p = station.position
				if math.sqrt((x - p[1]) ^ 2 + (z - p[3]) ^ 2) < r + (station.clear or 9) then
					return true
				end
			end
			if math.sqrt((x - pondAt[1]) ^ 2 + (z - pondAt[3]) ^ 2) < 6 + r + 2 then
				return true
			end
			-- The stream from the pond to the rim.
			if math.abs(z - pondAt[3]) < r + 3 and (x - pondAt[1]) * (gap[1] - pondAt[1]) > 0 then
				return true
			end
			return false
		end
		marketplace(island, layout, theme)
		scatterTrees(island, keepOut, 3, theme)
		for i, spot in layout.flowerBeds do
			flowers(island, localToWorld(c, spot), 8, 6, theme, i * 11)
		end
		return island
	end

	-- ---------------------------------------------------------------- world islands

	-- A world-style island at `center`. `index` seeds the irregular shapes (world index,
	-- or 100 + slot for event islands); openBack/openFront = bridge openings on the rim.
	-- ---------------------------------------------------------------- scripted deco (#82)
	-- Theme-driven decoration of the new worlds, built from a few reusable kits instead of
	-- imported models (works without any import). theme.deco = { budget, kits = { { kit,
	-- count, colors?, size = { min, max } } } }; kits: "Coral" (branchy or fan coral),
	-- "Column" (standing, broken or fallen ruin column), "Kelp" (swaying strands),
	-- "Bubbles" (invisible emitter part, IslandRole "Bubbles"), "Lamp" (glowing orb on a
	-- stone, role Glow = small light; keep few). Spots are taken like trees (clear of the
	-- field, path, stations, pond and terraces), every part is marked `deco` and counted
	-- against `budget`; optional bits are `detail` (hidden on graphics "Low").
	local DECO_KITS: { [string]: (at: V, size: number, yaw: number, colors: { { number } }, k: number, theme: any) -> { PartSpec } } =
		{}

	function DECO_KITS.Coral(at: V, size: number, yaw: number, colors: { { number } }, k: number, theme: any)
		local parts = {}
		local color = colors[(k - 1) % #colors + 1]
		local tip = colors[k % #colors + 1]
		table.insert(
			parts,
			disc(add(at, v(0, size * 0.1, 0)), size * 0.55, size * 0.2, {
				name = "CoralRock",
				color = theme.cliffLight,
				collide = false,
				role = "Coral",
				deco = true,
			})
		)
		if k % 3 == 0 then
			-- Fan coral: a thin upright fan with a lighter rim on top.
			table.insert(
				parts,
				spec("Ball", v(size, size * 0.9, size * 0.14), yawed(add(at, v(0, size * 0.55, 0)), yaw), {
					name = "CoralFan",
					color = color,
					collide = false,
					role = "Coral",
					deco = true,
				})
			)
			return parts
		end
		local branches = 2 + k % 2
		for b = 1, branches do
			local angle = yaw + (b - 1) / branches * math.pi * 2
			local lean = 0.25 + noise(k, b) * 0.2
			local from = add(at, v(0, size * 0.15, 0))
			local to = add(
				at,
				v(math.cos(angle) * size * lean, size * (0.7 + noise(b, k) * 0.35), math.sin(angle) * size * lean)
			)
			table.insert(
				parts,
				beam(from, to, size * 0.16, size * 0.16, {
					name = "CoralBranch",
					color = color,
					collide = false,
					role = "Coral",
					deco = true,
				})
			)
			table.insert(
				parts,
				ball(to, size * 0.26, {
					name = "CoralTip",
					color = tip,
					material = if b == 1 and k % 4 == 1 then "Neon" else "SmoothPlastic",
					role = "Coral",
					deco = true,
					detail = true,
				})
			)
		end
		return parts
	end

	function DECO_KITS.Column(at: V, size: number, yaw: number, colors: { { number } }, k: number, theme: any)
		local parts = {}
		local stone = colors[1] or theme.cliffLight
		local dark = colors[2] or theme.cliff
		local d = size * 0.22
		table.insert(
			parts,
			spec("Block", v(d * 1.5, size * 0.08, d * 1.5), yawed(add(at, v(0, size * 0.04, 0)), yaw), {
				name = "RuinBase",
				color = dark,
				role = "Ruin",
				deco = true,
			})
		)
		local variant = k % 3
		if variant == 2 then
			-- Fallen: the shaft lies beside its base, a little sunk into the sand.
			local c, sn = math.cos(yaw), math.sin(yaw)
			table.insert(
				parts,
				spec(
					"Cylinder",
					v(size * 0.8, d, d),
					yawed(add(at, v(c * size * 0.5, d * 0.4, -sn * size * 0.5)), yaw),
					{ name = "RuinFallen", color = stone, role = "Ruin", deco = true }
				)
			)
			return parts
		end
		local height = if variant == 0 then size else size * (0.45 + noise(k, 9) * 0.2)
		table.insert(
			parts,
			disc(add(at, v(0, size * 0.08 + height / 2, 0)), d, height, {
				name = "RuinColumn",
				color = stone,
				role = "Ruin",
				deco = true,
			})
		)
		if variant == 0 then
			table.insert(
				parts,
				spec(
					"Block",
					v(d * 1.6, size * 0.08, d * 1.6),
					yawed(add(at, v(0, size * 0.12 + height, 0)), yaw),
					{ name = "RuinCapital", color = dark, role = "Ruin", deco = true, detail = true }
				)
			)
		else
			-- Broken: a chunk of the shaft lies next to it.
			table.insert(
				parts,
				spec(
					"Block",
					v(d * 0.9, d * 0.7, d * 1.1),
					yawed(add(at, v(math.sin(yaw) * d * 1.6, d * 0.35, math.cos(yaw) * d * 1.6)), yaw + 0.6),
					{ name = "RuinChunk", color = stone, role = "Ruin", deco = true, detail = true }
				)
			)
		end
		return parts
	end

	function DECO_KITS.Kelp(at: V, size: number, yaw: number, colors: { { number } }, k: number, theme: any)
		local parts = {}
		local strands = 2 + k % 2
		for b = 1, strands do
			local color = colors[(k + b) % #colors + 1]
			local angle = yaw + b * 2.1
			local base = add(at, v(math.cos(angle) * size * 0.15, 0, math.sin(angle) * size * 0.15))
			local lean = (noise(k, b) - 0.5) * size * 0.35
			local top = add(base, v(math.cos(angle) * lean, size * (0.75 + noise(b, k) * 0.4), math.sin(angle) * lean))
			table.insert(
				parts,
				beam(base, top, size * 0.12, size * 0.04, {
					name = "Kelp",
					color = color,
					role = "Kelp",
					deco = true,
					detail = b > 1,
					collide = false,
				})
			)
		end
		return parts
	end

	function DECO_KITS.Bubbles(at: V, size: number, yaw: number, colors: { { number } }, k: number, theme: any)
		return {
			spec("Block", v(size, 0.4, size), yawed(add(at, v(0, 0.4, 0)), yaw), {
				name = "BubbleVent",
				color = colors[1] or { 210, 240, 255 },
				transparency = 1,
				collide = false,
				role = "Bubbles",
				deco = true,
			}),
		}
	end

	function DECO_KITS.Lamp(at: V, size: number, yaw: number, colors: { { number } }, k: number, theme: any)
		return {
			disc(add(at, v(0, size * 0.3, 0)), size * 0.7, size * 0.6, {
				name = "LampStone",
				color = theme.ruinDark or theme.cliff,
				role = "Lamp",
				deco = true,
			}),
			ball(add(at, v(0, size * 0.6 + size * 0.3, 0)), size * 0.6, {
				name = "LampOrb",
				color = colors[1] or theme.glow,
				material = "Neon",
				role = "Glow",
				deco = true,
				detail = true,
			}),
		}
	end

	-- Jungle kits (#83). JungleTree: a tall trunk (collides) with a root flare, two or three
	-- leaf crowns and lianas hanging from the crown edge (optional, detail).
	function DECO_KITS.JungleTree(at: V, size: number, yaw: number, colors: { { number } }, k: number, theme: any)
		local parts = {}
		local trunkD = size * 0.09
		local height = size * 0.75
		table.insert(
			parts,
			disc(add(at, v(0, height / 2, 0)), trunkD, height, {
				name = "JungleTrunk",
				color = theme.wood,
				role = "Tree",
				deco = true,
			})
		)
		table.insert(
			parts,
			disc(add(at, v(0, size * 0.04, 0)), trunkD * 2, size * 0.08, {
				name = "JungleRoots",
				color = theme.woodDark,
				collide = false,
				role = "Tree",
				deco = true,
			})
		)
		local crowns = 2 + k % 2
		local tips = {}
		for b = 1, crowns do
			local angle = yaw + b * 2.2
			local off = if b == 1 then 0 else size * 0.16
			local c = add(at, v(math.cos(angle) * off, height + size * (0.02 - b * 0.03), math.sin(angle) * off))
			local w = size * (0.55 - b * 0.06)
			table.insert(
				parts,
				spec("Ball", v(w, w * 0.42, w), yawed(c, angle), {
					name = "JungleCrown",
					color = colors[(k + b) % math.max(1, #colors) + 1] or theme.grass,
					collide = false,
					role = "Tree",
					deco = true,
				})
			)
			table.insert(tips, { c = c, w = w, angle = angle })
		end
		-- Lianas: thin strands from the crown's underside, swinging a little outwards.
		local strands = 2 + k % 2
		for s = 1, strands do
			local crown = tips[(s - 1) % #tips + 1]
			local a = crown.angle + s * 1.9
			local from = add(crown.c, v(math.cos(a) * crown.w * 0.32, -crown.w * 0.12, math.sin(a) * crown.w * 0.32))
			local drop = size * (0.3 + noise(k, s) * 0.25)
			local to = add(from, v(math.cos(a) * 0.6, -drop, math.sin(a) * 0.6))
			table.insert(
				parts,
				beam(from, to, 0.28, 0.28, {
					name = "Liana",
					color = theme.moss or theme.rope,
					role = "Liana",
					deco = true,
					detail = true,
				})
			)
		end
		return parts
	end

	-- Fern: four or five leaves fanned out around the middle, tilted outwards.
	function DECO_KITS.Fern(at: V, size: number, yaw: number, colors: { { number } }, k: number, theme: any)
		local parts = {}
		local leaves = 4 + k % 2
		for b = 1, leaves do
			local angle = yaw + (b - 1) / leaves * math.pi * 2
			local dir = v(math.cos(angle), 0, math.sin(angle))
			local tip = add(at, add(scale(dir, size * 0.5), v(0, size * (0.35 + noise(k, b) * 0.15), 0)))
			table.insert(
				parts,
				beam(add(at, v(0, 0.2, 0)), tip, size * 0.22, 0.15, {
					name = "FernLeaf",
					color = colors[(k + b) % math.max(1, #colors) + 1] or theme.grass,
					collide = false,
					role = "Fern",
					deco = true,
					detail = b > 3,
				})
			)
		end
		return parts
	end

	-- Idol: a carved stone head (block with brow, dark eyes and mouth) under a moss cap.
	function DECO_KITS.Idol(at: V, size: number, yaw: number, colors: { { number } }, k: number, theme: any)
		local stone = colors[1] or theme.ruin or theme.cliffLight
		local moss = colors[2] or theme.moss or theme.grass
		local dark = theme.ruinDark or theme.cliffDark
		local w = size * 0.7
		local c, sn = math.cos(yaw), math.sin(yaw)
		-- Front of the face = local -Z of yawed().
		local function front(d: number, y: number, side: number): V
			return add(at, v(-sn * d + c * side, y, -c * d - sn * side))
		end
		local parts = {
			spec("Block", v(w, size, w * 0.8), yawed(add(at, v(0, size / 2, 0)), yaw), {
				name = "IdolHead",
				color = stone,
				role = "Ruin",
				deco = true,
			}),
			spec("Block", v(w * 1.1, size * 0.14, w * 0.3), yawed(front(w * 0.42, size * 0.68, 0), yaw), {
				name = "IdolBrow",
				color = dark,
				collide = false,
				role = "Ruin",
				deco = true,
			}),
			spec("Block", v(w * 0.6, size * 0.1, 0.2), yawed(front(w * 0.41, size * 0.25, 0), yaw), {
				name = "IdolMouth",
				color = dark,
				collide = false,
				role = "Ruin",
				deco = true,
				detail = true,
			}),
		}
		for _, side in { -1, 1 } do
			table.insert(
				parts,
				spec("Block", v(w * 0.18, size * 0.12, 0.2), yawed(front(w * 0.41, size * 0.5, side * w * 0.22), yaw), {
					name = "IdolEye",
					color = if k % 2 == 0 then theme.glow else dark,
					material = if k % 2 == 0 then "Neon" else "SmoothPlastic",
					collide = false,
					role = "Ruin",
					deco = true,
					detail = true,
				})
			)
		end
		table.insert(
			parts,
			spec("Ball", v(w * 1.05, size * 0.3, w * 0.9), yawed(add(at, v(0, size, 0)), yaw), {
				name = "IdolMoss",
				color = moss,
				collide = false,
				role = "Ruin",
				deco = true,
				detail = true,
			})
		)
		return parts
	end

	-- Fireflies and Mist: invisible emitter parts (IslandBuilder adds the particles).
	function DECO_KITS.Fireflies(at: V, size: number, yaw: number, colors: { { number } }, k: number, theme: any)
		return {
			spec("Block", v(size, size * 0.4, size), yawed(add(at, v(0, 2 + size * 0.2, 0)), yaw), {
				name = "FireflySwarm",
				color = colors[1] or theme.glow,
				transparency = 1,
				collide = false,
				role = "Fireflies",
				deco = true,
			}),
		}
	end

	function DECO_KITS.Mist(at: V, size: number, yaw: number, colors: { { number } }, k: number, theme: any)
		return {
			spec("Block", v(size, 0.4, size), yawed(add(at, v(0, 0.6, 0)), yaw), {
				name = "MistPatch",
				color = colors[1] or { 230, 240, 235 },
				transparency = 1,
				collide = false,
				role = "Mist",
				deco = true,
			}),
		}
	end

	-- Desert Pyramids kits (#84): "Dune" (a sand ridge of two wedges, long windward and
	-- short lee side), "Pyramid" (small step pyramid), "Oasis" (pond with palms) and
	-- "Cactus" (saguaro with arms and a flower).
	function DECO_KITS.Dune(at: V, size: number, yaw: number, colors: { { number } }, k: number, theme: any)
		local sand = colors[(k - 1) % #colors + 1] or theme.grass
		local height = size * (0.18 + noise(k, 4) * 0.08)
		local width = size * 0.55
		local c, s = math.cos(yaw), math.sin(yaw)
		local back = v(s, 0, c)
		local long, short = size * 0.6, size * 0.28
		local ridge = add(at, v(0, height / 2 - 0.15, 0))
		return {
			spec("Wedge", v(width, height, long), yawed(add(ridge, scale(back, -long / 2)), yaw), {
				name = "Dune",
				color = sand,
				role = "Dune",
				deco = true,
			}),
			spec("Wedge", v(width, height, short), yawed(add(ridge, scale(back, short / 2)), yaw + math.pi), {
				name = "DuneLee",
				color = colors[k % #colors + 1] or sand,
				role = "Dune",
				deco = true,
			}),
		}
	end

	function DECO_KITS.Pyramid(at: V, size: number, yaw: number, colors: { { number } }, k: number, theme: any)
		local parts = {}
		local stone = colors[1] or theme.cliffLight
		local dark = colors[2] or theme.cliff
		local tiers = 3 + k % 2
		local step = size / tiers
		local h = size * 0.22
		for t = 1, tiers do
			local w = size - (t - 1) * step
			table.insert(
				parts,
				spec("Block", v(w, h, w), yawed(add(at, v(0, (t - 0.5) * h, 0)), yaw), {
					name = "MiniPyramid",
					color = if t % 2 == 0 then dark else stone,
					role = "Pyramid",
					deco = true,
					-- The small top tier is optional.
					detail = t == tiers,
				})
			)
		end
		return parts
	end

	function DECO_KITS.Oasis(at: V, size: number, yaw: number, colors: { { number } }, k: number, theme: any)
		local parts = {}
		table.insert(
			parts,
			disc(add(at, v(0, 0.12, 0)), size, 0.24, {
				name = "OasisShore",
				color = theme.grassLight or theme.grass,
				collide = false,
				role = "Oasis",
				deco = true,
			})
		)
		table.insert(
			parts,
			disc(add(at, v(0, 0.3, 0)), size * 0.72, 0.2, {
				name = "OasisWater",
				color = theme.water,
				material = "Glass",
				transparency = 0.2,
				collide = false,
				role = "Oasis",
				deco = true,
			})
		)
		local leaf = colors[1] or { 70, 160, 70 }
		local leafDark = colors[2] or leaf
		local trunk = theme.wood or { 160, 120, 80 }
		local palms = 1 + k % 2
		for b = 1, palms do
			local angle = yaw + b * 2.4
			local base = add(at, v(math.cos(angle) * size * 0.44, 0, math.sin(angle) * size * 0.44))
			local height = size * (0.7 + noise(k, b) * 0.25)
			local lean = size * 0.15
			local top = add(base, v(-math.cos(angle) * lean, height, -math.sin(angle) * lean))
			table.insert(
				parts,
				beam(base, top, size * 0.08, size * 0.08, {
					name = "PalmTrunk",
					color = trunk,
					role = "Oasis",
					deco = true,
				})
			)
			for f = 1, 4 do
				local a = angle + f * math.pi / 2 + 0.4
				local tip = add(top, v(math.cos(a) * size * 0.32, -size * 0.1, math.sin(a) * size * 0.32))
				table.insert(
					parts,
					beam(top, tip, size * 0.14, size * 0.03, {
						name = "PalmLeaf",
						color = if f % 2 == 0 then leafDark else leaf,
						collide = false,
						role = "Oasis",
						deco = true,
						detail = f > 2,
					})
				)
			end
		end
		return parts
	end

	function DECO_KITS.Cactus(at: V, size: number, yaw: number, colors: { { number } }, k: number, theme: any)
		local parts = {}
		local green = colors[(k - 1) % #colors + 1] or { 80, 150, 80 }
		local d = size * 0.2
		table.insert(
			parts,
			disc(add(at, v(0, size / 2, 0)), d, size, {
				name = "Cactus",
				color = green,
				role = "Cactus",
				deco = true,
			})
		)
		local arms = k % 3
		for a = 1, arms do
			local side = if a == 1 then 1 else -1
			local c, s = math.cos(yaw) * side, math.sin(yaw) * side
			local h = size * (0.35 + noise(k, a) * 0.2)
			local out = d * 1.3
			table.insert(
				parts,
				beam(add(at, v(0, h, 0)), add(at, v(c * out, h, -s * out)), d * 0.7, d * 0.7, {
					name = "CactusArm",
					color = green,
					collide = false,
					role = "Cactus",
					deco = true,
				})
			)
			table.insert(
				parts,
				disc(add(at, v(c * out, h + size * 0.15, -s * out)), d * 0.7, size * 0.32, {
					name = "CactusArm",
					color = green,
					collide = false,
					role = "Cactus",
					deco = true,
				})
			)
		end
		if k % 2 == 0 then
			table.insert(
				parts,
				ball(add(at, v(0, size + d * 0.1, 0)), d * 0.7, {
					name = "CactusFlower",
					color = theme.flowers and theme.flowers[k % #theme.flowers + 1] or { 255, 110, 150 },
					role = "Cactus",
					deco = true,
					detail = true,
				})
			)
		end
		return parts
	end

	-- Places theme.deco on a world island (after the trees, sharing their keep-out rules).
	local function scatterDeco(
		island: Island,
		keepOut: (x: number, z: number, r: number) -> boolean,
		seed: number,
		theme: any
	)
		local deco = theme.deco
		if deco == nil then
			return
		end
		local outline = island.outline
		local center = island.center
		-- Candidate spots: rings inside the rim, in a fixed pseudo-random order.
		local spots = {}
		for ring, inset in { 6, 14, 24, 36, 50 } do
			for i, p in outline do
				local dx, dz = p[1] - center[1], p[2] - center[3]
				local d = math.sqrt(dx * dx + dz * dz)
				local x = p[1] - dx / d * inset + (noise(i, seed + ring) - 0.5) * 6
				local z = p[2] - dz / d * inset + (noise(seed + ring, i) - 0.5) * 6
				table.insert(spots, { x = x, z = z, order = noise(i * 7 + ring, seed) })
			end
		end
		-- Plus a loose grid over the whole island (between the field and the rim).
		for gx = -half + 6, half - 6, 9 do
			for gz = -half + 6, half - 6, 9 do
				local x = center[1] + gx + (noise(gx, gz + seed) - 0.5) * 5
				local z = center[3] + gz + (noise(gz + seed, gx) - 0.5) * 5
				table.insert(spots, { x = x, z = z, order = noise(gx * 3 + gz, seed + 1) })
			end
		end
		table.sort(spots, function(a, b)
			return a.order < b.order
		end)
		local placed: { { x: number, z: number, r: number } } = {}
		local used = 0
		local cursor = 1
		local function free(x: number, z: number, r: number): boolean
			if keepOut(x, z, r) then
				return false
			end
			-- The whole piece stands on the island (fallen columns and branches reach out).
			for _, o in { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				if not IslandPlan.isInsideOutline(outline, x + o[1] * (r + 2), z + o[2] * (r + 2)) then
					return false
				end
			end
			for _, other in island.models do
				local ox, oz = other.position[1], other.position[3]
				if math.sqrt((ox - x) ^ 2 + (oz - z) ^ 2) < other.width * 0.45 + r then
					return false
				end
			end
			for _, other in placed do
				if math.sqrt((other.x - x) ^ 2 + (other.z - z) ^ 2) < other.r + r + 0.5 then
					return false
				end
			end
			return true
		end
		for kitIndex, item in deco.kits do
			local build = DECO_KITS[item.kit]
			assert(build, `unknown deco kit {item.kit}`)
			local placedOfKit = 0
			local tries = 0
			while placedOfKit < item.count and cursor <= #spots and tries < #spots do
				tries += 1
				local spot = spots[cursor]
				cursor += 1
				local k = placedOfKit + 1
				local size = lerp(item.size[1], item.size[2], noise(k * 3 + kitIndex, seed))
				local r = size * 0.42
				if free(spot.x, spot.z, r) then
					local parts = build(
						v(spot.x, groundY, spot.z),
						size,
						noise(k, seed + kitIndex) * math.pi * 2,
						item.colors or {},
						k,
						theme
					)
					if used + #parts > deco.budget then
						return
					end
					for _, part in parts do
						table.insert(island.parts, part)
					end
					used += #parts
					placedOfKit += 1
					table.insert(placed, { x = spot.x, z = spot.z, r = r })
				end
			end
			-- Every kit starts over at the first spots that were too close or blocked.
			cursor = 1
		end
	end

	local function buildIsland(center: V, index: number, world: any, openFront: boolean, openBack: boolean): Island
		local island = newIsland("world", center)
		local theme = themeOf(world.id)
		local layout = config.layout
		local openings
		island.outline, openings = roundOutline({
			center = center,
			radius = half,
			exponent = 4,
			wobble = 0.09,
			seed = index * 1.7,
			openFront = openFront,
			openBack = openBack,
			openingHalf = bridgeWidth / 2,
		})
		if openFront then
			island.openings.front = v(center[1], groundY, center[3] + half)
		end
		if openBack then
			island.openings.back = v(center[1], groundY, center[3] - half)
		end

		local fieldCenter = localToWorld(center, layout.field.center)
		island.field = { center = fieldCenter, size = { layout.field.size[1], layout.field.size[2] } }
		local fieldFront = fieldCenter[3] + layout.field.size[2] / 2
		local fieldBack = fieldCenter[3] - layout.field.size[2] / 2

		local stations = island.stations
		local function side(spot: { number }): Station
			local p = localToWorld(center, spot)
			-- Left of the path faces +X, right of it faces -X.
			return { position = p, yaw = if spot[1] < 0 then -math.pi / 2 else math.pi / 2 }
		end
		stations.Spawn = { position = localToWorld(center, layout.spawn), yaw = 0 }
		stations.Oven = side(layout.oven)
		stations.Shop = side(layout.shop)
		stations.Egg1 = side(layout.eggs[1])
		stations.Egg2 = side(layout.eggs[2])
		stations.Phone = side(layout.phone)
		stations.Van = side(layout.van)
		stations.Portal = side(layout.portal)
		stations.Landmark = { position = localToWorld(center, layout.landmark), yaw = 0 }
		-- Spot kept for the hidden chest (#100, theme.secretChest = { x, z, clear }): on the
		-- terrace top when it lies on a terrace, facing the island's middle. WorldMap puts
		-- an invisible anchor part "SecretChestAnchor" there; trees and deco keep clear.
		local chest = theme.secretChest
		if chest then
			local p = localToWorld(center, { chest[1], chest[2] })
			for _, t in layout.terraces do
				if math.sqrt((chest[1] - t[1]) ^ 2 + (chest[2] - t[2]) ^ 2) < t[3] then
					p[2] = groundY + t[4]
				end
			end
			stations.SecretChest = { position = p, yaw = facing(center[1] - p[1], center[3] - p[3]), clear = chest[3] }
		end

		local pondAt = localToWorld(center, layout.pond)
		local gap = pond(island, pondAt, 8, theme)
		shell(island, openings, theme, 1, { gap })

		-- Field: slightly lighter grass, not solid (the ground below carries the players).
		table.insert(
			island.parts,
			spec(
				"Block",
				v(island.field.size[1] + 6, 0.1, island.field.size[2] + 6),
				yawed(v(fieldCenter[1], groundY + THIN.ToppingArea - 0.05, fieldCenter[3]), 0),
				{
					name = "ToppingArea",
					color = theme.field,
					collide = false,
					role = "Field",
				}
			)
		)

		-- Furrows across the field (farm): thin darker strips, purely visual.
		if theme.fieldRows then
			local rows = math.floor(island.field.size[2] / 10)
			for k = 1, rows - 1 do
				local z = fieldBack + k * island.field.size[2] / rows
				table.insert(
					island.parts,
					spec(
						"Block",
						v(island.field.size[1] + 2, 0.1, 1.6),
						yawed(v(fieldCenter[1], groundY + THIN.FieldRow - 0.05, z), 0),
						{
							name = "FieldRow",
							color = theme.fieldRows,
							collide = false,
							role = "Field",
						}
					)
				)
			end
		end

		-- Main path: bridge -> field, field -> next bridge; plate pads in front of the stations.
		plates(
			island.parts,
			v(center[1], groundY, center[3] + half),
			v(center[1], groundY, fieldFront + 1),
			pathWidth,
			theme,
			index
		)
		if island.openings.back then
			plates(
				island.parts,
				v(center[1], groundY, fieldBack - 1),
				v(center[1], groundY, center[3] - half),
				pathWidth,
				theme,
				index + 20
			)
		end
		for _, name in { "Oven", "Shop", "Egg1", "Egg2", "Phone", "Van", "Portal" } do
			local station = stations[name]
			local p = station.position
			local fromX = center[1] + (if p[1] < center[1] then -pathWidth / 2 else pathWidth / 2)
			local toX = p[1] + (if p[1] < center[1] then 4 else -4)
			if math.abs(toX - fromX) > 2 then
				plates(island.parts, v(fromX, groundY, p[3]), v(toX, groundY, p[3]), 6, theme, #name)
			end
		end

		for _, t in layout.terraces do
			terrace(island, localToWorld(center, { t[1], t[2] }), t[3], t[4], theme)
		end
		local landmark = stations.Landmark.position
		local landmarkBase = groundY
		for _, t in layout.terraces do
			if t[1] == layout.landmark[1] and t[2] == layout.landmark[2] then
				landmarkBase = groundY + t[4]
			end
		end
		local buildLandmark = LANDMARKS[theme.landmark or "GiantPizza"] or giantPizza
		buildLandmark(island.parts, landmark, landmarkBase, theme)
		-- Props on the other terraces (e.g. the farm's barn), standing on the terrace top.
		for _, prop in theme.terraceProps or {} do
			local t = layout.terraces[prop.terrace]
			if t then
				table.insert(island.models, {
					model = prop.model,
					width = prop.width,
					position = v(
						center[1] + t[1] + prop.at[1],
						groundY + t[4] + (prop.lift or 0),
						center[3] + t[2] + prop.at[2]
					),
					yaw = math.rad(prop.yaw or 0),
					collide = prop.collide == true,
				})
			end
		end

		-- Glowing cracks in the ground (volcano lava): Neon with a small light each.
		local cracks = theme.cracks or {}
		for _, crack in cracks do
			table.insert(
				island.parts,
				spec(
					"Block",
					v(1.2, 0.12, crack[3]),
					yawed(
						v(center[1] + crack[1], groundY + THIN.LavaCrack - 0.06, center[3] + crack[2]),
						math.rad(crack[4])
					),
					{ name = "LavaCrack", color = theme.glow, material = "Neon", collide = false, role = "Glow" }
				)
			)
		end

		local function keepOut(x: number, z: number, r: number): boolean
			for _, crack in cracks do
				if math.sqrt((x - center[1] - crack[1]) ^ 2 + (z - center[3] - crack[2]) ^ 2) < crack[3] / 2 + r then
					return true
				end
			end
			local f = island.field :: any
			if
				math.abs(x - f.center[1]) < f.size[1] / 2 + r + 2
				and math.abs(z - f.center[3]) < f.size[2] / 2 + r + 2
			then
				return true
			end
			if math.abs(x - center[1]) < pathWidth / 2 + r + 2 then
				return true
			end
			for name, station in stations do
				if name ~= "Landmark" then
					local p = station.position
					if math.sqrt((x - p[1]) ^ 2 + (z - p[3]) ^ 2) < r + 10 then
						return true
					end
				end
			end
			-- Station row between path and stations, so the camera stays free.
			if z > fieldFront and z < center[3] + half and math.abs(x - center[1]) < 46 + r then
				return true
			end
			if math.sqrt((x - pondAt[1]) ^ 2 + (z - pondAt[3]) ^ 2) < 8 + r + 2 then
				return true
			end
			if math.abs(z - pondAt[3]) < r + 3 and (x - pondAt[1]) * (gap[1] - pondAt[1]) > 0 then
				return true
			end
			for _, t in layout.terraces do
				local tp = localToWorld(center, { t[1], t[2] })
				if math.sqrt((x - tp[1]) ^ 2 + (z - tp[3]) ^ 2) < t[3] + r + 5 then
					return true
				end
			end
			return false
		end
		if theme.trees ~= false then
			scatterTrees(island, keepOut, index * 13, theme)
		end
		scatterDeco(island, keepOut, index * 17, theme)

		-- Bushes and flower beds along the field's long sides and around the pond.
		local fieldHalfX = layout.field.size[1] / 2
		for i, z in { fieldBack + 12, fieldCenter[3], fieldFront - 12 } do
			for _, sx in { -1, 1 } do
				local at = v(center[1] + sx * (fieldHalfX + 9), groundY, z)
				if IslandPlan.isInsideOutline(island.outline, at[1], at[3]) and not keepOut(at[1], at[3], 2.5) then
					-- Theme accents ({ model, width }) take turns; default: bushes.
					local accents = theme.accents or { { model = "Bush", width = 5 } }
					local accent = accents[(i + (if sx > 0 then 1 else 0)) % #accents + 1]
					table.insert(island.models, {
						model = accent.model,
						width = accent.width + noise(i, sx) * accent.width * 0.4,
						position = at,
						yaw = noise(sx, i) * 6,
						collide = false,
					})
					flowers(island, add(at, v(0, 0, 6)), 6, 5, theme, i * 7 + sx)
				end
			end
		end
		flowers(island, add(pondAt, v(-11, 0, 4)), 8, 6, theme, 99)
		return island
	end

	local cache: { [number]: Island } = {}
	function plan.worldIsland(index: number): Island
		local cached = cache[index]
		if cached then
			return cached
		end
		local world = worlds[index]
		assert(world, `no world {index}`)
		local island = buildIsland(plan.worldCenter(index), index, world, true, index < #worlds)
		island.worldIndex = index
		cache[index] = island
		return island
	end

	-- Event islands (#77) float in a row beside the spawn island (towards +X), clear of
	-- the world chain along -Z. No bridges: the portal brings players there. Same floor
	-- plan and themes as the worlds (islands.themes[eventWorld.id]).
	function plan.eventCenter(slot: number): { number }
		-- One island spacing per slot to the side of the chain: a bridge length clear of world 1.
		return v(spacing * slot, groundY, spawnCenter[3])
	end

	function plan.eventIndexAt(x: number, z: number): number?
		for slot = 1, #eventWorlds do
			local c = plan.eventCenter(slot)
			if math.abs(x - c[1]) <= half and math.abs(z - c[3]) <= half then
				return slot
			end
		end
		return nil
	end

	local eventCache: { [number]: Island } = {}
	function plan.eventIsland(slot: number): Island
		local cached = eventCache[slot]
		if cached then
			return cached
		end
		local world = eventWorlds[slot]
		assert(world, `no event island {slot}`)
		local island = buildIsland(plan.eventCenter(slot), 100 + slot, world, false, false)
		island.kind = "event"
		island.eventIndex = slot
		eventCache[slot] = island
		return island
	end

	local spawnCache: Island? = nil
	local baseSpawnIsland = plan.spawnIsland
	function plan.spawnIsland(): Island
		if spawnCache == nil then
			spawnCache = baseSpawnIsland()
		end
		return spawnCache :: Island
	end

	-- ---------------------------------------------------------------- bridges and gates

	-- Wooden rope bridge from z = fromZ down to z = toZ (fromZ > toZ), sagging a little.
	local function ropeBridge(fromZ: number, toZ: number, theme: any): Bridge
		local parts: { PartSpec } = {}
		local len = fromZ - toZ
		local sag = 1.2
		local function deckY(t: number): number
			return groundY - sag * 4 * t * (1 - t)
		end
		local planks = math.floor(len / 2)
		local step = len / planks
		for i = 0, planks - 1 do
			local t0, t1 = i / planks, (i + 1) / planks
			local z0, z1 = fromZ - i * step, fromZ - (i + 1) * step
			local p = v(0, deckY(t0) - 0.3, z0)
			local q = v(0, deckY(t1) - 0.3, z1)
			local mid = scale(add(p, q), 0.5)
			local dir = sub(q, p)
			local tone = if i % 3 == 0 then theme.cliffDark else theme.wood
			table.insert(
				parts,
				spec("Block", v(bridgeWidth, 0.6, length(dir) - 0.25), along(mid, dir), {
					name = "Plank",
					color = tone,
					role = "Bridge",
				})
			)
		end
		-- Posts with ropes between them, on both sides.
		local postCount = 5
		for _, sx in { -1, 1 } do
			local x = sx * (bridgeWidth / 2 + 0.5)
			local previous: V? = nil
			local previousLow: V? = nil
			for k = 0, postCount - 1 do
				local t = k / (postCount - 1)
				local z = fromZ - t * len
				local base = deckY(t)
				table.insert(
					parts,
					disc(v(x, base + 1.6, z), 0.9, 4.4, { name = "BridgePost", color = theme.wood, role = "Bridge" })
				)
				local top = v(x, base + 3.6, z)
				local low = v(x, base + 1.6, z)
				if previous and previousLow then
					table.insert(
						parts,
						beam(
							previous,
							top,
							0.35,
							0.35,
							{ name = "Rope", color = theme.rope, collide = false, role = "Rope" }
						)
					)
					table.insert(
						parts,
						beam(
							previousLow,
							low,
							0.3,
							0.3,
							{ name = "Rope", color = theme.rope, collide = false, role = "Rope" }
						)
					)
				end
				previous, previousLow = top, low
			end
			-- Invisible wall along the side.
			table.insert(
				parts,
				spec(
					"Block",
					v(1, wallHeight + 1, len + 1),
					yawed(v(sx * (bridgeWidth / 2 + 0.5), groundY + (wallHeight - 1) / 2, (fromZ + toZ) / 2), 0),
					{
						name = "BridgeWall",
						color = { 255, 255, 255 },
						transparency = 1,
						role = "Wall",
					}
				)
			)
		end
		return { fromZ = fromZ, toZ = toZ, parts = parts }
	end

	-- Invisible walls along both sides of a bridge.
	local function bridgeWalls(parts: { PartSpec }, fromZ: number, toZ: number)
		for _, sx in { -1, 1 } do
			table.insert(
				parts,
				spec(
					"Block",
					v(1, wallHeight + 1, fromZ - toZ + 1),
					yawed(v(sx * (bridgeWidth / 2 + 0.5), groundY + (wallHeight - 1) / 2, (fromZ + toZ) / 2), 0),
					{
						name = "BridgeWall",
						color = { 255, 255, 255 },
						transparency = 1,
						role = "Wall",
					}
				)
			)
		end
	end

	-- Straight wooden boardwalk (to the beach): flat planks across, a stilt frame below
	-- and a low hand rail on posts.
	local function boardwalk(fromZ: number, toZ: number, theme: any): Bridge
		local parts: { PartSpec } = {}
		local len = fromZ - toZ
		local planks = math.floor(len / 1.6)
		local step = len / planks
		for i = 0, planks - 1 do
			local z = fromZ - (i + 0.5) * step
			table.insert(
				parts,
				spec("Block", v(bridgeWidth + 0.6, 0.6, step - 0.2), yawed(v(0, groundY - 0.3, z), 0), {
					name = "Plank",
					color = if i % 4 == 0 then theme.woodDark else theme.wood,
					role = "Bridge",
				})
			)
		end
		-- Two long beams under the planks and stilts with cross braces every 10 studs.
		for _, sx in { -1, 1 } do
			local x = sx * (bridgeWidth / 2 - 1)
			table.insert(
				parts,
				spec("Block", v(1, 1, len), yawed(v(x, groundY - 1.1, (fromZ + toZ) / 2), 0), {
					name = "BoardwalkBeam",
					color = theme.woodDark,
					role = "Bridge",
				})
			)
		end
		local posts = math.floor(len / 8)
		for k = 0, posts do
			-- End posts stay clear of the gate pillars on the bridge head.
			local z = fromZ - 1.5 - k * (len - 3) / posts
			for _, sx in { -1, 1 } do
				local x = sx * (bridgeWidth / 2 + 0.3)
				-- Rail post above the deck, stilt below it.
				table.insert(
					parts,
					spec("Block", v(0.8, 3.4, 0.8), yawed(v(x, groundY + 1.7, z), 0), {
						name = "BridgePost",
						color = theme.woodDark,
						role = "Bridge",
					})
				)
				if k > 0 and k < posts then
					table.insert(
						parts,
						spec("Block", v(1, 7, 1), yawed(v(sx * (bridgeWidth / 2 - 1), groundY - 5, z), 0), {
							name = "Stilt",
							color = theme.woodDark,
							collide = false,
							role = "Bridge",
						})
					)
				end
			end
			if k > 0 and k < posts then
				table.insert(
					parts,
					spec("Block", v(bridgeWidth - 1, 0.6, 0.6), yawed(v(0, groundY - 6.5, z), 0), {
						name = "StiltBrace",
						color = theme.woodDark,
						collide = false,
						role = "Bridge",
					})
				)
			end
		end
		for _, sx in { -1, 1 } do
			local x = sx * (bridgeWidth / 2 + 0.3)
			table.insert(
				parts,
				spec("Block", v(0.6, 0.5, len), yawed(v(x, groundY + 3.2, (fromZ + toZ) / 2), 0), {
					name = "HandRail",
					color = theme.wood,
					collide = false,
					role = "Rope",
				})
			)
		end
		bridgeWalls(parts, fromZ, toZ)
		return { fromZ = fromZ, toZ = toZ, parts = parts }
	end

	-- Ice bridge (to the icebergs): a slightly arched deck of ice slabs, low ice walls with
	-- snow on top and crystal pillars at both ends.
	local function iceBridge(fromZ: number, toZ: number, theme: any): Bridge
		local parts: { PartSpec } = {}
		local len = fromZ - toZ
		local rise = 1.6
		local function deckY(t: number): number
			return groundY + rise * 4 * t * (1 - t)
		end
		local slabs = math.floor(len / 4)
		local step = len / slabs
		for i = 0, slabs - 1 do
			local t0, t1 = i / slabs, (i + 1) / slabs
			local p = v(0, deckY(t0) - 0.4, fromZ - i * step)
			local q = v(0, deckY(t1) - 0.4, fromZ - (i + 1) * step)
			local dir = sub(q, p)
			table.insert(
				parts,
				spec("Block", v(bridgeWidth, 0.8, length(dir) + 0.1), along(scale(add(p, q), 0.5), dir), {
					name = "IceSlab",
					color = if i % 2 == 0 then theme.path else theme.pathDark,
					role = "Bridge",
				})
			)
			-- Arch below the deck.
			local under = 1.6 + 3 * (1 - 4 * ((t0 + t1) / 2) * (1 - (t0 + t1) / 2))
			table.insert(
				parts,
				spec(
					"Block",
					v(bridgeWidth - 2, under, length(dir) + 0.1),
					along(add(scale(add(p, q), 0.5), v(0, -0.4 - under / 2, 0)), dir),
					{ name = "IceArch", color = theme.iceDark, collide = false, role = "Bridge" }
				)
			)
			for _, sx in { -1, 1 } do
				local x = sx * (bridgeWidth / 2 + 0.4)
				local a, b = add(p, v(x, 1.2, 0)), add(q, v(x, 1.2, 0))
				table.insert(
					parts,
					beam(a, b, 1, 2.4, {
						name = "IceRail",
						color = theme.ice,
						material = "Glass",
						transparency = 0.2,
						role = "Bridge",
					})
				)
				table.insert(
					parts,
					beam(add(a, v(0, 1.35, 0)), add(b, v(0, 1.35, 0)), 1.3, 0.4, {
						name = "IceRailSnow",
						color = theme.snow,
						collide = false,
						role = "Bridge",
					})
				)
			end
		end
		-- Crystal pillars at both ends.
		for _, z in { fromZ - 2.5, toZ + 3.5 } do
			for _, sx in { -1, 1 } do
				local foot = v(sx * (bridgeWidth / 2 + 1.2), groundY, z)
				table.insert(
					parts,
					beam(foot, add(foot, v(sx * 0.6, 7, 0)), 1.6, 1.6, {
						name = "IcePillar",
						color = theme.ice,
						material = "Glass",
						transparency = 0.1,
						role = "Bridge",
					})
				)
			end
		end
		bridgeWalls(parts, fromZ, toZ)
		return { fromZ = fromZ, toZ = toZ, parts = parts }
	end

	-- Basalt bridge (to the volcano): a straight deck of stone slabs with a few glowing
	-- lava seams, basalt columns along the sides and columns hanging below.
	local function basaltBridge(fromZ: number, toZ: number, theme: any): Bridge
		local parts: { PartSpec } = {}
		local len = fromZ - toZ
		local slabs = math.floor(len / 4)
		local step = len / slabs
		for i = 0, slabs - 1 do
			local z = fromZ - (i + 0.5) * step
			table.insert(
				parts,
				spec("Block", v(bridgeWidth, 1, step - 0.15), yawed(v(0, groundY - 0.5, z), 0), {
					name = "BasaltSlab",
					color = if i % 2 == 0 then theme.path else theme.pathDark,
					role = "Bridge",
				})
			)
			-- Lava between some of the slabs (each one a small light, so only three).
			if i % 3 == 2 and i < slabs - 1 then
				table.insert(
					parts,
					spec("Block", v(bridgeWidth - 1.5, 0.1, 0.35), yawed(v(0, groundY + 0.02, z - step / 2), 0), {
						name = "LavaSeam",
						color = theme.glow,
						material = "Neon",
						collide = false,
						role = "Glow",
					})
				)
			end
		end
		-- Thick rock beam under the deck with columns hanging from it.
		table.insert(
			parts,
			spec("Block", v(bridgeWidth - 2, 2.5, len), yawed(v(0, groundY - 2.2, (fromZ + toZ) / 2), 0), {
				name = "BasaltBeam",
				color = theme.cliff,
				collide = false,
				role = "Bridge",
			})
		)
		for k = 1, math.floor(len / 5) - 1 do
			for _, sx in { -1, 1 } do
				local h = 3 + noise(k, sx + 3) * 5
				table.insert(
					parts,
					disc(v(sx * (bridgeWidth / 2 - 2.2), groundY - 3.4 - h / 2, fromZ - k * 5), 2.2, h, {
						name = "HangingColumn",
						color = if (k + sx) % 2 == 0 then theme.cliffDark else theme.cliff,
						collide = false,
						role = "Bridge",
					})
				)
			end
		end
		-- Low basalt columns along both sides (clear of the gate pillars at the ends).
		local columns = math.floor((len - 6) / 2.5)
		for k = 0, columns do
			local z = fromZ - 3 - k * (len - 6) / columns
			for _, sx in { -1, 1 } do
				local h = 1.6 + noise(k, sx) * 1.6
				table.insert(
					parts,
					disc(v(sx * (bridgeWidth / 2 + 0.5), groundY + h / 2, z), 1.8, h, {
						name = "BasaltColumn",
						color = if (k + sx) % 3 == 0 then theme.cliffLight else theme.rim,
						role = "Bridge",
					})
				)
			end
		end
		bridgeWalls(parts, fromZ, toZ)
		return { fromZ = fromZ, toZ = toZ, parts = parts }
	end

	-- Candy cane bridge (to candy land): wafer slabs, striped rails on striped posts and a
	-- big candy cane at every corner.
	local function candyCaneBridge(fromZ: number, toZ: number, theme: any): Bridge
		local parts: { PartSpec } = {}
		local len = fromZ - toZ
		local frosting = theme.frosting or { 255, 246, 250 }
		local red = theme.rim
		local pink = { 255, 170, 200 }
		local planks = math.floor(len / 2)
		local step = len / planks
		for i = 0, planks - 1 do
			local z = fromZ - (i + 0.5) * step
			table.insert(
				parts,
				spec("Block", v(bridgeWidth, 0.7, step - 0.2), yawed(v(0, groundY - 0.35, z), 0), {
					name = "WaferSlab",
					color = if i % 2 == 0 then frosting else pink,
					role = "Bridge",
				})
			)
		end
		table.insert(
			parts,
			spec("Block", v(bridgeWidth - 1, 1.2, len), yawed(v(0, groundY - 1.3, (fromZ + toZ) / 2), 0), {
				name = "WaferBeam",
				color = theme.cliff,
				collide = false,
				role = "Bridge",
			})
		)
		-- Striped hand rails (red and white pieces).
		local pieces = math.floor(len / 2)
		for _, sx in { -1, 1 } do
			local x = sx * (bridgeWidth / 2 + 0.3)
			for k = 0, pieces - 1 do
				local z0 = fromZ - k * len / pieces
				local z1 = fromZ - (k + 1) * len / pieces
				table.insert(
					parts,
					beam(v(x, groundY + 2.8, z0), v(x, groundY + 2.8, z1), 0.6, 0.6, {
						name = "CaneRail",
						color = if k % 2 == 0 then red else frosting,
						collide = false,
						role = "Rope",
					})
				)
			end
		end
		-- Striped posts under the rails, clear of the corner canes.
		local posts = math.floor((len - 10) / 8)
		for k = 0, posts do
			local z = fromZ - 5 - k * (len - 10) / posts
			for _, sx in { -1, 1 } do
				local x = sx * (bridgeWidth / 2 + 0.3)
				for j = 0, 3 do
					table.insert(
						parts,
						disc(v(x, groundY + 0.35 + j * 0.7, z), 0.9, 0.7, {
							name = "CaneStripe",
							color = if j % 2 == 0 then red else frosting,
							role = "Bridge",
						})
					)
				end
			end
		end
		-- A big candy cane at every corner, hooked towards the deck.
		for _, z in { fromZ - 2.5, toZ + 3.5 } do
			for _, sx in { -1, 1 } do
				local x = sx * (bridgeWidth / 2 + 1.2)
				for j = 0, 7 do
					table.insert(
						parts,
						disc(v(x, groundY + 0.45 + j * 0.9, z), 1.3, 0.9, {
							name = "CaneStripe",
							color = if j % 2 == 0 then red else frosting,
							role = "Bridge",
						})
					)
				end
				local top = groundY + 7.2
				for j = 0, 5 do
					local a = j / 5 * math.pi
					table.insert(
						parts,
						ball(v(x - sx * 1.2 + sx * 1.2 * math.cos(a), top + 1.2 * math.sin(a), z), 1.3, {
							name = "CaneHook",
							color = if j % 2 == 0 then frosting else red,
							collide = false,
							role = "Bridge",
						})
					)
				end
			end
		end
		bridgeWalls(parts, fromZ, toZ)
		return { fromZ = fromZ, toZ = toZ, parts = parts }
	end

	-- Light bridge (into space): pale metal slabs with a glowing strip along each edge,
	-- see-through side panels and posts with small glowing tips.
	local function lightBridge(fromZ: number, toZ: number, theme: any): Bridge
		local parts: { PartSpec } = {}
		local len = fromZ - toZ
		local slabs = math.floor(len / 4)
		local step = len / slabs
		for i = 0, slabs - 1 do
			local z = fromZ - (i + 0.5) * step
			table.insert(
				parts,
				spec("Block", v(bridgeWidth, 0.8, step - 0.1), yawed(v(0, groundY - 0.4, z), 0), {
					name = "LightSlab",
					color = if i % 2 == 0 then theme.path else theme.pathDark,
					role = "Bridge",
				})
			)
		end
		table.insert(
			parts,
			spec("Block", v(bridgeWidth - 3, 0.8, len), yawed(v(0, groundY - 1.2, (fromZ + toZ) / 2), 0), {
				name = "LightBeam",
				color = theme.woodDark,
				collide = false,
				role = "Bridge",
			})
		)
		for _, sx in { -1, 1 } do
			-- One glowing strip per side (one light each).
			table.insert(
				parts,
				spec(
					"Block",
					v(0.5, 0.15, len - 2),
					yawed(v(sx * (bridgeWidth / 2 - 0.5), groundY + 0.07, (fromZ + toZ) / 2), 0),
					{
						name = "LightStrip",
						color = theme.glow,
						material = "Neon",
						collide = false,
						role = "Glow",
					}
				)
			)
			local panels = math.floor((len - 4) / 4)
			for k = 0, panels - 1 do
				local z = fromZ - 2 - (k + 0.5) * (len - 4) / panels
				table.insert(
					parts,
					spec(
						"Block",
						v(0.3, 2.2, (len - 4) / panels - 0.6),
						yawed(v(sx * (bridgeWidth / 2 + 0.3), groundY + 1.3, z), 0),
						{
							name = "LightPanel",
							color = theme.water,
							material = "Glass",
							transparency = 0.4,
							role = "Bridge",
						}
					)
				)
			end
			for k = 0, panels do
				local z = fromZ - 2 - k * (len - 4) / panels
				table.insert(
					parts,
					spec("Block", v(0.6, 3, 0.6), yawed(v(sx * (bridgeWidth / 2 + 0.3), groundY + 1.5, z), 0), {
						name = "LightPost",
						color = theme.wood,
						role = "Bridge",
					})
				)
				if k % 2 == 0 then
					table.insert(
						parts,
						ball(v(sx * (bridgeWidth / 2 + 0.3), groundY + 3.25, z), 0.6, {
							name = "LightPostTip",
							color = theme.glow,
							material = "Neon",
							collide = false,
							role = "Bridge",
						})
					)
				end
			end
		end
		bridgeWalls(parts, fromZ, toZ)
		return { fromZ = fromZ, toZ = toZ, parts = parts }
	end

	local BRIDGES = {
		Rope = ropeBridge,
		Boardwalk = boardwalk,
		Ice = iceBridge,
		Basalt = basaltBridge,
		CandyCane = candyCaneBridge,
		Light = lightBridge,
	}

	-- Bridge into world `index`, in the style of the world it leads to (theme.bridge).
	local function bridgeInto(index: number, fromZ: number, toZ: number): Bridge
		local theme = themeOf(worlds[index].id)
		local build = BRIDGES[theme.bridge or "Rope"] or ropeBridge
		return build(fromZ, toZ, theme)
	end

	function plan.bridges(): { Bridge }
		local bridges = {}
		table.insert(bridges, bridgeInto(1, spawnCenter[3] - spawnRadius, plan.worldCenter(1)[3] + half))
		for index = 1, #worlds - 1 do
			local fromZ = plan.worldCenter(index)[3] - half
			table.insert(bridges, bridgeInto(index + 1, fromZ, fromZ - bridgeLength))
		end
		return bridges
	end

	-- Glowing gate on the bridge head of world `index`; its barrier blocks players until
	-- they unlocked the world (made passable per client).
	function plan.gate(index: number): Gate
		local world = worlds[index]
		local accent = world.color or { 255, 200, 80 }
		local frontZ = plan.worldCenter(index)[3] + half
		local z = frontZ - 1
		local parts: { PartSpec } = {}
		local stone = { 236, 228, 214 }
		for _, sx in { -1, 1 } do
			local x = sx * (bridgeWidth / 2 + 1.75)
			table.insert(
				parts,
				spec(
					"Block",
					v(3.5, 17, 3.5),
					yawed(v(x, groundY + 8.5, z), 0),
					{ name = "GatePillar", color = stone, role = "Gate" }
				)
			)
			table.insert(
				parts,
				ball(
					v(x, groundY + 21.2, z),
					4.4,
					{ name = "GateCap", color = accent, material = "Neon", role = "Glow" }
				)
			)
			table.insert(
				parts,
				spec("Block", v(0.6, 15, 0.8), yawed(v(x - sx * 1.9, groundY + 8, z + 1.6), 0), {
					name = "GateGlow",
					color = accent,
					material = "Neon",
					collide = false,
					role = "Glow",
				})
			)
		end
		table.insert(
			parts,
			spec(
				"Block",
				v(bridgeWidth + 7, 3, 3.5),
				yawed(v(0, groundY + 18.5, z), 0),
				{ name = "GateBeam", color = stone, role = "Gate" }
			)
		)
		table.insert(
			parts,
			spec("Block", v(bridgeWidth, 0.6, 0.8), yawed(v(0, groundY + 16.7, z + 1.6), 0), {
				name = "GateGlow",
				color = accent,
				material = "Neon",
				collide = false,
				role = "Glow",
			})
		)
		local barrier = spec(
			"Block",
			v(bridgeWidth + 0.4, wallHeight + 1, 1.2),
			yawed(v(0, groundY + (wallHeight - 1) / 2, z), 0),
			{
				name = "Barrier",
				color = accent,
				material = "ForceField",
				transparency = 0.2,
				role = "Barrier",
			}
		)
		return { parts = parts, barrier = barrier, returnPoint = v(0, groundY + 3, frontZ + 12) }
	end

	return plan
end

return IslandPlan
