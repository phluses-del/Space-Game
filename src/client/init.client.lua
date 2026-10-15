--[[
	Client entry point: finds the pilot's ship, then each frame reads input,
	flies the ship, moves the camera and refreshes the HUD.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ChaseCamera = require(script.ChaseCamera)
local Effects = require(script.Effects)
local Flight = require(script.Flight)
local Hud = require(script.Hud)
local Input = require(script.Input)
local Targeting = require(script.Targeting)

local player = Players.LocalPlayer

-- There is no character to walk around with, so switch off Roblox's default
-- movement controls (and their touch thumbstick).
task.spawn(function()
	local ok, playerModule = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and playerModule then
		playerModule:GetControls():Disable()
	end
end)

local ship: Model? = nil

local function setShip(model: Model?)
	ship = model
	Flight.setShip(model)
	Hud.setShip(model)
	ChaseCamera.snap(model)
end

local function currentTarget()
	local lockValue = ship and ship:FindFirstChild("LockTarget")
	return if lockValue then lockValue.Value else nil
end

Input.on("Lock", function()
	Targeting.lockNearestInView(ship)
end)
Input.on("NextTarget", function()
	Targeting.nextTarget(ship, currentTarget())
end)
Input.on("ClearLock", Targeting.clear)
Input.on("Subsystem", Targeting.cycleSubsystem)
Input.on("Assist", function()
	Flight.toggleAssist()
	Hud.alert("Flight assist " .. (if Flight.assist then "on" else "off"))
end)

Hud.start()
Effects.start()
Input.start()

Effects.onShipEvent(function(kind, model, moduleName)
	if kind == "ShieldDown" and model then
		if model == ship then
			Hud.alert("Your shield is down", Color3.fromRGB(255, 120, 120))
		elseif model == currentTarget() then
			Hud.alert("Target shield down", Color3.fromRGB(120, 220, 255))
		end
	elseif kind == "Knockout" and model then
		local name = string.gsub(moduleName or "module", "(%l)(%u)", "%1 %2")
		if model == ship then
			Hud.alert("Knocked out: your " .. string.lower(name), Color3.fromRGB(255, 160, 80))
		elseif model == currentTarget() then
			Hud.alert("Knocked out: target " .. string.lower(name), Color3.fromRGB(255, 220, 80))
		end
	end
end)

-- The server points player.Ship at our ship model and swaps it on respawn.
task.spawn(function()
	local pointer = player:WaitForChild("Ship")
	local function refresh()
		local model = pointer.Value
		if model and model:IsA("Model") then
			if not model.PrimaryPart then
				model:GetPropertyChangedSignal("PrimaryPart"):Wait()
			end
			setShip(model)
		else
			setShip(nil)
		end
	end
	pointer:GetPropertyChangedSignal("Value"):Connect(refresh)
	refresh()
end)

RunService.RenderStepped:Connect(function(dt)
	Input.update()
	if ship and not ship:IsDescendantOf(workspace) then
		setShip(nil)
	end
	Flight.update(dt, Input.axes)
	ChaseCamera.update(dt, ship)
	Hud.update(ship)
end)
