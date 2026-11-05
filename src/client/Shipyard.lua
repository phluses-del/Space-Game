--[[
	The shipyard screen: pick a hull, fit weapons, shield, engines and module
	cells, paint the ship, save up to a few loadouts per hull, buy what's
	missing in one click and launch.

	Everything is checked again on the server; this screen uses the same
	Outfitting rules only to show stats and problems as you change things.

	API for the menus:
		Shipyard.open(hull?)   show the screen, optionally on a hull
		Shipyard.close()
		Shipyard.isOpen()
		Shipyard.onClosed(callback)
		Shipyard.profile()     latest profile from the server, or nil
		Shipyard.onProfile(callback)  called with each new profile
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Outfitting = require(ReplicatedStorage.Shared.Outfitting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Shipyard = {}

--------------------------------------------------------------------------------
-- Style
--------------------------------------------------------------------------------

local WHITE = Color3.fromRGB(235, 240, 255)
local DIM = Color3.fromRGB(150, 160, 180)
local FAINT = Color3.fromRGB(95, 105, 125)
local ACCENT = Color3.fromRGB(90, 200, 255)
local GOOD = Color3.fromRGB(120, 230, 140)
local WARN = Color3.fromRGB(255, 200, 80)
local BAD = Color3.fromRGB(255, 100, 100)
local BG = Color3.fromRGB(8, 11, 20)
local PANEL = Color3.fromRGB(16, 21, 34)
local ROW = Color3.fromRGB(26, 33, 50)
local SELECTED = Color3.fromRGB(30, 70, 110)

local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

local TABS = { "Weapons", "Systems", "Modules", "Paint" }
local SLOT_KIND_NAMES = { Small = "Small", Medium = "Medium", Any = "Turret" }
local COSMETIC_NAMES = { paint = "Hull paint", trim = "Trim", glow = "Engine glow", trail = "Engine trail", finish = "Finish" }

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local player = Players.LocalPlayer
local profile = nil -- latest from the server
local profileCallbacks = {}
local closedCallbacks = {}

local gui = nil
local ui = {} -- named instances
local isOpen = false
local busy = false

local selectedHull = nil
local draft = nil -- the design being edited (clean, see Outfitting.sanitize)
local draftDirty = false
local tab = "Weapons"

--------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------

local function make(className, props, parent)
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function corner(parent, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
end

local function pad(parent, x, y)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, x),
		PaddingRight = UDim.new(0, x),
		PaddingTop = UDim.new(0, y),
		PaddingBottom = UDim.new(0, y),
	}, parent)
end

local function list(parent, spacing, horizontal)
	return make("UIListLayout", {
		Padding = UDim.new(0, spacing or 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
	}, parent)
end

local function label(text, props, parent)
	local l = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = WHITE,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = text,
		Size = UDim2.new(1, 0, 0, 18),
	}, parent)
	for key, value in props or {} do
		l[key] = value
	end
	return l
end

local function button(text, props, parent, onClick)
	local b = make("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = ROW,
		BorderSizePixel = 0,
		Font = FONT,
		TextColor3 = WHITE,
		TextSize = 14,
		Text = text,
		Size = UDim2.new(1, 0, 0, 32),
	}, parent)
	for key, value in props or {} do
		b[key] = value
	end
	corner(b, 5)
	local base = b.BackgroundColor3
	b.MouseEnter:Connect(function()
		if b.Active then
			b.BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.08)
		end
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = base
	end)
	if onClick then
		b.Activated:Connect(function()
			if b.Active then
				onClick()
			end
		end)
	end
	return b
end

local function setEnabled(b, enabled)
	b.Active = enabled
	b.AutoButtonColor = false
	b.TextTransparency = if enabled then 0 else 0.55
	b.BackgroundTransparency = if enabled then 0 else 0.4
end

local function clear(frame)
	for _, child in frame:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
end

local function credits(n)
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", "")) .. " cr"
end

local function hullSize(hull)
	local base = Config.Hulls[hull]
	return if base then base.size else Outfitting.Hulls[hull].shieldSize
end

local function owned(key)
	return profile and profile.items[key] or 0
end

local function isFree()
	return profile ~= nil and profile.freeMode
end

local function toast(text, color)
	if not ui.toast then
		return
	end
	ui.toast.Text = text
	ui.toast.TextColor3 = color or WHITE
	ui.toast.Visible = true
	local stamp = os.clock()
	ui.toastStamp = stamp
	task.delay(3, function()
		if ui.toastStamp == stamp and ui.toast then
			ui.toast.Visible = false
		end
	end)
end

--------------------------------------------------------------------------------
-- Server calls
--------------------------------------------------------------------------------

local function setProfile(newProfile)
	if type(newProfile) ~= "table" then
		return
	end
	profile = newProfile
	for _, callback in profileCallbacks do
		task.spawn(callback, profile)
	end
end

local function request(action, payload)
	if busy then
		return { ok = false, error = "Busy" }
	end
	busy = true
	local ok, result = pcall(function()
		return Remotes.ShipyardRequest:InvokeServer(action, payload)
	end)
	busy = false
	if not ok or type(result) ~= "table" then
		return { ok = false, error = "No answer from the server" }
	end
	setProfile(result.profile)
	return result
end

--------------------------------------------------------------------------------
-- Draft handling
--------------------------------------------------------------------------------

local function findDesign(id)
	if not profile then
		return nil
	end
	for _, design in profile.loadouts do
		if design.id == id then
			return design
		end
	end
	return nil
end

local function designsFor(hull)
	local result = {}
	if profile then
		for _, design in profile.loadouts do
			if design.hull == hull then
				table.insert(result, design)
			end
		end
	end
	return result
end

local function loadDraft(design)
	draft = Outfitting.sanitize(design) or Outfitting.stockDesign(selectedHull)
	draftDirty = false
end

local function selectHull(hull)
	selectedHull = hull
	local active = profile and findDesign(profile.active[hull])
	if active then
		loadDraft(active)
	else
		local stock = Outfitting.stockDesign(hull)
		stock.name = hull
		loadDraft(stock)
	end
end

local function changed()
	draftDirty = true
	Shipyard.refresh()
end

--------------------------------------------------------------------------------
-- Picker (a pop-over list of options for one slot)
--------------------------------------------------------------------------------

local function closePicker()
	if ui.picker then
		ui.picker:Destroy()
		ui.picker = nil
	end
end

--[[
	options: list of { text, detail, key?, price?, onPick, current? }.
	tiered: show Mk I to Mk IV buttons; getOptions(tier) rebuilds the list.
]]
local function openPicker(title, getOptions, startTier)
	closePicker()
	local tier = startTier or 1

	local overlay = make("TextButton", {
		Name = "Picker",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
	}, ui.main)
	overlay.Activated:Connect(closePicker)
	ui.picker = overlay

	local box = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 420, 0.8, 0),
		BackgroundColor3 = PANEL,
		ZIndex = 51,
	}, overlay)
	make("UISizeConstraint", { MaxSize = Vector2.new(math.huge, 520) }, box)
	corner(box, 8)
	pad(box, 12, 12)
	make("UIStroke", { Color = ACCENT, Transparency = 0.6 }, box)

	label(title, { Font = FONT_BOLD, TextSize = 18, Size = UDim2.new(1, -40, 0, 24), ZIndex = 52 }, box)
	button("X", { Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -28, 0, -2), ZIndex = 52 }, box, closePicker)

	local tierRow = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = 52,
	}, box)
	list(tierRow, 6, true)

	local scroll = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, if getOptions(nil) == "tiered" then 66 else 32),
		Size = UDim2.new(1, 0, 1, if getOptions(nil) == "tiered" then -66 else -32),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ZIndex = 52,
	}, box)
	list(scroll, 4)

	local function render()
		clear(tierRow)
		clear(scroll)
		if getOptions(nil) == "tiered" then
			for t = 1, #Outfitting.Tiers do
				local b = button(Outfitting.TierNames[t], {
					Size = UDim2.fromOffset(70, 26),
					BackgroundColor3 = if t == tier then SELECTED else ROW,
					ZIndex = 53,
				}, tierRow, function()
					tier = t
					render()
				end)
				b.LayoutOrder = t
			end
		else
			tierRow.Visible = false
		end

		for i, option in getOptions(tier) do
			local row = button("", {
				LayoutOrder = i,
				Size = UDim2.new(1, -8, 0, 46),
				BackgroundColor3 = if option.current then SELECTED else ROW,
				ZIndex = 53,
			}, scroll, function()
				option.onPick(tier)
				closePicker()
				changed()
			end)
			label(option.text, {
				Position = UDim2.fromOffset(10, 5),
				Size = UDim2.new(1, -130, 0, 18),
				Font = FONT_BOLD,
				ZIndex = 54,
			}, row)
			label(option.detail or "", {
				Position = UDim2.fromOffset(10, 24),
				Size = UDim2.new(1, -130, 0, 16),
				TextSize = 12,
				TextColor3 = DIM,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 54,
			}, row)
			local right, rightColor = "", DIM
			if option.key then
				local have = owned(option.key)
				if isFree() then
					right, rightColor = "free", GOOD
				elseif have > 0 then
					right, rightColor = "own " .. have, GOOD
				elseif option.price then
					right, rightColor = credits(option.price), WARN
				end
			elseif option.price then
				right, rightColor = if option.price > 0 then credits(option.price) else "free", if option.price > 0
					then WARN
					else GOOD
			end
			label(right, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 14),
				Size = UDim2.new(0, 110, 0, 18),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = rightColor,
				ZIndex = 54,
			}, row)
		end
	end
	render()
end

--------------------------------------------------------------------------------
-- Option builders
--------------------------------------------------------------------------------

local function weaponDetail(id, tier, mount)
	local weapon = Config.Weapons[id]
	local dps = (weapon.dps or 0) * (Config.TierMultiplier[tier] or 1)
	if Config.Slots[mount] then
		dps *= Config.Slots[mount].damageScale
	end
	local range = if weapon.optimal
		then string.format("%d/%d studs", weapon.optimal, weapon.range)
		else string.format("%d studs", weapon.range or 0)
	local extra = if weapon.class == "Energy"
		then string.format("draws %d power", math.floor((weapon.powerDraw or 0) * Outfitting.TierScale.energyDraw[tier]))
		else string.format("needs %d magazine", weapon.magazineCells or 1)
	return string.format(
		"%s · %.1f dps · %s · %s tracking · %s · reactor %d",
		weapon.class,
		dps,
		range,
		weapon.tracking or "?",
		extra,
		Outfitting.weaponReactor(id)
	)
end

local function pickWeapon(slotIndex)
	local slot = Outfitting.Hulls[draft.hull].weapons[slotIndex]
	local current = draft.weapons[slotIndex]
	openPicker("Weapon slot " .. slotIndex, function(tier)
		if tier == nil then
			return "tiered"
		end
		local options = {
			{
				text = "Empty",
				detail = "Leave this slot free to save reactor load",
				current = not current,
				onPick = function()
					draft.weapons[slotIndex] = false
				end,
			},
		}
		for _, option in Outfitting.weaponOptions(slot) do
			local weapon = Config.Weapons[option.id]
			local size = weapon.size or "Small"
			table.insert(options, {
				text = string.format("%s %s (%s)", Outfitting.displayName(option.id), Outfitting.TierNames[tier], option.mount),
				detail = weaponDetail(option.id, tier, option.mount),
				key = Outfitting.key(option.id, size, tier),
				price = Outfitting.price(option.id, size, tier),
				current = current and current.id == option.id and current.mount == option.mount and current.tier == tier,
				onPick = function(t)
					draft.weapons[slotIndex] = { id = option.id, tier = t, mount = option.mount }
				end,
			})
		end
		return options
	end, if current then current.tier else 1)
end

local function pickMissile()
	local current = draft.missile
	openPicker("Missile rack", function(tier)
		if tier == nil then
			return "tiered"
		end
		local options = {
			{
				text = "Empty",
				detail = "No missiles",
				current = not current,
				onPick = function()
					draft.missile = false
				end,
			},
		}
		for _, id in Outfitting.missileOptions() do
			local weapon = Config.Weapons[id]
			local size = weapon.size or "Small"
			table.insert(options, {
				text = Outfitting.displayName(id) .. " " .. Outfitting.TierNames[tier],
				detail = string.format("%s · reactor %d", weapon.class or "", Outfitting.weaponReactor(id)),
				key = Outfitting.key(id, size, tier),
				price = Outfitting.price(id, size, tier),
				current = current and current.id == id and current.tier == tier,
				onPick = function(t)
					draft.missile = { id = id, tier = t }
				end,
			})
		end
		return options
	end, if current then current.tier else 1)
end

local function pickShield()
	local size = hullSize(draft.hull)
	local current = draft.shield
	openPicker("Shield generator", function(tier)
		if tier == nil then
			return "tiered"
		end
		local options = {
			{
				text = "No shield",
				detail = "Frees reactor load; Energy weapons hit your hull directly",
				current = not current,
				onPick = function()
					draft.shield = false
				end,
			},
		}
		for _, id in Outfitting.ShieldOrder do
			local def = Outfitting.Shields[id]
			if def.pool[size] then
				table.insert(options, {
					text = def.name .. " " .. Outfitting.TierNames[tier],
					detail = string.format(
						"%d shield · reactor %g%s",
						math.floor(def.pool[size] * Outfitting.TierScale.shield[tier]),
						def.reactor * ({ Small = 1, Medium = 2, Large = 4, Capital = 8 })[size],
						if def.mass > 0.03 then " · heavy" else ""
					),
					key = Outfitting.key(id, size, tier),
					price = Outfitting.price(id, size, tier),
					current = current and current.id == id and current.tier == tier,
					onPick = function(t)
						draft.shield = { id = id, tier = t }
					end,
				})
			end
		end
		return options
	end, if current then current.tier else 1)
end

local function pickEngine(mountIndex)
	local size = hullSize(draft.hull)
	local current = draft.engines[mountIndex]
	openPicker("Engine mount " .. mountIndex, function(tier)
		if tier == nil then
			return "tiered"
		end
		local options = {
			{
				text = "Empty",
				detail = "Slower, but frees reactor load",
				current = not current,
				onPick = function()
					draft.engines[mountIndex] = false
				end,
			},
		}
		for _, id in Outfitting.EngineOrder do
			local def = Outfitting.Engines[id]
			local scale = Outfitting.TierScale.engine[tier]
			table.insert(options, {
				text = def.name .. " " .. Outfitting.TierNames[tier],
				detail = string.format(
					"thrust x%.2f · %d power output · reactor %g",
					def.thrust * scale,
					math.floor((Outfitting.EngineBaseOutput[size] or 100) * def.output * scale),
					def.reactor * ({ Small = 1, Medium = 2, Large = 4, Capital = 8 })[size]
				),
				key = Outfitting.key(id, size, tier),
				price = Outfitting.price(id, size, tier),
				current = current and current.id == id and current.tier == tier,
				onPick = function(t)
					local thrust = if current then current.thrust else 100
					draft.engines[mountIndex] = { id = id, tier = t, thrust = thrust }
				end,
			})
		end
		return options
	end, if current then current.tier else 1)
end

local function pickModule(cellIndex)
	local size = hullSize(draft.hull)
	local current = draft.modules[cellIndex]
	openPicker("Module cell " .. cellIndex, function(tier)
		if tier == nil then
			return "flat"
		end
		local options = {
			{
				text = "Empty",
				detail = "",
				current = not current,
				onPick = function()
					draft.modules[cellIndex] = false
				end,
			},
		}
		for _, id in Outfitting.ModuleOrder do
			local def = Outfitting.Modules[id]
			local itemSize = Outfitting.itemSize(id, size)
			local detail = if id == "ArmorPlate"
				then string.format(
					"+%d hull, -%d%% Kinetic damage (max %d%%), heavy",
					Config.Defense.armorHPPerPlate[size] or Config.Defense.armorHPPerPlate.Large,
					Config.Defense.armorReductionPerPlate * 100,
					Config.Defense.armorReductionCap * 100
				)
				else "Feeds one small Kinetic gun; cooks off if knocked out"
			table.insert(options, {
				text = def.name,
				detail = detail .. string.format(" · reactor %g", def.reactor),
				key = Outfitting.key(id, itemSize, 1),
				price = Outfitting.price(id, itemSize, 1),
				current = current == id,
				onPick = function()
					draft.modules[cellIndex] = id
				end,
			})
		end
		return options
	end, 1)
end

--------------------------------------------------------------------------------
-- Building the screen
--------------------------------------------------------------------------------

local function sectionTitle(text, parent, order)
	return label(text, { Font = FONT_BOLD, TextSize = 13, TextColor3 = DIM, LayoutOrder = order }, parent)
end

-- A row showing one slot and what's in it; clicking opens its picker.
local function slotRow(parent, order, title, content, detail, key, onClick)
	local row = button("", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 50),
		BackgroundColor3 = ROW,
	}, parent, onClick)
	label(title, {
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(0.5, 0, 0, 14),
		TextSize = 11,
		TextColor3 = FAINT,
	}, row)
	label(content, {
		Position = UDim2.fromOffset(10, 18),
		Size = UDim2.new(1, -120, 0, 16),
		Font = FONT_BOLD,
		TextColor3 = if content == "Empty" then FAINT else WHITE,
	}, row)
	label(detail or "", {
		Position = UDim2.fromOffset(10, 34),
		Size = UDim2.new(1, -120, 0, 14),
		TextSize = 11,
		TextColor3 = DIM,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)
	if key then
		local used = Outfitting.itemsUsed(draft)[key] or 0
		local have = owned(key)
		local text, color
		if isFree() then
			text, color = "", GOOD
		elseif have >= used then
			text, color = "owned", GOOD
		else
			text, color = "not owned", WARN
		end
		label(text, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 18),
			Size = UDim2.new(0, 100, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = 12,
			TextColor3 = color,
		}, row)
	end
	return row
end

local function renderWeapons(content)
	local def = Outfitting.Hulls[draft.hull]
	local size = hullSize(draft.hull)
	sectionTitle("WEAPON SLOTS", content, 0)
	for i, slot in def.weapons do
		local fit = draft.weapons[i]
		local title = string.format("SLOT %d · %s (%s)", i, SLOT_KIND_NAMES[slot.size] or slot.size, table.concat(slot.mounts, " or "))
		if fit then
			local weapon = Config.Weapons[fit.id]
			slotRow(
				content,
				i,
				title,
				string.format("%s %s · %s", Outfitting.displayName(fit.id), Outfitting.TierNames[fit.tier], fit.mount),
				weaponDetail(fit.id, fit.tier, fit.mount),
				Outfitting.key(fit.id, weapon.size or "Small", fit.tier),
				function()
					pickWeapon(i)
				end
			)
		else
			slotRow(content, i, title, "Empty", "Click to fit a weapon", nil, function()
				pickWeapon(i)
			end)
		end
	end
	if def.missileRack then
		local fit = draft.missile
		local options = Outfitting.missileOptions()
		local row = slotRow(
			content,
			100,
			"MISSILE RACK",
			if fit then Outfitting.displayName(fit.id) .. " " .. Outfitting.TierNames[fit.tier] else "Empty",
			if #options == 0 then "No missiles available yet" else "Pilot-fired, limited ammo",
			if fit then Outfitting.key(fit.id, Config.Weapons[fit.id].size or "Small", fit.tier) else nil,
			pickMissile
		)
		setEnabled(row, #options > 0 or fit ~= false)
	end
	label(
		string.format(
			"Fixed: narrow cone, full damage. Gimbal: wider cone, %d%% less damage. Turrets track on their own.",
			(1 - Config.Slots.Gimbal.damageScale) * 100
		),
		{ LayoutOrder = 200, TextSize = 12, TextColor3 = FAINT, Size = UDim2.new(1, -8, 0, 32) },
		content
	)
	local _ = size
end

local function renderSystems(content)
	local def = Outfitting.Hulls[draft.hull]
	local size = hullSize(draft.hull)

	sectionTitle("SHIELD", content, 0)
	local shield = draft.shield
	if shield then
		local s = Outfitting.Shields[shield.id]
		slotRow(
			content,
			1,
			"SHIELD GENERATOR · " .. size,
			s.name .. " " .. Outfitting.TierNames[shield.tier],
			string.format("%d shield, recharges after %d s without Energy hits", math.floor(s.pool[size] * Outfitting.TierScale.shield[shield.tier]), Config.Defense.shieldRechargeDelay),
			Outfitting.key(shield.id, size, shield.tier),
			pickShield
		)
	else
		slotRow(content, 1, "SHIELD GENERATOR · " .. size, "Empty", "No shield fitted", nil, pickShield)
	end

	sectionTitle("ENGINES", content, 10)
	for i = 1, def.engineMounts do
		local fit = draft.engines[i]
		if fit then
			local e = Outfitting.Engines[fit.id]
			local holder = make("Frame", { BackgroundTransparency = 1, LayoutOrder = 10 + i * 2, Size = UDim2.new(1, -8, 0, 50) }, content)
			local row = slotRow(
				holder,
				0,
				string.format("ENGINE MOUNT %d · %s", i, size),
				e.name .. " " .. Outfitting.TierNames[fit.tier],
				string.format("thrust x%.2f", e.thrust * Outfitting.TierScale.engine[fit.tier]),
				Outfitting.key(fit.id, size, fit.tier),
				function()
					pickEngine(i)
				end
			)
			row.Size = UDim2.new(1, -150, 1, 0)

			-- Thrust slider as - / + buttons, 60 to 120 percent.
			local t = Outfitting.Thrust
			local minus = button("-", { Size = UDim2.fromOffset(32, 50), Position = UDim2.new(1, -140, 0, 0) }, holder, function()
				fit.thrust = math.max(t.min, fit.thrust - t.step)
				changed()
			end)
			local value = label(fit.thrust .. "%", {
				Position = UDim2.new(1, -106, 0, 0),
				Size = UDim2.fromOffset(60, 50),
				TextXAlignment = Enum.TextXAlignment.Center,
				Font = FONT_BOLD,
				TextColor3 = if fit.thrust > 100 then WARN elseif fit.thrust < 100 then ACCENT else WHITE,
			}, holder)
			local plus = button("+", { Size = UDim2.fromOffset(32, 50), Position = UDim2.new(1, -44, 0, 0) }, holder, function()
				fit.thrust = math.min(t.max, fit.thrust + t.step)
				changed()
			end)
			setEnabled(minus, fit.thrust > t.min)
			setEnabled(plus, fit.thrust < t.max)
			local _ = value
		else
			slotRow(content, 10 + i * 2, string.format("ENGINE MOUNT %d · %s", i, size), "Empty", "Click to fit an engine", nil, function()
				pickEngine(i)
			end)
		end
	end
	label(
		"Thrust above 100% costs extra reactor load. Below 100% saves it. Engine power output (for plasma guns) doesn't change with thrust.",
		{ LayoutOrder = 100, TextSize = 12, TextColor3 = FAINT, Size = UDim2.new(1, -8, 0, 32) },
		content
	)
end

local function renderModules(content)
	local def = Outfitting.Hulls[draft.hull]
	local size = hullSize(draft.hull)
	sectionTitle("MODULE CELLS", content, 0)
	for i = 1, def.moduleCells do
		local id = draft.modules[i]
		if id then
			local m = Outfitting.Modules[id]
			slotRow(content, i, "CELL " .. i, m.name, "", Outfitting.key(id, Outfitting.itemSize(id, size), 1), function()
				pickModule(i)
			end)
		else
			slotRow(content, i, "CELL " .. i, "Empty", "Armor plate or ammo magazine", nil, function()
				pickModule(i)
			end)
		end
	end
	label(
		"Kinetic guns need a magazine each. Armor adds hull and cuts Kinetic damage but slows the ship. Cargo, mining and utility modules come later.",
		{ LayoutOrder = 200, TextSize = 12, TextColor3 = FAINT, Size = UDim2.new(1, -8, 0, 32) },
		content
	)
end

local function renderPaint(content)
	local order = 0
	for _, slot in Outfitting.CosmeticSlots do
		order += 1
		sectionTitle(string.upper(COSMETIC_NAMES[slot]), content, order)
		order += 1
		local grid = make("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, content)
		make("UIGridLayout", {
			CellSize = UDim2.fromOffset(92, 54),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, grid)

		local entries = Outfitting.Cosmetics[if slot == "trim" then "paint" else slot]
		for i, entry in entries do
			local key = Outfitting.cosmeticKey(slot, entry.id)
			local unlocked = entry.price <= 0 or isFree() or (profile and profile.cosmetics[key])
			local selected = draft.cosmetics[slot] == entry.id
			local cell = button("", {
				LayoutOrder = i,
				BackgroundColor3 = if selected then SELECTED else ROW,
			}, grid, function()
				draft.cosmetics[slot] = entry.id
				changed()
			end)
			if selected then
				make("UIStroke", { Color = ACCENT, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, cell)
			end
			if entry.rgb then
				local swatch = make("Frame", {
					Position = UDim2.fromOffset(6, 6),
					Size = UDim2.new(1, -12, 0, 20),
					BackgroundColor3 = Color3.fromRGB(entry.rgb[1], entry.rgb[2], entry.rgb[3]),
					BorderSizePixel = 0,
				}, cell)
				corner(swatch, 4)
			else
				label(slot == "trail" and (entry.length > 0 and string.rep("~", math.ceil(entry.length * 8)) or "-") or entry.material, {
					Position = UDim2.fromOffset(6, 6),
					Size = UDim2.new(1, -12, 0, 20),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = DIM,
					TextSize = 12,
				}, cell)
			end
			label(entry.name, {
				Position = UDim2.fromOffset(4, 28),
				Size = UDim2.new(1, -8, 0, 12),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 11,
			}, cell)
			label(if unlocked then "" else credits(entry.price), {
				Position = UDim2.fromOffset(4, 40),
				Size = UDim2.new(1, -8, 0, 12),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 10,
				TextColor3 = WARN,
			}, cell)
		end
	end
end

local function statLine(parent, order, name, value, color)
	local row = make("Frame", { BackgroundTransparency = 1, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 18) }, parent)
	label(name, { Size = UDim2.new(0.55, 0, 1, 0), TextColor3 = DIM, TextSize = 13 }, row)
	label(value, {
		Position = UDim2.fromScale(0.55, 0),
		Size = UDim2.new(0.45, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 13,
		TextColor3 = color or WHITE,
		Font = FONT_BOLD,
	}, row)
end

local function meter(parent, order, name, used, max)
	local holder = make("Frame", { BackgroundTransparency = 1, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 34) }, parent)
	local over = used > max
	label(name, { Size = UDim2.new(0.5, 0, 0, 16), TextColor3 = DIM, TextSize = 13 }, holder)
	label(string.format("%g / %g", used, max), {
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0.5, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 13,
		Font = FONT_BOLD,
		TextColor3 = if over then BAD else WHITE,
	}, holder)
	local back = make("Frame", {
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = ROW,
		BorderSizePixel = 0,
	}, holder)
	corner(back, 4)
	local fill = make("Frame", {
		Size = UDim2.fromScale(math.clamp(used / math.max(max, 1), 0, 1), 1),
		BackgroundColor3 = if over then BAD elseif used / max > 0.85 then WARN else ACCENT,
		BorderSizePixel = 0,
	}, back)
	corner(fill, 4)
end

local function renderStats()
	local panel = ui.stats
	clear(panel)
	local stats = Outfitting.stats(draft)
	local base = Config.Hulls[draft.hull]

	meter(panel, 1, "Reactor load", stats.reactorUsed, stats.reactorMax)
	sectionTitle("COMBAT", panel, 10)
	statLine(panel, 11, "Damage per second", string.format("%.1f", stats.dps))
	statLine(
		panel,
		12,
		"Plasma fire rate",
		string.format("%d%%", math.floor(stats.plasmaRate * 100 + 0.5)),
		if stats.plasmaRate < 1 then WARN else WHITE
	)
	statLine(panel, 13, "Engine power", string.format("%d / %d", stats.engineOutput, math.floor(stats.energyDraw)))
	statLine(
		panel,
		14,
		"Magazines",
		string.format("%d / %d", stats.magazineCells, stats.magazineCellsNeeded),
		if stats.magazineCells < stats.magazineCellsNeeded then BAD else WHITE
	)
	sectionTitle("DEFENSE", panel, 20)
	statLine(panel, 21, "Shield", tostring(stats.shieldHP))
	statLine(panel, 22, "Hull", tostring(stats.hullHP))
	statLine(panel, 23, "Kinetic armor", string.format("%d%%", stats.armorReduction * 100))
	sectionTitle("HANDLING", panel, 30)
	if base then
		local function vs(value, stock)
			if value > stock + 0.5 then
				return GOOD
			elseif value < stock - 0.5 then
				return WARN
			end
			return WHITE
		end
		statLine(panel, 31, "Top speed", string.format("%d", stats.topSpeed), vs(stats.topSpeed, base.topSpeed))
		statLine(panel, 32, "Acceleration", string.format("%d", stats.accel), vs(stats.accel, base.accel))
		statLine(panel, 33, "Turn rate", string.format("%g°/s", stats.turnRate), vs(stats.turnRate, base.turnRate))
		statLine(panel, 34, "Strafe", string.format("%d", stats.strafeSpeed), vs(stats.strafeSpeed, base.strafeSpeed))
	end

	local problems = Outfitting.problems(draft, stats)
	local order = 40
	for _, problem in problems do
		order += 1
		label("• " .. problem, { LayoutOrder = order, TextColor3 = BAD, TextSize = 13, Size = UDim2.new(1, 0, 0, 32) }, panel)
	end

	local missingCost = 0
	if profile and not isFree() then
		local _, itemCost = Outfitting.missingItems(draft, profile.items)
		local _, cosmeticCost = Outfitting.missingCosmetics(draft, profile.cosmetics)
		missingCost = itemCost + cosmeticCost
	end
	if missingCost > 0 then
		label("Parts to buy: " .. credits(missingCost), {
			LayoutOrder = 60,
			TextColor3 = WARN,
			TextSize = 13,
			Font = FONT_BOLD,
		}, panel)
	end

	return problems, missingCost
end

local function renderHulls()
	local panel = ui.hulls
	clear(panel)
	for i, hull in Outfitting.HullOrder do
		local def = Outfitting.Hulls[hull]
		local available = Outfitting.hullAvailable(hull)
		local own = profile and profile.hulls[hull]
		local row = button("", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = if hull == selectedHull then SELECTED else ROW,
		}, panel, function()
			if not available then
				return
			end
			if hull == selectedHull then
				return
			end
			if draftDirty then
				toast("Unsaved changes to " .. draft.name .. " were dropped", WARN)
			end
			-- Unowned hulls open as a preview with a Buy button.
			selectHull(hull)
			Shipyard.refresh()
		end)
		label(hull, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 18), Font = FONT_BOLD }, row)
		local sub, color
		if not available then
			sub, color = "Coming soon", FAINT
		elseif own then
			local active = findDesign(profile.active[hull])
			sub, color = if active then active.name else "Stock fit", DIM
		else
			sub, color = "Buy · " .. credits(def.price), WARN
		end
		label(sub, { Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -20, 0, 14), TextSize = 12, TextColor3 = color }, row)
		if not available then
			setEnabled(row, false)
		end
	end
end

local function renderLoadouts()
	local panel = ui.loadouts
	clear(panel)
	local designs = designsFor(selectedHull)
	if not profile.hulls[selectedHull] then
		label("Buy this hull to save loadouts for it. You can try fits first.", {
			TextSize = 12,
			TextColor3 = FAINT,
			Size = UDim2.new(1, 0, 0, 32),
		}, panel)
		return
	end
	for i, design in designs do
		local isActive = profile.active[selectedHull] == design.id
		local isEditing = draft.id == design.id
		local row = button("", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = if isEditing then SELECTED else ROW,
		}, panel, function()
			loadDraft(design)
			Shipyard.refresh()
		end)
		label((if isActive then "★ " else "") .. design.name, {
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -16, 1, 0),
			TextSize = 13,
			TextColor3 = if isActive then ACCENT else WHITE,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, row)
	end
	local limit = profile and profile.loadoutsPerHull or 3
	if #designs < limit then
		button("+ New loadout", { LayoutOrder = 100, Size = UDim2.new(1, 0, 0, 28), TextSize = 13, TextColor3 = ACCENT }, panel, function()
			local stock = Outfitting.stockDesign(selectedHull)
			stock.name = selectedHull .. " " .. (#designs + 1)
			loadDraft(stock)
			draftDirty = true
			Shipyard.refresh()
		end)
	end
	label(string.format("%d of %d loadout slots used", #designs, limit), {
		LayoutOrder = 101,
		TextSize = 11,
		TextColor3 = FAINT,
	}, panel)
end

function Shipyard.refresh()
	if not (gui and isOpen and draft and profile) then
		return
	end
	closePicker()

	ui.credits.Text = if isFree() then "Free mode" else credits(profile.credits)
	ui.saveWarning.Visible = not profile.persistent

	renderHulls()
	renderLoadouts()

	for name, b in ui.tabs do
		b.BackgroundColor3 = if name == tab then SELECTED else ROW
	end
	local content = ui.content
	clear(content)
	if tab == "Weapons" then
		renderWeapons(content)
	elseif tab == "Systems" then
		renderSystems(content)
	elseif tab == "Modules" then
		renderModules(content)
	else
		renderPaint(content)
	end

	if not ui.nameBox:IsFocused() then
		ui.nameBox.Text = draft.name
	end

	local problems, missingCost = renderStats()
	local isSaved = draft.id ~= "" and findDesign(draft.id) ~= nil
	local isActive = isSaved and profile.active[draft.hull] == draft.id

	ui.saveButton.Text = if isSaved then (if draftDirty then "Save changes" else "Saved") else "Save as new loadout"
	setEnabled(ui.saveButton, draftDirty or not isSaved)
	ui.deleteButton.Visible = isSaved
	ui.refitButton.Visible = missingCost > 0
	ui.refitButton.Text = "Buy missing parts · " .. credits(missingCost)
	setEnabled(ui.refitButton, missingCost > 0 and (isFree() or profile.credits >= missingCost))
	local ownsHull = profile.hulls[draft.hull] == true
	if ownsHull then
		ui.launchButton.Text = if isActive and not draftDirty then "Launch" else "Save, set active and launch"
		setEnabled(ui.launchButton, #problems == 0 and missingCost == 0)
	else
		local price = Outfitting.Hulls[draft.hull].price
		ui.launchButton.Text = "Buy the " .. draft.hull .. " · " .. credits(price)
		setEnabled(ui.launchButton, isFree() or profile.credits >= price)
		setEnabled(ui.saveButton, false)
		ui.refitButton.Visible = false
	end
end

-- Saves the draft; returns true on success.
local function saveDraft()
	local result = request("SaveDesign", draft)
	if not result.ok then
		toast(result.error or "Couldn't save", BAD)
		return false
	end
	local saved = findDesign(result.id)
	if saved then
		loadDraft(saved)
	end
	return true
end

local function build()
	gui = make("ScreenGui", {
		Name = "Shipyard",
		DisplayOrder = 20,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	local backdrop = make("Frame", {
		BackgroundColor3 = BG,
		BackgroundTransparency = 0.25,
		Size = UDim2.fromScale(1, 1),
	}, gui)

	local main = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -32, 1, -32),
		BackgroundColor3 = BG,
	}, backdrop)
	make("UISizeConstraint", { MaxSize = Vector2.new(1180, 760) }, main)
	corner(main, 10)
	make("UIStroke", { Color = ACCENT, Transparency = 0.75 }, main)
	ui.main = main

	-- Top bar
	label("SHIPYARD", {
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(0, 200, 0, 28),
		Font = FONT_BOLD,
		TextSize = 22,
	}, main)
	ui.credits = label("", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -60, 0, 14),
		Size = UDim2.new(0, 200, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = FONT_BOLD,
		TextSize = 18,
		TextColor3 = WARN,
	}, main)
	ui.saveWarning = label("Progress isn't being saved on this server", {
		Position = UDim2.fromOffset(180, 16),
		Size = UDim2.new(0, 320, 0, 20),
		TextSize = 12,
		TextColor3 = BAD,
		Visible = false,
	}, main)
	button("X", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(36, 32),
		Font = FONT_BOLD,
	}, main, function()
		Shipyard.close()
	end)

	local body = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 52),
		Size = UDim2.new(1, -24, 1, -64),
	}, main)

	-- Left: hulls and loadouts
	local left = make("Frame", {
		BackgroundColor3 = PANEL,
		Size = UDim2.new(0, 200, 1, 0),
	}, body)
	corner(left, 8)
	pad(left, 8, 8)
	label("HULLS", { Font = FONT_BOLD, TextSize = 13, TextColor3 = DIM, Size = UDim2.new(1, 0, 0, 16) }, left)
	ui.hulls = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0.5, -24),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
	}, left)
	list(ui.hulls, 4)
	label("LOADOUTS", {
		Font = FONT_BOLD,
		TextSize = 13,
		TextColor3 = DIM,
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 16),
	}, left)
	ui.loadouts = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0.5, 20),
		Size = UDim2.new(1, 0, 0.5, -20),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
	}, left)
	list(ui.loadouts, 4)

	-- Right: stats and actions
	local right = make("Frame", {
		BackgroundColor3 = PANEL,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 260, 1, 0),
	}, body)
	corner(right, 8)
	pad(right, 10, 10)

	ui.nameBox = make("TextBox", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = ROW,
		BorderSizePixel = 0,
		Font = FONT_BOLD,
		TextSize = 15,
		TextColor3 = WHITE,
		PlaceholderText = "Loadout name",
		PlaceholderColor3 = FAINT,
		ClearTextOnFocus = false,
		Text = "",
	}, right)
	corner(ui.nameBox, 5)
	ui.nameBox.FocusLost:Connect(function()
		if draft then
			local name = string.sub(ui.nameBox.Text, 1, Outfitting.Settings.maxNameLength)
			if name ~= "" and name ~= draft.name then
				draft.name = name
				changed()
			else
				ui.nameBox.Text = draft.name
			end
		end
	end)

	ui.stats = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -40 - 4 * 38),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
	}, right)
	list(ui.stats, 3)

	local actions = make("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 4 * 38 - 6),
	}, right)
	list(actions, 6)

	ui.refitButton = button("", { LayoutOrder = 1, BackgroundColor3 = Color3.fromRGB(90, 70, 20) }, actions, function()
		local result = request("Refit", draft)
		if result.ok then
			toast(string.format("Bought missing parts for %s", credits(result.cost or 0)), GOOD)
		else
			toast(result.error or "Couldn't buy parts", BAD)
		end
		Shipyard.refresh()
	end)
	local saveRow = make("Frame", { BackgroundTransparency = 1, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 32) }, actions)
	ui.saveButton = button("Save", { Size = UDim2.new(1, -78, 1, 0) }, saveRow, function()
		if saveDraft() then
			toast("Saved " .. draft.name, GOOD)
		end
		Shipyard.refresh()
	end)
	ui.deleteButton = button("Delete", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 72, 1, 0),
		TextColor3 = BAD,
	}, saveRow, function()
		local name = draft.name
		local result = request("DeleteDesign", draft.id)
		if result.ok then
			toast("Deleted " .. name, WARN)
			selectHull(selectedHull)
		else
			toast(result.error or "Couldn't delete", BAD)
		end
		Shipyard.refresh()
	end)
	ui.launchButton = button("Launch", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Color3.fromRGB(30, 110, 70),
		Font = FONT_BOLD,
		TextSize = 16,
	}, actions, function()
		if not profile.hulls[draft.hull] then
			local hull = draft.hull
			local result = request("BuyHull", hull)
			if result.ok then
				toast("Bought the " .. hull .. ", with its stock fit", GOOD)
				selectHull(hull)
			else
				toast(result.error or "Couldn't buy that", BAD)
			end
			Shipyard.refresh()
			return
		end
		if draftDirty or draft.id == "" or not findDesign(draft.id) then
			if not saveDraft() then
				Shipyard.refresh()
				return
			end
		end
		if profile.active[draft.hull] ~= draft.id then
			local result = request("SetActive", draft.id)
			if not result.ok then
				toast(result.error or "Couldn't set active", BAD)
				Shipyard.refresh()
				return
			end
		end
		local result = request("Launch", draft.hull)
		if result.ok then
			Shipyard.close()
		else
			toast(result.error or "Couldn't launch", BAD)
			Shipyard.refresh()
		end
	end)

	-- Middle: tabs and slot editor
	local middle = make("Frame", {
		BackgroundColor3 = PANEL,
		Position = UDim2.fromOffset(212, 0),
		Size = UDim2.new(1, -212 - 272, 1, 0),
	}, body)
	corner(middle, 8)
	pad(middle, 10, 10)

	local tabRow = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32) }, middle)
	list(tabRow, 6, true)
	ui.tabs = {}
	for i, name in TABS do
		ui.tabs[name] = button(name, {
			LayoutOrder = i,
			Size = UDim2.new(1 / #TABS, -5, 1, 0),
			Font = FONT_BOLD,
		}, tabRow, function()
			tab = name
			Shipyard.refresh()
		end)
	end

	ui.content = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -42),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
	}, middle)
	list(ui.content, 6)

	ui.toast = label("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0, 420, 0, 32),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.05,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = FONT_BOLD,
		Visible = false,
		ZIndex = 60,
	}, main)
	corner(ui.toast, 6)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function Shipyard.open(hull: string?)
	if not gui then
		build()
	end
	if not profile then
		request("GetProfile")
	end
	if not profile then
		warn("[Shipyard] Couldn't load your profile")
		return
	end
	isOpen = true
	gui.Enabled = true
	-- An unowned hull opens too, so the player can look it over and buy it.
	local target = hull or selectedHull or profile.lastHull
	if not (target and Outfitting.hullAvailable(target)) then
		target = Outfitting.Settings.starterHulls[1]
	end
	if target ~= selectedHull or not draft then
		selectHull(target)
	end
	Shipyard.refresh()
end

function Shipyard.close()
	if not isOpen then
		return
	end
	isOpen = false
	closePicker()
	if gui then
		gui.Enabled = false
	end
	for _, callback in closedCallbacks do
		task.spawn(callback)
	end
end

function Shipyard.isOpen(): boolean
	return isOpen
end

function Shipyard.onClosed(callback)
	table.insert(closedCallbacks, callback)
end

function Shipyard.profile()
	return profile
end

function Shipyard.onProfile(callback)
	table.insert(profileCallbacks, callback)
end

Remotes.ProfileUpdated.OnClientEvent:Connect(function(newProfile)
	setProfile(newProfile)
	if isOpen then
		Shipyard.refresh()
	end
end)

return Shipyard
