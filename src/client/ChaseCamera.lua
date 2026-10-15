--[[
	Chase camera that sits behind and above the pilot's ship and rolls with
	it, smoothed so fast turns don't jerk the view.
]]

local Flight = require(script.Parent.Flight)

local ChaseCamera = {}

local OFFSET = CFrame.new(0, 7, 26) * CFrame.Angles(math.rad(-8), 0, 0)
local STIFFNESS = 10
local BASE_FOV = 70
local BOOST_FOV = 85

function ChaseCamera.update(dt: number, model: Model?)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	if not model or not model.PrimaryPart then
		return
	end

	local target = model.PrimaryPart.CFrame * OFFSET
	local alpha = 1 - math.exp(-STIFFNESS * dt)
	camera.CFrame = camera.CFrame:Lerp(target, alpha)

	local fov = if Flight.boosting then BOOST_FOV else BASE_FOV
	camera.FieldOfView += (fov - camera.FieldOfView) * alpha
end

-- Snap straight to the ship, used on spawn.
function ChaseCamera.snap(model: Model?)
	if model and model.PrimaryPart then
		workspace.CurrentCamera.CFrame = model.PrimaryPart.CFrame * OFFSET
	end
end

return ChaseCamera
