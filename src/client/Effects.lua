--[[
	Draws what the server says happened: tracers for every shot, shield
	ripples, sparks on hull hits, the shield shatter when a generator goes
	down, and explosions. Nothing here affects damage.

	Energy is cyan and magenta, Kinetic is yellow, as in weapons-and-damage.md.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Effects = {}

local ENERGY = Color3.fromRGB(80, 230, 255)
local ENERGY_ALT = Color3.fromRGB(255, 90, 220)
local KINETIC = Color3.fromRGB(255, 220, 80)
local SHIELD = Color3.fromRGB(90, 200, 255)

local folder = Instance.new("Folder")
folder.Name = "Effects"
folder.Parent = workspace

local random = Random.new()
local shipEventListeners = {}

local function effectPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for key, value in props do
		p[key] = value
	end
	p.Parent = folder
	return p
end

local function fade(p, duration, goal)
	goal = goal or {}
	goal.Transparency = 1
	TweenService:Create(p, TweenInfo.new(duration), goal):Play()
	Debris:AddItem(p, duration)
end

local function radiusOf(model)
	local hull = Config.Hulls[model:GetAttribute("Hull")]
	return if hull then hull.radius else 6
end

local function tracer(from, to, class, gunIndex)
	local length = (to - from).Magnitude
	if length < 0.1 then
		return
	end
	local color = if class == "Energy" then (if gunIndex % 2 == 0 then ENERGY_ALT else ENERGY) else KINETIC
	local thickness = if class == "Energy" then 0.5 else 0.25
	local p = effectPart({
		Size = Vector3.new(thickness, thickness, length),
		CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2),
		Color = color,
		Transparency = 0.1,
	})
	fade(p, if class == "Energy" then 0.12 else 0.07)
end

local function shieldRipple(model, class)
	local root = model.PrimaryPart
	local size = radiusOf(model) * 2.6
	local p = effectPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		CFrame = root.CFrame,
		Color = SHIELD,
		Material = Enum.Material.ForceField,
		-- Kinetic only leaves a small ripple as it passes through.
		Transparency = if class == "Energy" then 0.2 else 0.6,
	})
	fade(p, 0.25)
end

local function spark(position, color)
	local p = effectPart({
		Size = Vector3.one * 1.2,
		CFrame = CFrame.new(position),
		Color = color,
	})
	fade(p, 0.15, { Size = Vector3.one * 3 })
end

local function onShot(shot)
	local shooter, gunIndex, target = shot.shooter, shot.gun, shot.target
	local hit, class, shield = shot.hit, shot.class, shot.shield
	if not (shooter and target and shooter.PrimaryPart and target.PrimaryPart) then
		return
	end
	local mount = shooter.PrimaryPart:FindFirstChild("Gun" .. gunIndex)
	local from = if mount then mount.WorldPosition else shooter.PrimaryPart.Position
	local radius = radiusOf(target)
	local center = target.PrimaryPart.Position

	local to
	if hit then
		to = center + random:NextUnitVector() * radius * (if shield then 1.3 else 0.5)
	else
		-- Misses fly past the target.
		local past = (center - from).Unit * radius * 4
		to = center + past + random:NextUnitVector() * radius * 2.5
	end
	tracer(from, to, class, gunIndex)

	if hit and shield then
		shieldRipple(target, class)
	end
	-- Energy stopped by a shield leaves no spark; Kinetic always reaches the hull.
	local color = if class == "Energy" then ENERGY else KINETIC
	if hit and (not shield or class == "Kinetic") then
		spark(to, color)
	end
end

local function shieldShatter(model)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local radius = radiusOf(model) * 1.3
	for _ = 1, 8 do
		local direction = random:NextUnitVector()
		local p = effectPart({
			Size = Vector3.new(radius * 0.6, radius * 0.6, 0.3),
			CFrame = CFrame.lookAt(root.Position + direction * radius, root.Position + direction * radius * 2),
			Color = SHIELD,
			Transparency = 0.2,
		})
		fade(p, 0.6, { CFrame = p.CFrame * CFrame.new(0, 0, -radius * 2) })
	end
end

local function explosion(position, radius)
	local boom = Instance.new("Explosion")
	boom.Position = position
	boom.BlastRadius = radius * 2
	boom.BlastPressure = 0
	boom.DestroyJointRadiusPercent = 0
	boom.ExplosionType = Enum.ExplosionType.NoCraters
	boom.Parent = folder

	for _ = 1, 10 do
		local direction = random:NextUnitVector()
		local p = effectPart({
			Size = Vector3.one * random:NextNumber(0.8, 2),
			CFrame = CFrame.new(position),
			Color = if random:NextNumber() < 0.5 then Color3.fromRGB(255, 140, 40) else Color3.fromRGB(70, 70, 80),
		})
		fade(p, 1, { CFrame = CFrame.new(position + direction * radius * 4) })
	end
end

function Effects.onShipEvent(callback)
	table.insert(shipEventListeners, callback)
end

function Effects.start()
	Remotes.CombatEffects.OnClientEvent:Connect(function(shots)
		for _, shot in shots do
			onShot(shot)
		end
	end)

	Remotes.ShipEvent.OnClientEvent:Connect(function(kind, ...)
		if kind == "ShieldDown" then
			local model = ...
			if model then
				shieldShatter(model)
			end
		elseif kind == "Knockout" then
			local model = ...
			if model and model.PrimaryPart then
				spark(model.PrimaryPart.Position, Color3.fromRGB(255, 140, 40))
			end
		elseif kind == "Destroyed" then
			local position, radius = ...
			explosion(position, radius)
		end
		for _, callback in shipEventListeners do
			callback(kind, ...)
		end
	end)
end

return Effects
