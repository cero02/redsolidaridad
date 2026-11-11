--!strict
-- Primeros pasos: lista de tareas para el jugador nuevo que se completa sola al jugar.
-- Enseña los controles con práctica real (pilar sentirse inteligente) y lleva al jugador
-- hasta la puerta del coliseo en sus primeros minutos (pilar progreso). Solo aparece
-- para quien aún no ha vencido a la Hidra y está en nivel 1.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NetClient = require(ReplicatedStorage.Shared.Net.Client)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local F = Theme.Fonts

type Step = { id: string, text: string }

local STEPS: { Step } = {
	{ id = "hit", text = "Golpea al muñeco del ludus (clic izquierdo)" },
	{ id = "dodge", text = "Esquiva con Q" },
	{ id = "block", text = "Bloquea manteniendo clic derecho" },
	{ id = "parry", text = "Parada perfecta: bloquea justo antes de su golpe" },
	{ id = "arena", text = "Cruza la puerta dorada del Gran Coliseo" },
}

local localPlayer = Players.LocalPlayer

local OnboardingController = {}

local gui: ScreenGui? = nil
local rows: { [string]: TextLabel } = {}
local done: { [string]: boolean } = {}
local active = false

local function finish()
	local screen = gui
	if screen == nil then
		return
	end
	active = false
	task.delay(4, function()
		screen:Destroy()
	end)
end

local function complete(id: string)
	if not active or done[id] then
		return
	end
	done[id] = true
	local row = rows[id]
	if row then
		row.Text = `✔  {row:GetAttribute("Text")}`
		row.TextColor3 = C.Green
		TweenService:Create(row, TweenInfo.new(0.3), { TextTransparency = 0.35 }):Play()
	end
	for _, step in STEPS do
		if not done[step.id] then
			return
		end
	end
	local screen = gui
	local title = if screen then screen:FindFirstChild("Title", true) else nil
	if title and title:IsA("TextLabel") then
		title.Text = "¡LISTO, GLADIADOR! LA HIDRA TE ESPERA"
	end
	finish()
end

local function build()
	local screen = Theme.create("ScreenGui", { Name = "Onboarding", ResetOnSpawn = false })
	local panel = Theme.panel({
		Size = UDim2.fromOffset(330, 36 + #STEPS * 26),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.45, 0),
	}, screen)
	Theme.label({
		Name = "Title",
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.fromOffset(10, 8),
		Font = F.Title,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "PRIMEROS PASOS",
	}, panel)
	for index, step in STEPS do
		local row = Theme.label({
			Size = UDim2.new(1, -20, 0, 22),
			Position = UDim2.fromOffset(10, 8 + index * 26),
			TextScaled = false,
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = F.Body,
			Text = `○  {step.text}`,
		}, panel)
		row:SetAttribute("Text", step.text)
		rows[step.id] = row
	end
	screen.Parent = localPlayer:WaitForChild("PlayerGui")
	gui = screen
end

local function onProfile(profile: { [string]: any })
	-- Solo para quien empieza: nivel 1 y sin victorias.
	local isNew = (profile.level or 1) <= 1 and (profile.hydraKills or 0) == 0
	if isNew and gui == nil then
		build()
		active = true
	elseif not isNew and gui ~= nil and active then
		finish()
	end
end

function OnboardingController.Start(_self: typeof(OnboardingController))
	NetClient.on("ProfileReady", onProfile)
	NetClient.on("ProgressUpdate", onProfile)

	NetClient.on("CombatEvent", function(kind: string, userId: number, a: any)
		if userId ~= localPlayer.UserId then
			return
		end
		if kind == "Hit" then
			complete("hit")
		elseif kind == "Dodge" then
			complete("dodge")
		elseif kind == "Block" and a == true then
			complete("block")
		elseif kind == "Defense" and a == "Parried" then
			complete("parry")
		end
	end)
	NetClient.on("EncounterState", function(state: string)
		if state == "Intro" or state == "Fighting" then
			complete("arena")
		end
	end)
end

return OnboardingController
