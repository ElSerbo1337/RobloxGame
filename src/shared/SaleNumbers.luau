--!strict
-- Big coloured sale numbers (#110, juice): pure rules, no Roblox API.
-- The colour stage of a sale depends on how big it is compared with the player's
-- recent sales (a running average), so a big sale stands out in every world:
--   stage 1 white  (normal sale)
--   stage 2 yellow (>= 1.5 x the average)
--   stage 3 orange (>= 3 x)
--   stage 4 pink   (>= 6 x)
-- The first sale (no average yet) is white.

local SaleNumbers = {}

-- Minimum ratio (sale / average) per stage, ascending.
SaleNumbers.STAGE_RATIOS = { 1.5, 3, 6 }
-- RGB 0-255 per stage: white -> yellow -> orange -> pink.
SaleNumbers.COLORS = {
	{ 255, 255, 255 },
	{ 255, 220, 50 },
	{ 255, 140, 40 },
	{ 255, 80, 180 },
}
-- Text size grows with the stage (scale factor per stage).
SaleNumbers.SCALES = { 1, 1.2, 1.45, 1.75 }
-- Weight of a new sale in the running average.
SaleNumbers.AVERAGE_WEIGHT = 0.2

-- 1..4 for `amount` compared with the running `average` (nil/0 = no average yet).
function SaleNumbers.stage(amount: number, average: number?): number
	if average == nil or average <= 0 or amount <= 0 then
		return 1
	end
	local ratio = amount / average
	local stage = 1
	for index, minimum in SaleNumbers.STAGE_RATIOS do
		if ratio >= minimum then
			stage = index + 1
		end
	end
	return stage
end

-- Running average after a sale of `amount`.
function SaleNumbers.nextAverage(average: number?, amount: number): number
	if average == nil or average <= 0 then
		return amount
	end
	return average + (amount - average) * SaleNumbers.AVERAGE_WEIGHT
end

return SaleNumbers
