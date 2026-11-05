--[[
	Holds this player's settings on the client: loads them from the server,
	applies each one to the module it affects, and sends changes back to be
	saved (batched, so dragging a slider doesn't flood the server).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)

local ChaseCamera = require(script.Parent.ChaseCamera)
local Flight = require(script.Parent.Flight)
local Hud = require(script.Parent.Hud)
local Input = require(script.Parent.Input)

local ClientSettings = {}

ClientSettings.values = Settings.defaults()

local SAVE_DELAY = 2
local saveQueued = false
local changedCallbacks = {}

-- Sounds added later should use these groups so the volume settings apply.
local function soundGroup(name: string): SoundGroup
	local group = SoundService:FindFirstChild(name)
	if not group then
		group = Instance.new("SoundGroup")
		group.Name = name
		group.Parent = SoundService
	end
	return group
end

local APPLY = {
	invertPitch = function(value)
		Input.settings.invertPitch = value
	end,
	steerSensitivity = function(value)
		Input.settings.steerSensitivity = value
	end,
	mouseDeadzone = function(value)
		Input.settings.mouseDeadzone = value
	end,
	fieldOfView = ChaseCamera.setFieldOfView,
	cameraDistance = ChaseCamera.setDistance,
	hudScale = Hud.setScale,
	controlHints = Hud.setHintsVisible,
	musicVolume = function(value)
		soundGroup("Music").Volume = value
	end,
	effectsVolume = function(value)
		soundGroup("Effects").Volume = value
	end,
	-- flightAssist is applied at launch, see ClientSettings.applyLaunch.
}

local function applyAll()
	for key, apply in APPLY do
		apply(ClientSettings.values[key])
	end
end

function ClientSettings.get(key: string)
	return ClientSettings.values[key]
end

function ClientSettings.set(key: string, value: any)
	local item = Settings.byKey[key]
	if not item then
		return
	end
	local candidate = table.clone(ClientSettings.values)
	candidate[key] = value
	ClientSettings.values = Settings.sanitize(candidate)
	if APPLY[key] then
		APPLY[key](ClientSettings.values[key])
	end
	for _, callback in changedCallbacks do
		task.spawn(callback, key, ClientSettings.values[key])
	end

	if not saveQueued then
		saveQueued = true
		task.delay(SAVE_DELAY, function()
			saveQueued = false
			Remotes.SaveSettings:FireServer(ClientSettings.values)
		end)
	end
end

function ClientSettings.resetAll()
	for key, value in Settings.defaults() do
		ClientSettings.set(key, value)
	end
end

function ClientSettings.onChanged(callback: (string, any) -> ())
	table.insert(changedCallbacks, callback)
end

-- Called each time the player's ship spawns.
function ClientSettings.applyLaunch()
	Flight.assist = ClientSettings.values.flightAssist
end

-- Applies defaults right away, then the saved values once the server answers.
function ClientSettings.start()
	applyAll()
	task.spawn(function()
		local ok, saved = pcall(function()
			return Remotes.GetSettings:InvokeServer()
		end)
		if ok then
			ClientSettings.values = Settings.sanitize(saved)
			applyAll()
			for _, callback in changedCallbacks do
				task.spawn(callback, nil, nil)
			end
		end
	end)
end

return ClientSettings
