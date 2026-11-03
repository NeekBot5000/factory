--!strict
-- E, the Godot way (Player.gd interact / look_target_text): with something in your hands, E drops it. Otherwise E
-- uses what you're looking at within reach: a tool you put down ("[E] take"), the hatchet in the chopping block,
-- the truck when there's bark in the back ("[E] ship  $12.40"), the cabin computer that runs TimberMart ("[E] use"), or picks up
-- loose bark ("[E] grab"). The HUD shows the same hint text under the crosshair. A held thing floats in front of
-- you where Godot holds it, and the truck shows what its load is worth (its sign) and runs its engine on the road.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local BarkGrid = require(ReplicatedStorage.Shared.BarkGrid)
local InputController = require(script.Parent.InputController)
local ShopController = require(script.Parent.ShopController)
local BuildController = require(script.Parent.BuildController)
local Land = require(game:GetService("ReplicatedStorage").Shared.Land)
local Mining = require(game:GetService("ReplicatedStorage").Shared.Mining)
local Weight = require(game:GetService("ReplicatedStorage").Shared.Weight)
local Drones = require(game:GetService("ReplicatedStorage").Shared.Drones)
local State = require(script.Parent.Parent.State)
local Sfx = require(script.Parent.Parent.Sfx)

local InteractController = {}
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
local REACH = Config.Player.grabReach * M
local HOLD = Vector3.new(0, -0.28, -0.9) * M          -- Godot's HOLD_OFFSET

local function held(): BasePart?
	local loose = workspace:FindFirstChild("Loose")
	if loose then
		for _, p in loose:GetChildren() do
			if p:IsA("BasePart") and p:GetAttribute("HeldBy") == player.UserId then
				return p
			end
		end
	end
	-- (or a log)
	local logs = workspace:FindFirstChild("Logs")
	for _, m in if logs then logs:GetChildren() else {} do
		local t = m:FindFirstChild("Trunk")
		if t and t:GetAttribute("HeldBy") == player.UserId then
			return t :: BasePart
		end
	end
	return nil
end

-- what a log would fetch at the mill (Godot's Log.value), from the bark still on it
function InteractController.logValue(log: Instance): number
	local bands = log:GetAttribute("Bands") :: number or 1
	local s = log:GetAttribute("Bark")
	local g = if typeof(s) == "string" then BarkGrid.decode(log:GetAttribute("Sectors") :: number or 16, bands, s) else nil
	if not g then
		return 0
	end
	return BarkGrid.logValue(g, bands * Config.Tree.bandH, (log:GetAttribute("Radius") :: number or 1.2) / M)
end
InteractController.held = held

local function owns(id: string): boolean
	local s = player:GetAttribute("Owned")
	return typeof(s) == "string" and table.find(string.split(s, ","), id) ~= nil
end

local function look(): RaycastResult?
	local cam = workspace.CurrentCamera
	local params = RaycastParams.new()
	local ignore: { Instance } = { cam }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local h = held()
	if h then
		table.insert(ignore, h)
	end
	params.FilterDescendantsInstances = ignore
	params.FilterType = Enum.RaycastFilterType.Exclude
	return workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * REACH, params)
end

local function truck(): Model?
	return workspace:FindFirstChild("Truck") :: Model?
end

-- what the truck's load is worth (everyone's bark in its bed), while it's parked
function InteractController.truckValue(): number
	local t = truck()
	local bed = t and t:FindFirstChild("Bed") :: BasePart?
	local loose = workspace:FindFirstChild("Loose")
	if not t or not bed or not loose or t:GetAttribute("State") ~= "parked" then
		return 0
	end
	local v = 0
	for _, p in loose:GetChildren() do
		local value = p:GetAttribute("Value")
		if p:IsA("BasePart") and typeof(value) == "number" then
			local lp = bed.CFrame:PointToObjectSpace(p.Position)
			if math.abs(lp.X) <= bed.Size.X / 2 and math.abs(lp.Z) <= bed.Size.Z / 2 and lp.Y > -1 and lp.Y < 5.5 then
				v += value
			end
		end
	end
	return v
end

-- the tool lying on the ground that this part belongs to, if it's yours
local function toolItem(part: Instance): Model?
	local m = part:FindFirstAncestorWhichIsA("Model")
	while m do
		if m:GetAttribute("Kind") == "tool" then
			return if m:GetAttribute("Owner") == player.UserId then m else nil
		end
		m = m:FindFirstAncestorWhichIsA("Model")
	end
	return nil
end

-- What E would do here: (hint text, action). Godot's look_target_text and interact, in one place.
-- the plan or build a part belongs to
local function buildOf(part: Instance): Model?
	local m = part:FindFirstAncestorWhichIsA("Model")
	while m and m:GetAttribute("Kind") ~= "plan" and m:GetAttribute("Kind") ~= "build" and m:GetAttribute("Kind") ~= "forsale" do
		m = m:FindFirstAncestorWhichIsA("Model")
	end
	return m
end
InteractController.buildOf = buildOf

function InteractController.target(): (string, (() -> ())?)
	if State.uiOpen or State.fainted then
		return "", nil
	end
	if State.placing then
		-- placing a build: E puts the hologram away
		return State.buildHint or "", BuildController.cancel
	end
	local h = held()
	if h then
		-- (holding something and looking at a sorter belt: E sorts that kind of thing out to the left)
		local sh = look()
		local sb = sh and buildOf(sh.Instance)
		if sh and sb and sb:GetAttribute("Build") == "sorter" then
			return "[E] sort this out to the left", function()
				remotes.UseMachine:FireServer(sh.Instance)
			end
		end
		return "[E] drop", function()
			remotes.Grab:FireServer(nil)
			Sfx.play("drop", 0.9, -6)
		end
	end
	local hit = look()
	if not hit then
		return "", nil
	end
	local part = hit.Instance
	-- the log scale: how heavy what you point it at is, and what the mill would pay (Godot's scale_reading)
	if (Config.Tools :: any)[State.tool] and (Config.Tools :: any)[State.tool].weigh then
		local thing = if part.Parent and part.Parent:IsA("BasePart") then part.Parent :: BasePart else part
		local logM = part:FindFirstAncestorWhichIsA("Model")
		if logM and logM:GetAttribute("Kind") == "log" then
			local trunk = logM:FindFirstChild("Trunk") :: BasePart?
			local len = (logM:GetAttribute("Bands") :: number? or 0) * Config.Tree.bandH
			return string.format("Log  %.1f m  ·  %d kg  ·  worth $%.2f", len, math.floor(if trunk then Weight.of(trunk) else 0), InteractController.logValue(logM)), nil
		end
		local value = thing:GetAttribute("Value")
		if typeof(value) == "number" and thing:IsA("BasePart") and not thing.Anchored then
			return string.format("%.1f kg  ·  worth $%.2f", Weight.of(thing), value), nil
		end
	end
	-- dynamite: stick a charge on what you're looking at (Godot's Player hint)
	if (Config.Tools :: any)[State.tool] and (Config.Tools :: any)[State.tool].plant and (hit.Position - workspace.CurrentCamera.CFrame.Position).Magnitude < (Config.Tools :: any)[State.tool].reach * M then
		local cm = part:FindFirstAncestorWhichIsA("Model")
		if not (cm and cm:GetAttribute("Build") == "charge") then
			return string.format("[Click] stick a charge on it  (%d left)", player:GetAttribute("Charges") :: number? or 0), nil
		end
	end
	-- rocks and mine shafts say what they are (Godot's Rock / Shaft hint_text)
	if part:GetAttribute("Rock") ~= nil then
		return "Stone  ·  any pickaxe", nil
	end
	local sh = part:FindFirstAncestorWhichIsA("Model")
	if sh and sh:GetAttribute("Kind") == "shaft" then
		local depth = sh:GetAttribute("Depth") :: number? or 0
		if depth >= Mining.MAX_DEPTH then
			return string.format("Mine shaft  ·  %d m deep  ·  as deep as it goes", depth), nil
		end
		return string.format("Mine shaft  ·  %.1f m deep  ·  %s", depth, Mining.layerName(depth)), nil
	end
	if sh and sh:GetAttribute("Kind") == "rail" then
		local nm = if (sh:GetAttribute("Curve") :: number? or -1) >= 0 then "Curved Rail" else "Rail"
		return if State.tool == "hammer" then nm .. "    [Click] pick it up    [R] turn it" else nm, nil
	end
	local b = buildOf(part)
	if b and b:GetAttribute("Kind") == "forsale" then
		local land = string.split(player:GetAttribute("Land") :: string? or "", ";")
		return string.format("[E] buy this plot of land    $%d", Land.nextPrice(land)), function()
			remotes.BuyLand:FireServer(b:GetAttribute("Plot"), b:GetPivot().Position)
		end
	elseif b and b:GetAttribute("Kind") == "plan" then
		if State.tool == "hammer" then
			return "[X] knock down the plan (materials drop out)    [E] cancel", function()
				remotes.PlanCancel:FireServer(part)
			end
		end
		return "[E] cancel", function()
			remotes.PlanCancel:FireServer(part)
		end
	elseif b and b:GetAttribute("Kind") == "build" and State.tool == "hammer" then
		return string.format("[X] take down  +$%.2f", b:GetAttribute("SaleValue") :: number? or 0), nil
	elseif b and b:GetAttribute("Kind") == "build" and InteractController.machineHint(b) then
		local text, use = InteractController.machineHint(b)
		return text :: string, if use then function()
			remotes.UseMachine:FireServer(part)
		end else nil
	elseif b and b:GetAttribute("Build") == "catapult" then
		return if b:GetAttribute("Busy") then "" else "[Click] fire", nil
	elseif b and b:GetAttribute("Build") == "compost" then
		return string.format("%d/%d leaves", b:GetAttribute("Stock") :: number? or 0, 8), nil
	elseif b and b:GetAttribute("Build") == "hammock" then
		return "[E] lie down", function()
			remotes.Lie:FireServer(part)
		end
	end
	local item = toolItem(part)
	if item then
		return "[E] take", function()
			remotes.Use:FireServer(part)
		end
	end
	-- a TimberMart box: click to open it, or carry it
	if part:GetAttribute("Kind") == "box" and part:GetAttribute("Owner") == player.UserId and not part:GetAttribute("Opened") then
		return "[Click] open    [E] grab", function()
			remotes.Grab:FireServer(part)
			Sfx.play("pickup")
		end
	end
	-- the tool rising out of an opened box
	local pickup = part:FindFirstAncestorWhichIsA("Model")
	while pickup and pickup:GetAttribute("Kind") ~= "pickup" do
		pickup = pickup:FindFirstAncestorWhichIsA("Model")
	end
	if pickup and pickup:GetAttribute("Owner") == player.UserId then
		return "[E] take", function()
			remotes.Use:FireServer(part)
		end
	end
	local t = truck()
	if t and part:IsDescendantOf(t) then
		local v = InteractController.truckValue()
		if v > 0 then
			return string.format("[E] ship  $%.2f", v), function()
				remotes.Use:FireServer(part)
			end
		end
		return "", nil
	end
	local block = part:FindFirstAncestor("ChoppingBlock")
	if block then
		if not owns("hatchet") then
			return "[E] take", function()
				remotes.Use:FireServer(part)
			end
		end
		return "", nil
	end
	if part.Name == "Computer" and part.Parent and part.Parent.Name == "TimberMart" then
		return "[E] use", ShopController.open
	end
	local loose = workspace:FindFirstChild("Loose")
	-- (a sheet of several panels: the panels ride on the first one, which is the sheet)
	local sheet = part
	if loose and part.Parent and part.Parent:IsA("BasePart") and part.Parent.Parent == loose then
		sheet = part.Parent :: BasePart
	end
	if loose and sheet.Parent == loose and sheet:GetAttribute("Rooted") then
		-- a sapling that has taken root: how far it has grown (Godot's Sapling.hint_text)
		return string.format("%d%%", math.floor((sheet:GetAttribute("Grow") :: number? or 0) / Config.Sapling.growTime * 100)), nil
	end
	if loose and sheet.Parent == loose and sheet:IsA("BasePart") and not sheet.Anchored and not sheet:GetAttribute("HeldBy") then
		local value = sheet:GetAttribute("Value")
		local ore = sheet:GetAttribute("Ore")
		local label = if typeof(ore) == "string" and Mining.KINDS[ore] then string.format("[E] grab    %s  $%.2f", Mining.KINDS[ore].name, value :: number)
			elseif sheet:GetAttribute("Product") == "battery_cell" then "[E] grab    Battery Cell  ·  " .. (if (sheet:GetAttribute("Charge") :: number? or 0) <= 0
				then "empty - charge it in a charger" else string.format("%d%% charged", math.floor((sheet:GetAttribute("Charge") :: number) * 100)))
			elseif typeof(value) == "number" then string.format("[E] grab    $%.2f", value) else "[E] grab"
		if State.tool == "hammer" and (sheet:GetAttribute("Product") == "rail" or sheet:GetAttribute("Product") == "curved_rail") then
			label ..= "    [Click] lay it"
		end
		return label, function()
			remotes.Grab:FireServer(sheet)
			Sfx.play("pickup")
		end
	end
	-- a log: grab it if it's short enough, and what it's worth (Godot's Log.hint_text)
	local log = part:FindFirstAncestorWhichIsA("Model")
	if log and log:GetAttribute("Kind") == "log" then
		local worth = string.format("worth $%.2f", InteractController.logValue(log))
		local liftable = not log:GetAttribute("HasCrown") and (log:GetAttribute("Bands") :: number) * Config.Tree.bandH <= Config.Saw.carryMax
		local trunk = log:FindFirstChild("Trunk")
		if liftable and trunk and not trunk:GetAttribute("HeldBy") then
			return "[E] grab    " .. worth, function()
				remotes.Grab:FireServer(trunk)
				Sfx.play("pickup")
			end
		end
		return "Too heavy to lift - cut it up    " .. worth, nil
	end
	-- a tree says what's special about it (Godot's ForestTree.hint_text)
	local tree = part:FindFirstAncestorWhichIsA("Model")
	if tree and tree:HasTag("Tree") then
		return InteractController.treeHint(tree), nil
	end
	return "", nil
end

-- what a machine says when you look at it (Godot's hint_text for each), and whether E does something
function InteractController.machineHint(m: Model): (string?, boolean)
	local id = m:GetAttribute("Build")
	local powered = m:GetAttribute("Powered") == true
	if State.tool == "wires" then
		return InteractController.wireHint(m), false
	end
	if id == "crank" then
		local c = m:GetAttribute("Charge") :: number? or 0
		return if c > 0 then string.format("[E] wind    %ds left", math.ceil(c)) else "[E] wind", true
	elseif id == "lever" then
		return if m:GetAttribute("On") then "[E] switch off" else "[E] switch on", true
	elseif id == "button" then
		return "[E] press", true
	elseif id == "lamp" or id == "bell" then
		return string.format("%s  ·  %s", if id == "lamp" then "Lamp" else "Bell", if powered then "powered" else "no power"), false
	elseif id == "windmill" then
		local w = 0.55 + 0.3 * math.sin(os.clock() / 37) + 0.2 * math.sin(os.clock() / 11 + 1) + 0.08 * math.sin(os.clock() / 3.1)
		w = math.clamp(w, 0, 1)
		return string.format("Windmill  ·  %s  ·  wind %d%%", if w >= 0.35 then "turning" else "too calm", math.floor(w * 100)), false
	elseif id == "generator" then
		local f = m:GetAttribute("Fuel") :: number? or 0
		return string.format("Generator  ·  %s    drop bark, leaves or wood in the hopper", if f > 0 then string.format("%ds of fuel", math.floor(f)) else "no fuel"), false
	elseif id == "battery" then
		local c = m:GetAttribute("Charge") :: number? or 0
		return string.format("Battery  ·  %d%%  ·  %s", math.floor(c / 180 * 100), if m:GetAttribute("Feeding") then "powering" elseif powered then "charging" else "idle"), false
	elseif id == "charge" then
		return "Dynamite  ·  wire it to a switch with power to set it off", false
	elseif Drones.isDrone(m) then
		-- (Godot's Drone.hint_text: the dial you're looking at, or the cell)
		local d = Drones.SIZES[id]
		local c = m:GetAttribute("Cell") :: number?
		local parts = { d.name, if c then string.format("battery %d%%", math.floor(c * 100)) else "no battery cell", string.format("lifts up to %.1f kg", d.lift) }
		if m:GetAttribute("Heavy") then
			table.insert(parts, "too heavy to lift!")
		end
		local text = table.concat(parts, "  ·  ")
		local hit = look()
		local i = hit and Drones.dialOf(m, hit.Instance)
		if i then
			local name = Drones.DIALS[i]
			return text .. string.format("\n%s dial: %s    [E] change", string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2), Drones.channelName(Drones.dials(m)[i])), true
		elseif c then
			return text .. "    [E] take the cell out", true
		end
		return text .. "    drop a charged battery cell in the cradle on its back", false
	elseif string.sub(id, 1, 9) == "minecart_" then
		local c = m:GetAttribute("Cell") :: number?
		return string.format("Minecart (%s long)  ·  %s%s", string.sub(id, 10), if c then string.format("battery %d%%", math.floor(c * 100)) else "no battery cell",
			if c then "    [E] take the cell out" else "    drop a charged battery cell in the cradle at the back"), c ~= nil
	elseif id == "cart_go" or id == "cart_back" or id == "rail_layer" or id == "rail_lifter" then
		local what = ({
			cart_go = "Go  ·  the cart rolls forward while this is powered (wire a switch into it)",
			cart_back = "Reverse  ·  the cart rolls backward while this is powered (wire a switch into it)",
			rail_layer = "Rail Layer  ·  lays a rail ahead from a crate on the cart when the track runs out",
			rail_lifter = "Rail Lifter  ·  picks up the rail behind the cart into a crate on the cart",
		})[id]
		return string.format("%s  ·  %s", what, if powered then "powered" else "off"), false
	elseif id == "cart_sensor" then
		return "Cart Sensor  ·  " .. (if m:GetAttribute("Sensing") then "a cart is here" else "lets power through while a cart is on the rail in front"), false
	elseif id == "rail_switch" then
		return "Rail Switch  ·  " .. (if not m:GetAttribute("Works") then "build it beside a straight rail, pointing along it"
			elseif powered then "branching" else "straight on - power it to branch"), false
	elseif id == "rail_buffer" then
		return "Rail Buffer  ·  " .. (if powered then "open - carts go by" else "down - carts stop here (power it to open)"), false
	elseif id == "cart_unloader" then
		return "Cart Unloader  ·  " .. (if powered then "emptying the crate on the cart behind it" else "power it to empty a cart's crate out of its front"), false
	elseif id == "drone_pad" then
		return "Drone Pad  ·  " .. (if powered then "charging battery cells left on it" else "power it to charge drones over it"), false
	elseif id == "rotator" then
		return string.format("Rotator  ·  %s    [Hammer] %s", if powered then "powered" else "no power", if m:GetAttribute("Stuck") then "let go" else "stick what's on it"), false
	elseif id == "truck_caller" then
		return "Truck Caller  ·  sends the log truck whenever it gets power", false
	elseif typeof(id) == "string" and string.sub(id, 1, 5) == "gate_" then
		local mode = string.sub(id, 6)
		local setting = (m:GetAttribute("Setting") :: number? or 0) + 1
		if mode == "diode" then
			return "One-Way  ·  power in the back, out the front", false
		elseif mode == "and" then
			return "Relay  ·  passes back -> front while a side is powered", false
		elseif mode == "not" then
			return "Inverting Relay  ·  passes back -> front while no side is powered", false
		elseif mode == "timer" then
			return string.format("Timer  ·  pulses every %ds    [E] change", ({ 1, 2, 4, 8 })[setting]), true
		elseif mode == "delay" then
			return string.format("Delay  ·  %.1fs    [E] change", ({ 0.5, 1, 2, 4 })[setting]), true
		elseif mode == "latch" then
			return string.format("Toggle Latch  ·  %s  ·  a pulse at the back flips it    [E] flip", if m:GetAttribute("LatchOn") then "on" else "off"), true
		elseif mode == "counter" then
			return string.format("Counter  ·  %d of %d pulses    [E] change", m:GetAttribute("Count") :: number? or 0, ({ 2, 3, 5, 10 })[setting]), true
		end
	elseif id == "feller" then
		local saw = m:GetAttribute("Holds") :: string?
		if not saw then
			if State.tool == "saw" or State.tool == "chainsaw" or State.tool == "crosscut" then
				return "[E] put your saw in", true
			end
			return "Tree Feller  ·  needs a saw (bow saw, chainsaw or crosscut)", false
		end
		local p = m:GetAttribute("Progress") :: number? or 0
		return string.format("Tree Feller  ·  %s%s%s", (Config.Tools :: any)[saw].name, if State.tool == "hands" then "    [E] take the saw out" else "",
			if p > 0 and powered then string.format("  ·  %d%%", math.floor(p * 100)) else ""), State.tool == "hands"
	elseif id == "drill_rig" then
		local drill = m:GetAttribute("Holds") :: string?
		if not drill then
			if State.tool == "rock_drill" or State.tool == "core_drill" then
				return "[E] put your drill in", true
			end
			return "Drill Rig  ·  needs a rock drill or steel core drill", false
		end
		local depth = m:GetAttribute("Depth") :: number? or 0
		local max = if drill == "rock_drill" then 12 else 30
		local take = if State.tool == "hands" then "    [E] take the drill out" else ""
		if depth >= max then
			return string.format("Drill Rig  ·  drilled out at %d m - move it somewhere new%s", depth, take), State.tool == "hands"
		end
		return string.format("Drill Rig  ·  %.1f of %d m  ·  %s%s", depth, max, Mining.layerName(depth), take), State.tool == "hands"
	elseif id == "transmitter" or id == "receiver" then
		local names = { "red", "green", "blue", "yellow", "purple", "orange", "white", "pink" }
		local ch = (m:GetAttribute("Channel") :: number? or 0) + 1
		local state = if id == "transmitter" then (if powered then "sending" else "no power") else (if powered then "receiving" else "nothing on this channel")
		return string.format("%s  ·  %s channel  ·  %s    [E] change channel", if id == "transmitter" then "Transmitter" else "Receiver", names[ch], state), true
	elseif id == "crate" then
		return "Storage Crate  ·  power it to empty it out of the front", false
	elseif id == "sprinkler" then
		return "Sprinkler  ·  " .. (if powered then "watering" else "waters saplings nearby while powered"), false
	elseif id == "planter" then
		return "Planter  ·  drop saplings in the hopper and power it: they're planted in a row in front", false
	elseif id == "grabber" then
		return "Grabber Arm  ·  moves things from in front (the arrow's tail) to behind it, while powered", false
	elseif id == "splitter" then
		return "Splitter Belt  ·  every other thing goes off to the left", false
	elseif id == "sorter" then
		local f = m:GetAttribute("Filter") :: string? or ""
		if f == "" then
			return "Sorter Belt  ·  hold something and press [E] to sort that out to the left", true
		end
		return string.format("Sorter Belt  ·  sends %s left    [E] with empty hands to clear", (string.gsub(f, "_", " "))), true
	elseif id == "pressure_plate" then
		return "Pressure Plate  ·  " .. (if m:GetAttribute("Sensing") then "pressed" else "lets power through while something stands on it"), false
	elseif id == "level_sensor" then
		local n = m:GetAttribute("Has") :: number? or -1
		return string.format("Level Sensor  ·  %s  ·  lets power through at %d or more    [E] change", if n < 0 then "no crate in front" else n .. " in the crate",
			({ 5, 10, 20, 30 })[(m:GetAttribute("Setting") :: number? or 1) + 1]), true
	elseif id == "charger" then
		local n = m:GetAttribute("Cells") :: number? or 0
		return "Charger  ·  " .. (if n > 0 and m:GetAttribute("Powered") then string.format("charging %d cell%s", n, if n == 1 then "" else "s") else "drop battery cells in and power it"), false
	elseif id == "item_sensor" then
		return "Item Sensor  ·  " .. (if m:GetAttribute("Sensing") then "sees something" else "lets power through while something is in front of it"), false
	elseif id == "sawmill" then
		return string.format("Sawmill  ·  %s", if m:GetAttribute("LogUid") then "cutting" else "lay a log on the table and power it"), false
	elseif id == "smelter" or id == "kiln" then
		local q = m:GetAttribute("Queue") :: string? or ""
		local n = if q == "" then 0 else #string.split(q, ";")
		if id == "smelter" then
			return "Smelter  ·  copper or iron ore in, bars out" .. (if n > 0 then string.format("  ·  %d waiting", n) else ""), false
		end
		return "Kiln  ·  planks in, dried planks out" .. (if n > 0 then string.format("  ·  %d drying", n) else ""), false
	elseif id == "oil_pump" then
		local Mining = require(game:GetService("ReplicatedStorage").Shared.Mining) :: any
		local at = m:GetPivot().Position
		local r = Mining.richness("oil", at.X, at.Z)
		if r < 0.12 then
			return "Oil Pump  ·  no oil under here - look for it with the ore detector", false
		end
		return string.format("Oil Pump  ·  %s oil  ·  barrel %d%% full  ·  %s", if r > 0.6 then "rich" elseif r > 0.3 then "some" else "a little",
			math.floor((m:GetAttribute("Fill") :: number? or 0) * 100), if powered then "pumping" else "power it to pump"), false
	elseif id == "refinery" then
		local q = m:GetAttribute("Queue") :: string? or ""
		local n = if q == "" then 0 else #string.split(q, ";")
		return "Refinery  ·  a barrel of oil in, a fuel can and a plastic sheet out" .. (if n > 0 then string.format("  ·  %d waiting", n) else ""), false
	elseif id == "chipper" then
		return string.format("Chipper  ·  %d%% of a bag    drop bark or leaves in the hopper", math.floor((m:GetAttribute("Stock") :: number? or 0) / 4 * 100)), false
	elseif id == "assembler" then
		local order = { "chair", "table", "lantern", "cabinet", "toy_truck", "lawn_chair", "bucket", "battery_cell", "rail", "curved_rail" }
		local names = { chair = "Chair", table = "Table", lantern = "Lantern", cabinet = "Cabinet", toy_truck = "Toy Truck", lawn_chair = "Lawn Chair", bucket = "Bucket", battery_cell = "Battery Cell", rail = "Rail", curved_rail = "Curved Rail" }
		local recipes = { chair = { { "plank", 2 } }, table = { { "plank", 4 }, { "iron_bar", 1 } }, lantern = { { "copper_bar", 1 }, { "plank", 1 } },
			cabinet = { { "plank", 6 }, { "copper_bar", 1 } }, toy_truck = { { "plank", 2 }, { "iron_bar", 1 } }, battery_cell = { { "copper_bar", 1 }, { "iron_bar", 1 } },
			rail = { { "iron_bar", 1 } }, curved_rail = { { "iron_bar", 1 } }, lawn_chair = { { "plastic", 2 } }, bucket = { { "plastic", 1 }, { "iron_bar", 1 } } }
		local resName = { plank = "planks", copper_bar = "copper bars", iron_bar = "iron bars", plastic = "plastic" }
		local r = order[(m:GetAttribute("Recipe") :: number? or 0) + 1]
		local parts = {}
		for _, need in recipes[r] do
			table.insert(parts, string.format("%d/%d %s", m:GetAttribute("Have_" .. need[1]) :: number? or 0, need[2], resName[need[1]]))
		end
		local what = if r == "rail" then "2 rails" else "a " .. string.lower(names[r])
		return string.format("Assembler  ·  making %s  ·  %s    [E] change", what, table.concat(parts, ", ")), true
	end
	local GB = require(game:GetService("ReplicatedStorage").Shared.Builds) :: any
	local def = GB.def(id)
	if def and def.machine then
		return string.format("%s  ·  %s", def.name, if powered then "powered" else "no power"), false
	end
	return nil, false
end

-- the Wire Spool (Godot's wire hints): start a wire, then connect or disconnect a second machine
local wireFrom: Model? = nil
function InteractController.wireHint(m: Model): string
	local GB = require(game:GetService("ReplicatedStorage").Shared.Builds) :: any
	local name = if m:GetAttribute("Build") == "charge" then "Dynamite" else (GB.def(m:GetAttribute("Build")) or {}).name or "machine"
	if wireFrom and wireFrom.Parent then
		if wireFrom ~= m then
			return "[Click] connect / disconnect " .. name
		end
		return "[Click] a second machine    [Click empty] cancel"
	end
	return "[Click] start a wire from " .. name
end
function InteractController.wireClick(m: Model?)
	if not m then
		if wireFrom then
			wireFrom = nil
			Sfx.play("click", 0.6, -6)
		end
		return
	end
	if wireFrom and wireFrom.Parent and wireFrom ~= m then
		remotes.Wire:FireServer(wireFrom:FindFirstChildWhichIsA("BasePart"), m:FindFirstChildWhichIsA("BasePart"))
		wireFrom = nil
	else
		wireFrom = m
		Sfx.play("click", 1.2, -4)
	end
end

local TREE_HINTS = {
	hickory = "Shagbark Hickory  ·  its shaggy bark pulls off by hand",
	cedar = "Western Red Cedar  ·  long, valuable strips",
	cork = "Cork Oak  ·  the cork grows back",
	eucalyptus = "Rainbow Eucalyptus  ·  its inner bark changes colour once it's showing",
}

function InteractController.treeHint(tree: Instance): string
	if tree:GetAttribute("Legendary") then
		return "The Legendary Tree  ·  only a two-man crosscut gets through it"
	elseif tree:GetAttribute("Giant") then
		return "Ancient tree  ·  too thick for most saws"
	end
	return TREE_HINTS[tree:GetAttribute("Species") :: string] or ""
end

-- the truck's sign: what its load is worth, over the bed (the one floating number the Godot game has)
local function truckSign(): BillboardGui?
	local t = truck()
	local bed = t and t:FindFirstChild("Bed") :: BasePart?
	if not bed then
		return nil
	end
	local sign = bed:FindFirstChild("ValueSign") :: BillboardGui?
	if not sign then
		local b = Instance.new("BillboardGui")
		b.Name = "ValueSign"
		b.Size = UDim2.fromOffset(160, 44)
		b.StudsOffset = Vector3.new(0, 6, 0)
		b.AlwaysOnTop = false
		b.LightInfluence = 0
		b.MaxDistance = 80
		local l = Instance.new("TextLabel")
		l.Name = "Text"
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
		l.TextScaled = true
		l.TextColor3 = Color3.fromHex("7aff9a")
		l.TextStrokeTransparency = 0.3
		l.Parent = b
		b.Parent = bed
		sign = b
	end
	return sign
end

function InteractController.start()
	InputController.on("Grab", function(state)
		if state ~= Enum.UserInputState.Begin then
			return
		end
		if State.uiOpen then
			ShopController.close()
			BuildController.closeMenu()
			return
		end
		local _, action = InteractController.target()
		if action then
			action()
		end
	end)
	-- X with the hammer: knock down the plan or the build you're looking at (Godot's hammer_take_down)
	InputController.on("TakeDown", function(state)
		if state ~= Enum.UserInputState.Begin or State.tool ~= "hammer" or State.placing or State.uiOpen then
			return
		end
		local hit = look()
		local b = hit and buildOf(hit.Instance)
		if hit and b and (b:GetAttribute("Kind") == "plan" or b:GetAttribute("Kind") == "build") then
			remotes.TakeDown:FireServer(hit.Instance)
			State.swing = 0
		end
	end)
	local engines: { [string]: Sound? } = {}
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		-- carry the held thing in front of you
		local p = held()
		local cam = workspace.CurrentCamera
		if p and cam then
			local align = p:FindFirstChildOfClass("AlignPosition")
			if align then
				align.Position = (cam.CFrame * CFrame.new(HOLD)).Position
			end
		end
		-- the hatchet in the chopping block is only there until you take it
		local block = workspace:FindFirstChild("ChoppingBlock")
		local hatchet = block and block:FindFirstChild("Hatchet")
		if hatchet then
			local gone = owns("hatchet")
			for _, d in hatchet:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = if gone then 1 else 0
				end
			end
		end
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local t = truck()
		if not t then
			return
		end
		local sign = truckSign()
		local v = InteractController.truckValue()
		if sign then
			sign.Enabled = v > 0
			(sign:FindFirstChild("Text") :: TextLabel).Text = string.format("$%.2f", v)
		end
		-- the diesel engines run while the truck or the van is on the road
		for _, name in { "Truck", "Van" } do
			local veh = workspace:FindFirstChild(name) :: Model?
			local st = veh and veh:GetAttribute("State")
			local moving = st == "leaving" or st == "returning" or st == "arriving" or st == "docking"
			local snd = engines[name]
			if veh and moving and not snd then
				snd = Sfx.loop("engine", -6, veh:FindFirstChild("Cab") or veh:FindFirstChildWhichIsA("BasePart"))
				if snd then
					snd.RollOffMaxDistance = 45 * M
					snd.RollOffMinDistance = 4 * M
				end
				engines[name] = snd
			elseif not moving and snd then
				snd:Destroy()
				engines[name] = nil
			end
		end
	end)
	-- the server's sounds for things only it knows about (the horn as the truck leaves, a tutorial step done)
	remotes.Fx.OnClientEvent:Connect(function(name: string, at: Vector3?, pitch: number?, db: number?)
		if name == "lightning" then
			return          -- (the ToolController draws the bolt and plays the thunder)
		elseif at then
			Sfx.playAt(name, at, pitch, db)
		else
			Sfx.play(name, pitch, db)
		end
	end)
end

return InteractController
