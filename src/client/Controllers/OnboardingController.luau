--!strict
-- Primeros pasos: lista de tareas para el jugador nuevo que se completa sola al jugar.
-- Enseña los controles con práctica real (pilar sentirse inteligente) y lleva al jugador
-- hasta la puerta del coliseo en sus primeros minutos (pilar progreso). Solo aparece
-- para quien aún no ha vencido a la Hidra y está en nivel 1.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Bus = require(script.Parent.Parent.UI.Bus)
local I18n = require(script.Parent.Parent.UI.I18n)
local NetClient = require(ReplicatedStorage.Shared.Net.Client)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local F = Theme.Fonts

-- Cada paso usa la clave onboarding.<id> de Shared/Locale.
local STEPS = { "hit", "dodge", "block", "parry", "arena" }

local localPlayer = Players.LocalPlayer

local OnboardingController = {}

local gui: ScreenGui? = nil
local titleLabel: TextLabel? = nil
local rows: { [string]: TextLabel } = {}
local done: { [string]: boolean } = {}
local active = false
local allDone = false

local function rowText(id: string): string
	return `{if done[id] then "✔" else "○"}  {I18n.t(`onboarding.{id}`)}`
end

local function relabel()
	local title = titleLabel
	if title then
		title.Text = I18n.t(if allDone then "onboarding.done" else "onboarding.title")
	end
	for id, row in rows do
		row.Text = rowText(id)
	end
end

local function finish()
	local screen = gui
	if screen == nil then
		return
	end
	active = false
	task.delay(4, function()
		screen:Destroy()
		gui = nil
	end)
end

local function complete(id: string)
	if not active or done[id] then
		return
	end
	done[id] = true
	local row = rows[id]
	if row then
		row.Text = rowText(id)
		row.TextColor3 = C.Green
		TweenService:Create(row, TweenInfo.new(0.3), { TextTransparency = 0.3 }):Play()
	end
	for _, step in STEPS do
		if not done[step] then
			return
		end
	end
	allDone = true
	relabel()
	finish()
end

local function build()
	local screen = Theme.create("ScreenGui", { Name = "Onboarding", ResetOnSpawn = false })
	local panel = Theme.panel({
		Size = UDim2.fromOffset(340, 40 + #STEPS * 26),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.45, 0),
	}, screen)
	titleLabel = Theme.label({
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.fromOffset(10, 8),
		Font = F.Title,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = I18n.t("onboarding.title"),
	}, panel)
	for index, step in STEPS do
		rows[step] = Theme.label({
			Size = UDim2.new(1, -20, 0, 22),
			Position = UDim2.fromOffset(10, 10 + index * 26),
			TextScaled = false,
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = F.Heading,
			Text = rowText(step),
		}, panel)
	end
	screen.Parent = localPlayer:WaitForChild("PlayerGui")
	gui = screen
end

local function onProfile(profile: { [string]: any })
	-- Solo para quien empieza: nivel 1 y sin victorias.
	local isNew = (profile.level or 1) <= 1 and (profile.hydraKills or 0) == 0
	if isNew and gui == nil and not allDone then
		build()
		active = true
	elseif not isNew and gui ~= nil and active then
		finish()
	end
end

function OnboardingController.Start(_self: typeof(OnboardingController))
	Bus.Profile:Connect(onProfile)
	I18n.Changed:Connect(relabel)

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
