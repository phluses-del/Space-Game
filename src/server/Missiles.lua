--[[
	Missile racks, homing missiles and point defense.

	The pilot fires a missile with the Missile button once their lock is
	complete and the target is in range. Missiles fly as real server parts so
	point-defense turrets can shoot them down; each PD turret engages the
	nearest missile heading for its own ship. Plasma Torpedo racks reload from
	engine power (slower when plasma fire rate is below 100%); Hull-Cracker
	racks only refill on respawn for now (stations and carriers later).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ships = require(script.Parent.Ships)

local Missiles = {}

local ENERGY = Color3.fromRGB(255, 90, 220)
local KINETIC = Color3.fromRGB(255, 200, 80)

local live = {} -- list of { shooter, target, weapon, tier, part, position, direction, travelled }
local random = Random.new()

local folder = Instance.new("Folder")
folder.Name = "Missiles"
folder.Parent = workspace

local function makePart(weapon, cframe)
	local color = if weapon.class == "Energy" then ENERGY else KINETIC
	local p = Instance.new("Part")
	p.Name = "Missile"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = if weapon.class == "Energy" then Vector3.new(1, 1, 1.6) else Vector3.new(0.5, 0.5, 2.4)
	p.CFrame = cframe

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.2, p.Size.Z / 2)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.2, p.Size.Z / 2)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.4
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.LightEmission = 1
	trail.Parent = p

	p.Parent = folder
	return p
end

-- Returns true if a missile launched, or false and a reason for the HUD.
function Missiles.fire(ship)
	local rack = ship.rack
	if not (ship.alive and rack) then
		return false, "No missile rack"
	end
	if rack.ammo <= 0 then
		return false, "Missile rack empty"
	end
	local lock = ship.lock
	if not (lock and lock.locked and lock.target.alive) then
		return false, "Lock a target first"
	end

	local weapon = rack.weapon
	local target = lock.target
	local origin = if rack.attachment then rack.attachment.WorldPosition else ship.root.Position
	if (target.root.Position - origin).Magnitude > weapon.range then
		return false, "Target out of missile range"
	end

	rack.ammo -= 1
	local direction = ship.root.CFrame.LookVector
	table.insert(live, {
		shooter = ship,
		target = target,
		weapon = weapon,
		tier = rack.tier,
		position = origin,
		direction = direction,
		travelled = 0,
		part = makePart(weapon, CFrame.lookAt(origin, origin + direction)),
	})
	return true
end

local function burst(missile, size)
	Remotes.ShipEvent:FireAllClients("MissileBurst", missile.position, size)
	missile.part:Destroy()
end

local function rotateToward(direction, wanted, maxAngle)
	local angle = math.acos(math.clamp(direction:Dot(wanted), -1, 1))
	if angle <= maxAngle or angle < 1e-4 then
		return wanted
	end
	local axis = direction:Cross(wanted)
	if axis.Magnitude < 1e-4 then
		return direction
	end
	return (CFrame.fromAxisAngle(axis.Unit, maxAngle) * direction).Unit
end

local function reloadRacks(dt)
	for _, ship in Ships.all do
		local rack = ship.rack
		local rechargeTime = rack and rack.weapon.rechargeTime
		if rechargeTime and rack.ammo < rack.maxAmmo then
			rack.recharge += dt * ship.plasmaRate
			if rack.recharge >= rechargeTime then
				rack.recharge = 0
				rack.ammo += 1
			end
		end
	end
end

-- Each point-defense turret fires at the nearest missile heading for its ship.
local function pointDefense(dt, effects)
	for _, ship in Ships.all do
		for _, gun in ship.guns do
			if not gun.antiMissile then
				continue
			end
			local weapon = gun.weapon
			gun.timer = math.min(gun.timer + dt, weapon.interval)
			if not gun.module.online then
				gun.status = "Offline"
				continue
			end

			local origin = if gun.mount then gun.mount.WorldPosition else ship.root.Position
			local best, bestDistance = nil, weapon.range
			for _, missile in live do
				if missile.target == ship and not missile.dead then
					local distance = (missile.position - origin).Magnitude
					if distance <= bestDistance then
						best, bestDistance = missile, distance
					end
				end
			end

			if not best then
				gun.status = "Idle"
				continue
			end
			gun.status = "Firing"
			if gun.timer < weapon.interval then
				continue
			end
			gun.timer -= weapon.interval

			local hit = random:NextNumber() < weapon.missileHitChance
			table.insert(effects, {
				shooter = ship.model,
				gun = gun.index,
				position = best.position,
				hit = hit,
				class = "Kinetic",
			})
			if hit then
				best.dead = true
				burst(best, 2)
			end
		end
	end
end

function Missiles.update(dt)
	reloadRacks(dt)

	local effects = {}
	pointDefense(dt, effects)

	for i = #live, 1, -1 do
		local missile = live[i]
		if missile.dead then
			table.remove(live, i)
			continue
		end

		local weapon = missile.weapon
		local target = missile.target
		local step = weapon.speed * dt

		if target.alive then
			local toTarget = target.root.Position - missile.position
			local reach = target.hull.radius + 2
			if toTarget.Magnitude <= reach + step then
				local damage = weapon.damage * Config.TierMultiplier[missile.tier]
				if missile.shooter.owner == nil then
					damage *= Config.TestSystem.droneDamageScale
				end
				missile.position = target.root.Position - toTarget.Unit * reach
				local result = Ships.applyHit(target, missile.shooter, {
					class = weapon.class,
					damage = damage,
					moduleMultiplier = weapon.moduleMultiplier,
				})
				table.insert(effects, {
					impact = true,
					position = missile.position,
					target = target.model,
					class = weapon.class,
					shield = result.shield,
				})
				burst(missile, 6)
				table.remove(live, i)
				continue
			end
			missile.direction = rotateToward(missile.direction, toTarget.Unit, math.rad(weapon.turnRate) * dt)
		end

		missile.position += missile.direction * step
		missile.travelled += step
		if missile.travelled > weapon.range * 1.5 then
			burst(missile, 3)
			table.remove(live, i)
			continue
		end
		missile.part.CFrame = CFrame.lookAt(missile.position, missile.position + missile.direction)
	end

	if #effects > 0 then
		Remotes.CombatEffects:FireAllClients(effects)
	end
end

return Missiles
