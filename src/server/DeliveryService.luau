--!strict
-- Delivery service (phone -> order -> delivery van), one phone and one van per world.
-- * The phone rings per player: the server asks the rules every second (rules.ringPhone)
--   and replicates PhoneRinging; each client shows and plays the ringing for itself.
-- * Standing at the phone opens its panel on the client (PhoneOpen): the order while it
--   rings, otherwise just the switch to turn calls off or on (after the tutorial). The
--   client only answers with AnswerPhone / SetPhoneCalls; the server checks the player
--   is at a phone.
-- * Walking into the van's zone with an active order delivers it (rules.deliverOrder).
-- * When an order's time is up, the server ends it through rules.expireOrder.
-- Time is the server clock (os.time(), seconds), so an accepted order keeps running
-- while the player is offline and is gone after rejoining once its time is up.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)
local WorldMap = require(script.Parent.WorldMap)

type PlayerState = GameRules.PlayerState

local CHECK_SECONDS = 0.25
-- How often the rules are asked about ringing/expiry and the HUD order card is re-synced.
local RULES_SECONDS = 1
local SYNC_SECONDS = 5
-- Blender models (#28), widest side in studs; used once imported, else the parts below.
local PHONE_MODEL_WIDTH = 2.2
local VAN_MODEL_LENGTH = 13.2

export type Station = { worldId: string, phoneZone: BasePart, vanZone: BasePart }

local DeliveryService = {}

local function isInside(zone: BasePart, position: Vector3): boolean
	local relative = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function sign(parent: Instance, adornee: BasePart, text: string, height: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromScale(10, 2.5)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	billboard.MaxDistance = 150
	billboard.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 240, 200)
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard
	billboard.Parent = parent
end

local function invisibleZone(name: string, size: Vector3, position: Vector3, parent: Instance): Part
	return part({
		Name = name,
		Size = size,
		Position = position,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = parent,
	})
end

-- Phone: the rotary phone model (facing the topping area, -X) or, until it is imported,
-- a red retro phone on a post. The client finds it by the "Handset" part (attribute
-- DeliveryPhone) and makes it ring for its own player; with the model it stays invisible.
local function buildPhone(parent: Instance, ground: Vector3): BasePart
	local model = Instance.new("Model")
	model.Name = "DeliveryPhone"
	part({
		Name = "Post",
		Size = Vector3.new(1, 3.5, 1),
		Position = ground + Vector3.new(0, 1.75, 0),
		Color = Color3.fromRGB(120, 80, 50),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	local handset = part({
		Name = "Handset",
		Size = Vector3.new(2.4, 1.4, 1.8),
		Position = ground + Vector3.new(0, 4.2, 0),
		Color = Color3.fromRGB(220, 50, 45),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	part({
		Name = "Receiver",
		Size = Vector3.new(2.8, 0.5, 0.7),
		Position = ground + Vector3.new(0, 5.15, 0),
		Color = Color3.fromRGB(60, 35, 20),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	handset:SetAttribute("DeliveryPhone", true)
	sign(model, handset, "📞 Telefon – Aufträge", 3)
	ModelLibrary.dressPlaceholder(
		model,
		"Telephone",
		PHONE_MODEL_WIDTH,
		CFrame.lookAt(ground, ground - Vector3.xAxis),
		{ "Post", "Handset", "Receiver" }
	)
	model.Parent = parent
	return invisibleZone("PhoneZone", Vector3.new(10, 8, 10), ground + Vector3.new(0, 4, 0), model)
end

-- Delivery van: the van model with the pizza box on its roof or, until it is imported,
-- a box truck from parts. Along Z, cab at −Z, the hand-over zone on its −X side.
local function buildVan(parent: Instance, ground: Vector3): BasePart
	local model = Instance.new("Model")
	model.Name = "DeliveryVan"
	local body = part({
		Name = "Cargo",
		Size = Vector3.new(6, 6, 9),
		Position = ground + Vector3.new(0, 4, 2),
		Color = Color3.fromRGB(255, 248, 230),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	part({
		Name = "Cab",
		Size = Vector3.new(6, 4, 3.5),
		Position = ground + Vector3.new(0, 3, -4.25),
		Color = Color3.fromRGB(230, 70, 50),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	part({
		Name = "Window",
		Size = Vector3.new(5.6, 1.6, 0.2),
		Position = ground + Vector3.new(0, 4, -6.05),
		Color = Color3.fromRGB(150, 210, 240),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		Parent = model,
	})
	part({
		Name = "Stripe",
		Size = Vector3.new(6.1, 1, 9.1),
		Position = ground + Vector3.new(0, 3.2, 2),
		Color = Color3.fromRGB(240, 130, 60),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	for _, offset in { Vector3.new(-3, 0, -4), Vector3.new(3, 0, -4), Vector3.new(-3, 0, 4), Vector3.new(3, 0, 4) } do
		part({
			Name = "Wheel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 2.2, 2.2),
			Position = ground + offset + Vector3.new(0, 1.1, 0),
			Color = Color3.fromRGB(50, 45, 45),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
	end
	sign(model, body, "🚚 Lieferwagen – Bestellung abgeben", 5)
	ModelLibrary.dressPlaceholder(
		model,
		"DeliveryVan",
		VAN_MODEL_LENGTH,
		CFrame.new(ground),
		{ "Cargo", "Cab", "Window", "Stripe", "Wheel" }
	)
	model.Parent = parent
	-- Hand-over zone beside the van, towards the topping area.
	return invisibleZone("VanZone", Vector3.new(7, 7, 14), ground + Vector3.new(-6.5, 3.5, 0), model)
end

-- One phone and one van per configured world, on the station spots of its island.
function DeliveryService.buildAll(): { Station }
	local folder = Instance.new("Folder")
	folder.Name = "Delivery"
	folder.Parent = Workspace
	local stations = {}
	-- Phone and van are built facing -X (their hand-over side); the station yaw from
	-- WorldMap is for a -Z facing station, so turn by yaw - 90 degrees.
	local function placed(zone: BasePart, spot: CFrame): BasePart
		local _, yaw = spot:ToEulerAnglesYXZ()
		local model = zone.Parent :: Model
		model.WorldPivot = CFrame.new(spot.Position)
		model:PivotTo(CFrame.new(spot.Position) * CFrame.Angles(0, yaw - math.pi / 2, 0))
		return zone
	end
	for index, world in GameConfig.worlds do
		local phone = WorldMap.station(index, "Phone") :: CFrame
		local van = WorldMap.station(index, "Van") :: CFrame
		table.insert(stations, {
			worldId = world.id,
			phoneZone = placed(buildPhone(folder, phone.Position), phone),
			vanZone = placed(buildVan(folder, van.Position), van),
		})
	end
	return stations
end

local function counts(pizza: { string }): { [string]: number }
	local result = {}
	for _, toppingId in pizza do
		result[toppingId] = (result[toppingId] or 0) + 1
	end
	return result
end

local function replicate(player: Player, state: PlayerState)
	local rules = PlayerStates.rules
	player:SetAttribute("PhoneRinging", rules.deliveryCall(state) ~= nil)
	player:SetAttribute("PhoneCalls", state.phoneCalls)
	local order = rules.activeOrder(state)
	if order == nil then
		player:SetAttribute("DeliveryOrder", "")
		return
	end
	local now = os.time()
	local reward = rules.orderReward(state, now)
	player:SetAttribute(
		"DeliveryOrder",
		HttpService:JSONEncode({
			toppings = order.toppings,
			have = counts(state.pizza),
			reward = order.reward,
			potionId = order.potionId,
			secondsLeft = rules.orderTimeLeft(state, now),
			rewardNow = if reward then reward.amount else 0,
		})
	)
end

function DeliveryService.start(stations: { Station })
	local notify = Net.event("Notify")
	local phoneOpen = Net.event("PhoneOpen")
	local phoneClose = Net.event("PhoneClose")
	local rules = PlayerStates.rules
	local random = Random.new()
	local function draw(): number
		return random:NextNumber()
	end

	-- Where each player stands: the phone zone they are in (world id) and whether they
	-- are at a van (one delivery attempt per visit).
	local atPhone: { [Player]: string } = {}
	local atVan: { [Player]: boolean } = {}
	-- Whether the order panel is open for the player.
	local phoneShown: { [Player]: boolean } = {}

	local function showPhone(player: Player, state: PlayerState)
		if not state.phoneCalls then
			-- Calls are off: the panel offers to switch them back on.
			phoneOpen:FireClient(player, nil, nil, nil)
			phoneShown[player] = true
			return
		end
		local call = rules.deliveryCall(state)
		if call == nil then
			-- No call right now (quiet time or an order running): the panel still offers
			-- to switch calls off, so players can do that at any time (not during the
			-- tutorial, where the phone stays silent anyway).
			if rules.tutorial(state) ~= nil then
				return
			end
			phoneOpen:FireClient(player, nil, nil, nil, true)
			phoneShown[player] = true
			return
		end
		-- Show the best case: the reward if delivered right after accepting.
		local preview = rules.acceptOrder(state, os.time()).state
		phoneOpen:FireClient(player, call, rules.orderReward(preview, os.time()), GameConfig.delivery.timeLimitSeconds)
		phoneShown[player] = true
	end

	local function hidePhone(player: Player)
		if phoneShown[player] then
			phoneShown[player] = nil
			phoneClose:FireClient(player)
		end
	end

	PlayerStates.onChanged(replicate)
	for _, player in Players:GetPlayers() do
		local state = PlayerStates.get(player)
		if state then
			replicate(player, state)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		atPhone[player] = nil
		atVan[player] = nil
		phoneShown[player] = nil
	end)

	Net.event("AnswerPhone").OnServerEvent:Connect(function(player: Player, accept: unknown)
		if type(accept) ~= "boolean" or atPhone[player] == nil then
			return -- only answer while standing at a phone
		end
		local state = PlayerStates.get(player)
		if state == nil then
			return
		end
		local result = if accept then rules.acceptOrder(state, os.time()) else rules.declineOrder(state, os.time())
		hidePhone(player)
		if result.ok then
			PlayerStates.set(player, result.state)
			notify:FireClient(player, if accept then "OrderAccepted" else "OrderDeclined")
		end
	end)

	Net.event("SetPhoneCalls").OnServerEvent:Connect(function(player: Player, enabled: unknown)
		if type(enabled) ~= "boolean" or atPhone[player] == nil then
			return -- only switched at a phone
		end
		local state = PlayerStates.get(player)
		if state == nil then
			return
		end
		local result = rules.setPhoneCalls(state, enabled, os.time())
		if result.ok then
			PlayerStates.set(player, result.state)
			hidePhone(player)
			notify:FireClient(player, if enabled then "PhoneCallsOn" else "PhoneCallsOff")
			if not enabled then
				showPhone(player, result.state)
			end
		end
	end)

	local function deliver(player: Player, state: PlayerState)
		if rules.activeOrder(state) == nil then
			notify:FireClient(player, "NoOrder")
			return
		end
		local result = rules.deliverOrder(state, os.time())
		if result.ok and result.reward then
			PlayerStates.set(player, result.state)
			notify:FireClient(player, "Delivered", result.reward.amount, result.reward.reward, result.reward.potionId)
		elseif result.reason == "WrongToppings" then
			notify:FireClient(player, "WrongToppings")
		end
	end

	-- Ringing, expiry and re-syncing the HUD timer/reward.
	task.spawn(function()
		local sinceSync = 0
		while true do
			task.wait(RULES_SECONDS)
			sinceSync += RULES_SECONDS
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local state = PlayerStates.get(player)
				if state == nil then
					continue
				end
				if rules.activeOrder(state) then
					local expired = rules.expireOrder(state, now)
					if expired.ok then
						PlayerStates.set(player, expired.state)
						notify:FireClient(player, "OrderExpired")
					elseif sinceSync >= SYNC_SECONDS then
						replicate(player, state)
					end
				else
					local rung = rules.ringPhone(state, now, draw)
					if rung.ok then
						PlayerStates.set(player, rung.state)
						notify:FireClient(player, "PhoneRinging")
						if atPhone[player] then
							showPhone(player, rung.state)
						end
					end
				end
			end
			if sinceSync >= SYNC_SECONDS then
				sinceSync = 0
			end
		end
	end)

	-- Who stands at which phone / van.
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local phone: string?, van = nil, false
				if root then
					for _, station in stations do
						if isInside(station.phoneZone, root.Position) then
							phone = station.worldId
						end
						if isInside(station.vanZone, root.Position) then
							van = true
						end
					end
				end
				local state = PlayerStates.get(player)

				if phone ~= atPhone[player] then
					atPhone[player] = phone
					if phone and state then
						showPhone(player, state)
					else
						hidePhone(player)
					end
				end

				if van ~= (atVan[player] == true) then
					atVan[player] = van or nil
					if van and state then
						deliver(player, state)
					end
				end
			end
		end
	end)
end

return DeliveryService
