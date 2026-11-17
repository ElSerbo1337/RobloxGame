--!strict
-- Look and feel per world: lighting, atmosphere, post-processing, clouds, music.
-- Pure data; the client (WorldAmbience) applies the look of the world the player is in.
-- A new world gets its look by adding an entry here (missing entries use PizzeriaGarden).
-- Colors are { r, g, b } (0-255). Lighting.Technology = Future is set once in Studio
-- (it can't be set from scripts), see docs/pc-todo.md (#15).

export type Rgb = { number }

export type Look = {
	clockTime: number,
	brightness: number,
	ambient: Rgb,
	outdoorAmbient: Rgb,
	colorShiftTop: Rgb,
	atmosphere: { density: number, offset: number, color: Rgb, decay: Rgb, glare: number, haze: number },
	bloom: { intensity: number, size: number, threshold: number },
	colorCorrection: { brightness: number, contrast: number, saturation: number, tint: Rgb },
	sunRays: { intensity: number, spread: number },
	clouds: { cover: number, density: number, color: Rgb },
	-- Key in client/Sounds.luau.
	music: string,
}

local WorldLooks: { [string]: Look } = {
	-- World 1: sunny, warm afternoon in a garden; saturated cartoon colors.
	PizzeriaGarden = {
		clockTime = 14.5,
		brightness = 3,
		ambient = { 110, 100, 95 },
		outdoorAmbient = { 150, 140, 130 },
		colorShiftTop = { 255, 236, 205 },
		atmosphere = {
			density = 0.28,
			offset = 0.2,
			color = { 255, 232, 205 },
			decay = { 255, 190, 150 },
			glare = 0.25,
			haze = 1.2,
		},
		bloom = { intensity = 0.5, size = 24, threshold = 1.6 },
		colorCorrection = { brightness = 0.02, contrast = 0.08, saturation = 0.2, tint = { 255, 250, 242 } },
		sunRays = { intensity = 0.05, spread = 0.6 },
		clouds = { cover = 0.55, density = 0.7, color = { 255, 255, 255 } },
		music = "Music_PizzeriaGarden",
	},
	-- World 2: golden early morning on the farm, warm haze over the fields.
	Farm = {
		clockTime = 8.6,
		brightness = 2.8,
		ambient = { 120, 105, 90 },
		outdoorAmbient = { 160, 140, 115 },
		colorShiftTop = { 255, 226, 180 },
		atmosphere = {
			density = 0.32,
			offset = 0.15,
			color = { 255, 226, 180 },
			decay = { 255, 170, 110 },
			glare = 0.35,
			haze = 1.6,
		},
		bloom = { intensity = 0.5, size = 24, threshold = 1.6 },
		colorCorrection = { brightness = 0.02, contrast = 0.06, saturation = 0.18, tint = { 255, 244, 224 } },
		sunRays = { intensity = 0.08, spread = 0.7 },
		clouds = { cover = 0.45, density = 0.6, color = { 255, 246, 230 } },
		music = "Music_Farm",
	},
	-- World 3: bright midday at the sea, clear blue air, strong sun.
	Beach = {
		clockTime = 12.5,
		brightness = 3.3,
		ambient = { 115, 125, 135 },
		outdoorAmbient = { 160, 172, 185 },
		colorShiftTop = { 255, 250, 235 },
		atmosphere = {
			density = 0.22,
			offset = 0.25,
			color = { 200, 236, 255 },
			decay = { 140, 205, 255 },
			glare = 0.4,
			haze = 0.8,
		},
		bloom = { intensity = 0.6, size = 24, threshold = 1.5 },
		colorCorrection = { brightness = 0.03, contrast = 0.08, saturation = 0.25, tint = { 246, 252, 255 } },
		sunRays = { intensity = 0.08, spread = 0.6 },
		clouds = { cover = 0.4, density = 0.5, color = { 255, 255, 255 } },
		music = "Music_Beach",
	},
	-- World 4: cold, clear morning; bluish light, white haze, bright snow.
	Icebergs = {
		clockTime = 10,
		brightness = 3.2,
		ambient = { 140, 160, 185 },
		outdoorAmbient = { 170, 195, 225 },
		colorShiftTop = { 220, 240, 255 },
		atmosphere = {
			density = 0.36,
			offset = 0.2,
			color = { 222, 238, 255 },
			decay = { 170, 200, 240 },
			glare = 0.2,
			haze = 2,
		},
		bloom = { intensity = 0.45, size = 24, threshold = 1.7 },
		colorCorrection = { brightness = 0.03, contrast = 0.05, saturation = 0.05, tint = { 236, 246, 255 } },
		sunRays = { intensity = 0.04, spread = 0.5 },
		clouds = { cover = 0.7, density = 0.7, color = { 240, 248, 255 } },
		music = "Music_Icebergs",
	},
	-- World 5: fiery but readable (#24): warm orange light from high above (afternoon
	-- sun), light warm ambient, thin orange haze, glowing lava (strong bloom).
	Volcano = {
		clockTime = 15.8,
		brightness = 3,
		ambient = { 150, 110, 95 },
		outdoorAmbient = { 185, 135, 110 },
		colorShiftTop = { 255, 170, 110 },
		atmosphere = {
			density = 0.3,
			offset = 0.15,
			color = { 230, 140, 100 },
			decay = { 255, 120, 60 },
			glare = 0.45,
			haze = 1.5,
		},
		bloom = { intensity = 0.8, size = 28, threshold = 1.3 },
		colorCorrection = { brightness = 0.04, contrast = 0.1, saturation = 0.18, tint = { 255, 236, 222 } },
		sunRays = { intensity = 0.1, spread = 0.8 },
		clouds = { cover = 0.65, density = 0.7, color = { 200, 130, 105 } },
		music = "Music_Volcano",
	},
	-- World 6: soft pastel afternoon, pink haze and candy-floss clouds.
	CandyLand = {
		clockTime = 15,
		brightness = 2.8,
		ambient = { 150, 120, 140 },
		outdoorAmbient = { 190, 160, 185 },
		colorShiftTop = { 255, 215, 240 },
		atmosphere = {
			density = 0.3,
			offset = 0.2,
			color = { 255, 215, 240 },
			decay = { 255, 160, 210 },
			glare = 0.3,
			haze = 1.4,
		},
		bloom = { intensity = 0.6, size = 24, threshold = 1.5 },
		colorCorrection = { brightness = 0.04, contrast = 0.05, saturation = 0.3, tint = { 255, 240, 250 } },
		sunRays = { intensity = 0.06, spread = 0.6 },
		clouds = { cover = 0.6, density = 0.6, color = { 255, 222, 244 } },
		music = "Music_CandyLand",
	},
	-- World 7: night with stars and moon; purple ambient keeps it playable, neon glows.
	Space = {
		clockTime = 0.5,
		brightness = 1.5,
		ambient = { 125, 115, 165 },
		outdoorAmbient = { 115, 115, 175 },
		colorShiftTop = { 180, 170, 255 },
		atmosphere = {
			density = 0.15,
			offset = 0,
			color = { 60, 50, 110 },
			decay = { 120, 90, 200 },
			glare = 0,
			haze = 0,
		},
		bloom = { intensity = 1, size = 30, threshold = 0.9 },
		colorCorrection = { brightness = 0.05, contrast = 0.1, saturation = 0.15, tint = { 232, 228, 255 } },
		sunRays = { intensity = 0, spread = 0 },
		clouds = { cover = 0, density = 0, color = { 255, 255, 255 } },
		music = "Music_Space",
	},
}

return WorldLooks
