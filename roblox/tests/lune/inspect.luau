-- Prints what Roblox made of each downloaded Model asset (build/assets/*.rbxm): how many parts, their names,
-- sizes and where the marker cubes ended up. Run by the roblox-assets workflow.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
for _, f in fs.readDir("build/assets") do
	if string.sub(f, -5) == ".rbxm" then
		local ok, insts = pcall(roblox.deserializeModel, fs.readFile("build/assets/" .. f))
		if not ok then
			print(f, "could not read:", insts)
			continue
		end
		local n, classes, shown = 0, {}, 0
		for _, root in insts do
			print(f, "root", root.ClassName, root.Name)
			for _, d in root:GetDescendants() do
				classes[d.ClassName] = (classes[d.ClassName] or 0) + 1
				if d:IsA("BasePart") then
					n += 1
					if shown < 12 or string.find(d.Name, "marker") then
						shown += 1
						print(string.format("  %s %s size=%s at=%s", d.ClassName, d.Name, tostring(d.Size), tostring(d.CFrame.Position)))
					end
				end
			end
		end
		local cs = {}
		for c, k in classes do
			table.insert(cs, c .. "=" .. k)
		end
		print(f, n, "parts;", table.concat(cs, " "))
	end
end
