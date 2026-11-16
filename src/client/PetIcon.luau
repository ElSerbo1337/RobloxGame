--!strict
-- Pet pictures for the UI (egg preview, pet menu, hatch card): a small 3D view of the
-- imported pet model (ViewportFrame), so no image upload is needed. Without the Studio
-- import (docs/pc-todo.md, #16) callers keep their dot in the rarity color.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)

local PetIcon = {}

-- Shows the pet in `holder`, centered and `scale` times its size (a bit larger than
-- the holder so the pet pops out of its circle). Returns false if there is no model.
function PetIcon.show(holder: GuiObject, petId: string, scale: number?): boolean
	local view = ModelLibrary.viewport(petId)
	if view == nil then
		return false
	end
	local size = scale or 1.25
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.Position = UDim2.fromScale(0.5, 0.5)
	view.Size = UDim2.fromScale(size, size)
	view.ZIndex = holder.ZIndex + 1
	view.Parent = holder
	return true
end

return PetIcon
