--[[
	Chase camera that sits behind and above the pilot's ship and rolls with
	it, smoothed so fast turns don't jerk the view.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Flight = require(script.Parent.Flight)

local ChaseCamera = {}

local DISTANCES = { Near = 0.75, Normal = 1, Far = 1.4 } -- camera distance setting
local BOOST_FOV_EXTRA = 15
local distanceScale = 1

-- Tuned for the Fighter (radius 7); bigger hulls pull the camera back in
-- proportion so the whole ship stays in view.
local BASE_RADIUS = 7

local function offsetFor(model: Model)
	local hull = Config.Hulls[model:GetAttribute("Hull")]
	local scale = math.max(0.85, (if hull then hull.radius else BASE_RADIUS) / BASE_RADIUS) * distanceScale
	return CFrame.new(0, 7 * scale, 26 * scale) * CFrame.Angles(math.rad(-8), 0, 0)
end
local STIFFNESS = 10
local BASE_FOV = 70
local BOOST_FOV = BASE_FOV + BOOST_FOV_EXTRA

-- Field of view setting; boost widens it a little more.
function ChaseCamera.setFieldOfView(fov: number)
	BASE_FOV = fov
	BOOST_FOV = fov + BOOST_FOV_EXTRA
end

-- Camera distance setting: "Near", "Normal" or "Far".
function ChaseCamera.setDistance(name: string)
	distanceScale = DISTANCES[name] or 1
end

function ChaseCamera.update(dt: number, model: Model?)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	if not model or not model.PrimaryPart then
		return
	end

	local target = model.PrimaryPart.CFrame * offsetFor(model)
	local alpha = 1 - math.exp(-STIFFNESS * dt)
	camera.CFrame = camera.CFrame:Lerp(target, alpha)

	local fov = if Flight.boosting then BOOST_FOV else BASE_FOV
	camera.FieldOfView += (fov - camera.FieldOfView) * alpha
end

-- Snap straight to the ship, used on spawn.
function ChaseCamera.snap(model: Model?)
	if model and model.PrimaryPart then
		workspace.CurrentCamera.CFrame = model.PrimaryPart.CFrame * offsetFor(model)
	end
end

return ChaseCamera
