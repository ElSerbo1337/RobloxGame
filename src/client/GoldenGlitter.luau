--!strict
-- Golden toppings on the field (#94): the topping field is shared, the golden chance is
-- per player. The server tags every normal topping part with its gold roll (attribute
-- GoldRoll, tag GoldenLook.FIELD_TAG) and replicates the player's chance (attribute
-- GoldenChance); this module glitters the toppings that are golden for this player.
-- Purely visual: the server's rules decide on collect whether a topping was golden.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoldenLook = require(ReplicatedStorage.Shared.GoldenLook)

local GoldenGlitter = {}

function GoldenGlitter.start()
	local player = Players.LocalPlayer

	local function chance(): number
		return (player:GetAttribute("GoldenChance") :: number?) or 0
	end

	local function update(part: Instance)
		if not part:IsA("BasePart") then
			return
		end
		local roll = part:GetAttribute("GoldRoll")
		if type(roll) == "number" and roll < chance() then
			GoldenLook.apply(part)
		else
			GoldenLook.remove(part)
		end
	end

	CollectionService:GetInstanceAddedSignal(GoldenLook.FIELD_TAG):Connect(update)
	for _, part in CollectionService:GetTagged(GoldenLook.FIELD_TAG) do
		update(part)
	end
	-- Gold Luck bought, gold potion started or ended: re-check every lying topping.
	player:GetAttributeChangedSignal("GoldenChance"):Connect(function()
		for _, part in CollectionService:GetTagged(GoldenLook.FIELD_TAG) do
			update(part)
		end
	end)
end

return GoldenGlitter
