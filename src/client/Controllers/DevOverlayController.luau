--!strict
-- Solo en Studio: panel rojo con los errores del cliente y del servidor, para poder hacer
-- una captura y enviarla. En el juego publicado no aparece.

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local I18n = require(script.Parent.Parent.UI.I18n)
local NetClient = require(ReplicatedStorage.Shared.Net.Client)
local Theme = require(script.Parent.Parent.UI.Theme)

local MAX_LINES = 6
local MAX_LENGTH = 220

local DevOverlayController = {}

local panel: Frame? = nil
local list: Frame? = nil
local lines: { string } = {}

local function render()
	local frame, container = panel, list
	if frame == nil or container == nil then
		return
	end
	for _, child in container:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for index, text in lines do
		Theme.label({
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 30),
			TextScaled = false,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Font = Enum.Font.Code,
			TextColor3 = Color3.fromRGB(255, 220, 220),
			Text = text,
		}, container)
	end
	frame.Visible = #lines > 0
end

local function add(text: string)
	-- Sin duplicados seguidos (un error en bucle llenaría el panel).
	if lines[#lines] == text then
		return
	end
	table.insert(lines, string.sub(text, 1, MAX_LENGTH))
	while #lines > MAX_LINES do
		table.remove(lines, 1)
	end
	render()
end

local function build()
	local gui =
		Theme.create("ScreenGui", { Name = "DevOverlay", ResetOnSpawn = false, DisplayOrder = 100 })
	local frame = Theme.create("Frame", {
		Size = UDim2.fromOffset(560, 230),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		BackgroundColor3 = Color3.fromRGB(110, 16, 16),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	Theme.corner(frame, 8)
	Theme.label({
		Size = UDim2.new(1, -50, 0, 20),
		Position = UDim2.fromOffset(10, 6),
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = I18n.t("dev.errors"),
	}, frame)
	local close = Theme.create("TextButton", {
		Size = UDim2.fromOffset(28, 22),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 6),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Text = "✕",
	}, frame)
	close.Activated:Connect(function()
		table.clear(lines)
		render()
	end)
	local container = Theme.create("Frame", {
		Size = UDim2.new(1, -20, 1, -34),
		Position = UDim2.fromOffset(10, 30),
		BackgroundTransparency = 1,
	}, frame)
	Theme.create(
		"UIListLayout",
		{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) },
		container
	)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	panel = frame
	list = container
end

function DevOverlayController.Start(_self: typeof(DevOverlayController))
	if not RunService:IsStudio() then
		return
	end
	build()
	for _, entry in LogService:GetLogHistory() do
		if entry.messageType == Enum.MessageType.MessageError then
			add(`[client] {entry.message}`)
		end
	end
	LogService.MessageOut:Connect(function(message: string, messageType: Enum.MessageType)
		local problem = messageType == Enum.MessageType.MessageError
			or (
				messageType == Enum.MessageType.MessageWarning
				and string.find(message, "ERROR", 1, true) ~= nil
			)
		if problem then
			add(`[client] {message}`)
		end
	end)
	NetClient.on("DevLog", add)
end

return DevOverlayController
