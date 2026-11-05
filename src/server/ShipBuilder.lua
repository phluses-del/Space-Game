--[[
	Builds low-poly ship models out of plain parts for all six hulls, so the
	prototype needs no uploaded meshes. Every ship is one assembly: a "Hull" root part with the
	other parts welded to it, plus attachments for the flight constraints and
	each weapon mount.
]]

local ShipBuilder = {}

local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	return p
end

-- Hull layouts. Offsets are relative to the root part's centre; -Z is forward.
-- pieces: { className, size, offset, colour kind }.
-- mounts: weapon mounts in loadout order. kind is "Small" or "Medium" for
-- forward guns (fixed or gimbal) and "Turret" for turrets, which also have a
-- facing (the direction the turret dome points; its arc is measured from it).
-- missileRack: where missiles launch from, for hulls that have one.
-- bays: hangar bay entrances (Carrier), for docking later.
local UP = Vector3.new(0, 1, 0)
local DOWN = Vector3.new(0, -1, 0)
local RIGHT = Vector3.new(1, 0, 0)
local LEFT = Vector3.new(-1, 0, 0)

local function rotZ(deg)
	return CFrame.Angles(0, 0, math.rad(deg))
end

local LAYOUTS = {
	Scout = {
		rootSize = Vector3.new(3, 1.6, 8),
		pieces = {
			{ "WedgePart", Vector3.new(3, 1.6, 4), CFrame.new(0, 0, -6), "hull" },
			{ "WedgePart", Vector3.new(0.6, 4, 4), CFrame.new(-3.5, 0, 1.5) * rotZ(90), "trim" },
			{ "WedgePart", Vector3.new(0.6, 4, 4), CFrame.new(3.5, 0, 1.5) * rotZ(-90), "trim" },
			{ "Part", Vector3.new(1.6, 0.8, 2.4), CFrame.new(0, 1.2, -1.5), "glass" },
			{ "Part", Vector3.new(1.2, 1.2, 1.6), CFrame.new(-0.9, 0, 4.5), "engine" },
			{ "Part", Vector3.new(1.2, 1.2, 1.6), CFrame.new(0.9, 0, 4.5), "engine" },
			{ "Part", Vector3.new(0.9, 0.9, 0.3), CFrame.new(-0.9, 0, 5.4), "glow" },
			{ "Part", Vector3.new(0.9, 0.9, 0.3), CFrame.new(0.9, 0, 5.4), "glow" },
			{ "Part", Vector3.new(0.3, 0.3, 3), CFrame.new(0, 1.1, -5), "trim" }, -- scanner antenna
		},
		mounts = {
			{ kind = "Small", position = Vector3.new(-2, -0.4, -3) },
			{ kind = "Small", position = Vector3.new(2, -0.4, -3) },
		},
	},

	Fighter = {
		rootSize = Vector3.new(4, 2, 10),
		pieces = {
			{ "WedgePart", Vector3.new(4, 2, 4), CFrame.new(0, 0, -7), "hull" }, -- nose
			{ "WedgePart", Vector3.new(1, 6, 7), CFrame.new(-5, 0, 1) * rotZ(90), "trim" }, -- left wing
			{ "WedgePart", Vector3.new(1, 6, 7), CFrame.new(5, 0, 1) * rotZ(-90), "trim" }, -- right wing
			{ "Part", Vector3.new(2, 1, 3), CFrame.new(0, 1.5, -2), "glass" }, -- canopy
			{ "Part", Vector3.new(1.6, 1.6, 2), CFrame.new(-1.2, 0, 5.5), "engine" },
			{ "Part", Vector3.new(1.6, 1.6, 2), CFrame.new(1.2, 0, 5.5), "engine" },
			{ "Part", Vector3.new(1.2, 1.2, 0.4), CFrame.new(-1.2, 0, 6.6), "glow" },
			{ "Part", Vector3.new(1.2, 1.2, 0.4), CFrame.new(1.2, 0, 6.6), "glow" },
			{ "Part", Vector3.new(0.5, 3, 3), CFrame.new(0, 2, 3.5), "trim" }, -- tail fin
			{ "Part", Vector3.new(1.4, 0.8, 4), CFrame.new(0, -1.4, -0.5), "trim" }, -- torpedo rack
		},
		mounts = {
			{ kind = "Small", position = Vector3.new(-6.5, 0, -1) },
			{ kind = "Small", position = Vector3.new(6.5, 0, -1) },
			{ kind = "Small", position = Vector3.new(-3.5, -0.5, -3) },
			{ kind = "Small", position = Vector3.new(3.5, -0.5, -3) },
		},
		missileRack = Vector3.new(0, -1.6, -3),
	},

	Hauler = {
		-- Boxy cargo body with a cab up front and two side pods.
		rootSize = Vector3.new(8, 5, 16),
		pieces = {
			{ "WedgePart", Vector3.new(8, 3, 5), CFrame.new(0, -1, -10.5), "hull" }, -- cab nose
			{ "Part", Vector3.new(6, 2, 3), CFrame.new(0, 1.5, -9), "glass" }, -- cab window
			{ "Part", Vector3.new(3, 4, 13), CFrame.new(-5.5, -0.5, 1), "trim" }, -- cargo pod
			{ "Part", Vector3.new(3, 4, 13), CFrame.new(5.5, -0.5, 1), "trim" },
			{ "Part", Vector3.new(2, 0.4, 13), CFrame.new(-5.5, 1.7, 1), "hull" }, -- pod stripes
			{ "Part", Vector3.new(2, 0.4, 13), CFrame.new(5.5, 1.7, 1), "hull" },
			{ "Part", Vector3.new(1.5, 1.5, 4), CFrame.new(-2.5, -3, -8), "trim" }, -- mining arms
			{ "Part", Vector3.new(1.5, 1.5, 4), CFrame.new(2.5, -3, -8), "trim" },
			{ "Part", Vector3.new(2.4, 2.4, 2.5), CFrame.new(-3, 0, 9), "engine" },
			{ "Part", Vector3.new(2.4, 2.4, 2.5), CFrame.new(0, 0.5, 9), "engine" },
			{ "Part", Vector3.new(2.4, 2.4, 2.5), CFrame.new(3, 0, 9), "engine" },
			{ "Part", Vector3.new(1.8, 1.8, 0.4), CFrame.new(-3, 0, 10.4), "glow" },
			{ "Part", Vector3.new(1.8, 1.8, 0.4), CFrame.new(0, 0.5, 10.4), "glow" },
			{ "Part", Vector3.new(1.8, 1.8, 0.4), CFrame.new(3, 0, 10.4), "glow" },
		},
		mounts = {
			{ kind = "Turret", position = Vector3.new(0, 2.9, 2), facing = UP },
		},
	},

	Frigate = {
		-- Long wedge warship: two gun sponsons, a bridge tower, turrets top and bottom.
		rootSize = Vector3.new(10, 5, 34),
		pieces = {
			{ "WedgePart", Vector3.new(10, 5, 9), CFrame.new(0, 0, -21.5), "hull" }, -- bow
			{ "Part", Vector3.new(4, 3, 22), CFrame.new(-7, -0.5, 0), "trim" }, -- sponsons
			{ "Part", Vector3.new(4, 3, 22), CFrame.new(7, -0.5, 0), "trim" },
			{ "WedgePart", Vector3.new(4, 3, 4), CFrame.new(-7, -0.5, -13), "trim" },
			{ "WedgePart", Vector3.new(4, 3, 4), CFrame.new(7, -0.5, -13), "trim" },
			{ "Part", Vector3.new(5, 4, 7), CFrame.new(0, 4.5, 8), "hull" }, -- bridge tower
			{ "Part", Vector3.new(4.4, 1.2, 0.4), CFrame.new(0, 5.4, 4.4), "glass" },
			{ "Part", Vector3.new(0.4, 4, 0.4), CFrame.new(0, 8.5, 9), "trim" }, -- mast
			{ "Part", Vector3.new(0.6, 6, 6), CFrame.new(0, 3, 14), "trim" }, -- tail fin
			{ "Part", Vector3.new(3, 3, 3), CFrame.new(-3.5, 1.5, 18), "engine" },
			{ "Part", Vector3.new(3, 3, 3), CFrame.new(3.5, 1.5, 18), "engine" },
			{ "Part", Vector3.new(3, 3, 3), CFrame.new(-3.5, -1.5, 18), "engine" },
			{ "Part", Vector3.new(3, 3, 3), CFrame.new(3.5, -1.5, 18), "engine" },
			{ "Part", Vector3.new(2.4, 2.4, 0.4), CFrame.new(-3.5, 1.5, 19.6), "glow" },
			{ "Part", Vector3.new(2.4, 2.4, 0.4), CFrame.new(3.5, 1.5, 19.6), "glow" },
			{ "Part", Vector3.new(2.4, 2.4, 0.4), CFrame.new(-3.5, -1.5, 19.6), "glow" },
			{ "Part", Vector3.new(2.4, 2.4, 0.4), CFrame.new(3.5, -1.5, 19.6), "glow" },
		},
		mounts = {
			{ kind = "Medium", position = Vector3.new(-7, -0.5, -15) },
			{ kind = "Medium", position = Vector3.new(7, -0.5, -15) },
			{ kind = "Turret", position = Vector3.new(0, 2.6, -12), facing = UP },
			{ kind = "Turret", position = Vector3.new(0, 2.6, -2), facing = UP },
			{ kind = "Turret", position = Vector3.new(0, -2.6, -8), facing = DOWN },
			{ kind = "Turret", position = Vector3.new(0, -2.6, 6), facing = DOWN },
		},
	},

	Industrial = {
		-- Chunky bulk miner: ore containers on the flanks, mining prongs up
		-- front and a refinery stack on top.
		rootSize = Vector3.new(14, 8, 30),
		pieces = {
			{ "Part", Vector3.new(6, 4, 4), CFrame.new(0, 2, -17), "hull" }, -- cockpit block
			{ "Part", Vector3.new(5, 1.6, 0.4), CFrame.new(0, 2.6, -19.1), "glass" },
			{ "Part", Vector3.new(2, 2, 10), CFrame.new(-5, -2.5, -20), "trim" }, -- mining prongs
			{ "Part", Vector3.new(2, 2, 10), CFrame.new(5, -2.5, -20), "trim" },
			{ "Part", Vector3.new(1.4, 1.4, 1.4), CFrame.new(-5, -2.5, -25.5), "glow" }, -- laser emitters
			{ "Part", Vector3.new(1.4, 1.4, 1.4), CFrame.new(5, -2.5, -25.5), "glow" },
			{ "Part", Vector3.new(4, 6, 22), CFrame.new(-9, 0, 0), "trim" }, -- ore containers
			{ "Part", Vector3.new(4, 6, 22), CFrame.new(9, 0, 0), "trim" },
			{ "Part", Vector3.new(4.2, 1, 22.2), CFrame.new(-9, 1, 0), "hull" },
			{ "Part", Vector3.new(4.2, 1, 22.2), CFrame.new(9, 1, 0), "hull" },
			{ "Part", Vector3.new(5, 6, 5), CFrame.new(0, 7, 6), "trim" }, -- refinery stack
			{ "Part", Vector3.new(3, 1, 3), CFrame.new(0, 10.5, 6), "glow" },
			{ "Part", Vector3.new(3.5, 3.5, 3), CFrame.new(-4, 2, 16.5), "engine" },
			{ "Part", Vector3.new(3.5, 3.5, 3), CFrame.new(4, 2, 16.5), "engine" },
			{ "Part", Vector3.new(3.5, 3.5, 3), CFrame.new(-4, -2, 16.5), "engine" },
			{ "Part", Vector3.new(3.5, 3.5, 3), CFrame.new(4, -2, 16.5), "engine" },
			{ "Part", Vector3.new(2.8, 2.8, 0.4), CFrame.new(-4, 2, 18.2), "glow" },
			{ "Part", Vector3.new(2.8, 2.8, 0.4), CFrame.new(4, 2, 18.2), "glow" },
			{ "Part", Vector3.new(2.8, 2.8, 0.4), CFrame.new(-4, -2, 18.2), "glow" },
			{ "Part", Vector3.new(2.8, 2.8, 0.4), CFrame.new(4, -2, 18.2), "glow" },
		},
		mounts = {
			{ kind = "Turret", position = Vector3.new(0, 4.1, -6), facing = UP },
			{ kind = "Turret", position = Vector3.new(0, -4.1, 4), facing = DOWN },
		},
	},

	Carrier = {
		-- Capital hull with a flat flight deck, a command island on the
		-- starboard side and four hangar bays along the flanks.
		rootSize = Vector3.new(24, 10, 80),
		pieces = {
			{ "WedgePart", Vector3.new(24, 10, 14), CFrame.new(0, 0, -47), "hull" }, -- bow
			{ "Part", Vector3.new(30, 1, 92), CFrame.new(0, 5.5, -4), "trim" }, -- flight deck
			{ "Part", Vector3.new(0.6, 0.2, 80), CFrame.new(0, 6.1, -4), "glow" }, -- deck centre line
			{ "Part", Vector3.new(6, 9, 14), CFrame.new(12, 10.5, 12), "hull" }, -- command island
			{ "Part", Vector3.new(6.2, 1.6, 10), CFrame.new(12, 13, 12), "glass" },
			{ "Part", Vector3.new(0.6, 8, 0.6), CFrame.new(12, 19, 14), "trim" }, -- mast
			{ "Part", Vector3.new(28, 4, 60), CFrame.new(0, -6, 0), "trim" }, -- keel
			-- Hangar bay doors (two per side)
			{ "Part", Vector3.new(0.4, 6, 12), CFrame.new(-12.1, 0, -16), "bay" },
			{ "Part", Vector3.new(0.4, 6, 12), CFrame.new(-12.1, 0, 10), "bay" },
			{ "Part", Vector3.new(0.4, 6, 12), CFrame.new(12.1, 0, -16), "bay" },
			{ "Part", Vector3.new(0.4, 6, 12), CFrame.new(12.1, 0, 10), "bay" },
			{ "Part", Vector3.new(0.5, 0.5, 12), CFrame.new(-12.2, 3.2, -16), "glow" },
			{ "Part", Vector3.new(0.5, 0.5, 12), CFrame.new(-12.2, 3.2, 10), "glow" },
			{ "Part", Vector3.new(0.5, 0.5, 12), CFrame.new(12.2, 3.2, -16), "glow" },
			{ "Part", Vector3.new(0.5, 0.5, 12), CFrame.new(12.2, 3.2, 10), "glow" },
			-- Six engines in two rows of three
			{ "Part", Vector3.new(5, 5, 4), CFrame.new(-7, 2.5, 42), "engine" },
			{ "Part", Vector3.new(5, 5, 4), CFrame.new(0, 2.5, 42), "engine" },
			{ "Part", Vector3.new(5, 5, 4), CFrame.new(7, 2.5, 42), "engine" },
			{ "Part", Vector3.new(5, 5, 4), CFrame.new(-7, -2.5, 42), "engine" },
			{ "Part", Vector3.new(5, 5, 4), CFrame.new(0, -2.5, 42), "engine" },
			{ "Part", Vector3.new(5, 5, 4), CFrame.new(7, -2.5, 42), "engine" },
			{ "Part", Vector3.new(4, 4, 0.4), CFrame.new(-7, 2.5, 44.2), "glow" },
			{ "Part", Vector3.new(4, 4, 0.4), CFrame.new(0, 2.5, 44.2), "glow" },
			{ "Part", Vector3.new(4, 4, 0.4), CFrame.new(7, 2.5, 44.2), "glow" },
			{ "Part", Vector3.new(4, 4, 0.4), CFrame.new(-7, -2.5, 44.2), "glow" },
			{ "Part", Vector3.new(4, 4, 0.4), CFrame.new(0, -2.5, 44.2), "glow" },
			{ "Part", Vector3.new(4, 4, 0.4), CFrame.new(7, -2.5, 44.2), "glow" },
		},
		mounts = {
			{ kind = "Turret", position = Vector3.new(-11, 6.4, -30), facing = UP },
			{ kind = "Turret", position = Vector3.new(-11, 6.4, 25), facing = UP },
			{ kind = "Turret", position = Vector3.new(0, 6.4, -42), facing = UP },
			{ kind = "Turret", position = Vector3.new(0, -8.4, -20), facing = DOWN },
			{ kind = "Turret", position = Vector3.new(-14.6, 0, 26), facing = LEFT },
			{ kind = "Turret", position = Vector3.new(14.6, 0, 26), facing = RIGHT },
		},
		bays = {
			Vector3.new(-12.5, 0, -16),
			Vector3.new(-12.5, 0, 10),
			Vector3.new(12.5, 0, -16),
			Vector3.new(12.5, 0, 10),
		},
	},
}

local GLASS = Color3.fromRGB(120, 200, 255)
local TRIM = Color3.fromRGB(60, 64, 76)
local ENGINE = Color3.fromRGB(40, 42, 50)
local GLOW = Color3.fromRGB(255, 150, 60)
local BAY = Color3.fromRGB(20, 22, 28)
local GUN = Color3.fromRGB(45, 48, 58)

-- Rotation whose up vector is the turret's facing and whose forward stays as
-- close to the ship's nose as it can.
local function turretFrame(position, facing)
	local right = facing:Cross(Vector3.zAxis)
	if right.Magnitude < 1e-3 then
		right = Vector3.xAxis
	end
	return CFrame.fromMatrix(position, right.Unit, facing.Unit)
end

-- Gun barrels and turret domes, so every mount reads as a weapon at a glance.
local function mountPieces(mount)
	local p = mount.position
	if mount.kind == "Small" then
		return {
			{ "Part", Vector3.new(0.4, 0.4, 2.4), CFrame.new(p + Vector3.new(0, 0, -0.6)), "gun" },
		}
	elseif mount.kind == "Medium" then
		return {
			{ "Part", Vector3.new(2, 2, 3), CFrame.new(p + Vector3.new(0, 0, 1)), "gun" },
			{ "Part", Vector3.new(0.9, 0.9, 6), CFrame.new(p + Vector3.new(0, 0, -2.5)), "gun" },
		}
	else
		local frame = turretFrame(p, mount.facing or UP)
		return {
			{ "Part", Vector3.new(2.6, 0.8, 2.6), frame, "gun" },
			{ "Part", Vector3.new(1.6, 0.9, 1.8), frame * CFrame.new(0, 0.8, 0), "trim" },
			{ "Part", Vector3.new(0.35, 0.35, 2.6), frame * CFrame.new(-0.4, 0.9, -1.8), "gun" },
			{ "Part", Vector3.new(0.35, 0.35, 2.6), frame * CFrame.new(0.4, 0.9, -1.8), "gun" },
		}
	end
end

function ShipBuilder.build(hullName: string, color: Color3, name: string): Model
	local layout = LAYOUTS[hullName]
	assert(layout, "No ship layout for hull " .. tostring(hullName))

	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local root = part({
		Name = "Hull",
		Size = layout.rootSize,
		Color = color,
		Massless = false,
		CanCollide = true,
		CanQuery = true,
	})
	root.Parent = model
	model.PrimaryPart = root

	local pieces = table.clone(layout.pieces)
	for _, mount in layout.mounts do
		for _, piece in mountPieces(mount) do
			table.insert(pieces, piece)
		end
	end

	for _, piece in pieces do
		local className, size, offset, kind = piece[1], piece[2], piece[3], piece[4]
		local p = part({ ClassName = className, Size = size, CFrame = offset })
		if kind == "hull" then
			p.Color = color
		elseif kind == "trim" then
			p.Color = TRIM
		elseif kind == "glass" then
			p.Color = GLASS
			p.Material = Enum.Material.Glass
			p.Transparency = 0.2
		elseif kind == "engine" then
			p.Color = ENGINE
		elseif kind == "glow" then
			p.Color = GLOW
			p.Material = Enum.Material.Neon
		elseif kind == "gun" then
			p.Color = GUN
			p.Material = Enum.Material.Metal
		elseif kind == "bay" then
			p.Color = BAY
		end
		p.CanQuery = true
		p.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end

	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = root

	for i, mount in layout.mounts do
		local attachment = Instance.new("Attachment")
		attachment.Name = "Gun" .. i
		attachment.Position = mount.position
		if mount.kind == "Turret" then
			-- Raise the muzzle above the dome so tracers start at the barrels.
			attachment.Position += (mount.facing or UP) * 1.2
		end
		attachment:SetAttribute("Kind", mount.kind)
		attachment.Parent = root
	end

	if layout.missileRack then
		local rack = Instance.new("Attachment")
		rack.Name = "MissileRack"
		rack.Position = layout.missileRack
		rack.Parent = root
	end

	for i, position in layout.bays or {} do
		local bay = Instance.new("Attachment")
		bay.Name = "Bay" .. i
		bay.Position = position
		bay.Parent = root
	end

	local linear = Instance.new("LinearVelocity")
	linear.Name = "Thrust"
	linear.Attachment0 = center
	linear.RelativeTo = Enum.ActuatorRelativeTo.World
	linear.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linear.MaxForce = math.huge
	linear.VectorVelocity = Vector3.zero
	linear.Parent = root

	local angular = Instance.new("AngularVelocity")
	angular.Name = "Turn"
	angular.Attachment0 = center
	angular.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	angular.MaxTorque = math.huge
	angular.AngularVelocity = Vector3.zero
	angular.Parent = root

	return model
end

function ShipBuilder.mountCount(hullName: string): number
	return #LAYOUTS[hullName].mounts
end

-- Weapon mounts for a hull in loadout order: { kind, position, facing? }.
-- kind is "Small", "Medium" or "Turret". Read-only; don't edit the result.
function ShipBuilder.mounts(hullName: string)
	local layout = LAYOUTS[hullName]
	return if layout then layout.mounts else {}
end

function ShipBuilder.hasMissileRack(hullName: string): boolean
	local layout = LAYOUTS[hullName]
	return layout ~= nil and layout.missileRack ~= nil
end

function ShipBuilder.canBuild(hullName: string): boolean
	return LAYOUTS[hullName] ~= nil
end

return ShipBuilder
