--[[
	Flight and combat HUD, built in code: your shield and hull, speed and
	flight mode, each gun's status, the locked target's shield, hull and
	subsystem, a lock marker on the target, and short alerts.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Flight = require(script.Parent.Flight)
local Input = require(script.Parent.Input)

local Hud = {}

local WHITE = Color3.fromRGB(235, 240, 255)
local DIM = Color3.fromRGB(150, 160, 180)
local SHIELD = Color3.fromRGB(90, 200, 255)
local HULL = Color3.fromRGB(240, 170, 70)
local LOCKING = Color3.fromRGB(255, 220, 80)
local LOCKED = Color3.fromRGB(255, 80, 80)
local PANEL = Color3.fromRGB(10, 14, 24)

local GUN_STATUS_TEXT = {
	Idle = { "no lock", DIM },
	Firing = { "firing", Color3.fromRGB(120, 255, 140) },
	OutOfArc = { "out of arc", LOCKING },
	OutOfRange = { "out of range", LOCKING },
	NoLineOfSight = { "blocked", LOCKING },
	NoAmmo = { "no ammo", LOCKED },
	NoPower = { "no power", LOCKED },
	Offline = { "knocked out", LOCKED },
}

local WEAPON_NAMES = {
	PulseBlaster = "Pulse Blaster",
	Autocannon = "Autocannon",
}

local SUBSYSTEM_NAMES = {
	Hull = "Hull",
	ShieldGenerator = "Shield generator",
	Engine = "Engines",
	Weapon = "Weapons",
}

local gui, ownPanel, targetPanel, gunList, lockMarker, cursor, alertLabel, hint
local ownBars, targetBars = {}, {}
local gunRows = {}
local blips = {}
local alertUntil = 0

local function make(className, props, parent)
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function label(text, props, parent)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextColor3 = WHITE,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
		Size = UDim2.new(1, 0, 0, 18),
	}
	for key, value in props do
		defaults[key] = value
	end
	return make("TextLabel", defaults, parent)
end

local function panel(props, parent)
	local frame = make("Frame", {
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, parent)
	for key, value in props do
		frame[key] = value
	end
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, frame)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}, frame)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, frame)
	return frame
end

local function bar(name, color, parent, order)
	local holder = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = order }, parent)
	local back = make("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 46, 60),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 60, 0, 3),
		Size = UDim2.new(1, -60, 0, 10),
	}, holder)
	local fill = make("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, back)
	local text = label(name, { Size = UDim2.new(0, 60, 1, 0), TextSize = 12, TextColor3 = DIM }, holder)
	return { fill = fill, text = text, name = name }
end

local function setBar(b, value, max)
	local fraction = if max and max > 0 then math.clamp(value / max, 0, 1) else 0
	b.fill.Size = UDim2.fromScale(fraction, 1)
	b.text.Text = string.format("%s %.0f", b.name, value or 0)
end

local function corner(parent, anchor, rotation)
	local c = make("Frame", {
		AnchorPoint = anchor,
		Position = UDim2.fromScale(anchor.X, anchor.Y),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		Rotation = rotation,
	}, parent)
	make("Frame", { Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0, BackgroundColor3 = WHITE, Name = "H" }, c)
	make("Frame", { Size = UDim2.new(0, 2, 1, 0), BorderSizePixel = 0, BackgroundColor3 = WHITE, Name = "V" }, c)
	return c
end

function Hud.start()
	local player = Players.LocalPlayer
	gui = make("ScreenGui", { Name = "FlightHud", ResetOnSpawn = false, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))

	ownPanel = panel({ Position = UDim2.fromOffset(16, 56), Size = UDim2.fromOffset(240, 120) }, gui)
	ownBars.shield = bar("Shield", SHIELD, ownPanel, 1)
	ownBars.hull = bar("Hull", HULL, ownPanel, 2)
	ownBars.speed = label("", { LayoutOrder = 3 }, ownPanel)
	ownBars.mode = label("", { LayoutOrder = 4, TextColor3 = DIM, TextSize = 12 }, ownPanel)
	ownBars.power = label("", { LayoutOrder = 5, TextColor3 = DIM, TextSize = 12 }, ownPanel)

	gunList = panel({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(240, 110),
	}, gui)

	targetPanel = panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 56),
		Size = UDim2.fromOffset(250, 130),
		Visible = false,
	}, gui)
	targetBars.name = label("", { LayoutOrder = 1, TextSize = 16 }, targetPanel)
	targetBars.state = label("", { LayoutOrder = 2, TextSize = 12 }, targetPanel)
	targetBars.shield = bar("Shield", SHIELD, targetPanel, 3)
	targetBars.hull = bar("Hull", HULL, targetPanel, 4)
	targetBars.subsystem = label("", { LayoutOrder = 5, TextSize = 12, TextColor3 = DIM }, targetPanel)
	targetBars.generator = label("", { LayoutOrder = 6, TextSize = 12, TextColor3 = DIM }, targetPanel)

	lockMarker = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(56, 56),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	corner(lockMarker, Vector2.new(0, 0), 0)
	corner(lockMarker, Vector2.new(1, 0), 90)
	corner(lockMarker, Vector2.new(1, 1), 180)
	corner(lockMarker, Vector2.new(0, 1), 270)

	-- Centre dot plus a ring that follows the mouse when it is steering.
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, gui)
	cursor = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
	}, gui)
	make("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.3 }, cursor)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, cursor)

	alertLabel = label("", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(500, 28),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		Visible = false,
	}, gui)

	hint = label(
		"Mouse steer · W/S thrust · A/D strafe · Space/Ctrl up/down · Q/E roll · Shift boost · T lock · Tab next · G part · X unlock · F assist",
		{
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.fromOffset(900, 18),
			TextSize = 12,
			TextColor3 = DIM,
			TextXAlignment = Enum.TextXAlignment.Center,
		},
		gui
	)
end

function Hud.alert(text: string, color: Color3?)
	alertLabel.Text = text
	alertLabel.TextColor3 = color or WHITE
	alertLabel.Visible = true
	alertUntil = os.clock() + 2.5
end

local function rebuildGunRows(model)
	for _, row in gunRows do
		row:Destroy()
	end
	table.clear(gunRows)
	for i = 1, model:GetAttribute("GunCount") or 0 do
		gunRows[i] = label("", { LayoutOrder = i, TextSize = 13 }, gunList)
	end
	gunList.Size = UDim2.fromOffset(240, 20 + #gunRows * 22)
end

function Hud.setShip(model: Model?)
	if model then
		rebuildGunRows(model)
	end
end

local function updateOwn(model)
	setBar(ownBars.shield, model:GetAttribute("ShieldHP") or 0, model:GetAttribute("MaxShieldHP"))
	setBar(ownBars.hull, model:GetAttribute("HullHP") or 0, model:GetAttribute("MaxHullHP"))
	ownBars.speed.Text = string.format("Speed %.0f%s", Flight.speed, if Flight.boosting then "  BOOST" else "")
	ownBars.mode.Text = "Flight assist " .. (if Flight.assist then "on" else "off (drifting)")
	ownBars.power.Text = string.format("Plasma fire rate %.0f%%", (model:GetAttribute("PlasmaRate") or 1) * 100)

	for i, row in gunRows do
		local weapon = model:GetAttribute("Gun" .. i .. "Weapon")
		local status = GUN_STATUS_TEXT[model:GetAttribute("Gun" .. i .. "Status") or "Idle"] or GUN_STATUS_TEXT.Idle
		local ammo = model:GetAttribute("Gun" .. i .. "Ammo")
		row.Text = string.format(
			"%.0f  %s  %s%s",
			i,
			WEAPON_NAMES[weapon] or weapon or "?",
			status[1],
			if ammo then string.format("  (%.0f)", ammo) else ""
		)
		row.TextColor3 = status[2]
	end
end

local function updateTarget(model, target)
	local camera = workspace.CurrentCamera
	if not (target and target.PrimaryPart and target:IsDescendantOf(workspace)) then
		targetPanel.Visible = false
		lockMarker.Visible = false
		return
	end

	local progress = model:GetAttribute("LockProgress") or 0
	local locked = progress >= 1
	local distance = (target.PrimaryPart.Position - model.PrimaryPart.Position).Magnitude

	targetPanel.Visible = true
	targetBars.name.Text = target:GetAttribute("DisplayName") or target.Name
	targetBars.state.Text = if locked
		then string.format("LOCKED · %.0f studs", distance)
		else string.format("Locking %.0f%% · %.0f studs", progress * 100, distance)
	targetBars.state.TextColor3 = if locked then LOCKED else LOCKING
	setBar(targetBars.shield, target:GetAttribute("ShieldHP") or 0, target:GetAttribute("MaxShieldHP"))
	setBar(targetBars.hull, target:GetAttribute("HullHP") or 0, target:GetAttribute("MaxHullHP"))
	targetBars.subsystem.Text = "Aiming at: " .. SUBSYSTEM_NAMES[model:GetAttribute("Subsystem") or "Hull"]
	local genHP = target:GetAttribute("Mod_ShieldGenerator") or 0
	targetBars.generator.Text = if genHP > 0
		then string.format("Shield generator %.0f / %.0f", genHP, target:GetAttribute("ModMax_ShieldGenerator") or 0)
		else "Shield generator knocked out"

	local screen, onScreen = camera:WorldToViewportPoint(target.PrimaryPart.Position)
	local viewport = camera.ViewportSize
	local x, y = screen.X, screen.Y
	if not onScreen or screen.Z < 0 then
		-- Pin the marker to the screen edge in the target's direction.
		local direction = Vector2.new(x - viewport.X / 2, y - viewport.Y / 2)
		if screen.Z < 0 then
			direction = -direction
		end
		if direction.Magnitude < 1 then
			direction = Vector2.new(0, 1)
		end
		local edge = Vector2.new(viewport.X / 2 - 40, viewport.Y / 2 - 40)
		local scale = math.min(edge.X / math.max(math.abs(direction.X), 1), edge.Y / math.max(math.abs(direction.Y), 1))
		x = viewport.X / 2 + direction.X * scale
		y = viewport.Y / 2 + direction.Y * scale
	end
	lockMarker.Visible = true
	lockMarker.Position = UDim2.fromOffset(x, y)
	local color = if locked then LOCKED else LOCKING
	for _, c in lockMarker:GetChildren() do
		c.H.BackgroundColor3 = color
		c.V.BackgroundColor3 = color
	end
end

-- Small diamonds over every other ship on screen so targets are easy to find.
local function updateBlips(model, target)
	local camera = workspace.CurrentCamera
	local seen = {}
	for _, ship in CollectionService:GetTagged("Ship") do
		if ship ~= model and ship ~= target and ship.PrimaryPart and ship:IsDescendantOf(workspace) then
			local screen, onScreen = camera:WorldToViewportPoint(ship.PrimaryPart.Position)
			if onScreen then
				local blip = blips[ship]
				if not blip then
					blip = make("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.fromOffset(10, 10),
						Rotation = 45,
						BackgroundTransparency = 1,
					}, gui)
					make("UIStroke", {
						Color = if ship:GetAttribute("IsDrone") then LOCKED else SHIELD,
						Thickness = 1.5,
					}, blip)
					blips[ship] = blip
				end
				blip.Position = UDim2.fromOffset(screen.X, screen.Y)
				seen[ship] = true
			end
		end
	end
	for ship, blip in blips do
		if not seen[ship] then
			blip:Destroy()
			blips[ship] = nil
		end
	end
end

function Hud.update(model: Model?)
	if alertLabel.Visible and os.clock() > alertUntil then
		alertLabel.Visible = false
	end

	cursor.Visible = Input.mouseSteering
	if Input.mouseSteering then
		local mouse = UserInputService:GetMouseLocation()
		cursor.Position = UDim2.fromOffset(mouse.X, mouse.Y)
	end
	hint.Visible = not UserInputService.TouchEnabled

	local alive = model ~= nil and model.PrimaryPart ~= nil and model:IsDescendantOf(workspace)
	ownPanel.Visible = alive
	gunList.Visible = alive
	if not model or not alive then
		targetPanel.Visible = false
		lockMarker.Visible = false
		updateBlips(nil, nil)
		return
	end

	local lockValue = model:FindFirstChild("LockTarget")
	local target = if lockValue then lockValue.Value else nil
	updateOwn(model)
	updateTarget(model, target)
	updateBlips(model, target)
end

return Hud
