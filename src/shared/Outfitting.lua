--[[
	Ship customization data and rules, shared by the server (which trusts
	nothing from the client and re-checks everything here) and the shipyard
	screen (which uses the same functions to show stats and errors live).

	A "design" is a saved loadout: which hull, what sits in each weapon slot,
	the shield, the engine on each mount, what fills each module cell, and the
	paint job. Designs are plain tables of strings and numbers so they save to
	a DataStore and travel over remotes as they are.

	Design shape:
	{
		id = "L1", name = "Brawler", hull = "Fighter",
		weapons = { { id = "PulseBlaster", tier = 1, mount = "Gimbal" }, false, ... }, -- one per weapon slot
		missile = { id = "PlasmaTorpedo", tier = 1 } | false, -- hulls with a missile rack
		shield = { id = "ShieldStandard", tier = 1 } | false,
		engines = { { id = "Standard", tier = 1, thrust = 100 }, false, ... }, -- one per engine mount
		modules = { "ArmorPlate", "Magazine", false, ... }, -- one per module cell
		cosmetics = { paint = "Azure", trim = "Graphite", glow = "Amber", trail = "None", finish = "Matte" },
	}

	Owned items are counted in an inventory keyed by Outfitting.key(id, size, tier),
	for example "PulseBlaster|Small|1" or "Sprint|Small|2". Size matters for
	shields, engines and armor (a Small shield can't go on a Large hull), so it
	is part of the key for every item to keep things uniform.

	Every number here is a playtest starting point.
]]

local Config = require(script.Parent.Config)

local Outfitting = {}

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

Outfitting.Settings = {
	startingCredits = 25000, -- placeholder until mining and trading pay
	starterHulls = { "Scout", "Fighter" }, -- owned from the start
	loadoutsPerHull = 3, -- extra slots are a planned game pass
	sellBackRate = 0.5, -- share of the price returned when selling an item

	-- true: every hull, item and cosmetic is owned and free. For playtests.
	freeMode = false,

	-- Changing ship is blocked for this many seconds after taking damage, so a
	-- loadout swap can't be used as an escape or a free repair.
	swapCombatLockout = 10,

	maxNameLength = 24,
}

Outfitting.Tiers = { 1, 2, 3, 4 }
Outfitting.TierNames = { "Mk I", "Mk II", "Mk III", "Mk IV" }

-- weapons-and-damage.md and ship-types.md tier scaling.
Outfitting.TierScale = {
	weaponDamage = Config.TierMultiplier, -- Combat reads this one from Config
	energyDraw = { 1, 1.1, 1.21, 1.33 }, -- Energy guns draw ~1.1x more engine output per tier
	kineticAmmo = { 1, 1.15, 1.32, 1.52 }, -- Kinetic tiers raise ammo per magazine ~15%
	engine = { 1, 1.2, 1.45, 1.75 }, -- engine thrust and output
	shield = { 1, 1.15, 1.3, 1.5 }, -- shield pool (placeholder)
	price = { 1, 2.5, 6, 14 }, -- credits (placeholder)
}

--------------------------------------------------------------------------------
-- Hull fitting layouts (ship-types.md, "The answers at a glance")
--------------------------------------------------------------------------------

-- Weapon slot kinds. Slot i is ShipBuilder mount "Gun"..i.
local SMALL = { size = "Small", mounts = { "Fixed", "Gimbal" } }
local MEDIUM = { size = "Medium", mounts = { "Fixed", "Gimbal" } }
local TURRET = { size = "Any", mounts = { "Turret" } }

-- reactor: power budget every fitted module draws from (the reactor module is
--   built into the hull for now).
-- moduleCells: interior cells for armor plates, magazines and (later) cargo,
--   mining and utility modules. The grid editor replaces this list later.
-- price: credits to buy the hull. stock: the free fit a new hull comes with;
--   guns, missile and armor come from ShipClasses when it has them, and
--   magazines are added for whatever the stock guns need.
-- A hull only shows up once Config.Hulls has an entry for it.
Outfitting.Hulls = {
	Scout = {
		price = 0,
		weapons = { SMALL, SMALL },
		missileRack = false,
		shieldSize = "Small",
		engineMounts = 2,
		moduleCells = 2,
		reactor = 60,
		stock = {
			weapons = { { "PulseBlaster", "Gimbal" }, { "PulseBlaster", "Gimbal" } },
			shield = "ShieldLight",
			engine = "Standard",
			cosmetics = { paint = "Azure" },
		},
	},
	Fighter = {
		price = 8000,
		weapons = { SMALL, SMALL, SMALL, SMALL },
		missileRack = true,
		shieldSize = "Small",
		engineMounts = 2,
		moduleCells = 4,
		reactor = 110,
		stock = {
			weapons = {
				{ "PulseBlaster", "Gimbal" },
				{ "PulseBlaster", "Gimbal" },
				{ "Autocannon", "Gimbal" },
				{ "Autocannon", "Gimbal" },
			},
			shield = "ShieldStandard",
			engine = "Standard",
			cosmetics = { paint = "Azure" },
		},
	},
	Hauler = {
		price = 15000,
		weapons = { TURRET },
		missileRack = false,
		shieldSize = "Medium",
		engineMounts = 3,
		moduleCells = 8,
		reactor = 140,
		stock = {
			weapons = { { "PointDefense", "Turret" } },
			shield = "ShieldStandard",
			engine = "Standard",
			cosmetics = { paint = "Ivory" },
		},
	},
	Frigate = {
		price = 60000,
		weapons = { MEDIUM, MEDIUM, TURRET, TURRET, TURRET, TURRET },
		missileRack = false,
		shieldSize = "Large",
		engineMounts = 4,
		moduleCells = 10,
		reactor = 420,
		stock = {
			weapons = {
				{ "PlasmaCannon", "Fixed" },
				{ "PlasmaCannon", "Fixed" },
				{ "FlakTurret", "Turret" },
				{ "FlakTurret", "Turret" },
				{ "BeamTurret", "Turret" },
				{ "PointDefense", "Turret" },
			},
			shield = "ShieldStandard",
			engine = "Standard",
			cosmetics = { paint = "Graphite" },
		},
	},
	Industrial = {
		price = 55000,
		weapons = { TURRET, TURRET },
		missileRack = false,
		shieldSize = "Large",
		engineMounts = 4,
		moduleCells = 14,
		reactor = 280,
		stock = {
			weapons = { { "FlakTurret", "Turret" }, { "PointDefense", "Turret" } },
			shield = "ShieldLight",
			engine = "Standard",
			cosmetics = { paint = "Ember" },
		},
	},
	Carrier = {
		price = 250000,
		weapons = { TURRET, TURRET, TURRET, TURRET, TURRET, TURRET },
		missileRack = false,
		shieldSize = "Capital",
		engineMounts = 6,
		moduleCells = 20,
		reactor = 900,
		stock = {
			weapons = {
				{ "FlakTurret", "Turret" },
				{ "BeamTurret", "Turret" },
				{ "PointDefense", "Turret" },
				{ "PointDefense", "Turret" },
				{ "PointDefense", "Turret" },
				{ "PointDefense", "Turret" },
			},
			shield = "ShieldStandard",
			engine = "Standard",
			cosmetics = { paint = "Graphite" },
		},
	},
}

Outfitting.HullOrder = { "Scout", "Fighter", "Hauler", "Frigate", "Industrial", "Carrier" }

--------------------------------------------------------------------------------
-- Items
--------------------------------------------------------------------------------

-- Weapons come from Config.Weapons. A weapon may set `mountsOn` (default
-- Fixed and Gimbal), `price` and `reactor`; otherwise these defaults apply.
Outfitting.WeaponDefaults = {
	priceBySize = { Small = 1000, Medium = 4000, Large = 9000, Capital = 20000 },
	turretPrice = 5000,
	missilePrice = 3500,
	reactorBySize = { Small = 10, Medium = 25, Large = 45, Capital = 90 },
	turretReactor = 20,
	missileReactor = 15,
}

-- Shields: pool by hull size. Standard matches the "typical fit" numbers in
-- ship-types.md. Heavy adds mass, Light frees reactor for guns or cargo.
local SIZE_REACTOR = { Small = 1, Medium = 2, Large = 4, Capital = 8 }
local SIZE_PRICE = { Small = 1, Medium = 2.5, Large = 7, Capital = 20 }

Outfitting.Shields = {
	ShieldLight = {
		name = "Light shield",
		pool = { Small = 400, Medium = 800, Large = 2000, Capital = 5500 },
		reactor = 10,
		mass = 0,
		price = 600,
	},
	ShieldStandard = {
		name = "Standard shield",
		pool = { Small = 800, Medium = 1200, Large = 3000, Capital = 8000 },
		reactor = 20,
		mass = 0.02,
		price = 1500,
	},
	ShieldHeavy = {
		name = "Heavy shield",
		pool = { Small = 1100, Medium = 1700, Large = 4200, Capital = 11000 },
		reactor = 30,
		mass = 0.06,
		price = 3500,
	},
}
Outfitting.ShieldOrder = { "ShieldLight", "ShieldStandard", "ShieldHeavy" }

-- Engines (ship-types.md, "Engines and handling"). thrust and output are
-- multiples of a Standard engine; output by size is the Mk I Standard value.
-- accel < 1 is Heavy lift's slow ramp. reactor is the Small value, scaled by size.
Outfitting.EngineBaseOutput = { Small = 100, Medium = 200, Large = 350, Capital = 600 }
Outfitting.Engines = {
	Standard = { name = "Standard engine", thrust = 1.0, output = 1.0, accel = 1.0, reactor = 10, mass = 0, price = 800 },
	Sprint = { name = "Sprint engine", thrust = 1.3, output = 0.8, accel = 1.1, reactor = 15, mass = -0.02, price = 1800 },
	HeavyLift = { name = "Heavy lift engine", thrust = 1.3, output = 1.0, accel = 0.75, reactor = 10, mass = 0.04, price = 1600 },
	Efficient = { name = "Efficient engine", thrust = 0.7, output = 1.3, accel = 0.9, reactor = 5, mass = -0.02, price = 1400 },
}
Outfitting.EngineOrder = { "Standard", "Sprint", "HeavyLift", "Efficient" }

-- Thrust slider, percent. Above 100 costs extra reactor (heat comes later).
Outfitting.Thrust = { min = 60, max = 120, step = 10, reactorPerPercentOver = 0.02 }

-- Module cells. Untiered for now. mass is added to a ship's mass factor.
Outfitting.Modules = {
	ArmorPlate = { name = "Armor plate", reactor = 2, mass = 0.06, price = 700 },
	Magazine = { name = "Ammo magazine", reactor = 2, mass = 0.02, price = 400 },
}
Outfitting.ModuleOrder = { "ArmorPlate", "Magazine" }

-- How module mass slows a ship: top speed scales by (thrust / mass) ^ speedExponent,
-- acceleration by thrust / mass, and turning by 1 / mass ^ turnExponent.
Outfitting.Handling = {
	speedExponent = 0.5,
	turnExponent = 0.5,
	minScale = 0.4,
	maxScale = 1.6,
}

--------------------------------------------------------------------------------
-- Cosmetics (looks only; bought with Credits for now, Robux shop later)
--------------------------------------------------------------------------------

Outfitting.Cosmetics = {
	paint = {
		{ id = "Azure", name = "Azure", rgb = { 70, 140, 220 }, price = 0 },
		{ id = "Crimson", name = "Crimson", rgb = { 200, 60, 60 }, price = 0 },
		{ id = "Graphite", name = "Graphite", rgb = { 60, 64, 76 }, price = 0 },
		{ id = "Ivory", name = "Ivory", rgb = { 225, 220, 205 }, price = 0 },
		{ id = "Ember", name = "Ember", rgb = { 230, 120, 40 }, price = 500 },
		{ id = "Toxic", name = "Toxic", rgb = { 120, 220, 60 }, price = 500 },
		{ id = "Violet", name = "Violet", rgb = { 130, 80, 210 }, price = 800 },
		{ id = "Teal", name = "Teal", rgb = { 40, 170, 160 }, price = 800 },
		{ id = "Rose", name = "Rose", rgb = { 230, 120, 170 }, price = 800 },
		{ id = "Midnight", name = "Midnight", rgb = { 25, 30, 60 }, price = 1200 },
		{ id = "Gold", name = "Gold", rgb = { 220, 180, 60 }, price = 3000 },
	},
	-- Trim uses the paint list (and the paints the player owns).
	glow = {
		{ id = "Amber", name = "Amber", rgb = { 255, 150, 60 }, price = 0 },
		{ id = "Ice", name = "Ice blue", rgb = { 120, 210, 255 }, price = 0 },
		{ id = "Plasma", name = "Plasma pink", rgb = { 255, 90, 200 }, price = 600 },
		{ id = "Emerald", name = "Emerald", rgb = { 80, 255, 140 }, price = 600 },
		{ id = "White", name = "White hot", rgb = { 255, 255, 255 }, price = 1000 },
		{ id = "Crimson", name = "Red giant", rgb = { 255, 60, 50 }, price = 1000 },
	},
	trail = {
		{ id = "None", name = "No trail", length = 0, price = 0 },
		{ id = "Ion", name = "Ion trail", length = 0.35, price = 1200 },
		{ id = "Comet", name = "Comet trail", length = 0.9, price = 2500 },
	},
	finish = {
		{ id = "Matte", name = "Matte", material = "SmoothPlastic", price = 0 },
		{ id = "Metallic", name = "Metallic", material = "Metal", price = 1000 },
		{ id = "Plated", name = "Plated", material = "DiamondPlate", price = 1500 },
		{ id = "Foil", name = "Foil", material = "Foil", price = 2000 },
	},
}
Outfitting.CosmeticSlots = { "paint", "trim", "glow", "trail", "finish" }
Outfitting.CosmeticDefaults = { paint = "Azure", trim = "Graphite", glow = "Amber", trail = "None", finish = "Matte" }

-- trim draws from the paint list.
local function cosmeticList(slot)
	return Outfitting.Cosmetics[if slot == "trim" then "paint" else slot]
end

function Outfitting.cosmetic(slot: string, id: string)
	local list = cosmeticList(slot)
	if not list then
		return nil
	end
	for _, entry in list do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

-- Ownership key for a cosmetic. Trim and paint share ownership.
function Outfitting.cosmeticKey(slot: string, id: string): string
	local category = if slot == "trim" then "paint" else slot
	return category .. ":" .. id
end

function Outfitting.cosmeticColor(slot: string, id: string)
	local entry = Outfitting.cosmetic(slot, id)
	if entry and entry.rgb then
		return Color3.fromRGB(entry.rgb[1], entry.rgb[2], entry.rgb[3])
	end
	return nil
end

--------------------------------------------------------------------------------
-- Item lookups
--------------------------------------------------------------------------------

function Outfitting.key(id: string, size: string, tier: number?): string
	return id .. "|" .. size .. "|" .. tostring(tier or 1)
end

function Outfitting.parseKey(key: string)
	local id, size, tier = string.match(key, "^([%w_]+)|([%w_]+)|(%d)$")
	if not id then
		return nil
	end
	return id, size, tonumber(tier)
end

local function weaponMounts(weapon)
	return weapon.mountsOn or { "Fixed", "Gimbal" }
end

local function isTurretWeapon(weapon)
	return table.find(weaponMounts(weapon), "Turret") ~= nil
end

local function isMissileWeapon(weapon)
	return table.find(weaponMounts(weapon), "MissileRack") ~= nil
end

-- Magazine cells a weapon needs: none for Energy or unlimited-ammo guns (point
-- defense), one for small guns, two for a Railgun or turret (weapons-and-damage.md).
function Outfitting.magazineCells(id: string): number
	local weapon = Config.Weapons[id]
	if not weapon or not (weapon.ammoShots or weapon.ammoSeconds) then
		return 0
	end
	if weapon.magazineCells then
		return weapon.magazineCells
	end
	return if weapon.size == "Medium" or isTurretWeapon(weapon) then 2 else 1
end

-- Which category an item id belongs to: "Weapon", "Shield", "Engine", "Module" or nil.
function Outfitting.category(id: string): string?
	if Config.Weapons[id] then
		return "Weapon"
	elseif Outfitting.Shields[id] then
		return "Shield"
	elseif Outfitting.Engines[id] then
		return "Engine"
	elseif Outfitting.Modules[id] then
		return "Module"
	end
	return nil
end

function Outfitting.displayName(id: string): string
	local def = Outfitting.Shields[id] or Outfitting.Engines[id] or Outfitting.Modules[id]
	if def then
		return def.name
	end
	local weapon = Config.Weapons[id]
	if weapon and weapon.displayName then
		return weapon.displayName
	end
	-- "PulseBlaster" -> "Pulse Blaster"
	return (string.gsub(id, "(%l)(%u)", "%1 %2"))
end

-- The size an item is keyed under when fitted to a hull of hullSize.
function Outfitting.itemSize(id: string, hullSize: string): string
	local weapon = Config.Weapons[id]
	if weapon then
		return weapon.size or "Small"
	elseif Outfitting.Modules[id] == Outfitting.Modules.Magazine then
		return "Any"
	end
	return hullSize
end

function Outfitting.weaponReactor(id: string): number
	local weapon = Config.Weapons[id]
	if not weapon then
		return 0
	end
	if weapon.reactor then
		return weapon.reactor
	end
	local d = Outfitting.WeaponDefaults
	if isMissileWeapon(weapon) then
		return d.missileReactor
	elseif isTurretWeapon(weapon) then
		return d.turretReactor
	end
	return d.reactorBySize[weapon.size or "Small"] or d.reactorBySize.Small
end

-- Price in Credits of one item. Returns nil for unknown items.
function Outfitting.price(id: string, size: string, tier: number?): number?
	tier = tier or 1
	local tierScale = Outfitting.TierScale.price[tier]
	if not tierScale then
		return nil
	end
	local category = Outfitting.category(id)
	local base
	if category == "Weapon" then
		local weapon = Config.Weapons[id]
		local d = Outfitting.WeaponDefaults
		base = weapon.price
			or (if isMissileWeapon(weapon)
				then d.missilePrice
				elseif isTurretWeapon(weapon) then d.turretPrice
				else d.priceBySize[weapon.size or "Small"] or d.priceBySize.Small)
	elseif category == "Shield" then
		base = Outfitting.Shields[id].price * (SIZE_PRICE[size] or 1)
	elseif category == "Engine" then
		base = Outfitting.Engines[id].price * (SIZE_PRICE[size] or 1)
	elseif category == "Module" then
		base = Outfitting.Modules[id].price * (SIZE_PRICE[size] or 1)
		tierScale = 1
	else
		return nil
	end
	return math.floor(base * tierScale / 10 + 0.5) * 10
end

-- True when the item can be bought: known id, valid tier, and a size that
-- some hull could use.
function Outfitting.isBuyable(id: string, size: string, tier: number): boolean
	local category = Outfitting.category(id)
	if not category or not Outfitting.TierScale.price[tier] then
		return false
	end
	if category == "Weapon" then
		return size == (Config.Weapons[id].size or "Small")
	elseif category == "Module" then
		if tier ~= 1 then
			return false
		end
		if id == "Magazine" then
			return size == "Any"
		end
	end
	return SIZE_REACTOR[size] ~= nil
end

function Outfitting.hullAvailable(hull: string): boolean
	return Outfitting.Hulls[hull] ~= nil and Config.Hulls[hull] ~= nil
end

function Outfitting.availableHulls(): { string }
	local list = {}
	for _, hull in Outfitting.HullOrder do
		if Outfitting.hullAvailable(hull) then
			table.insert(list, hull)
		end
	end
	return list
end

-- Can this weapon go in this slot with this mount type?
function Outfitting.weaponFits(slot, weaponId: string, mount: string): boolean
	local weapon = Config.Weapons[weaponId]
	if not weapon or not table.find(slot.mounts, mount) then
		return false
	end
	if not table.find(weaponMounts(weapon), mount) then
		return false
	end
	return slot.size == "Any" or (weapon.size or "Small") == slot.size
end

-- Weapons that could go in a slot, as { id, mount } pairs, in a stable order.
function Outfitting.weaponOptions(slot)
	local options = {}
	local ids = {}
	for id in Config.Weapons do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		for _, mount in slot.mounts do
			if Outfitting.weaponFits(slot, id, mount) then
				table.insert(options, { id = id, mount = mount })
			end
		end
	end
	return options
end

function Outfitting.missileOptions(): { string }
	local options = {}
	for id, weapon in Config.Weapons do
		if isMissileWeapon(weapon) then
			table.insert(options, id)
		end
	end
	table.sort(options)
	return options
end

--------------------------------------------------------------------------------
-- Designs
--------------------------------------------------------------------------------

local function tierOrNil(value)
	if type(value) == "number" and value == math.floor(value) and value >= 1 and value <= #Outfitting.Tiers then
		return value
	end
	return nil
end

-- The shield whose pool is closest to the hull's "typical fit" shield.
local function stockShield(hull, fallback)
	local base = Config.Hulls[hull]
	if not (base and base.typicalShield) then
		return fallback
	end
	local best, bestGap = fallback, math.huge
	for _, id in Outfitting.ShieldOrder do
		local pool = Outfitting.Shields[id].pool[base.size]
		if pool and math.abs(pool - base.typicalShield) < bestGap then
			best, bestGap = id, math.abs(pool - base.typicalShield)
		end
	end
	return best
end

-- The stock design for a hull. Weapons that don't exist in Config.Weapons yet
-- are left empty so this works before every weapon is built.
function Outfitting.stockDesign(hull: string)
	local def = Outfitting.Hulls[hull]
	assert(def, "No fitting layout for hull " .. tostring(hull))
	local stock = def.stock

	-- The ship classes own each hull's stock guns, missile and armor
	-- (Config.Hulls[hull].stock, from ShipClasses); this file's stock list
	-- is the fallback and supplies the shield, engines and paint.
	local classStock = Config.Hulls[hull] and Config.Hulls[hull].stock
	local stockWeapons = stock.weapons
	if classStock and classStock.guns then
		stockWeapons = {}
		for i, gun in classStock.guns do
			stockWeapons[i] = { gun.weapon, gun.slot }
		end
	end

	local design = {
		id = "",
		name = "Stock " .. hull,
		hull = hull,
		weapons = {},
		missile = false,
		shield = { id = stockShield(hull, stock.shield), tier = 1 },
		engines = {},
		modules = {},
		cosmetics = table.clone(Outfitting.CosmeticDefaults),
	}

	for i, slot in def.weapons do
		local fit = stockWeapons[i]
		if fit and Outfitting.weaponFits(slot, fit[1], fit[2]) then
			design.weapons[i] = { id = fit[1], tier = 1, mount = fit[2] }
		else
			design.weapons[i] = false
		end
	end
	for i = 1, def.engineMounts do
		design.engines[i] = { id = stock.engine, tier = 1, thrust = 100 }
	end
	if classStock and classStock.missile and def.missileRack and Config.Weapons[classStock.missile.weapon] then
		design.missile = { id = classStock.missile.weapon, tier = classStock.missile.tier or 1 }
	end
	for slot, id in stock.cosmetics or {} do
		design.cosmetics[slot] = id
	end

	-- Module cells: exactly the magazines the stock guns need, then armor.
	for i = 1, def.moduleCells do
		design.modules[i] = false
	end
	local cell = 0
	for _, fit in design.weapons do
		if fit then
			for _ = 1, Outfitting.magazineCells(fit.id) do
				cell += 1
				if cell <= def.moduleCells then
					design.modules[cell] = "Magazine"
				end
			end
		end
	end
	local plates = if classStock then classStock.armorPlates or 0 else 0
	for _ = 1, plates do
		cell += 1
		if cell <= def.moduleCells then
			design.modules[cell] = "ArmorPlate"
		end
	end
	return design
end

--[[
	Rebuilds a design from untrusted input (a client request or old save data)
	into a clean table that matches the hull's layout. Anything malformed is
	dropped to an empty slot rather than failing, so old saves survive balance
	changes. Returns nil only when the hull itself is unknown.
]]
function Outfitting.sanitize(raw)
	if type(raw) ~= "table" or type(raw.hull) ~= "string" then
		return nil, "No hull"
	end
	local hull = raw.hull
	local def = Outfitting.Hulls[hull]
	if not def then
		return nil, "Unknown hull"
	end
	local hullSize = Config.Hulls[hull] and Config.Hulls[hull].size or def.shieldSize

	local design = {
		id = if type(raw.id) == "string" then string.sub(raw.id, 1, 16) else "",
		name = "",
		hull = hull,
		weapons = {},
		missile = false,
		shield = false,
		engines = {},
		modules = {},
		cosmetics = {},
	}

	if type(raw.name) == "string" then
		-- Printable characters only, trimmed. Text shown to other players
		-- must still be filtered with TextService by the server.
		local name = string.gsub(raw.name, "[%c]", "")
		name = string.match(name, "^%s*(.-)%s*$") or ""
		design.name = string.sub(name, 1, Outfitting.Settings.maxNameLength)
	end
	if design.name == "" then
		design.name = hull
	end

	local weapons = if type(raw.weapons) == "table" then raw.weapons else {}
	for i, slot in def.weapons do
		local fit = weapons[i]
		local tier = type(fit) == "table" and tierOrNil(fit.tier)
		if
			tier
			and type(fit.id) == "string"
			and type(fit.mount) == "string"
			and Outfitting.weaponFits(slot, fit.id, fit.mount)
		then
			design.weapons[i] = { id = fit.id, tier = tier, mount = fit.mount }
		else
			design.weapons[i] = false
		end
	end

	local missile = raw.missile
	if def.missileRack and type(missile) == "table" and tierOrNil(missile.tier) and type(missile.id) == "string" then
		local weapon = Config.Weapons[missile.id]
		if weapon and isMissileWeapon(weapon) then
			design.missile = { id = missile.id, tier = missile.tier }
		end
	end

	local shield = raw.shield
	if type(shield) == "table" and type(shield.id) == "string" and Outfitting.Shields[shield.id] then
		local tier = tierOrNil(shield.tier)
		if tier and Outfitting.Shields[shield.id].pool[hullSize] then
			design.shield = { id = shield.id, tier = tier }
		end
	end

	local engines = if type(raw.engines) == "table" then raw.engines else {}
	for i = 1, def.engineMounts do
		local fit = engines[i]
		local tier = type(fit) == "table" and tierOrNil(fit.tier)
		if tier and type(fit.id) == "string" and Outfitting.Engines[fit.id] then
			local thrust = if type(fit.thrust) == "number" then fit.thrust else 100
			local t = Outfitting.Thrust
			thrust = math.clamp(math.floor(thrust / t.step + 0.5) * t.step, t.min, t.max)
			design.engines[i] = { id = fit.id, tier = tier, thrust = thrust }
		else
			design.engines[i] = false
		end
	end

	local modules = if type(raw.modules) == "table" then raw.modules else {}
	for i = 1, def.moduleCells do
		local id = modules[i]
		design.modules[i] = if type(id) == "string" and Outfitting.Modules[id] then id else false
	end

	local cosmetics = if type(raw.cosmetics) == "table" then raw.cosmetics else {}
	for _, slot in Outfitting.CosmeticSlots do
		local id = cosmetics[slot]
		if type(id) == "string" and Outfitting.cosmetic(slot, id) then
			design.cosmetics[slot] = id
		else
			design.cosmetics[slot] = Outfitting.CosmeticDefaults[slot]
		end
	end

	return design
end

-- Mass factor of a hull's stock fit, the baseline handling is measured from.
local stockMassCache = {}
local function stockMass(hull)
	if stockMassCache[hull] then
		return stockMassCache[hull]
	end
	local design = Outfitting.stockDesign(hull)
	local mass = 1
	if design.shield then
		mass += Outfitting.Shields[design.shield.id].mass
	end
	for _, fit in design.engines do
		if fit then
			mass += Outfitting.Engines[fit.id].mass
		end
	end
	for _, id in design.modules do
		if id then
			mass += Outfitting.Modules[id].mass
		end
	end
	stockMassCache[hull] = mass
	return mass
end

--[[
	Everything the shipyard shows and the server spawns from, worked out from a
	clean design. Combat numbers use the formulas in weapons-and-damage.md.
]]
function Outfitting.stats(design)
	local hull = design.hull
	local def = Outfitting.Hulls[hull]
	local base = Config.Hulls[hull]
	local hullSize = if base then base.size else def.shieldSize

	local stats = {
		hull = hull,
		size = hullSize,
		reactorMax = def.reactor,
		reactorUsed = 0,
		mass = 1,
		engineOutput = 0,
		energyDraw = 0,
		plasmaRate = 1,
		thrust = 0,
		accelFactor = 0,
		shieldHP = 0,
		hullHP = if base then base.hullHP else 0,
		armorPlates = 0,
		armorReduction = 0,
		magazineCells = 0,
		magazineCellsNeeded = 0,
		weaponCount = 0,
		dpsEnergy = 0,
		dpsKinetic = 0,
		emptyEngines = 0,
	}

	for _, fit in design.weapons do
		if fit then
			local weapon = Config.Weapons[fit.id]
			local slotScale = (Config.Slots[fit.mount] and Config.Slots[fit.mount].damageScale) or 1
			local dps = (weapon.dps or 0) * (Config.TierMultiplier[fit.tier] or 1) * slotScale
			stats.weaponCount += 1
			stats.reactorUsed += Outfitting.weaponReactor(fit.id)
			stats.magazineCellsNeeded += Outfitting.magazineCells(fit.id)
			if weapon.class == "Energy" then
				stats.energyDraw += (weapon.powerDraw or 0) * Outfitting.TierScale.energyDraw[fit.tier]
				stats.dpsEnergy += dps
			else
				stats.dpsKinetic += dps
			end
		end
	end
	if design.missile then
		stats.reactorUsed += Outfitting.weaponReactor(design.missile.id)
	end

	if design.shield then
		local shield = Outfitting.Shields[design.shield.id]
		stats.shieldHP = math.floor((shield.pool[hullSize] or 0) * Outfitting.TierScale.shield[design.shield.tier])
		stats.reactorUsed += shield.reactor * (SIZE_REACTOR[hullSize] or 1)
		stats.mass += shield.mass
	end

	local thrustSum = 0
	for _, fit in design.engines do
		if fit then
			local engine = Outfitting.Engines[fit.id]
			local tierScale = Outfitting.TierScale.engine[fit.tier]
			local setting = fit.thrust / 100
			thrustSum += engine.thrust * tierScale * setting
			stats.accelFactor += engine.accel
			stats.engineOutput += (Outfitting.EngineBaseOutput[hullSize] or 100) * engine.output * tierScale
			local over = math.max(0, fit.thrust - 100) * Outfitting.Thrust.reactorPerPercentOver
			local under = math.max(0, 100 - fit.thrust) / 100
			stats.reactorUsed += engine.reactor * (SIZE_REACTOR[hullSize] or 1) * (1 + over - under * 0.5)
			stats.mass += engine.mass
		else
			stats.emptyEngines += 1
		end
	end
	-- Thrust and accel relative to a full set of stock Standard engines at 100%.
	stats.thrust = thrustSum / def.engineMounts
	stats.accelFactor = if thrustSum > 0 then stats.accelFactor / (def.engineMounts - stats.emptyEngines) else 0

	for _, id in design.modules do
		if id then
			local module = Outfitting.Modules[id]
			stats.reactorUsed += module.reactor
			stats.mass += module.mass
			if id == "ArmorPlate" then
				stats.armorPlates += 1
			elseif id == "Magazine" then
				stats.magazineCells += 1
			end
		end
	end

	local defense = Config.Defense
	stats.hullHP += stats.armorPlates * (defense.armorHPPerPlate[hullSize] or defense.armorHPPerPlate.Large)
	stats.armorReduction = math.min(defense.armorReductionCap, stats.armorPlates * defense.armorReductionPerPlate)
	stats.plasmaRate = if stats.energyDraw > 0 then math.min(1, stats.engineOutput / stats.energyDraw) else 1
	stats.reactorUsed = math.floor(stats.reactorUsed * 10 + 0.5) / 10

	-- Handling from thrust over mass, relative to the stock fit so a stock
	-- ship flies exactly as the hull table in ship-types.md says.
	local h = Outfitting.Handling
	stats.massRatio = stats.mass / stockMass(hull)
	local ratio = stats.thrust / stats.massRatio
	local speedScale = if ratio > 0 then math.clamp(ratio ^ h.speedExponent, h.minScale, h.maxScale) else 0
	local accelScale = if ratio > 0 then math.clamp(ratio * stats.accelFactor, h.minScale, h.maxScale) else 0
	local turnScale = math.clamp(1 / stats.massRatio ^ h.turnExponent, h.minScale, h.maxScale)
	stats.speedScale = speedScale
	if base then
		stats.topSpeed = math.floor(base.topSpeed * speedScale + 0.5)
		stats.strafeSpeed = math.floor(base.strafeSpeed * speedScale + 0.5)
		stats.accel = math.floor(base.accel * accelScale + 0.5)
		stats.turnRate = math.floor(base.turnRate * turnScale * 10 + 0.5) / 10
		stats.rollRate = math.floor(base.rollRate * turnScale * 10 + 0.5) / 10
	end

	-- Plasma guns fire slower when output can't keep up.
	stats.dpsEnergy *= stats.plasmaRate
	stats.dps = math.floor((stats.dpsEnergy + stats.dpsKinetic) * 10 + 0.5) / 10
	return stats
end

-- Problems that stop a design from launching. Returns a list of short,
-- player-facing messages; empty means it can fly.
function Outfitting.problems(design, stats)
	stats = stats or Outfitting.stats(design)
	local list = {}
	if not Outfitting.hullAvailable(design.hull) then
		table.insert(list, "This hull isn't built yet")
	end
	if stats.reactorUsed > stats.reactorMax then
		table.insert(list, string.format("Reactor overloaded (%g / %g)", stats.reactorUsed, stats.reactorMax))
	end
	if stats.magazineCells < stats.magazineCellsNeeded then
		table.insert(
			list,
			string.format(
				"Kinetic guns need %d magazine cell%s (fitted %d)",
				stats.magazineCellsNeeded,
				if stats.magazineCellsNeeded == 1 then "" else "s",
				stats.magazineCells
			)
		)
	end
	if stats.emptyEngines == #design.engines then
		table.insert(list, "Fit at least one engine")
	end
	return list
end

-- Inventory items a design uses, as { [key] = count }.
function Outfitting.itemsUsed(design)
	local base = Config.Hulls[design.hull]
	local hullSize = if base then base.size else Outfitting.Hulls[design.hull].shieldSize
	local used = {}
	local function add(id, tier)
		local key = Outfitting.key(id, Outfitting.itemSize(id, hullSize), tier)
		used[key] = (used[key] or 0) + 1
	end
	for _, fit in design.weapons do
		if fit then
			add(fit.id, fit.tier)
		end
	end
	if design.missile then
		add(design.missile.id, design.missile.tier)
	end
	if design.shield then
		add(design.shield.id, design.shield.tier)
	end
	for _, fit in design.engines do
		if fit then
			add(fit.id, fit.tier)
		end
	end
	for _, id in design.modules do
		if id then
			add(id, 1)
		end
	end
	return used
end

-- Items the design needs that the inventory doesn't hold, and the Credits to
-- buy them all: missing = { [key] = count }, cost = number.
function Outfitting.missingItems(design, inventory)
	local missing, cost = {}, 0
	for key, count in Outfitting.itemsUsed(design) do
		local short = count - (inventory[key] or 0)
		if short > 0 then
			missing[key] = short
			local id, size, tier = Outfitting.parseKey(key)
			cost += (Outfitting.price(id, size, tier) or 0) * short
		end
	end
	return missing, cost
end

-- Cosmetics the design uses that the player hasn't unlocked.
function Outfitting.missingCosmetics(design, owned)
	local missing, cost = {}, 0
	for _, slot in Outfitting.CosmeticSlots do
		local id = design.cosmetics[slot]
		local entry = Outfitting.cosmetic(slot, id)
		local key = Outfitting.cosmeticKey(slot, id)
		if entry and entry.price > 0 and not owned[key] and not missing[key] then
			missing[key] = true
			cost += entry.price
		end
	end
	return missing, cost
end

--[[
	Turns a clean design into the loadout table Ships.spawn takes. Guns carry
	their mount index so empty slots keep the rest on the right mounts.
]]
function Outfitting.toSpawnLoadout(design, displayName: string?)
	local stats = Outfitting.stats(design)
	local base = Config.Hulls[design.hull]

	local guns, magazineFor = {}, {}
	for mount, fit in design.weapons do
		if fit then
			local weapon = Config.Weapons[fit.id]
			table.insert(guns, { weapon = fit.id, slot = fit.mount, tier = fit.tier, mount = mount })
			for _ = 1, Outfitting.magazineCells(fit.id) do
				table.insert(magazineFor, #guns)
			end
			local _ = weapon
		end
	end

	local engines = {}
	for _, fit in design.engines do
		if fit then
			local engine = Outfitting.Engines[fit.id]
			table.insert(engines, {
				name = fit.id,
				output = (Outfitting.EngineBaseOutput[base.size] or 100)
					* engine.output
					* Outfitting.TierScale.engine[fit.tier],
			})
		end
	end

	local cosmetics = {}
	for _, slot in Outfitting.CosmeticSlots do
		cosmetics[slot] = design.cosmetics[slot]
	end

	return {
		hull = design.hull,
		displayName = displayName or design.name,
		designName = design.name,
		guns = guns,
		missile = if design.missile then { weapon = design.missile.id, tier = design.missile.tier } else nil,
		shieldHP = stats.shieldHP,
		engines = engines,
		armorPlates = stats.armorPlates,
		magazineFor = magazineFor,
		color = Outfitting.cosmeticColor("paint", cosmetics.paint),
		cosmetics = cosmetics,
		stats = {
			topSpeed = stats.topSpeed,
			strafeSpeed = stats.strafeSpeed,
			accel = stats.accel,
			turnRate = stats.turnRate,
			rollRate = stats.rollRate,
		},
	}
end

return Outfitting
