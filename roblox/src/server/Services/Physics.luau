--!strict
-- Roblox lets the player nearest a loose object simulate it (network ownership), so it moves smoothly for them. But
-- then a velocity or position the server gives it (a crate pushing it out, a piston's shove, the catapult, a blast,
-- a cart carrying it) is overwritten by that player's own simulation a moment later, and the machine seems to do
-- nothing. Before the server moves something itself, it takes the object back: take() makes the server simulate it.
-- (Picking it up gives it to the carrier again: CarryService.)
local Physics = {}

-- the server simulates this loose part (and whatever is welded to it) from now on
function Physics.take(p: BasePart?)
	if not p or p.Anchored or not p:IsDescendantOf(workspace) then
		return
	end
	pcall(function()
		p:SetNetworkOwner(nil)
	end)
end

function Physics.push(p: BasePart, velocity: Vector3)
	Physics.take(p)
	p.AssemblyLinearVelocity = velocity
end

function Physics.start() end

return Physics
