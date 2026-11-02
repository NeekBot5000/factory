--!strict
-- Works out which machines have power, like the Godot version's Circuit.gd: power starts at every source and
-- spreads along links to connected machines, passing through any that conduct (an open switch stops it).
-- Batteries charge when their network has other power, and power it themselves when it doesn't.
-- Pure Luau: the server runs it on a 10 Hz tick (never every frame), and the tests run it directly.

local PowerGrid = {}

export type Node = {
	id: string,
	source: boolean,        -- gives power right now (a wound crank, a turning windmill)
	conducts: boolean,      -- lets power through (false for an open lever)
	battery: number?,       -- charge, if it's a battery
}

-- nodes: id -> Node; links: { {a, b}, ... }. Returns the set of powered ids, and which batteries are feeding.
function PowerGrid.solve(nodes: { [string]: Node }, links: { { string } })
	local adj: { [string]: { string } } = {}
	for id in nodes do
		adj[id] = {}
	end
	for _, l in links do
		local a, b = l[1], l[2]
		if adj[a] and adj[b] then
			table.insert(adj[a], b)
			table.insert(adj[b], a)
		end
	end
	local function spread(feeding: { [string]: boolean })
		local live: { [string]: boolean } = {}
		local queue = {}
		for id, n in nodes do
			if n.source or feeding[id] then
				live[id] = true
				table.insert(queue, id)
			end
		end
		while #queue > 0 do
			local id = table.remove(queue) :: string
			local n = nodes[id]
			if n.source or n.conducts or feeding[id] then
				for _, other in adj[id] do
					if not live[other] then
						live[other] = true
						table.insert(queue, other)
					end
				end
			end
		end
		return live
	end
	local feeding: { [string]: boolean } = {}
	local live = spread(feeding)
	local any = false
	for id, n in nodes do
		if n.battery and n.battery > 0 and not live[id] then
			feeding[id] = true
			any = true
		end
	end
	if any then
		live = spread(feeding)
	end
	return live, feeding
end

return PowerGrid
