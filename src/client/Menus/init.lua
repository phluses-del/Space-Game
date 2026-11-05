--[[
	Menu controller: owns the menu ScreenGui, which screen is showing, and
	the flow between them.

	  join -> Main menu -> Hangar (pick a ship) -> Launch -> flying
	  flying -> P / M / View button / on-screen Menu -> Pause
	  Pause -> Resume, Hangar (dock), Settings, Controls, Main menu
	  ship destroyed -> Destroyed screen -> Relaunch or Hangar

	While any screen is open, flight input is off and the HUD is hidden.
	The server says which state the pilot is in through the player's
	ShipState attribute ("None", "Flying", "Destroyed").

	Each screen is a module with:
	  build(canvas, Menus)  makes its Frame (hidden) once
	  open(context)         shows it; may return the button gamepads start on
	  close()               optional, hides it
	  update(dt)            optional, runs every frame while it's on top
	Other code can add a screen with Menus.registerScreen(name, module).
]]

local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShipCatalog = require(ReplicatedStorage.Shared.ShipCatalog)

local Hud = require(script.Parent.Hud)
local Input = require(script.Parent.Input)
local Theme = require(script.Theme)

local Menus = {}

Menus.screens = {} -- [name] = module
Menus.stack = {} -- names of open screens, top last
Menus.ship = nil :: Model? -- the pilot's ship while flying
Menus.selectedShip = ShipCatalog.defaultId -- Hangar selection, also the relaunch choice

local player = Players.LocalPlayer
local gui, backdrop, canvas, canvasScale, toast, menuButton, blur
local frames = {} -- [name] = Frame
local toastUntil = 0
local afterDock = nil -- screen to open once the server confirms the ship docked
local orbitAngle = 0

local C = Theme.colors

local function shipState(): string
	return player:GetAttribute("ShipState") or "None"
end

local function isGamepad(): boolean
	return string.find(UserInputService:GetLastInputType().Name, "Gamepad") ~= nil
end

-- The Shipyard (ship customization) is its own module and ScreenGui, built in
-- another thread. Found lazily so the menus work with or without it.
local function shipyard()
	local module = script.Parent:FindFirstChild("Shipyard")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			return result
		end
	end
	return nil
end

function Menus.isOpen(): boolean
	if #Menus.stack > 0 then
		return true
	end
	local yard = shipyard()
	return yard ~= nil and yard.isOpen ~= nil and yard.isOpen()
end

function Menus.top(): string?
	return Menus.stack[#Menus.stack]
end

local function refresh()
	local open = Menus.isOpen()
	local flying = Menus.ship ~= nil
	local yard = shipyard()
	local yardOpen = yard ~= nil and yard.isOpen ~= nil and yard.isOpen()
	Input.enabled = not open
	Input.setTouchButtonsVisible(flying and not open)
	Hud.setVisible(flying and not open)
	-- Hidden under the Shipyard; shown while flying for the Menu button.
	gui.Enabled = (#Menus.stack > 0 and not yardOpen) or (flying and not open)
	backdrop.Visible = #Menus.stack > 0
	-- Over a live flight, darken more so the menu reads; over the main menu
	-- backdrop, keep the stars visible.
	backdrop.BackgroundTransparency = if flying then 0.35 else 0.55
	blur.Enabled = open and flying
	menuButton.Visible = flying and not open
	if not open then
		GuiService.SelectedObject = nil
	end
end

local function showTop(context)
	for name, frame in frames do
		frame.Visible = name == Menus.top()
	end
	local name = Menus.top()
	if name then
		local selection = Menus.screens[name].open(context or {})
		if isGamepad() and selection then
			GuiService.SelectedObject = selection
		end
	end
	refresh()
end

local function hideTop()
	local name = Menus.top()
	if name then
		local screen = Menus.screens[name]
		if screen.close then
			screen.close()
		end
		frames[name].Visible = false
	end
end

function Menus.registerScreen(name: string, module)
	Menus.screens[name] = module
	if canvas then
		frames[name] = module.build(canvas, Menus)
	end
end

-- Opens a screen on top of the current one; back() returns to it.
function Menus.open(name: string, context: any?)
	assert(Menus.screens[name], "No menu screen called " .. name)
	hideTop()
	table.insert(Menus.stack, name)
	showTop(context)
end

-- Replaces the whole stack with one screen.
function Menus.switch(name: string, context: any?)
	hideTop()
	table.clear(Menus.stack)
	table.insert(Menus.stack, name)
	showTop(context)
end

function Menus.back()
	hideTop()
	table.remove(Menus.stack)
	if #Menus.stack == 0 and not Menus.ship then
		table.insert(Menus.stack, "MainMenu") -- nothing to go back to without a ship
	end
	showTop()
end

function Menus.closeAll()
	hideTop()
	table.clear(Menus.stack)
	showTop()
end

function Menus.toast(text: string, color: Color3?)
	toast.Text = text
	toast.TextColor3 = color or C.text
	toast.Visible = true
	toastUntil = os.clock() + 3.5
	if Menus.ship and not Menus.isOpen() then
		Hud.alert(text, color)
	end
end

-- Asks the server to launch a ship from the Hangar or after a respawn.
function Menus.launch(shipId: string)
	Menus.selectedShip = shipId
	Remotes.RequestSpawn:FireServer(shipId)
end

-- Docks the current ship (refused by the server in combat), then opens
-- `thenOpen` ("Hangar" or "MainMenu").
function Menus.dock(thenOpen: string)
	afterDock = thenOpen
	Remotes.ReturnToHangar:FireServer()
end

-- Opens the Shipyard for a ship if the customization module is installed.
function Menus.openShipyard(shipId: string): boolean
	local yard = shipyard()
	if not yard or not yard.open then
		Menus.toast("Ship customization isn't in this build yet.", C.highlight)
		return false
	end
	yard.open(shipId)
	refresh()
	return true
end

function Menus.hasShipyard(): boolean
	return shipyard() ~= nil
end

-- Called by the client entry point whenever the pilot's ship changes.
function Menus.setShip(model: Model?)
	Menus.ship = model
	if model then
		afterDock = nil
		Menus.closeAll()
	else
		refresh()
	end
end

function Menus.togglePause()
	if not Menus.ship then
		return
	end
	local yard = shipyard()
	if yard and yard.isOpen and yard.isOpen() then
		return
	end
	if #Menus.stack == 0 then
		Menus.open("Pause")
	elseif Menus.top() == "Pause" then
		Menus.closeAll()
	else
		Menus.back()
	end
end

local function onShipStateChanged()
	local state = shipState()
	if state == "Destroyed" then
		Menus.switch("Destroyed")
	elseif state == "None" then
		if afterDock then
			local target = afterDock
			afterDock = nil
			Menus.switch(target)
		elseif #Menus.stack == 0 then
			Menus.switch("MainMenu")
		end
	end
	-- "Flying" closes the menus once the ship model arrives (Menus.setShip).
end

local function buildGui()
	gui = Theme.make("ScreenGui", {
		Name = "Menus",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10, -- above the HUD, below the Shipyard (20)
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	backdrop = Theme.make("Frame", {
		Name = "Backdrop",
		BackgroundColor3 = C.backdrop,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, gui)
	Theme.make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 0.4),
		}),
	}, backdrop)

	canvas = Theme.make("Frame", {
		Name = "Canvas",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(Theme.CANVAS.X, Theme.CANVAS.Y),
		BackgroundTransparency = 1,
	}, backdrop)
	canvasScale = Theme.make("UIScale", {}, canvas)

	local function fit()
		local viewport = workspace.CurrentCamera.ViewportSize
		canvasScale.Scale = math.min(viewport.X / Theme.CANVAS.X, viewport.Y / Theme.CANVAS.Y)
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

	toast = Theme.label("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -40, 0, 30),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		ZIndex = 10,
		Visible = false,
	}, canvas)

	-- On-screen pause button while flying, mainly for touch.
	menuButton = Theme.button("Menu", "secondary", Menus.togglePause, {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(16, 186),
		Size = UDim2.fromOffset(84, 36),
		TextSize = 16,
		BackgroundTransparency = 0.25,
		Visible = false,
	}, gui)

	blur = Theme.make("BlurEffect", { Name = "MenuBlur", Size = 14, Enabled = false }, Lighting)
end

function Menus.start()
	buildGui()
	for name, module in Menus.screens do
		frames[name] = module.build(canvas, Menus)
	end

	Input.on("Pause", Menus.togglePause)

	Remotes.Notice.OnClientEvent:Connect(function(text)
		if type(text) == "string" then
			Menus.toast(text, C.highlight)
			for _, screen in Menus.screens do
				if screen.onNotice then
					screen.onNotice(text)
				end
			end
		end
	end)

	local yard = shipyard()
	if yard and yard.onClosed then
		yard.onClosed(function()
			refresh()
			local name = Menus.top()
			if name then
				showTop()
			end
		end)
	end

	player:GetAttributeChangedSignal("ShipState"):Connect(onShipStateChanged)
	Menus.switch("MainMenu")
	if shipState() == "Destroyed" then
		onShipStateChanged()
	end
end

-- Runs every frame: the top screen's update, the toast timer, and a slow
-- orbiting camera over the system while there's no ship to follow.
function Menus.update(dt: number)
	local name = Menus.top()
	if name and Menus.screens[name].update then
		Menus.screens[name].update(dt)
	end
	if toast.Visible and os.clock() > toastUntil then
		toast.Visible = false
	end

	if not Menus.ship then
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		orbitAngle += dt * 0.03
		local spawn = Config.TestSystem.playerSpawn
		local eye = Vector3.new(math.sin(orbitAngle) * 900, 220, math.cos(orbitAngle) * 900)
		camera.CFrame = CFrame.lookAt(eye, spawn * 0.3)
		camera.FieldOfView = 70
	end
end

return Menus
