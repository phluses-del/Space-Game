--[[
	Simple NPC drones for the test system. A "Hunt" drone locks the nearest
	player ship in range and strafes around it, keeping its nose on the target
	so its guns fire. An "Idle" drone just sits still as a target dummy.
	Drones fly with the same thrust and turn constraints as player ships.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ships = require(script.Parent.Ships)
local Combat = require(script.Parent.Combat)

local Drones = {}

local drones = {} -- [ship] = { ai, home, orbitSign, velocity }

function Drones.spawn(spec)
	local ship = Ships.spawn(spec.loadout, CFrame.new(spec.position))
	drones[ship] = {
		spec = spec,
		home = spec.position,
		orbitSign = if math.random() < 0.5 then -1 else 1,
		velocity = Vector3.zero,
	}
	return ship
end

local function nearestPlayerShip(position)
	local best, bestDistance = nil, Config.TestSystem.droneAggroRange
	for _, ship in Ships.all do
		if ship.owner and ship.alive then
			local distance = (ship.root.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = ship, distance
			end
		end
	end
	return best
end

-- Turn the nose toward a world direction and keep the wings roughly level.
local function steer(ship, desiredForward)
	local cframe = ship.root.CFrame
	local forward = cframe.LookVector
	local turnRate = math.rad(ship.hull.turnRate)

	local axis = forward:Cross(desiredForward)
	local angle = math.acos(math.clamp(forward:Dot(desiredForward), -1, 1))
	local worldTurn = Vector3.zero
	if axis.Magnitude > 1e-4 then
		worldTurn = axis.Unit * math.min(turnRate, angle * 3)
	elseif angle > 3 then
		-- Pointing straight away: pick any perpendicular axis.
		worldTurn = cframe.UpVector * turnRate
	end

	local localTurn = cframe:VectorToObjectSpace(worldTurn)
	-- Roll toward level: compare the ship's right vector with the horizon.
	local levelRoll = -cframe.RightVector.Y * 2
	ship.root.Turn.AngularVelocity = Vector3.new(localTurn.X, localTurn.Y, levelRoll)
end

local function fly(ship, state, desiredVelocity, dt)
	local accel = ship.hull.accel
	local delta = desiredVelocity - state.velocity
	local step = accel * dt
	if delta.Magnitude > step then
		delta = delta.Unit * step
	end
	state.velocity += delta
	ship.root.Thrust.VectorVelocity = state.velocity
end

function Drones.update(dt)
	for ship, state in drones do
		if not ship.alive then
			drones[ship] = nil
			task.delay(Config.TestSystem.respawnDelay, Drones.spawn, state.spec)
			continue
		end

		if state.spec.ai == "Idle" then
			fly(ship, state, Vector3.zero, dt)
			ship.root.Turn.AngularVelocity = Vector3.zero
			continue
		end

		local position = ship.root.Position
		local topSpeed = ship.hull.topSpeed * Config.TestSystem.droneSpeedScale * ship.speedScale
		local target = nearestPlayerShip(position)

		if target then
			Combat.requestLock(ship, target)

			local toTarget = target.root.Position - position
			local distance = toTarget.Magnitude
			local direction = toTarget.Unit
			local tangent = direction:Cross(Vector3.yAxis)
			if tangent.Magnitude < 1e-3 then
				tangent = direction:Cross(Vector3.xAxis)
			end
			tangent = tangent.Unit * state.orbitSign

			-- Strafe around the target while closing to orbit distance.
			local radial = math.clamp((distance - Config.TestSystem.droneOrbitDistance) / 100, -1, 1)
			local desired = (tangent * 0.7 + direction * radial)
			if desired.Magnitude > 1 then
				desired = desired.Unit
			end
			fly(ship, state, desired * topSpeed, dt)
			steer(ship, direction)
		else
			if ship.lock then
				Combat.clearLock(ship)
			end
			local toHome = state.home - position
			if toHome.Magnitude > 40 then
				fly(ship, state, toHome.Unit * topSpeed * 0.5, dt)
				steer(ship, toHome.Unit)
			else
				fly(ship, state, Vector3.zero, dt)
				ship.root.Turn.AngularVelocity = Vector3.zero
			end
		end
	end
end

return Drones
