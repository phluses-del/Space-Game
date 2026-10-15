--[[
	Builds the test star system: an asteroid field to fly through and break
	line of sight with, a spawn platform, and a planet and sun in the distance
	for orientation. Everything is plain low-poly parts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local TestSystem = {}

local ROCK_COLORS = {
	Color3.fromRGB(105, 98, 92),
	Color3.fromRGB(86, 82, 80),
	Color3.fromRGB(122, 108, 90),
	Color3.fromRGB(70, 68, 72),
}

local function anchoredPart(props)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	return p
end

local function makeAsteroid(random, position, size, parent)
	local model = Instance.new("Model")
	model.Name = "Asteroid"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local color = ROCK_COLORS[random:NextInteger(1, #ROCK_COLORS)]

	-- A few overlapping rotated blocks read as a faceted low-poly rock.
	for i = 1, random:NextInteger(2, 4) do
		local scale = if i == 1 then 1 else random:NextNumber(0.5, 0.85)
		local offset = if i == 1 then Vector3.zero else random:NextUnitVector() * size * 0.3
		anchoredPart({
			Name = "Rock",
			Size = Vector3.new(size, size * random:NextNumber(0.6, 1), size * random:NextNumber(0.7, 1)) * scale,
			CFrame = CFrame.new(position + offset)
				* CFrame.Angles(random:NextNumber(0, 6.28), random:NextNumber(0, 6.28), random:NextNumber(0, 6.28)),
			Color = color,
			Material = Enum.Material.Slate,
			Parent = model,
		})
	end
	model.Parent = parent
end

local function clearOfSpawns(position, spacing)
	if (position - Config.TestSystem.playerSpawn).Magnitude < spacing then
		return false
	end
	for _, drone in Config.TestSystem.drones do
		if (position - drone.position).Magnitude < spacing then
			return false
		end
	end
	return true
end

function TestSystem.build()
	-- A fresh Baseplate place comes with a floor and spawn we don't want in space.
	for _, name in { "Baseplate", "SpawnLocation" } do
		local existing = workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end

	local settings = Config.TestSystem
	local random = Random.new(settings.seed)

	local world = Instance.new("Folder")
	world.Name = "TestSystem"
	world.Parent = workspace

	local asteroids = Instance.new("Folder")
	asteroids.Name = "Asteroids"
	asteroids.Parent = world

	local placed = 0
	while placed < settings.asteroidCount do
		local position = random:NextUnitVector() * random:NextNumber(150, settings.asteroidFieldRadius)
		position = Vector3.new(position.X, position.Y * 0.35, position.Z) -- flatten the field into a disc
		if clearOfSpawns(position, 140) then
			local size = random:NextNumber(settings.asteroidSize[1], settings.asteroidSize[2])
			makeAsteroid(random, position, size, asteroids)
			placed += 1
		end
	end

	-- Spawn platform: a ring the player's ship starts inside.
	local spawn = settings.playerSpawn
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		anchoredPart({
			Name = "SpawnRing",
			Size = Vector3.new(4, 4, 22),
			CFrame = CFrame.new(spawn) * CFrame.Angles(0, 0, angle) * CFrame.new(0, 40, 0) * CFrame.Angles(0, math.rad(90), 0),
			Color = Color3.fromRGB(60, 200, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			Parent = world,
		})
	end

	anchoredPart({
		Name = "Planet",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1800, 1800, 1800),
		CFrame = CFrame.new(1500, -900, -5200),
		Color = Color3.fromRGB(70, 120, 170),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		Parent = world,
	})
	anchoredPart({
		Name = "Sun",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(600, 600, 600),
		CFrame = CFrame.new(-4500, 1800, -3000),
		Color = Color3.fromRGB(255, 220, 150),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		Parent = world,
	})
end

return TestSystem
