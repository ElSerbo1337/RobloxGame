--!strict
-- Pets: equip/unequip requests, replication of the pet inventory, and the pet models
-- that follow their owner. The server only creates/removes the models (so every player
-- sees them); each client moves all pet models locally for smooth following (PetFollow).
--
-- Replicated player attributes:
--   Pets            JSON list of { uid, petId, equipped }
--   PetSlots        how many pets can be equipped
--   CoinMultiplier  1 + sum of equipped pet bonuses

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)

type PlayerState = GameRules.PlayerState

local PET_SIZE = 2.2

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

-- Placeholder pet: round body in the rarity color with eyes and a name tag.
local function buildPet(uid: number, petId: string, origin: CFrame, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = tostring(uid)
	model:SetAttribute("PetId", petId)

	local body = ball("Body", PET_SIZE, rarityColor(petId), origin, model)
	for _, side in { -1, 1 } do
		local eyeCFrame = origin * CFrame.new(side * PET_SIZE * 0.2, PET_SIZE * 0.15, -PET_SIZE * 0.42)
		ball("Eye", PET_SIZE * 0.28, Color3.new(1, 1, 1), eyeCFrame, model)
		ball("Pupil", PET_SIZE * 0.14, Color3.new(0.1, 0.1, 0.1), eyeCFrame * CFrame.new(0, 0, -PET_SIZE * 0.1), model)
	end

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(160, 32)
	tag.StudsOffset = Vector3.new(0, PET_SIZE * 0.9, 0)
	tag.MaxDistance = 60
	tag.Adornee = body
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = GameConfig.pets[petId].displayName
	text.TextColor3 = rarityColor(petId)
	text.TextStrokeTransparency = 0.2
	text.Parent = tag
	tag.Parent = body

	model.PrimaryPart = body
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
		player:SetAttribute("CoinMultiplier", rules.coinMultiplier(state))
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

	Players.PlayerRemoving:Connect(function(player)
		local folder = petsFolder:FindFirstChild(tostring(player.UserId))
		if folder then
			folder:Destroy()
		end
	end)
end

return PetService
