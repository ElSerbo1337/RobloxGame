local TestKit = require("./TestKit")
local SaleNumbers = require("../src/shared/SaleNumbers")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("SaleNumbers", function()
	it("shows the first sale and normal sales in white", function()
		expect(SaleNumbers.stage(500, nil)).toBe(1)
		expect(SaleNumbers.stage(100, 100)).toBe(1)
		expect(SaleNumbers.stage(149, 100)).toBe(1)
	end)

	it("goes white -> yellow -> orange -> pink as the sale grows against the average", function()
		expect(SaleNumbers.stage(150, 100)).toBe(2)
		expect(SaleNumbers.stage(300, 100)).toBe(3)
		expect(SaleNumbers.stage(600, 100)).toBe(4)
		expect(SaleNumbers.stage(1e12, 100)).toBe(4)
	end)

	it("has one colour and one scale per stage", function()
		expect(#SaleNumbers.COLORS).toBe(#SaleNumbers.STAGE_RATIOS + 1)
		expect(#SaleNumbers.SCALES).toBe(#SaleNumbers.STAGE_RATIOS + 1)
	end)

	it("starts the running average with the first sale and moves it towards new sales", function()
		expect(SaleNumbers.nextAverage(nil, 200)).toBe(200)
		expect(SaleNumbers.nextAverage(100, 600)).toBe(200)
	end)
end)
