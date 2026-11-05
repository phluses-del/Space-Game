--[[
	Hangar: pick a ship and launch it. Lists every hull in ShipCatalog, shows
	a turning 3D preview and the ship's stats, and has a Customize button
	that opens the Shipyard (ship customization) when it's installed.

	A hull shows "Coming soon" until Config has its hull and player loadout
	and the server could build its preview. If the Shipyard's profile says
	the player doesn't own a hull, its card says "Not owned"; the server has
	the final say on what can launch.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ShipCatalog = require(ReplicatedStorage.Shared.ShipCatalog)

local Theme = require(script.Parent.Theme)

local Hangar = {}

local C = Theme.colors
local TIER_NAMES = { "Mk I", "Mk II", "Mk III", "Mk IV" }

local menus
local frame, list, viewport, viewportCamera, nameLabel, roleLabel, blurbLabel, statsBox, weaponsLabel
local launchButton, customizeButton
local cards = {} -- [id] = { button, tag, stroke }
local statRows = {} -- [key] = { value, fill }
local previewModel = nil
local spin = 0
local launching = false
local launchTimeout = nil
local ownedHulls = nil -- from the Shipyard profile, if there is one

local STAT_ROWS = {
	{ key = "hullHP", label = "Hull" },
	{ key = "shieldHP", label = "Shield" },
	{ key = "topSpeed", label = "Top speed" },
	{ key = "turnRate", label = "Turning" },
}

local function previewsFolder()
	return ReplicatedStorage:FindFirstChild("ShipPreviews")
end

local function isOwned(id: string): boolean
	local entry = ShipCatalog.get(id)
	return ownedHulls == nil or (entry ~= nil and ownedHulls[entry.hull] == true)
end

local function canLaunch(id: string): boolean
	local folder = previewsFolder()
	return ShipCatalog.isAvailable(id) and folder ~= nil and folder:FindFirstChild(id) ~= nil
end

-- Largest value of each stat across launchable ships, so bars compare ships.
local function statMaxima()
	local maxima = {}
	for _, entry in ShipCatalog.entries do
		local stats = ShipCatalog.stats(entry.id)
		if stats then
			for _, row in STAT_ROWS do
				maxima[row.key] = math.max(maxima[row.key] or 0, stats[row.key] or 0)
			end
		end
	end
	return maxima
end

local function setPreview(id: string)
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
	local folder = previewsFolder()
	local source = folder and folder:FindFirstChild(id)
	if not source then
		return
	end
	previewModel = source:Clone()
	previewModel.Parent = viewport
	local size = previewModel:GetExtentsSize()
	local distance = math.max(size.Magnitude, 8) * 1.15
	viewportCamera.FieldOfView = 40
	viewportCamera.CFrame = CFrame.lookAt(Vector3.new(0, distance * 0.35, distance), Vector3.zero)
end

local function weaponName(id: string): string
	local weapon = Config.Weapons[id]
	return if weapon and weapon.displayName then weapon.displayName else Theme.spaced(id)
end

local function describeGuns(guns): string
	if #guns == 0 then
		return "No weapons"
	end
	-- Group identical guns: "2x Pulse Blaster (Gimbal, Mk I)"
	local order, counts = {}, {}
	for _, gun in guns do
		local text = string.format(
			"%s (%s, %s)",
			weaponName(gun.weapon),
			gun.slot or "?",
			TIER_NAMES[gun.tier or 1] or ("Mk " .. tostring(gun.tier))
		)
		if not counts[text] then
			table.insert(order, text)
		end
		counts[text] = (counts[text] or 0) + 1
	end
	local lines = {}
	for _, text in order do
		table.insert(lines, string.format("%dx %s", counts[text], text))
	end
	return table.concat(lines, "\n")
end

local function refreshCards()
	for _, entry in ShipCatalog.entries do
		local card = cards[entry.id]
		local selected = entry.id == menus.selectedShip
		local available = canLaunch(entry.id)
		card.stroke.Color = if selected then C.accent else C.stroke
		card.stroke.Thickness = if selected then 2 else 1
		card.button.BackgroundColor3 = if selected then C.panelLight else C.panel
		if not available then
			card.tag.Text = "Coming soon"
			card.tag.TextColor3 = C.faint
		elseif ownedHulls and not ownedHulls[entry.hull] then
			card.tag.Text = "Not owned"
			card.tag.TextColor3 = C.highlight
		else
			card.tag.Text = entry.size
			card.tag.TextColor3 = C.dim
		end
	end
end

local function select(id: string)
	menus.selectedShip = id
	local entry = ShipCatalog.get(id)
	local stats = ShipCatalog.stats(id)
	local available = canLaunch(id)

	nameLabel.Text = entry.name
	local unlock = if entry.unlock == "Start" then "starter ship" else "unlocks " .. string.lower(entry.unlock) .. " game"
	roleLabel.Text = string.format("%s · %s hull · %s", entry.role, entry.size, unlock)
	blurbLabel.Text = entry.blurb

	local maxima = statMaxima()
	for _, row in STAT_ROWS do
		local widgets = statRows[row.key]
		local value = stats and stats[row.key]
		widgets.value.Text = if value then string.format("%d", value) else "?"
		local fraction = if value and maxima[row.key] and maxima[row.key] > 0 then value / maxima[row.key] else 0
		widgets.fill.Size = UDim2.fromScale(math.clamp(fraction, 0.03, 1), 1)
	end
	if stats then
		weaponsLabel.Text = string.format(
			"%s%s\n\nBoost %d · Lock %.1f s · Armor plates %d · Engines %d",
			describeGuns(stats.guns),
			if stats.missile
				then string.format("\nMissile rack: %s", weaponName(stats.missile.weapon))
				else "",
			stats.topSpeed * Config.Flight.boostMultiplier,
			stats.lockTime or 0,
			stats.armorPlates,
			stats.engines
		)
	else
		weaponsLabel.Text = "This hull isn't built yet."
	end

	setPreview(id)
	if not launching then
		launchButton.Text = if available and not isOwned(id) then "Not owned" else "Launch"
	end
	Theme.setEnabled(launchButton, available and isOwned(id) and not launching)
	Theme.setEnabled(customizeButton, available)
	refreshCards()
end

local function makeCard(entry, order)
	local button = Theme.make("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		Text = "",
		LayoutOrder = order,
		Size = UDim2.new(1, -10, 0, 66),
		Selectable = true,
	}, list)
	Theme.corner(button, 8)
	local stroke = Theme.stroke(button, C.stroke, 1, 0.1)
	Theme.label(entry.name, {
		Font = Theme.fonts.heading,
		TextSize = 20,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -120, 0, 26),
	}, button)
	Theme.label(entry.role, {
		TextSize = 14,
		TextColor3 = C.dim,
		Position = UDim2.fromOffset(14, 34),
		Size = UDim2.new(1, -28, 0, 22),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, button)
	local tag = Theme.label("", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 10),
		Size = UDim2.fromOffset(110, 22),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, button)
	button.Activated:Connect(function()
		select(entry.id)
	end)
	button.SelectionGained:Connect(function()
		select(entry.id)
	end)
	cards[entry.id] = { button = button, tag = tag, stroke = stroke }
end

local function listenForProfile()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		return
	end
	local function apply(profile)
		if type(profile) == "table" and type(profile.hulls) == "table" then
			ownedHulls = profile.hulls
			if frame.Visible then
				select(menus.selectedShip)
			end
		end
	end
	local updated = remotes:FindFirstChild("ProfileUpdated")
	if updated and updated:IsA("RemoteEvent") then
		updated.OnClientEvent:Connect(apply)
	end
	local request = remotes:FindFirstChild("ShipyardRequest")
	if request and request:IsA("RemoteFunction") then
		task.spawn(function()
			local ok, profile = pcall(function()
				return request:InvokeServer("GetProfile")
			end)
			if ok then
				apply(profile)
			end
		end)
	end
end

local function stopLaunching()
	launching = false
	local id = menus.selectedShip
	launchButton.Text = if canLaunch(id) and not isOwned(id) then "Not owned" else "Launch"
	if frame.Visible then
		Theme.setEnabled(launchButton, canLaunch(id) and isOwned(id))
	end
end

function Hangar.build(canvas: Frame, Menus)
	menus = Menus
	frame = Theme.screen("Hangar", canvas)

	Theme.title("Hangar", frame, { Position = UDim2.fromOffset(40, 20), Size = UDim2.fromOffset(400, 44) })
	Theme.label("Pick a ship to launch", {
		TextColor3 = C.dim,
		Position = UDim2.fromOffset(40, 62),
		Size = UDim2.fromOffset(400, 22),
	}, frame)

	-- Ship list
	list = Theme.make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(40, 100),
		Size = UDim2.fromOffset(300, 430),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.stroke,
		Selectable = false,
	}, frame)
	Theme.list(list, 8)
	Theme.make("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }, list)
	for index, entry in ShipCatalog.entries do
		makeCard(entry, index)
	end

	-- Preview
	local previewPanel = Theme.panel({ Position = UDim2.fromOffset(360, 100), Size = UDim2.fromOffset(400, 300) }, frame)
	viewport = Theme.make("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(150, 160, 190),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-1, -1, -0.6),
	}, previewPanel)
	viewportCamera = Theme.make("Camera", {}, viewport)
	viewport.CurrentCamera = viewportCamera

	nameLabel = Theme.title("", frame, { Position = UDim2.fromOffset(360, 410), Size = UDim2.fromOffset(400, 36), TextSize = 28 })
	roleLabel = Theme.label("", {
		TextColor3 = C.accent,
		TextSize = 15,
		Position = UDim2.fromOffset(360, 446),
		Size = UDim2.fromOffset(400, 20),
	}, frame)
	blurbLabel = Theme.label("", {
		TextColor3 = C.dim,
		TextSize = 15,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(360, 470),
		Size = UDim2.fromOffset(400, 60),
	}, frame)

	-- Stats
	statsBox = Theme.panel({ Position = UDim2.fromOffset(780, 100), Size = UDim2.fromOffset(280, 430) }, frame)
	Theme.padding(statsBox, 16)
	Theme.list(statsBox, 10)
	Theme.label("Stats", { Font = Theme.fonts.heading, TextSize = 20, LayoutOrder = 0 }, statsBox)
	for index, row in STAT_ROWS do
		local holder = Theme.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = index }, statsBox)
		Theme.label(row.label, { TextSize = 15, TextColor3 = C.dim, Size = UDim2.new(0.6, 0, 0, 20) }, holder)
		local value = Theme.label("", {
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(0.5, 0, 0, 20),
		}, holder)
		local back = Theme.make("Frame", {
			BackgroundColor3 = C.panelLight,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, 0, 0, 8),
		}, holder)
		Theme.corner(back, 4)
		local fill = Theme.make("Frame", { BackgroundColor3 = C.accent, BorderSizePixel = 0, Size = UDim2.fromScale(0.5, 1) }, back)
		Theme.corner(fill, 4)
		statRows[row.key] = { value = value, fill = fill }
	end
	Theme.label("Weapons", { Font = Theme.fonts.heading, TextSize = 16, LayoutOrder = 10 }, statsBox)
	weaponsLabel = Theme.label("", {
		TextSize = 14,
		TextColor3 = C.dim,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 11,
		Size = UDim2.new(1, 0, 0, 140),
	}, statsBox)

	-- Bottom row
	Theme.button("Back", "secondary", function()
		Menus.back()
	end, { Position = UDim2.fromOffset(40, 550), Size = UDim2.fromOffset(160, 50) }, frame)
	customizeButton = Theme.button("Customize", "secondary", function()
		Menus.openShipyard(Menus.selectedShip)
	end, { Position = UDim2.fromOffset(700, 550), Size = UDim2.fromOffset(170, 50) }, frame)
	launchButton = Theme.button("Launch", "primary", function()
		if launching then
			return
		end
		launching = true
		launchButton.Text = "Launching..."
		Theme.setEnabled(launchButton, false)
		Menus.launch(Menus.selectedShip)
		-- If the server never answers, let the player try again.
		local token = {}
		launchTimeout = token
		task.delay(6, function()
			if launchTimeout == token and launching then
				stopLaunching()
			end
		end)
	end, { Position = UDim2.fromOffset(890, 550), Size = UDim2.fromOffset(170, 50), TextSize = 22 }, frame)

	listenForProfile()
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("ShipPreviews")
		local function onChange()
			if frame.Visible then
				select(menus.selectedShip)
			end
		end
		folder.ChildAdded:Connect(onChange)
		folder.ChildRemoved:Connect(onChange)
		onChange()
	end)
	return frame
end

function Hangar.open()
	stopLaunching()
	local id = menus.selectedShip
	if not canLaunch(id) then
		-- Fall back to the first launchable ship.
		for _, entry in ShipCatalog.entries do
			if canLaunch(entry.id) then
				id = entry.id
				break
			end
		end
	end
	select(id)
	return launchButton
end

function Hangar.close()
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
end

function Hangar.onNotice()
	if launching then
		stopLaunching()
	end
end

function Hangar.update(dt: number)
	if previewModel then
		spin += dt * 0.5
		previewModel:PivotTo(CFrame.Angles(0, spin, 0))
	end
end

return Hangar
