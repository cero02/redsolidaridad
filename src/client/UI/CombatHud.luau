--!strict
-- Interfaz mínima de combate (hito 1.1): barras de vida, aguante y definitiva, y un
-- mensaje central breve. Provisional: el diseño visual definitivo llegará más adelante.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)

local BAR_WIDTH = 260
local BAR_HEIGHT = 14
local MESSAGE_TIME = 0.9

local CombatHud = {}

local bars: { [string]: Frame } = {}
local message: TextLabel? = nil
local essenceLabel: TextLabel? = nil
local ultimateLabel: TextLabel? = nil
local messageToken = 0

local function createBar(parent: Instance, name: string, order: number, color: Color3)
	local back = Instance.new("Frame")
	back.Name = name
	back.Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT)
	back.Position = UDim2.new(0, 16, 1, -(16 + (4 - order) * (BAR_HEIGHT + 6)))
	back.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	back.BackgroundTransparency = 0.3
	back.BorderSizePixel = 0
	back.Parent = parent

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back

	bars[name] = fill
end

function CombatHud.create()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatHud"
	gui.ResetOnSpawn = false

	createBar(gui, "Health", 1, Color3.fromRGB(200, 50, 50))
	createBar(gui, "Stamina", 2, Color3.fromRGB(70, 180, 90))
	createBar(gui, "Ultimate", 3, Color3.fromRGB(230, 180, 50))

	local text = Instance.new("TextLabel")
	text.Name = "Message"
	text.Size = UDim2.fromOffset(500, 48)
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.3)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0
	text.Font = Enum.Font.GothamBold
	text.Text = ""
	text.Parent = gui
	message = text

	for index, name in { "Essence", "Ultimate" } do
		local ability = Instance.new("TextLabel")
		ability.Name = name
		ability.Size = UDim2.fromOffset(BAR_WIDTH, 18)
		ability.Position = UDim2.new(0, 16 + BAR_WIDTH + 12, 1, -(16 + (4 - index) * (BAR_HEIGHT + 6)) - 2)
		ability.BackgroundTransparency = 1
		ability.TextScaled = true
		ability.TextXAlignment = Enum.TextXAlignment.Left
		ability.Font = Enum.Font.GothamBold
		ability.TextColor3 = Color3.fromRGB(220, 220, 220)
		ability.TextStrokeTransparency = 0.3
		ability.Text = ""
		ability.Parent = gui
		if name == "Essence" then
			essenceLabel = ability
		else
			ultimateLabel = ability
		end
	end

	gui.Parent = playerGui
end

local function setBar(name: string, value: number, max: number)
	local fill = bars[name]
	if fill then
		fill.Size = UDim2.fromScale(math.clamp(value / max, 0, 1), 1)
	end
end

function CombatHud.update(health: number, stamina: number, ultimate: number, maxStamina: number?)
	setBar("Health", health, Combat.MAX_HEALTH)
	setBar("Stamina", stamina, maxStamina or Combat.MAX_STAMINA)
	setBar("Ultimate", ultimate, Combat.ULTIMATE_MAX)
end

-- Texto de la esencia y de la definitiva junto a las barras.
function CombatHud.updateAbilities(essenceText: string, ultimateText: string, ultimateReady: boolean)
	local essence, ultimate = essenceLabel, ultimateLabel
	if essence then
		essence.Text = essenceText
	end
	if ultimate then
		ultimate.Text = ultimateText
		ultimate.TextColor3 = if ultimateReady then Color3.fromRGB(255, 215, 80) else Color3.fromRGB(220, 220, 220)
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
	labelRef.TextColor3 = color or Color3.new(1, 1, 1)
	task.delay(MESSAGE_TIME, function()
		if messageToken == token then
			labelRef.Text = ""
		end
	end)
end

return CombatHud
