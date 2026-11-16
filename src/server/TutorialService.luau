--!strict
-- Marks the places the new-player tutorial points at, so the client can draw its
-- arrow there. Tutorial progress itself lives in the game rules: collecting,
-- selling, buying and opening eggs move it on, and PlayerStates replicates it
-- (attributes TutorialStep, TutorialNumber, TutorialTotal, TutorialProgress, TutorialGoal).
--
-- Every target is tagged "TutorialTarget" with the attribute TutorialStep = step id.
-- For "CollectToppings" the target is a folder; the client points at its nearest topping.

local CollectionService = game:GetService("CollectionService")

local TutorialService = {}

TutorialService.TAG = "TutorialTarget"

export type Targets = {
	CollectToppings: Instance,
	SellPizza: Instance,
	BuyUpgrade: Instance,
	OpenEgg: Instance,
}

function TutorialService.start(targets: Targets)
	for stepId, target in targets :: { [string]: Instance } do
		target:SetAttribute("TutorialStep", stepId)
		CollectionService:AddTag(target, TutorialService.TAG)
	end
end

return TutorialService
