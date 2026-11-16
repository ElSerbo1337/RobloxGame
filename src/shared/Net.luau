--!strict
-- RemoteEvents between client and server. The server creates them, the client waits for them.
--
-- CollectTopping  client -> server  (slotId: number, worldId: string)  "I tapped this topping"
-- SetAutoCollect  client -> server  (enabled: boolean)          "switch auto-collect on/off"
-- UnlockWorld     client -> server  (worldId: string)          "I want to buy the barrier to this world"
-- Notify          server -> client  (kind: string, amount: number?)  feedback, e.g. "PizzaFull", "Sold"
--
-- Player state for the HUD is replicated via player attributes (see PlayerStates on the server):
-- Coins, PizzaCount, PizzaCapacity, AutoCollect, UnlockedWorlds (comma-separated world ids bought).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local EVENTS = {
	CollectTopping = true,
	SetAutoCollect = true,
	Notify = true,
	UnlockWorld = true,
}

local Net = {}

function Net.event(name: string): RemoteEvent
	assert(EVENTS[name], `unknown remote event "{name}"`)

	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if folder == nil then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		local event = folder:FindFirstChild(name)
		if event == nil then
			event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
		return event :: RemoteEvent
	end

	return ReplicatedStorage:WaitForChild(FOLDER_NAME):WaitForChild(name) :: RemoteEvent
end

return Net
