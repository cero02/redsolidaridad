--!strict
-- Estilo visual de COLOSSEUM: "bronce imperial". Paleta, tipografías y componentes
-- comunes (paneles, botones, textos) para que toda la interfaz se vea como una sola.

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Colors = table.freeze({
	Ink = Color3.fromRGB(16, 12, 10),
	Panel = Color3.fromRGB(30, 21, 16),
	PanelLight = Color3.fromRGB(52, 36, 26),
	Gold = Color3.fromRGB(255, 205, 110),
	GoldDark = Color3.fromRGB(176, 124, 46),
	Bronze = Color3.fromRGB(150, 98, 52),
	Red = Color3.fromRGB(150, 28, 28),
	RedLight = Color3.fromRGB(205, 60, 50),
	Marble = Color3.fromRGB(236, 228, 214),
	Text = Color3.fromRGB(246, 238, 224),
	Muted = Color3.fromRGB(170, 158, 140),
	Green = Color3.fromRGB(140, 220, 130),
	Purple = Color3.fromRGB(205, 160, 255),
})

Theme.Fonts = table.freeze({
	Title = Enum.Font.Antique,
	Heading = Enum.Font.Garamond,
	Body = Enum.Font.Gotham,
	Bold = Enum.Font.GothamBold,
})

local C = Theme.Colors

-- Crea una instancia con propiedades. `Parent` se asigna al final.
function Theme.create(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Theme.corner(parent: Instance, radius: number?)
	Theme.create("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
end

function Theme.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?)
	Theme.create("UIStroke", {
		Color = color or C.GoldDark,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

-- Panel oscuro con degradado y borde de bronce.
function Theme.panel(props: { [string]: any }, parent: Instance?): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or C.Panel
	props.BackgroundTransparency = props.BackgroundTransparency or 0.12
	props.BorderSizePixel = 0
	local frame = Theme.create("Frame", props, parent)
	Theme.corner(frame, 10)
	Theme.stroke(frame)
	Theme.create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 160, 150)),
	}, frame)
	return frame
end

function Theme.label(props: { [string]: any }, parent: Instance?): TextLabel
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or C.Text
	props.Font = props.Font or Theme.Fonts.Body
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.6
	if props.TextSize == nil then
		props.TextScaled = true
	end
	return Theme.create("TextLabel", props, parent)
end

-- Botón con estilo: "primary" (rojo imperial), "secondary" (bronce) o "ghost".
function Theme.button(text: string, style: string, props: { [string]: any }, parent: Instance?): TextButton
	local base = if style == "primary" then C.Red elseif style == "secondary" then C.PanelLight else C.Panel
	props.Text = text
	props.BackgroundColor3 = base
	props.BackgroundTransparency = if style == "ghost" then 0.4 else 0.05
	props.BorderSizePixel = 0
	props.AutoButtonColor = false
	props.Font = props.Font or Theme.Fonts.Heading
	props.TextColor3 = props.TextColor3 or (if style == "primary" then C.Gold else C.Text)
	props.TextScaled = true
	local button: TextButton = Theme.create("TextButton", props, parent)
	Theme.corner(button, 8)
	Theme.stroke(button, if style == "primary" then C.Gold else C.GoldDark, 1.5, 0.15)
	Theme.create("UIPadding", {
		PaddingTop = UDim.new(0.18, 0),
		PaddingBottom = UDim.new(0.18, 0),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}, button)

	-- Al pasar el ratón, el botón se ilumina; al pulsar, se hunde un poco.
	local hover = base:Lerp(C.Gold, 0.18)
	local info = TweenInfo.new(0.12)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, info, { BackgroundColor3 = hover }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, info, { BackgroundColor3 = base }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(button, info, { BackgroundColor3 = base:Lerp(Color3.new(0, 0, 0), 0.25) }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(button, info, { BackgroundColor3 = hover }):Play()
	end)
	return button
end

-- Línea decorativa dorada (separador).
function Theme.divider(props: { [string]: any }, parent: Instance?): Frame
	props.BackgroundColor3 = C.GoldDark
	props.BorderSizePixel = 0
	props.Size = props.Size or UDim2.new(1, 0, 0, 2)
	local line: Frame = Theme.create("Frame", props, parent)
	Theme.create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, line)
	return line
end

return Theme
