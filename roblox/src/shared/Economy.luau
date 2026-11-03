--!strict
-- Prices and values, computed the same way everywhere. Pure Luau.
local Economy = {}

-- what a sheet of `panels` bark panels from a tree of `species` is worth
function Economy.barkValue(config: any, species: string, layer: number, panels: number, extra: number?): number
	local sp = config.Species[species] or config.Species.oak
	local per = if layer == 0 then config.PanelValue.outer * sp.outer else config.PanelValue.inner * sp.innerV
	return math.floor(per * panels * (extra or 1) * 100 + 0.5) / 100
end

-- an assembler recipe: given the values of what went in, what comes out is worth
function Economy.recipeValue(config: any, recipe: string, inputValue: number): number
	return inputValue * config.Recipes[recipe].mult
end

-- the refinery splits a barrel's value over its outputs
function Economy.refine(config: any, barrelValue: number): { [string]: number }
	local out = {}
	for kind, share in config.Refinery.outputs do
		out[kind] = barrelValue * share
	end
	return out
end

return Economy
