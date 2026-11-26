--!strict
-- Pet auras (#92): pure helpers for the client look in PetFollow (no Roblox API).
-- Legendary, Mythic and Secret pets get an aura in their rarity colour; the level
-- grows with the rarity's `order` (Legendary = 5 -> 1, Mythic -> 2, Secret -> 3).

local PetAura = {}

-- Rarity order of the first pet rarity with an aura (Legendary).
PetAura.FIRST_ORDER = 5
PetAura.MAX_LEVEL = 3
-- Aura particles per second at level 1; each level adds the same again.
PetAura.RATE_PER_LEVEL = 3
-- Same as GraphicsQuality.PARTICLE_FACTOR: "Low" emits this share of the particles.
PetAura.LOW_FACTOR = 0.3

-- Aura level 0 (none) .. MAX_LEVEL for a rarity id, given GameConfig.rarities.
function PetAura.level(rarityId: string?, rarities: { [string]: { order: number } }): number
	local rarity = rarityId and rarities[rarityId]
	if rarity == nil then
		return 0
	end
	return math.clamp(rarity.order - PetAura.FIRST_ORDER + 1, 0, PetAura.MAX_LEVEL)
end

-- Effective aura particles per second. On low graphics the weakest aura has no
-- particles at all and the others keep LOW_FACTOR of them.
function PetAura.particleRate(level: number, low: boolean): number
	if level <= 0 or (low and level <= 1) then
		return 0
	end
	local rate = level * PetAura.RATE_PER_LEVEL
	return if low then rate * PetAura.LOW_FACTOR else rate
end

return PetAura
