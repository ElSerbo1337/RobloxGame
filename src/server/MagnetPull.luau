--!strict
-- Cosmetic only: a topping picked up by auto-collect (and the magnet) flies into the
-- player's pizza instead of just vanishing. The pickup itself already happened.

local TweenService = game:GetService("TweenService")

local FLY_SECONDS = 0.25

local MagnetPull = {}

function MagnetPull.fly(topping: BasePart, root: BasePart)
	local ghost = topping:Clone()
	ghost:SetAttribute("SlotId", nil)
	ghost.Name = "PulledTopping"
	ghost.Parent = topping.Parent and topping.Parent.Parent or topping.Parent
	local tween =
		TweenService:Create(ghost, TweenInfo.new(FLY_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = root.Position,
			Size = ghost.Size * 0.3,
		})
	tween.Completed:Once(function()
		ghost:Destroy()
	end)
	tween:Play()
end

return MagnetPull
