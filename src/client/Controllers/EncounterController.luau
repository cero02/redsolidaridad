--!strict
-- Muestra la voz del anunciador del coliseo y el progreso del combate contra la bestia.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetClient = require(ReplicatedStorage.Shared.Net.Client)

local GOLD = Color3.fromRGB(255, 215, 110)

local EncounterController = {}

local announcer: TextLabel
local title: TextLabel
local announceToken = 0

local function makeLabel(parent: Instance, name: string, size: UDim2, position: UDim2, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = font
	label.TextColor3 = GOLD
	label.TextStrokeTransparency = 0
	label.Text = ""
	label.Parent = parent
	return label
end

local function onAnnounce(text: string, seconds: number)
	announceToken += 1
	local token = announceToken
	announcer.Text = text
	task.delay(seconds, function()
		if announceToken == token then
			announcer.Text = ""
		end
	end)
end

local function onEncounterState(state: string, progress: string)
	if state == "Idle" then
		title.Text = ""
	elseif state == "Intro" then
		title.Text = "LA HIDRA DE LERNA"
	elseif state == "Ending" then
		title.Text = "LA HIDRA DE LERNA · Fin del combate"
	else
		title.Text = `LA HIDRA DE LERNA · {progress}`
	end
end

function EncounterController.Start(_self: typeof(EncounterController))
	local gui = Instance.new("ScreenGui")
	gui.Name = "EncounterHud"
	gui.ResetOnSpawn = false

	title = makeLabel(gui, "Title", UDim2.new(0.6, 0, 0, 30), UDim2.new(0.5, 0, 0, 44), Enum.Font.GothamBold)
	title.TextColor3 = Color3.new(1, 1, 1)
	announcer = makeLabel(gui, "Announcer", UDim2.new(0.8, 0, 0, 64), UDim2.fromScale(0.5, 0.14), Enum.Font.Garamond)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	NetClient.on("Announce", onAnnounce)
	NetClient.on("EncounterState", onEncounterState)
end

return EncounterController
