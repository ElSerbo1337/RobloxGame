--!strict
-- Camera occlusion for everyone: Invisicam. Objects between the camera and the
-- character turn see-through instead of pushing the camera up to the head
-- (ovens, shops, egg stands and phones stood behind the camera; #22).
-- StarterPlayer's value is copied to players when they join; players already in the
-- game (e.g. in Studio, where the player can join before this runs) get it directly.

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local MODE = Enum.DevCameraOcclusionMode.Invisicam

local CameraService = {}

function CameraService.start()
	StarterPlayer.DevCameraOcclusionMode = MODE
	local function apply(player: Player)
		player.DevCameraOcclusionMode = MODE
	end
	Players.PlayerAdded:Connect(apply)
	for _, player in Players:GetPlayers() do
		apply(player)
	end
end

return CameraService
