--[[
	Turns keyboard and mouse, gamepad and touch into one set of flight axes,
	each from -1 to 1, plus button actions.

	PC:      mouse steers (pitch and yaw), W/S thrust, A/D strafe, Space/Ctrl up
	         and down, Q/E roll, Shift boost, T lock, Tab next target,
	         G subsystem, X clear lock, F flight assist
	Gamepad: left stick thrust and strafe, right stick steer, L1/R1 roll,
	         L2/R2 down and up, B boost, Y lock, D-pad right next target,
	         X subsystem, D-pad up flight assist
	Touch:   left half of the screen is a thrust stick, drag on the right half
	         to steer, on-screen buttons for everything else
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local Input = {}

Input.axes = {
	forward = 0,
	strafe = 0,
	vertical = 0,
	pitch = 0,
	yaw = 0,
	roll = 0,
	boost = false,
}
Input.mouseSteering = false -- true while the mouse is the active steering device

local held = {}
local actionCallbacks = {}

local TOUCH_STICK_RADIUS = 80
local TOUCH_STEER_RADIUS = 110

local touchThrust = nil -- { input, origin }
local touchSteer = nil

local function onHold(name)
	return function(_, state)
		held[name] = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Sink
	end
end

local function onPress(name)
	return function(_, state)
		if state == Enum.UserInputState.Begin and actionCallbacks[name] then
			actionCallbacks[name]()
		end
		return Enum.ContextActionResult.Sink
	end
end

-- Register what happens when an action button is pressed.
function Input.on(name: string, callback: () -> ())
	actionCallbacks[name] = callback
end

local function bindHold(name, title, position, ...)
	ContextActionService:BindAction(name, onHold(name), true, ...)
	ContextActionService:SetTitle(name, title)
	ContextActionService:SetPosition(name, position)
end

local function bindPress(name, title, position, ...)
	ContextActionService:BindAction(name, onPress(name), true, ...)
	ContextActionService:SetTitle(name, title)
	ContextActionService:SetPosition(name, position)
end

function Input.start()
	-- Touch buttons are laid out on the right side, above the steering area.
	bindHold("RollLeft", "Roll L", UDim2.new(1, -230, 1, -230), Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)
	bindHold("RollRight", "Roll R", UDim2.new(1, -90, 1, -230), Enum.KeyCode.E, Enum.KeyCode.ButtonR1)
	bindHold("Up", "Up", UDim2.new(1, -160, 1, -300), Enum.KeyCode.Space)
	bindHold("Down", "Down", UDim2.new(1, -160, 1, -160), Enum.KeyCode.LeftControl)
	bindHold("Boost", "Boost", UDim2.new(0, 30, 1, -300), Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonB)

	bindPress("Lock", "Lock", UDim2.new(1, -90, 0, 140), Enum.KeyCode.T, Enum.KeyCode.ButtonY)
	bindPress("NextTarget", "Next", UDim2.new(1, -160, 0, 140), Enum.KeyCode.Tab, Enum.KeyCode.DPadRight)
	bindPress("Subsystem", "Part", UDim2.new(1, -230, 0, 140), Enum.KeyCode.G, Enum.KeyCode.ButtonX)
	bindPress("ClearLock", "Unlock", UDim2.new(1, -300, 0, 140), Enum.KeyCode.X, Enum.KeyCode.DPadDown)
	bindPress("Assist", "Assist", UDim2.new(0, 30, 1, -370), Enum.KeyCode.F, Enum.KeyCode.DPadUp)

	UserInputService.TouchStarted:Connect(function(touch, processed)
		if processed then
			return
		end
		local position = Vector2.new(touch.Position.X, touch.Position.Y)
		local half = workspace.CurrentCamera.ViewportSize.X / 2
		if position.X < half and not touchThrust then
			touchThrust = { input = touch, origin = position }
		elseif position.X >= half and not touchSteer then
			touchSteer = { input = touch, origin = position }
		end
	end)

	UserInputService.TouchEnded:Connect(function(touch)
		if touchThrust and touchThrust.input == touch then
			touchThrust = nil
		end
		if touchSteer and touchSteer.input == touch then
			touchSteer = nil
		end
	end)
end

local function key(code)
	return if UserInputService:IsKeyDown(code) then 1 else 0
end

local function deadzone(value, zone)
	if math.abs(value) < zone then
		return 0
	end
	return math.sign(value) * (math.abs(value) - zone) / (1 - zone)
end

local function touchOffset(touch, radius)
	local position = Vector2.new(touch.input.Position.X, touch.input.Position.Y)
	local offset = (position - touch.origin) / radius
	if offset.Magnitude > 1 then
		offset = offset.Unit
	end
	return offset
end

-- Reads every device and updates Input.axes. Call once per frame.
function Input.update()
	local axes = Input.axes
	local forward = key(Enum.KeyCode.W) - key(Enum.KeyCode.S)
	local strafe = key(Enum.KeyCode.D) - key(Enum.KeyCode.A)
	local vertical = (if held.Up then 1 else 0) - (if held.Down then 1 else 0)
	local roll = (if held.RollRight then 1 else 0) - (if held.RollLeft then 1 else 0)
	local pitch, yaw = 0, 0

	-- Gamepad
	for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if state.KeyCode == Enum.KeyCode.Thumbstick1 then
			strafe += deadzone(state.Position.X, 0.15)
			forward += deadzone(state.Position.Y, 0.15)
		elseif state.KeyCode == Enum.KeyCode.Thumbstick2 then
			yaw += deadzone(state.Position.X, 0.15)
			pitch += deadzone(state.Position.Y, 0.15)
		elseif state.KeyCode == Enum.KeyCode.ButtonR2 then
			vertical += state.Position.Z
		elseif state.KeyCode == Enum.KeyCode.ButtonL2 then
			vertical -= state.Position.Z
		end
	end

	-- Touch
	if touchThrust then
		local offset = touchOffset(touchThrust, TOUCH_STICK_RADIUS)
		strafe += offset.X
		forward -= offset.Y
	end
	if touchSteer then
		local offset = touchOffset(touchSteer, TOUCH_STEER_RADIUS)
		yaw += offset.X
		pitch -= offset.Y
	end

	-- Mouse: distance of the cursor from the screen centre steers.
	local lastInput = UserInputService:GetLastInputType()
	Input.mouseSteering = UserInputService.MouseEnabled
		and not GuiService.MenuIsOpen
		and lastInput ~= Enum.UserInputType.Touch
		and not string.find(lastInput.Name, "Gamepad")
	if Input.mouseSteering then
		local viewport = workspace.CurrentCamera.ViewportSize
		local mouse = UserInputService:GetMouseLocation()
		local offset = (mouse - viewport / 2) / (math.min(viewport.X, viewport.Y) / 2)
		yaw += deadzone(math.clamp(offset.X, -1, 1), Config.Flight.mouseDeadzone)
		pitch -= deadzone(math.clamp(offset.Y, -1, 1), Config.Flight.mouseDeadzone)
	end

	axes.forward = math.clamp(forward, -1, 1)
	axes.strafe = math.clamp(strafe, -1, 1)
	axes.vertical = math.clamp(vertical, -1, 1)
	axes.pitch = math.clamp(pitch, -1, 1)
	axes.yaw = math.clamp(yaw, -1, 1)
	axes.roll = math.clamp(roll, -1, 1)
	axes.boost = held.Boost == true
end

return Input
