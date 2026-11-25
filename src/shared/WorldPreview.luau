--!strict
-- What the little 3D island on a world menu card (#78) looks like, as pure data: ground
-- and cliff colours from the world's island theme (GameConfig.islands.themes), its
-- landmark model, and the world colour as accent. Worlds without a theme (e.g. worlds
-- 8-15 before their models arrive) get colours derived from the world colour and no
-- landmark, so the client builds a simple fallback shape. No Roblox API.

export type RGB = { number }

export type Preview = {
	ground: RGB,
	cliff: RGB,
	accent: RGB,
	-- ModelLibrary name of the landmark (nil: none planned, build a fallback shape).
	landmark: string?,
}

local WorldPreview = {}

local DEFAULT_ACCENT = { 150, 90, 230 }
local CLIFF = { 168, 120, 84 }

local function mix(a: RGB, b: RGB, t: number): RGB
	return {
		math.floor(a[1] + (b[1] - a[1]) * t + 0.5),
		math.floor(a[2] + (b[2] - a[2]) * t + 0.5),
		math.floor(a[3] + (b[3] - a[3]) * t + 0.5),
	}
end

function WorldPreview.forWorld(world: { id: string, color: RGB? }, themes: { [string]: any }?): Preview
	local accent = world.color or DEFAULT_ACCENT
	local theme = themes and themes[world.id]
	if theme then
		return {
			ground = theme.grass or mix(accent, { 255, 255, 255 }, 0.35),
			cliff = theme.cliff or CLIFF,
			accent = accent,
			landmark = theme.landmark,
		}
	end
	return {
		ground = mix(accent, { 255, 255, 255 }, 0.35),
		cliff = mix(accent, { 60, 35, 20 }, 0.55),
		accent = accent,
		landmark = nil,
	}
end

return WorldPreview
