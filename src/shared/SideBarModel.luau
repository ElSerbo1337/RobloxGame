--!strict
-- Side bar bookkeeping (#75): which tiles exist, in which order, which show a red dot
-- ("has news") and which go behind the "More" tile when the bar has too few places.
-- Pure Luau without Roblox API, tested in Lune (tests/SideBar.spec.luau). The client
-- side (tiles, 3D icons, the More popup) is src/client/SideBar.luau.

export type Arranged = {
	shown: { string }, -- ids in the bar, in place order
	hidden: { string }, -- ids behind "More", in order
	more: boolean, -- the last place is the "More" tile
	moreBadge: boolean, -- a hidden tile has a red dot
}

export type Model = {
	register: (id: string, order: number) -> (),
	setBadge: (id: string, on: boolean) -> (),
	badge: (id: string) -> boolean,
	arrange: (places: number) -> Arranged,
}

local SideBarModel = {}

function SideBarModel.new(): Model
	local orders: { [string]: number } = {}
	local badges: { [string]: boolean } = {}

	local function register(id: string, order: number)
		if orders[id] ~= nil then
			error(`Side bar tile "{id}" is registered twice`, 2)
		end
		orders[id] = order
	end

	-- Badges may arrive before the tile registers (start order of the menus).
	local function setBadge(id: string, on: boolean)
		badges[id] = on == true
	end

	local function badge(id: string): boolean
		return badges[id] == true
	end

	local function sorted(): { string }
		local ids = {}
		for id in orders do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			if orders[a] ~= orders[b] then
				return orders[a] < orders[b]
			end
			return a < b
		end)
		return ids
	end

	local function arrange(places: number): Arranged
		local ids = sorted()
		local room = math.max(1, places)
		local result: Arranged = { shown = {}, hidden = {}, more = #ids > room, moreBadge = false }
		local shownCount = if result.more then room - 1 else #ids
		for index, id in ids do
			if index <= shownCount then
				table.insert(result.shown, id)
			else
				table.insert(result.hidden, id)
				result.moreBadge = result.moreBadge or badge(id)
			end
		end
		return result
	end

	return {
		register = register,
		setBadge = setBadge,
		badge = badge,
		arrange = arrange,
	}
end

return SideBarModel
