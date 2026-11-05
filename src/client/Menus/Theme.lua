--[[
	Colours, fonts and small builders shared by every menu screen, so the
	screens look like one game and a restyle is an edit here.

	Screens are laid out on a fixed 1100 x 620 canvas that Menus scales to fit
	the window, so one layout works on phones, PCs and TVs.
]]

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.CANVAS = Vector2.new(1100, 620)

Theme.colors = {
	text = Color3.fromRGB(235, 240, 255),
	dim = Color3.fromRGB(150, 160, 185),
	faint = Color3.fromRGB(95, 105, 130),
	panel = Color3.fromRGB(12, 17, 30),
	panelLight = Color3.fromRGB(24, 32, 52),
	stroke = Color3.fromRGB(55, 70, 100),
	accent = Color3.fromRGB(90, 200, 255), -- matches the HUD's shield blue
	accentDark = Color3.fromRGB(30, 95, 140),
	highlight = Color3.fromRGB(255, 160, 70), -- matches the engine glow
	danger = Color3.fromRGB(255, 95, 95),
	good = Color3.fromRGB(120, 230, 150),
	backdrop = Color3.fromRGB(4, 6, 14),
}

Theme.fonts = {
	title = Enum.Font.GothamBlack,
	heading = Enum.Font.GothamBold,
	body = Enum.Font.GothamMedium,
}

local C = Theme.colors

function Theme.make(className: string, props: { [string]: any }, parent: Instance?)
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end
local make = Theme.make

function Theme.corner(parent: Instance, radius: number?)
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
end

function Theme.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?)
	return make("UIStroke", {
		Color = color or C.stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function Theme.padding(parent: Instance, all: number)
	return make("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
	}, parent)
end

function Theme.list(parent: Instance, gap: number?, horizontal: boolean?)
	return make("UIListLayout", {
		Padding = UDim.new(0, gap or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
	}, parent)
end

function Theme.label(text: string, props: { [string]: any }?, parent: Instance?)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.fonts.body,
		TextColor3 = C.text,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		Text = text,
		Size = UDim2.new(1, 0, 0, 24),
	}
	for key, value in props or {} do
		defaults[key] = value
	end
	return make("TextLabel", defaults, parent)
end

function Theme.panel(props: { [string]: any }?, parent: Instance?)
	local frame = make("Frame", {
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, nil)
	for key, value in props or {} do
		frame[key] = value
	end
	Theme.corner(frame, 10)
	Theme.stroke(frame, C.stroke, 1, 0.3)
	frame.Parent = parent
	return frame
end

-- A full-canvas frame for one screen, hidden until opened.
function Theme.screen(name: string, parent: Instance)
	return make("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}, parent)
end

function Theme.title(text: string, parent: Instance, props: { [string]: any }?)
	local defaults = {
		Font = Theme.fonts.heading,
		TextSize = 34,
		Size = UDim2.new(1, 0, 0, 44),
	}
	for key, value in props or {} do
		defaults[key] = value
	end
	return Theme.label(text, defaults, parent)
end

local STYLES = {
	primary = { fill = C.accent, hover = Color3.fromRGB(150, 225, 255), text = C.backdrop, stroke = C.accent },
	secondary = { fill = C.panelLight, hover = Color3.fromRGB(40, 52, 80), text = C.text, stroke = C.stroke },
	danger = { fill = Color3.fromRGB(70, 24, 30), hover = Color3.fromRGB(110, 34, 42), text = C.text, stroke = C.danger },
}

--[[
	A menu button with hover, gamepad-selection and disabled looks.
	Returns the TextButton; call Theme.setEnabled(button, false) to grey it out.
]]
function Theme.button(text: string, style: string?, onClick: (() -> ())?, props: { [string]: any }?, parent: Instance?)
	local look = STYLES[style or "secondary"]
	local button = make("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = look.fill,
		BorderSizePixel = 0,
		Font = Theme.fonts.heading,
		Text = text,
		TextColor3 = look.text,
		TextSize = 20,
		Size = UDim2.new(1, 0, 0, 48),
		Selectable = true,
	}, nil)
	for key, value in props or {} do
		button[key] = value
	end
	Theme.corner(button, 8)
	local stroke = Theme.stroke(button, look.stroke, 1.5, 0.2)
	button:SetAttribute("Enabled", true)

	local function paint(hovered: boolean)
		local enabled = button:GetAttribute("Enabled")
		local fill = if not enabled then C.panel elseif hovered then look.hover else look.fill
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = fill }):Play()
		button.TextColor3 = if enabled then look.text else C.faint
		stroke.Color = if hovered and enabled then C.highlight else look.stroke
	end

	button.MouseEnter:Connect(function()
		paint(true)
	end)
	button.MouseLeave:Connect(function()
		paint(false)
	end)
	button.SelectionGained:Connect(function()
		paint(true)
	end)
	button.SelectionLost:Connect(function()
		paint(false)
	end)
	button:GetAttributeChangedSignal("Enabled"):Connect(function()
		paint(false)
	end)
	if onClick then
		button.Activated:Connect(function()
			if button:GetAttribute("Enabled") then
				onClick()
			end
		end)
	end
	button.Parent = parent
	return button
end

function Theme.setEnabled(button: GuiButton, enabled: boolean)
	button:SetAttribute("Enabled", enabled)
end

-- "PulseBlaster" -> "Pulse Blaster"
function Theme.spaced(name: string): string
	return (string.gsub(name, "(%l)(%u)", "%1 %2"))
end

return Theme
