--!strict
-- Respawn in the current world (#25): remembers the world a player is in and puts
-- every new character (after death and on join) at that world's spawn point. Which
-- world counts and where to spawn is decided by the game rules (enterWorld /
-- spawnWorld); this service only watches positions and moves characters.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlayerStates = require(script.Parent.PlayerStates)
local WorldMap = require(script.Parent.WorldMap)

local CHECK_SECONDS = 0.5

local SpawnService = {}

local indexById: { [string]: number } = {}
for index, world in GameConfig.worlds do
	indexById[world.id] = index
end

-- Characters already put at their spawn; only those count for "entering" a world, so a
-- fresh character standing at the default spawn does not overwrite the saved world.
local placed: { [Player]: Model } = {}

-- Asks the rules to remember `worldId` as the player's respawn world (portals call this
-- right after teleporting). Locked or unknown worlds are refused by the rules.
function SpawnService.enterWorld(player: Player, worldId: string)
	local state = PlayerStates.get(player)
	if state == nil then
		return
	end
	local result = PlayerStates.rules.enterWorld(state, worldId)
	if result.ok and result.state ~= state then
		PlayerStates.set(player, result.state)
	end
end

-- Moves a new character to the spawn of the player's world. Waits until the state is
-- loaded (on join the character can appear before the save is read).
local function place(player: Player, character: Model)
	local state = PlayerStates.get(player)
	while state == nil and player.Parent ~= nil and player.Character == character do
		task.wait(0.1)
		state = PlayerStates.get(player)
	end
	if state == nil or player.Character ~= character then
		return
	end
	if character:WaitForChild("HumanoidRootPart", 10) == nil then
		return
	end
	-- Let the engine finish putting the character on the SpawnLocation first.
	task.wait()
	if player.Character ~= character then
		return
	end
	local worldId = PlayerStates.rules.spawnWorld(state)
	local index = if worldId then indexById[worldId] else nil
	-- World 1 and "start" use the normal SpawnLocation in world 1.
	if index and index > 1 then
		character:PivotTo(WorldMap.spawnPointOf(index))
	end
	placed[player] = character
end

function SpawnService.start()
	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			placed[player] = nil
			place(player, character)
		end)
		if player.Character then
			task.spawn(place, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		placed[player] = nil
	end)

	-- Walking across a world border counts as entering that world.
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for player, character in placed do
				local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if player.Character == character and root then
					local index = WorldMap.worldIndexAt(root.Position)
					if index then
						SpawnService.enterWorld(player, GameConfig.worlds[index].id)
					end
				end
			end
		end
	end)
end

return SpawnService
