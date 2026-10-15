--[[
	Six-axis flight for the pilot's own ship. The client owns its ship's
	physics, so it drives the ship's Thrust (LinearVelocity) and Turn
	(AngularVelocity) constraints directly every frame. The server only
	checks the result.

	Flight assist on: the ship eases toward the speed your input asks for and
	stops when you let go. Off: thrust adds to your velocity and you keep
	drifting, Newtonian style, up to top speed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Flight = {}

Flight.assist = Config.Flight.assistDefault
Flight.boosting = false
Flight.speed = 0

local model: Model? = nil
local velocity = Vector3.zero
local turnRates = Vector3.zero -- pitch, yaw, roll in radians per second

function Flight.setShip(newModel: Model?)
	model = newModel
	turnRates = Vector3.zero
	velocity = if newModel and newModel.PrimaryPart then newModel.PrimaryPart.AssemblyLinearVelocity else Vector3.zero
end

function Flight.toggleAssist()
	Flight.assist = not Flight.assist
end

local function approach(current: Vector3, target: Vector3, maxStep: number): Vector3
	local delta = target - current
	if delta.Magnitude <= maxStep then
		return target
	end
	return current + delta.Unit * maxStep
end

function Flight.update(dt: number, axes)
	if not model or not model.Parent or not model.PrimaryPart then
		return
	end
	local root = model.PrimaryPart
	local thrust = root:FindFirstChild("Thrust")
	local turn = root:FindFirstChild("Turn")
	local hull = Config.Hulls[model:GetAttribute("Hull")]
	if not (thrust and turn and hull) then
		return
	end

	local speedScale = model:GetAttribute("SpeedScale") or 1
	local lastDamaged = model:GetAttribute("LastDamagedAt") or -math.huge
	local canBoost = workspace:GetServerTimeNow() - lastDamaged > Config.Flight.boostDamageLockout
	Flight.boosting = axes.boost and canBoost

	local boost = if Flight.boosting then Config.Flight.boostMultiplier else 1
	local topSpeed = hull.topSpeed * speedScale * boost
	local strafeSpeed = hull.strafeSpeed * speedScale
	local accel = hull.accel * speedScale * boost

	-- Boost always pushes forward at full throttle.
	local forward = if Flight.boosting then 1 else axes.forward
	local cframe = root.CFrame

	if Flight.assist then
		local reverseScale = if forward < 0 then 0.5 else 1
		local wanted = cframe:VectorToWorldSpace(Vector3.new(
			axes.strafe * strafeSpeed,
			axes.vertical * strafeSpeed,
			-forward * topSpeed * reverseScale
		))
		velocity = approach(velocity, wanted, accel * dt)
	else
		local push = Vector3.new(axes.strafe, axes.vertical, -forward)
		if push.Magnitude > 1 then
			push = push.Unit
		end
		velocity += cframe:VectorToWorldSpace(push) * accel * dt
		if velocity.Magnitude > topSpeed then
			velocity = approach(velocity, velocity.Unit * topSpeed, accel * dt * 2)
		end
	end
	thrust.VectorVelocity = velocity
	Flight.speed = velocity.Magnitude

	local turnRate = math.rad(hull.turnRate)
	local wantedTurn = Vector3.new(axes.pitch * turnRate, axes.yaw * turnRate, axes.roll * math.rad(hull.rollRate))
	turnRates = turnRates:Lerp(wantedTurn, 1 - math.exp(-Config.Flight.angularResponse * dt))
	-- Ship space: +X pitches the nose up, -Y yaws right, -Z rolls right.
	turn.AngularVelocity = Vector3.new(turnRates.X, -turnRates.Y, -turnRates.Z)
end

return Flight
