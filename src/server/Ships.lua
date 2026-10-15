--[[
	Owns every ship in the server: spawning from a loadout, health, shields,
	modules, and the damage pipeline steps 4 to 7 from weapons-and-damage.md.
	Combat decides whether a shot hits and how much it does; Ships decides
	where that damage goes.

	State the client needs (HP, shield, gun status, lock) is mirrored onto the
	ship model as attributes so the HUD can read it.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShipBuilder = require(script.Parent.ShipBuilder)

local Ships = {}

Ships.all = {} -- list of live ships
Ships.byModel = {} -- [Model] = ship

local destroyedCallbacks = {}
local nextId = 0
local random = Random.new()

local shipsFolder = Instance.new("Folder")
shipsFolder.Name = "Ships"
shipsFolder.Parent = workspace

local function now()
	return workspace:GetServerTimeNow()
end

local function setAttr(ship, name, value)
	if ship.attrCache[name] ~= value then
		ship.attrCache[name] = value
		ship.model:SetAttribute(name, value)
	end
end

local function addModule(ship, kind, name, extra)
	local maxHP = Config.ModuleHP[kind][ship.hull.size]
	local module = {
		kind = kind,
		name = name,
		hp = maxHP,
		maxHP = maxHP,
		online = true,
	}
	if extra then
		for key, value in extra do
			module[key] = value
		end
	end
	table.insert(ship.modules, module)
	return module
end

-- Plasma fire rate = total engine output / total plasma draw, capped at 100%.
-- Top speed falls by each knocked-out engine's share of output.
local function recomputePower(ship)
	local output, totalOutput = 0, 0
	for _, module in ship.modules do
		if module.kind == "Engine" then
			totalOutput += module.output
			if module.online then
				output += module.output
			end
		end
	end

	local draw = 0
	for _, gun in ship.guns do
		if gun.weapon.class == "Energy" then
			draw += gun.weapon.powerDraw
		end
	end

	ship.plasmaRate = if draw > 0 then math.min(1, output / draw) else 1
	local share = if totalOutput > 0 then output / totalOutput else 0
	ship.speedScale = math.max(Config.Flight.minSpeedScale, share)
end

function Ships.onDestroyed(callback)
	table.insert(destroyedCallbacks, callback)
end

function Ships.spawn(loadoutName: string, cframe: CFrame, owner: Player?)
	local loadout = Config.Loadouts[loadoutName]
	assert(loadout, "Unknown loadout " .. tostring(loadoutName))
	local hull = Config.Hulls[loadout.hull]
	assert(#loadout.guns <= ShipBuilder.mountCount(loadout.hull), loadoutName .. " has more guns than mounts")

	nextId += 1
	local name = if owner then owner.Name else loadout.displayName .. " " .. nextId
	local model = ShipBuilder.build(loadout.hull, loadout.color, name)
	model:PivotTo(cframe)

	local plates = loadout.armorPlates or 0
	local maxHull = hull.hullHP + plates * Config.Defense.armorHPPerPlate[hull.size]
	local maxShield = Config.ShieldGenerators[loadout.shield].shieldHP

	local ship = {
		id = nextId,
		model = model,
		root = model.PrimaryPart,
		loadoutName = loadoutName,
		loadout = loadout,
		hull = hull,
		owner = owner,
		alive = true,

		hullHP = maxHull,
		maxHullHP = maxHull,
		shieldHP = maxShield,
		maxShieldHP = maxShield,
		lastEnergyHit = -math.huge,
		lastDamagedAt = 0,
		armorReduction = math.min(Config.Defense.armorReductionCap, plates * Config.Defense.armorReductionPerPlate),

		modules = {},
		guns = {},
		lock = nil, -- { target = ship, progress = 0..1, locked = bool }
		subsystem = nil, -- nil means hull; else a module kind
		attrCache = {},
	}

	ship.generator = addModule(ship, "ShieldGenerator", "ShieldGenerator")
	addModule(ship, "Cockpit", "Cockpit")
	for i, engineName in loadout.engines do
		addModule(ship, "Engine", "Engine" .. i, { output = Config.Engines[engineName].output })
	end

	for i, fit in loadout.guns do
		local weapon = Config.Weapons[fit.weapon]
		local gun = {
			index = i,
			weaponName = fit.weapon,
			weapon = weapon,
			slot = Config.Slots[fit.slot],
			tier = fit.tier or 1,
			mount = ship.root:FindFirstChild("Gun" .. i),
			timer = 0,
			status = "Idle",
		}
		gun.module = addModule(ship, "Weapon", "Weapon" .. i, { gun = gun })
		ship.guns[i] = gun
	end

	for cell, gunIndex in loadout.magazineFor do
		local gun = ship.guns[gunIndex]
		local weapon = gun.weapon
		gun.magazine = addModule(ship, "Magazine", "Magazine" .. cell, { feeds = gun })
		gun.ammo = math.floor(weapon.ammoSeconds / weapon.interval)
		gun.maxAmmo = gun.ammo
	end

	recomputePower(ship)

	model:SetAttribute("ShipId", ship.id)
	model:SetAttribute("DisplayName", if owner then owner.DisplayName else loadout.displayName)
	model:SetAttribute("Hull", loadout.hull)
	model:SetAttribute("IsDrone", owner == nil)
	model:SetAttribute("GunCount", #ship.guns)
	for _, gun in ship.guns do
		model:SetAttribute("Gun" .. gun.index .. "Weapon", gun.weaponName)
		model:SetAttribute("Gun" .. gun.index .. "Class", gun.weapon.class)
	end
	if owner then
		model:SetAttribute("OwnerUserId", owner.UserId)
	end

	local lockValue = Instance.new("ObjectValue")
	lockValue.Name = "LockTarget"
	lockValue.Parent = model
	ship.lockValue = lockValue

	Ships.sync(ship)
	CollectionService:AddTag(model, "Ship")

	if owner then
		-- Keep the pilot's own ship streamed in for them no matter what.
		model.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
		model:AddPersistentPlayer(owner)
	end
	model.Parent = shipsFolder

	-- The pilot's client simulates its own ship for smooth six-axis controls;
	-- drones stay with the server.
	ship.root:SetNetworkOwner(owner)

	table.insert(Ships.all, ship)
	Ships.byModel[model] = ship
	return ship
end

function Ships.sync(ship)
	setAttr(ship, "HullHP", math.ceil(ship.hullHP))
	setAttr(ship, "MaxHullHP", ship.maxHullHP)
	setAttr(ship, "ShieldHP", math.ceil(ship.shieldHP))
	setAttr(ship, "MaxShieldHP", ship.maxShieldHP)
	setAttr(ship, "PlasmaRate", math.floor(ship.plasmaRate * 100 + 0.5) / 100)
	setAttr(ship, "SpeedScale", math.floor(ship.speedScale * 100 + 0.5) / 100)
	setAttr(ship, "LastDamagedAt", ship.lastDamagedAt)
	setAttr(ship, "Subsystem", ship.subsystem or "Hull")
	setAttr(ship, "LockProgress", if ship.lock then math.floor(ship.lock.progress * 20) / 20 else 0)

	for _, gun in ship.guns do
		setAttr(ship, "Gun" .. gun.index .. "Status", gun.status)
		if gun.ammo then
			setAttr(ship, "Gun" .. gun.index .. "Ammo", gun.ammo)
		end
	end
	for _, module in ship.modules do
		setAttr(ship, "Mod_" .. module.name, math.ceil(math.max(0, module.hp)))
		setAttr(ship, "ModMax_" .. module.name, module.maxHP)
	end

	local lockTarget = if ship.lock then ship.lock.target.model else nil
	if ship.lockValue.Value ~= lockTarget then
		ship.lockValue.Value = lockTarget
	end
end

function Ships.destroy(ship)
	if not ship.alive then
		return
	end
	ship.alive = false
	ship.hullHP = 0

	local index = table.find(Ships.all, ship)
	if index then
		table.remove(Ships.all, index)
	end
	Ships.byModel[ship.model] = nil

	Remotes.ShipEvent:FireAllClients("Destroyed", ship.root.Position, ship.hull.radius)
	for _, callback in destroyedCallbacks do
		task.spawn(callback, ship)
	end
	ship.model:Destroy()
end

local function knockOut(ship, module, events)
	if not module.online then
		return
	end
	module.online = false
	module.hp = 0
	table.insert(events, { "Knockout", module.name })

	if module.kind == "ShieldGenerator" then
		ship.shieldHP = 0
		table.insert(events, { "ShieldDown" })
	elseif module.kind == "Engine" then
		recomputePower(ship)
	elseif module.kind == "Cockpit" then
		ship.hullHP = 0
	elseif module.kind == "Magazine" then
		-- Cooks off: damage to the hull and to one other working module.
		-- There is no grid yet, so "neighbouring" is a random module.
		local cookoff = Config.Defense.magazineCookoffDamage
		ship.hullHP -= cookoff
		local others = {}
		for _, other in ship.modules do
			if other.online and other ~= module then
				table.insert(others, other)
			end
		end
		if #others > 0 then
			local other = others[random:NextInteger(1, #others)]
			other.hp -= cookoff
			if other.hp <= 0 then
				knockOut(ship, other, events)
			end
		end
	end
	-- Weapon knock-outs are read straight from module.online by Combat.
end

local function pickModule(ship, subsystem)
	local candidates = {}
	for _, module in ship.modules do
		if module.online and (subsystem == nil or module.kind == subsystem) then
			table.insert(candidates, module)
		end
	end
	if #candidates == 0 and subsystem ~= nil then
		return pickModule(ship, nil)
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[random:NextInteger(1, #candidates)]
end

function Ships.shieldUp(ship)
	return ship.generator.online and ship.shieldHP > 0
end

--[[
	Pipeline steps 4 to 7. hit = { class = "Energy" | "Kinetic", damage = number }.
	Returns { shield = bool } so Combat can tell clients whether to draw a
	shield ripple.
]]
function Ships.applyHit(target, attacker, hit)
	local damage = hit.damage
	local result = { shield = false }
	local events = {}
	local t = now()

	-- Step 4: Energy against a raised shield drains the pool first.
	if hit.class == "Energy" and Ships.shieldUp(target) then
		result.shield = true
		target.lastEnergyHit = t
		local absorbed = math.min(target.shieldHP, damage)
		target.shieldHP -= absorbed
		damage -= absorbed
		if target.shieldHP <= 0 then
			table.insert(events, { "ShieldDown" })
		end
	elseif hit.class == "Kinetic" then
		-- Step 5: Kinetic passes the shield, losing some damage, and is cut by armor.
		if Ships.shieldUp(target) then
			result.shield = true
			damage *= Config.Combat.kineticShieldPassThrough
		end
		damage *= 1 - target.armorReduction
	end

	if damage > 0 then
		target.hullHP -= damage
		target.lastDamagedAt = t

		-- Step 6: the same hit also damages one module.
		local multiplier = if hit.class == "Kinetic"
			then Config.Combat.kineticModuleMultiplier
			else Config.Combat.energyModuleMultiplier
		local module = pickModule(target, attacker.subsystem)
		if module then
			module.hp -= damage * multiplier
			if module.hp <= 0 then
				knockOut(target, module, events)
			end
		end
	end

	-- Step 7: tell clients about knock-outs and destruction.
	for _, event in events do
		Remotes.ShipEvent:FireAllClients(event[1], target.model, event[2])
	end
	if target.hullHP <= 0 then
		Ships.destroy(target)
	end

	return result
end

function Ships.update(dt)
	local t = now()
	for _, ship in Ships.all do
		if ship.generator.online and ship.shieldHP < ship.maxShieldHP then
			if t - ship.lastEnergyHit >= Config.Defense.shieldRechargeDelay then
				ship.shieldHP = math.min(
					ship.maxShieldHP,
					ship.shieldHP + ship.maxShieldHP * Config.Defense.shieldRechargeFraction * dt
				)
			end
		end
		Ships.sync(ship)
	end
end

return Ships
