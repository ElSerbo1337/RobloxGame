--!strict
-- Pets: equip/unequip requests, replication of the pet inventory, and the pet models
-- that follow their owner. The server only creates/removes the models (so every player
-- sees them); each client moves all pet models locally for smooth following (PetFollow).
--
-- Replicated player attributes:
--   Pets            JSON list of { uid, petId, equipped, variant, shiny, locked, bonus, level, xp, xpNeeded }
--                   (variant "Normal"|"Gold"|"Rainbow", bonus = effective GameRules.petBonus, #80;
--                   level 1-10, xp inside the level, xpNeeded = -1 at the max level, #90)
--   PetSlots        how many pets can be equipped
--   InventorySlots  how many pets can be owned (full inventory blocks opening eggs)
--   CoinMultiplier  1 + sum of equipped pet bonuses
--   PetTeams        JSON list (one per team) of saved pet uids that still exist (#91)
--   AutoDelete      JSON { [rarity]: true } of the rarities deleted when hatching (#91)
-- Pet management (#91): the Pets list also carries `name` (custom name, already filtered
-- by TextService) and `foundAt` (Unix time); `locked` only while features.petLock is on.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)
local SignText = require(script.Parent.SignText)
local Texts = require(ReplicatedStorage.Shared.Texts)

type PlayerState = GameRules.PlayerState

local PET_SIZE = 2.2
-- Imported pet models (#16): largest dimension in studs, a bit bigger for rarer pets.
local MODEL_SIZE = 2.8
local MODEL_SIZE_PER_RARITY = 0.25
-- PetFollow holds the pivot HOVER (1.4) studs above the ground; the models' bottom
-- should float just above it, like the placeholder ball did.
local MODEL_LIFT = 1.2
-- Merging (#80): at most one merge request per player in this many seconds.
local MERGE_COOLDOWN = 0.4
-- Pet levels (#90): play time is credited as XP to the equipped pets every this many seconds.
local XP_TICK = 10
-- Pet management (#91): at most one request per player in this many seconds (renaming
-- calls the text filter, so it waits longer).
local MANAGE_COOLDOWN = 0.25
local RENAME_COOLDOWN = 2
-- Longer raw names are refused before they reach the text filter.
local RENAME_MAX_BYTES = 200
-- Name tag / glow colours of the variants and the Shiny sparkles.
local GOLD_COLOR = Color3.fromRGB(255, 200, 40)
local RAINBOW_COLOR = Color3.fromRGB(255, 120, 220)
local SHINY_COLOR = Color3.fromRGB(255, 245, 170)

local PetService = {}

local function rarityColor(petId: string): Color3
	local rarity = GameConfig.rarities[GameConfig.pets[petId].rarity]
	return Color3.fromRGB(rarity.color[1], rarity.color[2], rarity.color[3])
end

local function ball(name: string, size: number, color: Color3, cframe: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(size, size, size)
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- The imported Blender model of the pet (tools/blender/build_pets.py), with an
-- invisible root part as PrimaryPart (= pivot) that PetFollow moves. Nil if the
-- model wasn't imported in Studio yet (docs/pc-todo.md, #16).
local function modelPet(petId: string, origin: CFrame): (Model?, BasePart?, number)
	local rarity = GameConfig.rarities[GameConfig.pets[petId].rarity]
	local size = MODEL_SIZE + (rarity.order - 1) * MODEL_SIZE_PER_RARITY
	local model = ModelLibrary.pet(petId, size)
	if model == nil then
		return nil, nil, 0
	end
	local _, boxSize = model:GetBoundingBox()
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	-- Root sits MODEL_LIFT above the model's bottom center, facing the model's front.
	root.CFrame = model:GetPivot() * CFrame.new(0, MODEL_LIFT, 0)
	root.Parent = model
	model.PrimaryPart = root
	model:PivotTo(origin)
	return model, root, boxSize.Y - MODEL_LIFT
end

-- Variant look (#80): Gold glows golden, Rainbow glows pink (the client cycles the
-- colours of models tagged with the "Variant" attribute, see PetFollow), Shiny pets
-- sparkle. Particles follow the low-graphics setting (GraphicsQuality).
local function addVariantLook(body: BasePart, pet: GameRules.OwnedPet)
	local variant = pet.variant or "Normal"
	if variant ~= "Normal" then
		local light = Instance.new("PointLight")
		light.Name = "VariantGlow"
		light.Color = if variant == "Rainbow" then RAINBOW_COLOR else GOLD_COLOR
		light.Range = 7
		light.Brightness = 1.6
		light.Parent = body
	end
	if pet.shiny then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "ShinySparkles"
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(SHINY_COLOR)
		sparkles.LightEmission = 1
		sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		sparkles.Lifetime = NumberRange.new(0.6, 1.1)
		sparkles.Rate = 6
		sparkles.Speed = NumberRange.new(0.5, 1.5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Parent = body
	end
end

-- Pet: the imported model, or a placeholder (round body in the rarity color with
-- eyes); both with a name tag (variant and Shiny in the name, #80).
local function buildPet(pet: GameRules.OwnedPet, origin: CFrame, parent: Instance): Model
	local uid, petId = pet.uid, pet.petId
	local model, body, height = modelPet(petId, origin)
	if model == nil or body == nil then
		model = Instance.new("Model")
		body = ball("Body", PET_SIZE, rarityColor(petId), origin, model)
		for _, side in { -1, 1 } do
			local eyeCFrame = origin * CFrame.new(side * PET_SIZE * 0.2, PET_SIZE * 0.15, -PET_SIZE * 0.42)
			ball("Eye", PET_SIZE * 0.28, Color3.new(1, 1, 1), eyeCFrame, model)
			ball(
				"Pupil",
				PET_SIZE * 0.14,
				Color3.new(0.1, 0.1, 0.1),
				eyeCFrame * CFrame.new(0, 0, -PET_SIZE * 0.1),
				model
			)
		end
		height = PET_SIZE / 2
	end
	assert(model and body, "pet model without body")
	model.Name = tostring(uid)
	model:SetAttribute("PetId", petId)
	model:SetAttribute("Variant", pet.variant or "Normal")
	model:SetAttribute("Shiny", pet.shiny == true)
	addVariantLook(body, pet)

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(160, 32)
	tag.StudsOffset = Vector3.new(0, height + PET_SIZE * 0.4, 0)
	tag.MaxDistance = 60
	tag.Adornee = body
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	-- Each player reads the pet name in their language (#68), with variant/Shiny (#80).
	-- A custom name (#91, filtered for everyone on the server) replaces it.
	local variant = pet.variant or "Normal"
	model:SetAttribute("PetName", pet.name or "")
	if pet.name then
		SignText.set(text, "sign.name", { name = if pet.shiny then `✨ {pet.name}` else pet.name })
	elseif variant ~= "Normal" or pet.shiny then
		local key = if variant ~= "Normal" then `pets.name.{variant}` else "pets.name.shiny"
		local nameArg = Texts.nameArg(GameConfig.pets[petId])
		if variant ~= "Normal" and pet.shiny then
			-- "✨ Gold-Katze": shiny wraps the variant name.
			SignText.set(text, "pets.name.shiny", { pet = { key = key, args = { pet = nameArg } } })
		else
			SignText.set(text, key, { pet = nameArg })
		end
	else
		SignText.set(text, "sign.name", { name = Texts.nameArg(GameConfig.pets[petId]) })
	end
	text.TextColor3 = if variant == "Gold"
		then GOLD_COLOR
		elseif variant == "Rainbow" then RAINBOW_COLOR
		else rarityColor(petId)
	text.TextStrokeTransparency = 0.2
	text.Parent = tag
	tag.Parent = body

	model.PrimaryPart = body
	-- Pets stay anchored where they were equipped on the server; every client moves them
	-- behind their owner (PetFollow). With streaming (phones) single parts of a model
	-- arrived later at that old server spot and floated in the air. Persistent models
	-- are always sent whole to every client and never streamed out.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = parent
	return model
end

function PetService.start()
	local rules = PlayerStates.rules
	local notify = Net.event("Notify")

	local petsFolder = Instance.new("Folder")
	petsFolder.Name = "Pets"
	petsFolder.Parent = Workspace

	-- One folder per player (named by UserId, attribute OwnerUserId) holding the equipped pets.
	local function ownerFolder(player: Player): Folder
		local existing = petsFolder:FindFirstChild(tostring(player.UserId))
		if existing then
			return existing :: Folder
		end
		local folder = Instance.new("Folder")
		folder.Name = tostring(player.UserId)
		folder:SetAttribute("OwnerUserId", player.UserId)
		folder.Parent = petsFolder
		return folder
	end

	local function syncModels(player: Player, state: PlayerState)
		local folder = ownerFolder(player)
		local wanted: { [string]: GameRules.OwnedPet } = {}
		for _, pet in state.pets do
			if table.find(state.equipped, pet.uid) then
				wanted[tostring(pet.uid)] = pet
			end
		end
		for _, child in folder:GetChildren() do
			local pet = wanted[child.Name]
			-- Renamed (#91): rebuild the model so its name tag shows the new name.
			if pet == nil or child:GetAttribute("PetName") ~= (pet.name or "") then
				child:Destroy()
			end
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local origin = if root then root.CFrame * CFrame.new(0, 0, 4) else CFrame.new(0, 3, 0)
		for uid, pet in wanted do
			if folder:FindFirstChild(uid) == nil then
				buildPet(pet, origin, folder)
			end
		end
		-- Slot order for the follow formation = order of equipping.
		for slot, uid in state.equipped do
			local model = folder:FindFirstChild(tostring(uid))
			if model then
				model:SetAttribute("Slot", slot)
			end
		end
	end

	local function replicate(player: Player, state: PlayerState)
		local list = {}
		for _, pet in state.pets do
			table.insert(list, {
				uid = pet.uid,
				petId = pet.petId,
				equipped = table.find(state.equipped, pet.uid) ~= nil,
				variant = rules.petVariant(pet),
				shiny = pet.shiny == true,
				locked = rules.isPetLocked(pet),
				bonus = rules.petBonus(pet),
				level = rules.petLevel(pet),
				xp = math.floor(rules.petXp(pet)),
				xpNeeded = rules.petXpNeeded(rules.petLevel(pet)) or -1,
				name = pet.name,
				foundAt = pet.foundAt,
			})
		end
		player:SetAttribute("Pets", HttpService:JSONEncode(list))
		local teams = {}
		for i = 1, rules.teamCount() do
			teams[i] = rules.petTeam(state, i)
		end
		player:SetAttribute("PetTeams", HttpService:JSONEncode(teams))
		player:SetAttribute("AutoDelete", HttpService:JSONEncode(state.autoDelete or {}))
		player:SetAttribute("PetSlots", rules.petSlots(state))
		player:SetAttribute("InventorySlots", rules.inventorySlots(state))
		-- Pets only (the rebirth factor is shown in the rebirth menu).
		player:SetAttribute("CoinMultiplier", rules.petMultiplier(state))
		syncModels(player, state)
	end

	PlayerStates.onChanged(replicate)
	for _, player in Players:GetPlayers() do
		local state = PlayerStates.get(player)
		if state then
			replicate(player, state)
		end
	end

	local function handle(action: (PlayerState, number) -> GameRules.Result)
		return function(player: Player, uid: unknown)
			if type(uid) ~= "number" then
				return
			end
			local state = PlayerStates.get(player)
			if state == nil then
				return
			end
			local result = action(state, uid)
			if result.ok then
				PlayerStates.set(player, result.state)
			else
				notify:FireClient(player, result.reason)
			end
		end
	end
	Net.event("EquipPet").OnServerEvent:Connect(handle(rules.equipPet))
	Net.event("UnequipPet").OnServerEvent:Connect(handle(rules.unequipPet))
	Net.event("DeletePet").OnServerEvent:Connect(handle(rules.deletePet))
	Net.event("EquipBest").OnServerEvent:Connect(function(player: Player)
		local state = PlayerStates.get(player)
		if state == nil then
			return
		end
		local result = rules.equipBest(state)
		if result.ok then
			PlayerStates.set(player, result.state)
		else
			notify:FireClient(player, result.reason)
		end
	end)

	-- Merging (#80): the rules pick the pets; the client gets the new pet and the used
	-- uids for its animation.
	local features = Features.new(GameConfig.features)
	local petMerged = Net.event("PetMerged")
	local lastMerge: { [Player]: number } = {}
	Net.event("MergePets").OnServerEvent
		:Connect(features.guard("petMerge", function(player: Player, petId: unknown, variant: unknown)
			if type(petId) ~= "string" or type(variant) ~= "string" then
				return
			end
			local now = os.clock()
			if now - (lastMerge[player] or -math.huge) < MERGE_COOLDOWN then
				return
			end
			lastMerge[player] = now
			local state = PlayerStates.get(player)
			if state == nil then
				return
			end
			local result = rules.mergePets(state, petId, variant, os.time())
			if not result.ok then
				notify:FireClient(player, result.reason)
				return
			end
			PlayerStates.set(player, result.state)
			local pet = result.pet :: GameRules.OwnedPet
			petMerged:FireClient(player, {
				uid = pet.uid,
				petId = pet.petId,
				variant = rules.petVariant(pet),
				shiny = pet.shiny == true,
				bonus = rules.petBonus(pet),
				level = rules.petLevel(pet),
			}, result.consumed)
		end))

	-- Pet levels (#90): equipped pets gain XP from play time (like the play time gifts,
	-- time while the state is still loading is not credited). A level up is announced
	-- with Notify("PetLevelUp", level, petId).
	local lastXp: { [Player]: number } = {}
	local function trackXp(player: Player)
		lastXp[player] = os.clock()
	end
	Players.PlayerAdded:Connect(trackXp)
	for _, player in Players:GetPlayers() do
		trackXp(player)
	end
	task.spawn(function()
		while true do
			task.wait(XP_TICK)
			if not features.enabled("petLevels") then
				continue
			end
			local now = os.clock()
			for player, since in lastXp do
				lastXp[player] = now
				local state = PlayerStates.get(player)
				if state == nil then
					continue
				end
				local result = rules.addPetXp(state, now - since)
				if not result.ok then
					continue
				end
				if result.state ~= state then
					PlayerStates.set(player, result.state)
				end
				for _, up in result.leveledUp do
					notify:FireClient(player, "PetLevelUp", up.level, up.petId)
				end
			end
		end
	end)

	-- Pet management (#91): lock, delete several, auto-delete, teams, rename. Every request
	-- goes through its feature switch and the rules; failures come back as Notify.
	local lastManage: { [Player]: number } = {}
	local function manage(featureId: string, cooldown: number, run: (Player, PlayerState, ...any) -> GameRules.Result?)
		return features.guard(featureId, function(player: Player, ...: any)
			local now = os.clock()
			if now - (lastManage[player] or -math.huge) < cooldown then
				return
			end
			lastManage[player] = now
			local state = PlayerStates.get(player)
			if state == nil then
				return
			end
			local result = run(player, state, ...)
			if result == nil then
				return
			end
			if result.ok then
				-- The state may have changed while the text filter ran (rename).
				PlayerStates.set(player, result.state)
			elseif result.reason ~= "Unchanged" then
				notify:FireClient(player, result.reason)
			end
		end)
	end

	Net.event("LockPet").OnServerEvent:Connect(manage("petLock", MANAGE_COOLDOWN, function(_, state, uid, locked)
		if type(uid) ~= "number" or type(locked) ~= "boolean" then
			return nil
		end
		return rules.setPetLocked(state, uid, locked)
	end))
	Net.event("DeletePets").OnServerEvent:Connect(manage("petMultiDelete", MANAGE_COOLDOWN, function(_, state, uids)
		if type(uids) ~= "table" then
			return nil
		end
		return rules.deletePets(state, uids)
	end))
	Net.event("SetAutoDelete").OnServerEvent
		:Connect(manage("petAutoDelete", MANAGE_COOLDOWN, function(_, state, rarity, enabled)
			if type(rarity) ~= "string" or type(enabled) ~= "boolean" then
				return nil
			end
			return rules.setAutoDelete(state, rarity, enabled)
		end))
	Net.event("SaveTeam").OnServerEvent:Connect(manage("petTeams", MANAGE_COOLDOWN, function(_, state, index)
		if type(index) ~= "number" then
			return nil
		end
		return rules.saveTeam(state, index)
	end))
	Net.event("EquipTeam").OnServerEvent:Connect(manage("petTeams", MANAGE_COOLDOWN, function(_, state, index)
		if type(index) ~= "number" then
			return nil
		end
		return rules.equipTeam(state, index)
	end))
	-- Renaming: the raw name is filtered for everyone (it shows on the name tag above the
	-- pet) before the rules check it. A filter error refuses the name (Notify FilterFailed).
	Net.event("RenamePet").OnServerEvent:Connect(manage("petRename", RENAME_COOLDOWN, function(player, _, uid, name)
		if type(uid) ~= "number" or type(name) ~= "string" or #name > RENAME_MAX_BYTES then
			return nil
		end
		local filtered = ""
		if string.match(name, "%S") then
			local ok, text = pcall(function()
				local result = TextService:FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PublicChat)
				return result:GetNonChatStringForBroadcastAsync()
			end)
			if not ok or type(text) ~= "string" then
				notify:FireClient(player, "FilterFailed")
				return nil
			end
			filtered = text
		end
		-- Re-read the state: the filter call yields.
		local current = PlayerStates.get(player)
		if current == nil then
			return nil
		end
		return rules.renamePet(current, uid, filtered)
	end))

	Players.PlayerRemoving:Connect(function(player)
		lastManage[player] = nil
		lastMerge[player] = nil
		lastXp[player] = nil
		local folder = petsFolder:FindFirstChild(tostring(player.UserId))
		if folder then
			folder:Destroy()
		end
	end)
end

return PetService
