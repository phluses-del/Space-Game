--[[
	Player settings: the list the Settings screen draws, their defaults, and
	a check the server runs before saving. Adding a setting here puts it on
	the Settings screen; client/ClientSettings.lua decides what it changes.

	kind "toggle": true or false
	kind "slider": number from min to max, snapped to step
	kind "choice": one of options
]]

local Settings = {}

Settings.list = {
	{ section = "Flight" },
	{
		key = "flightAssist",
		label = "Flight assist at launch",
		hint = "On: the ship stops when you let go. Off: you keep drifting. F toggles it in flight.",
		kind = "toggle",
		default = true,
	},
	{
		key = "invertPitch",
		label = "Invert pitch",
		hint = "Pull back to climb, like a flight sim.",
		kind = "toggle",
		default = false,
	},
	{
		key = "steerSensitivity",
		label = "Steering sensitivity",
		hint = "How hard the mouse, stick or touch drag turns the ship.",
		kind = "slider",
		min = 0.5,
		max = 2,
		step = 0.05,
		default = 1,
	},
	{
		key = "mouseDeadzone",
		label = "Mouse deadzone",
		hint = "How far from the centre the mouse must move before the ship turns.",
		kind = "slider",
		min = 0,
		max = 0.25,
		step = 0.01,
		default = 0.06,
	},

	{ section = "Camera" },
	{
		key = "fieldOfView",
		label = "Field of view",
		kind = "slider",
		min = 55,
		max = 95,
		step = 1,
		default = 70,
	},
	{
		key = "cameraDistance",
		label = "Camera distance",
		kind = "choice",
		options = { "Near", "Normal", "Far" },
		default = "Normal",
	},

	{ section = "Interface" },
	{
		key = "hudScale",
		label = "HUD size",
		kind = "slider",
		min = 0.7,
		max = 1.3,
		step = 0.05,
		default = 1,
	},
	{
		key = "controlHints",
		label = "Show control hints",
		kind = "toggle",
		default = true,
	},

	{ section = "Sound" },
	{
		key = "musicVolume",
		label = "Music volume",
		kind = "slider",
		min = 0,
		max = 1,
		step = 0.05,
		default = 0.6,
	},
	{
		key = "effectsVolume",
		label = "Effects volume",
		kind = "slider",
		min = 0,
		max = 1,
		step = 0.05,
		default = 0.8,
	},
}

Settings.byKey = {}
for _, item in Settings.list do
	if item.key then
		Settings.byKey[item.key] = item
	end
end

function Settings.defaults()
	local values = {}
	for key, item in Settings.byKey do
		values[key] = item.default
	end
	return values
end

-- Returns a clean copy with every key present and every value valid.
-- Unknown keys and wrong types fall back to the default.
function Settings.sanitize(input: any)
	local values = Settings.defaults()
	if type(input) ~= "table" then
		return values
	end
	for key, item in Settings.byKey do
		local value = input[key]
		if item.kind == "toggle" then
			if type(value) == "boolean" then
				values[key] = value
			end
		elseif item.kind == "slider" then
			if type(value) == "number" and value == value then
				local snapped = math.floor((value - item.min) / item.step + 0.5) * item.step + item.min
				values[key] = math.clamp(snapped, item.min, item.max)
			end
		elseif item.kind == "choice" then
			if type(value) == "string" and table.find(item.options, value) then
				values[key] = value
			end
		end
	end
	return values
end

return Settings
