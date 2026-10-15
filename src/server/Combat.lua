--[[
	Target lock and auto-fire. Every gun ticks on its own fire timer; when the
	locked target is inside its arc, in range and in line of sight, the server
	rolls a hit chance from the gun's tracking speed against how fast the
	target crosses its view, then hands the damage to Ships.

	This is steps 1 to 3 of the damage pipeline in weapons-and-damage.md.
	Clients never report hits; they only draw what the server sends.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ships = require(script.Parent.Ships)

local Combat = {}

local SUBSYSTEMS = { "Hull", "ShieldGenerator", "Engine", "Weapon" }

local random = Random.new()
local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude

function Combat.requestLock(ship, target)
	if not (ship.alive and target and target.alive) or ship == target then
		return
	end
	if ship.lock and ship.lock.target == target then
		return
	end
	if (target.root.Position - ship.root.Position).Magnitude > Config.LockRange then
		return
	end
	ship.lock = { target = target, progress = 0, locked = false }
end

function Combat.clearLock(ship)
	ship.lock = nil
	for _, gun in ship.guns do
		gun.status = "Idle"
	end
end

function Combat.cycleSubsystem(ship)
	local current = table.find(SUBSYSTEMS, ship.subsystem or "Hull") or 1
	local nextName = SUBSYSTEMS[current % #SUBSYSTEMS + 1]
	ship.subsystem = if nextName == "Hull" then nil else nextName
end

-- How fast the target sweeps across the shooter's view, in degrees per second.
local function angularSpeed(shooter, target, direction, distance)
	local relative = target.root.AssemblyLinearVelocity - shooter.root.AssemblyLinearVelocity
	local lateral = relative - direction * relative:Dot(direction)
	return math.deg(lateral.Magnitude / math.max(distance, 1))
end

local function hitChance(shooter, target, gun, direction, distance)
	local tracking = Config.Tracking[gun.weapon.tracking]
	local sweep = angularSpeed(shooter, target, direction, distance)
	local trackingFactor = if sweep > 1e-3 then math.min(1, tracking / sweep) else 1
	local sizeFactor = math.min(1, Config.SizeRank[target.hull.size] / Config.SizeRank[gun.weapon.size])
	return Config.Combat.baseAccuracy * trackingFactor * sizeFactor
end

local function shotDamage(shooter, gun, distance)
	local weapon = gun.weapon
	local damage = weapon.dps * weapon.interval * Config.TierMultiplier[gun.tier] * gun.slot.damageScale

	if weapon.class == "Energy" and distance > weapon.optimal then
		local t = math.clamp((distance - weapon.optimal) / (weapon.range - weapon.optimal), 0, 1)
		damage *= 1 - t * (1 - Config.Combat.energyFalloffAtMax)
	end
	if shooter.owner == nil then
		damage *= Config.TestSystem.droneDamageScale
	end
	return damage
end

local function hasLineOfSight(shooter, target, origin, toTarget)
	losParams.FilterDescendantsInstances = { shooter.model }
	local result = workspace:Raycast(origin, toTarget, losParams)
	return result == nil or result.Instance:IsDescendantOf(target.model)
end

-- Works out what a gun can do this frame without firing it.
local function gunStatus(ship, gun, target)
	if not gun.module.online then
		return "Offline"
	end
	if gun.weapon.class == "Kinetic" and ((gun.ammo or 0) <= 0 or not (gun.magazine and gun.magazine.online)) then
		return "NoAmmo"
	end
	if gun.weapon.class == "Energy" and ship.plasmaRate <= 0 then
		return "NoPower"
	end

	local origin = (ship.root.CFrame * CFrame.new(gun.mount.Position)).Position
	local toTarget = target.root.Position - origin
	local distance = toTarget.Magnitude
	local direction = toTarget.Unit

	local angle = math.deg(math.acos(math.clamp(ship.root.CFrame.LookVector:Dot(direction), -1, 1)))
	if angle > gun.slot.arc then
		return "OutOfArc"
	end
	if distance > gun.weapon.range then
		return "OutOfRange"
	end
	return "Ready", origin, toTarget, distance, direction
end

local function fireGun(ship, gun, target, effects, dt)
	local status, origin, toTarget, distance, direction = gunStatus(ship, gun, target)

	local interval = gun.weapon.interval
	if gun.weapon.class == "Energy" and ship.plasmaRate > 0 then
		interval /= ship.plasmaRate
	end
	gun.timer = math.min(gun.timer + dt, interval)

	if status ~= "Ready" then
		gun.status = status
		return
	end
	if gun.timer < interval then
		gun.status = "Firing"
		return
	end
	if not hasLineOfSight(ship, target, origin, toTarget) then
		gun.status = "NoLineOfSight"
		return
	end

	gun.status = "Firing"
	gun.timer -= interval
	if gun.ammo then
		gun.ammo -= 1
	end

	local hit = random:NextNumber() < hitChance(ship, target, gun, direction, distance)
	local shield = false
	if hit then
		local result = Ships.applyHit(target, ship, {
			class = gun.weapon.class,
			damage = shotDamage(ship, gun, distance),
		})
		shield = result.shield
	end

	table.insert(effects, {
		shooter = ship.model,
		gun = gun.index,
		target = target.model,
		hit = hit,
		class = gun.weapon.class,
		shield = shield,
	})
end

function Combat.update(dt)
	local effects = {}

	-- Copy the list: a ship destroyed mid-loop is removed from Ships.all.
	for _, ship in table.clone(Ships.all) do
		local lock = ship.lock
		if not ship.alive or not lock then
			continue
		end

		local target = lock.target
		if not target.alive or (target.root.Position - ship.root.Position).Magnitude > Config.LockRange then
			Combat.clearLock(ship)
			continue
		end

		if not lock.locked then
			lock.progress = math.min(1, lock.progress + dt / ship.hull.lockTime)
			lock.locked = lock.progress >= 1
			continue
		end

		for _, gun in ship.guns do
			if ship.alive and target.alive then
				fireGun(ship, gun, target, effects, dt)
			end
		end
	end

	if #effects > 0 then
		Remotes.CombatEffects:FireAllClients(effects)
	end
end

return Combat
