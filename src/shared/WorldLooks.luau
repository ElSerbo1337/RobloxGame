--!strict
-- Look and feel per world: lighting, atmosphere, post-processing, clouds, music.
-- Pure data; the client (WorldAmbience) applies it.
-- All islands are visible at once, so all worlds share one calm day look (#45) and only
-- the music differs. The per-world shape stays, so a later world-specific look (e.g. a
-- night for space) can replace an entry. A new world gets an entry via `day(music)`
-- (missing entries use PizzeriaGarden).
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

-- Shared calm day: moderate sun, little haze. The bloom threshold sits above the lit
-- brightness of white non-neon surfaces (sand, snow), so only neon glows, equally everywhere.
local DAY = {
	clockTime = 14,
	brightness = 2,
	ambient = { 100, 100, 105 },
	outdoorAmbient = { 128, 128, 135 },
	colorShiftTop = { 255, 240, 220 },
	atmosphere = {
		density = 0.25,
		offset = 0.2,
		color = { 220, 232, 245 },
		decay = { 170, 200, 230 },
		glare = 0,
		haze = 0.5,
	},
	bloom = { intensity = 0.6, size = 24, threshold = 2.8 },
	colorCorrection = { brightness = 0, contrast = 0.06, saturation = 0.15, tint = { 255, 255, 255 } },
	sunRays = { intensity = 0.04, spread = 0.5 },
	clouds = { cover = 0.5, density = 0.6, color = { 255, 255, 255 } },
}

local function day(music: string): Look
	return {
		clockTime = DAY.clockTime,
		brightness = DAY.brightness,
		ambient = DAY.ambient,
		outdoorAmbient = DAY.outdoorAmbient,
		colorShiftTop = DAY.colorShiftTop,
		atmosphere = DAY.atmosphere,
		bloom = DAY.bloom,
		colorCorrection = DAY.colorCorrection,
		sunRays = DAY.sunRays,
		clouds = DAY.clouds,
		music = music,
	}
end

local WorldLooks: { [string]: Look } = {
	PizzeriaGarden = day("Music_PizzeriaGarden"),
	Farm = day("Music_Farm"),
	Beach = day("Music_Beach"),
	Icebergs = day("Music_Icebergs"),
	Volcano = day("Music_Volcano"),
	CandyLand = day("Music_CandyLand"),
	Space = day("Music_Space"),
	-- Atlantis (#82): same day look (#45); the blue light comes from the island's own
	-- glowing corals and lamps (islands.themes.Atlantis.deco).
	Atlantis = day("Music_Atlantis"),
	-- Jungle temple (#83): same day look; fireflies, the jade gem and the mist come from
	-- the island deco (islands.themes.JungleTemple.deco).
	JungleTemple = day("Music_JungleTemple"),
	-- Desert Pyramids (#84): same day look (#45); the warm light comes from the golden sand
	-- and the glowing capstone of the pyramid.
	DesertPyramids = day("Music_DesertPyramids"),
}

return WorldLooks
