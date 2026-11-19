--!strict
-- Only one menu at a time (#53). Pure Luau without Roblox API, tested in Lune
-- (tests/MenuSwitch.spec.luau). The client uses one switch through UiKit
-- (UiKit.registerMenu / UiKit.menuOpened); docs/ui-style.md explains the rule.
--
-- Every menu registers with an id and its normal close function (the one its "X" uses).
-- When a menu reports that it opened, every other menu that opened before is closed
-- through that function, in registration order. Close functions must be safe to call
-- on a menu that is already closed (a menu closed by "X" is not reported).

export type MenuSwitch = {
	register: (id: string, close: () -> ()) -> (),
	opened: (id: string) -> (),
}

local MenuSwitch = {}

function MenuSwitch.new(): MenuSwitch
	local order: { string } = {}
	local closers: { [string]: () -> () } = {}
	local open: { [string]: boolean } = {}

	local function register(id: string, close: () -> ())
		if closers[id] == nil then
			table.insert(order, id)
		end
		closers[id] = close
	end

	local function opened(id: string)
		open[id] = true
		for _, other in order do
			if other ~= id and open[other] then
				open[other] = nil
				closers[other]()
			end
		end
	end

	return { register = register, opened = opened }
end

return MenuSwitch
