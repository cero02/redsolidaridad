--!strict
-- Interfaz de combate: barras de vida, aguante y gloria (la definitiva: el favor del
-- público se gana combatiendo), textos de esencia y definitiva, y un mensaje central.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Theme = require(script.Parent.Theme)

local C = Theme.Colors
local F = Theme.Fonts
local BAR_WIDTH = 250
local BAR_HEIGHT = 14
local MESSAGE_TIME = 0.9

local BARS = {
	{ name = "Health", label = "VIDA", color = Color3.fromRGB(196, 46, 40) },
	{ name = "Stamina", label = "AGUANTE", color = Color3.fromRGB(84, 170, 92) },
	{ name = "Ultimate", label = "GLORIA", color = Color3.fromRGB(235, 185, 60) },
}

local CombatHud = {}

local fills: { [string]: Frame } = {}
local message: TextLabel? = nil
local essenceLabel: TextLabel? = nil
local ultimateLabel: TextLabel? = nil
local ultimateGlow: UIStroke? = nil
local messageToken = 0

function CombatHud.create()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Theme.create("ScreenGui", { Name = "CombatHud", ResetOnSpawn = false })

	local panel = Theme.panel({
		Size = UDim2.fromOffset(BAR_WIDTH + 96, 3 * (BAR_HEIGHT + 8) + 52),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
	}, gui)

	for index, bar in BARS do
		local y = 10 + (index - 1) * (BAR_HEIGHT + 8)
		Theme.label({
			Size = UDim2.fromOffset(70, BAR_HEIGHT),
			Position = UDim2.fromOffset(10, y),
			Font = F.Bold,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = bar.label,
		}, panel)
		local back = Theme.create("Frame", {
			Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT),
			Position = UDim2.fromOffset(84, y),
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
		}, panel)
		Theme.corner(back, 4)
		local fill = Theme.create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = bar.color,
			BorderSizePixel = 0,
		}, back)
		Theme.corner(fill, 4)
		Theme.create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)),
		}, fill)
		fills[bar.name] = fill
		if bar.name == "Ultimate" then
			local glow = Theme.create("UIStroke", { Color = C.Gold, Thickness = 2, Transparency = 1 }, back)
			ultimateGlow = glow
		end
	end

	local abilityY = 10 + 3 * (BAR_HEIGHT + 8)
	essenceLabel = Theme.label({
		Size = UDim2.new(1, -20, 0, 16),
		Position = UDim2.fromOffset(10, abilityY),
		Font = F.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Text,
		Text = "",
	}, panel)
	ultimateLabel = Theme.label({
		Size = UDim2.new(1, -20, 0, 16),
		Position = UDim2.fromOffset(10, abilityY + 18),
		Font = F.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Muted,
		Text = "",
	}, panel)

	message = Theme.label({
		Name = "Message",
		Size = UDim2.fromOffset(560, 52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Font = F.Title,
		TextStrokeTransparency = 0.1,
		Text = "",
	}, gui)

	gui.Parent = playerGui
end

local function setBar(name: string, value: number, max: number)
	local fill = fills[name]
	if fill then
		fill.Size = UDim2.fromScale(math.clamp(value / math.max(max, 1), 0, 1), 1)
	end
end

function CombatHud.update(health: number, stamina: number, ultimate: number, maxStamina: number?)
	setBar("Health", health, Combat.MAX_HEALTH)
	setBar("Stamina", stamina, maxStamina or Combat.MAX_STAMINA)
	setBar("Ultimate", ultimate, Combat.ULTIMATE_MAX)
end

-- Texto de la esencia y de la definitiva bajo las barras.
function CombatHud.updateAbilities(essenceText: string, ultimateText: string, ultimateReady: boolean)
	local essence, ultimate, glow = essenceLabel, ultimateLabel, ultimateGlow
	if essence then
		essence.Text = essenceText
	end
	if ultimate then
		ultimate.Text = ultimateText
		ultimate.TextColor3 = if ultimateReady then C.Gold else C.Muted
	end
	if glow then
		-- La barra de gloria late cuando la definitiva está lista.
		glow.Transparency = if ultimateReady then 0.2 + 0.5 * (0.5 + 0.5 * math.sin(os.clock() * 6)) else 1
	end
end

function CombatHud.showMessage(text: string, color: Color3?)
	local labelRef = message
	if labelRef == nil then
		return
	end
	messageToken += 1
	local token = messageToken
	labelRef.Text = text
	labelRef.TextColor3 = color or C.Text
	labelRef.TextTransparency = 0
	labelRef.Size = UDim2.fromOffset(500, 46)
	TweenService:Create(labelRef, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(560, 52) }):Play()
	task.delay(MESSAGE_TIME, function()
		if messageToken == token then
			TweenService:Create(labelRef, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
		end
	end)
end

return CombatHud
