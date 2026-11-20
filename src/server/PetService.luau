--!strict
-- Pets: equip/unequip requests, replication of the pet inventory, and the pet models
-- that follow their owner. The server only creates/removes the models (so every player
-- sees them); each client moves all pet models locally for smooth following (PetFollow).
--
-- Replicated player attributes:
--   Pets            JSON list of { uid, petId, equipped }
--   PetSlots        how many pets can be equipped
--   InventorySlots  how many pets can be owned (full inventory blocks opening eggs)
--   CoinMultiplier  1 + sum of equipped pet bonuses

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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

-- Pet: the imported model, or a placeholder (round body in the rarity color with
-- eyes); both with a name tag.
local function buildPet(uid: number, petId: string, origin: CFrame, parent: Instance): Model
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
	-- Each player reads the pet name in their language (#68).
	SignText.set(text, "sign.name", { name = Texts.nameArg(GameConfig.pets[petId]) })
	text.TextColor3 = rarityColor(petId)
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
		local wanted: { [string]: string } = {}
		for _, pet in state.pets do
			if table.find(state.equipped, pet.uid) then
				wanted[tostring(pet.uid)] = pet.petId
			end
		end
		for _, child in folder:GetChildren() do
			if wanted[child.Name] == nil then
				child:Destroy()
			end
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local origin = if root then root.CFrame * CFrame.new(0, 0, 4) else CFrame.new(0, 3, 0)
		for uid, petId in wanted do
			if folder:FindFirstChild(uid) == nil then
				buildPet(tonumber(uid) :: number, petId, origin, folder)
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
			})
		end
		player:SetAttribute("Pets", HttpService:JSONEncode(list))
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

	Players.PlayerRemoving:Connect(function(player)
		local folder = petsFolder:FindFirstChild(tostring(player.UserId))
		if folder then
			folder:Destroy()
		end
	end)
end

return PetService
