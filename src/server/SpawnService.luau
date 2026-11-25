--!strict
-- Respawn in the current world (#25): remembers the world a player is in and puts
-- every new character (after death and on join) at that world's spawn point. Which
-- world counts and where to spawn is decided by the game rules (enterWorld /
-- spawnWorld); this service only watches positions and moves characters.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerStates = require(script.Parent.PlayerStates)
local WorldMap = require(script.Parent.WorldMap)

local CHECK_SECONDS = 0.5

local SpawnService = {}

-- First visit of a world (#79): the rules mark the intro as seen, the client plays it.
local worldIntro = Net.event("WorldIntro")

local indexById: { [string]: number } = {}
for index, world in GameConfig.worlds do
	indexById[world.id] = index
end

-- Characters already put at their spawn; only those count for "entering" a world, so a
-- fresh character standing at the default spawn does not overwrite the saved world.
local placed: { [Player]: Model } = {}

-- Asks the rules to remember `worldId` as the player's respawn world (portals call this
-- right after teleporting). Locked or unknown worlds are refused by the rules. On the
-- first entry of a world the rules also mark its intro as seen (saved with the state)
-- and the client is told to play it (#79).
function SpawnService.enterWorld(player: Player, worldId: string)
	local state = PlayerStates.get(player)
	if state == nil then
		return
	end
	local result = PlayerStates.rules.enterWorld(state, worldId)
	if result.ok and result.state ~= state then
		PlayerStates.set(player, result.state)
	end
	if result.ok and result.intro then
		worldIntro:FireClient(player, worldId)
	end
end

-- World index the player respawns in, or nil for the start (spawn island).
local function respawnIndex(state: any): number?
	local worldId = PlayerStates.rules.spawnWorld(state)
	return if worldId then indexById[worldId] else nil
end

-- A character that fell off the islands is put back on the spawn of its current world
-- (the same place a death would respawn it), without waiting for a death.
local function catchFall(player: Player, character: Model, root: BasePart)
	local state = PlayerStates.get(player)
	if state == nil then
		return
	end
	local index = respawnIndex(state)
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(if index then WorldMap.spawnPointOf(index) else WorldMap.startSpawnPoint())
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
	local index = respawnIndex(state)
	-- "Start" (no respawn world yet) uses the SpawnLocation on the spawn island (#27).
	if index then
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

	-- Walking across a world border counts as entering that world; falling off an island
	-- (below GameConfig.islands.fallY) puts the character back on its world's spawn.
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for player, character in placed do
				local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if player.Character == character and root and WorldMap.hasFallen(root.Position) then
					catchFall(player, character, root)
				elseif player.Character == character and root then
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
