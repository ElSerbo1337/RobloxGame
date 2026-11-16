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
}

return WorldLooks
