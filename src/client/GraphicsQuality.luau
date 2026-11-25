--!strict
-- Graphics setting "High"/"Low" (#76), purely local and cosmetic. Phones start on "Low".
-- On "Low":
-- * every ParticleEmitter in the Workspace emits PARTICLE_FACTOR as many particles
--   (also ones added later, e.g. by the environment tickets),
-- * Sparkles, Fire and Smoke effects are switched off,
-- * everything tagged DETAIL_TAG ("GraphicsDetail", CollectionService) is hidden: parts
--   become invisible locally (LocalTransparencyModifier), effects and lights inside go off.
-- Interface for later tickets (decoration, particles, juice): tag optional decoration with
-- GraphicsQuality.DETAIL_TAG, or ask Settings.lowGraphics() / GraphicsQuality.particleFactor()
-- and listen to Settings.observe("graphics", fn). See docs/ui-style.md ("Einstellungen").

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Settings = require(script.Parent.Settings)

local GraphicsQuality = {}

GraphicsQuality.DETAIL_TAG = "GraphicsDetail"
GraphicsQuality.PARTICLE_FACTOR = 0.3

-- Original values, so "High" restores exactly what the server built.
local originalRate: { [ParticleEmitter]: number } = setmetatable({}, { __mode = "k" }) :: any
local originalEnabled: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local low = false

-- 1 on "High", PARTICLE_FACTOR on "Low": multiply own particle rates/counts with it.
function GraphicsQuality.particleFactor(): number
	return if low then GraphicsQuality.PARTICLE_FACTOR else 1
end

local function isEffect(item: Instance): boolean
	return item:IsA("Sparkles") or item:IsA("Fire") or item:IsA("Smoke")
end

local function setEnabled(item: Instance, on: boolean)
	if originalEnabled[item] == nil then
		originalEnabled[item] = (item :: any).Enabled
	end
	(item :: any).Enabled = on and originalEnabled[item]
end

local function applyEmitter(emitter: ParticleEmitter)
	if originalRate[emitter] == nil then
		originalRate[emitter] = emitter.Rate
	end
	emitter.Rate = originalRate[emitter] * GraphicsQuality.particleFactor()
end

local function applyItem(item: Instance)
	if item:IsA("ParticleEmitter") then
		applyEmitter(item)
	elseif isEffect(item) then
		setEnabled(item, not low)
	end
end

local function applyDetail(root: Instance)
	local items = root:GetDescendants()
	table.insert(items, root)
	for _, item in items do
		if item:IsA("BasePart") then
			item.LocalTransparencyModifier = if low then 1 else 0
		elseif item:IsA("ParticleEmitter") or isEffect(item) or item:IsA("Light") or item:IsA("Beam") then
			setEnabled(item, not low)
		end
	end
end

local function applyAll()
	for _, item in Workspace:GetDescendants() do
		applyItem(item)
	end
	for _, root in CollectionService:GetTagged(GraphicsQuality.DETAIL_TAG) do
		applyDetail(root)
	end
end

function GraphicsQuality.start()
	low = Settings.lowGraphics()
	Workspace.DescendantAdded:Connect(function(item)
		if low and (item:IsA("ParticleEmitter") or isEffect(item)) then
			-- Let the creator finish setting it up first (Rate, Enabled).
			task.defer(applyItem, item)
		end
	end)
	CollectionService:GetInstanceAddedSignal(GraphicsQuality.DETAIL_TAG):Connect(function(root)
		if low then
			task.defer(applyDetail, root)
		end
	end)
	Settings.observe("graphics", function()
		local nextLow = Settings.lowGraphics()
		if nextLow ~= low then
			low = nextLow
			applyAll()
		end
	end)
	if low then
		applyAll()
	end
end

return GraphicsQuality
