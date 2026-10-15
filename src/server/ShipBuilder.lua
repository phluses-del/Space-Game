--[[
	Builds low-poly ship models out of plain parts, so the prototype needs no
	uploaded meshes. Every ship is one assembly: a "Hull" root part with the
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
-- mounts lists weapon mount positions in loadout order.
local LAYOUTS = {
	Fighter = {
		rootSize = Vector3.new(4, 2, 10),
		pieces = {
			{ "WedgePart", Vector3.new(4, 2, 4), CFrame.new(0, 0, -7), "hull" }, -- nose
			{ "WedgePart", Vector3.new(1, 6, 7), CFrame.new(-5, 0, 1) * CFrame.Angles(0, 0, math.rad(90)), "trim" }, -- left wing
			{ "WedgePart", Vector3.new(1, 6, 7), CFrame.new(5, 0, 1) * CFrame.Angles(0, 0, math.rad(-90)), "trim" }, -- right wing
			{ "Part", Vector3.new(2, 1, 3), CFrame.new(0, 1.5, -2), "glass" }, -- canopy
			{ "Part", Vector3.new(1.6, 1.6, 2), CFrame.new(-1.2, 0, 5.5), "engine" },
			{ "Part", Vector3.new(1.6, 1.6, 2), CFrame.new(1.2, 0, 5.5), "engine" },
			{ "Part", Vector3.new(1.2, 1.2, 0.4), CFrame.new(-1.2, 0, 6.6), "glow" },
			{ "Part", Vector3.new(1.2, 1.2, 0.4), CFrame.new(1.2, 0, 6.6), "glow" },
			{ "Part", Vector3.new(0.5, 3, 3), CFrame.new(0, 2, 3.5), "trim" }, -- tail fin
		},
		mounts = {
			Vector3.new(-6.5, 0, -1),
			Vector3.new(6.5, 0, -1),
			Vector3.new(-3.5, -0.5, -3),
			Vector3.new(3.5, -0.5, -3),
		},
	},
	Scout = {
		rootSize = Vector3.new(3, 1.6, 8),
		pieces = {
			{ "WedgePart", Vector3.new(3, 1.6, 4), CFrame.new(0, 0, -6), "hull" },
			{ "WedgePart", Vector3.new(0.6, 4, 4), CFrame.new(-3.5, 0, 1.5) * CFrame.Angles(0, 0, math.rad(90)), "trim" },
			{ "WedgePart", Vector3.new(0.6, 4, 4), CFrame.new(3.5, 0, 1.5) * CFrame.Angles(0, 0, math.rad(-90)), "trim" },
			{ "Part", Vector3.new(1.6, 0.8, 2.4), CFrame.new(0, 1.2, -1.5), "glass" },
			{ "Part", Vector3.new(1.2, 1.2, 1.6), CFrame.new(-0.9, 0, 4.5), "engine" },
			{ "Part", Vector3.new(1.2, 1.2, 1.6), CFrame.new(0.9, 0, 4.5), "engine" },
			{ "Part", Vector3.new(0.9, 0.9, 0.3), CFrame.new(-0.9, 0, 5.4), "glow" },
			{ "Part", Vector3.new(0.9, 0.9, 0.3), CFrame.new(0.9, 0, 5.4), "glow" },
		},
		mounts = {
			Vector3.new(-2, -0.4, -3),
			Vector3.new(2, -0.4, -3),
		},
	},
}

local GLASS = Color3.fromRGB(120, 200, 255)
local TRIM = Color3.fromRGB(60, 64, 76)
local ENGINE = Color3.fromRGB(40, 42, 50)
local GLOW = Color3.fromRGB(255, 150, 60)

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

	for _, piece in layout.pieces do
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

	for i, position in layout.mounts do
		local mount = Instance.new("Attachment")
		mount.Name = "Gun" .. i
		mount.Position = position
		mount.Parent = root
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

return ShipBuilder
