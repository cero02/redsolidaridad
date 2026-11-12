--!strict
-- Voz del anunciador del coliseo y progreso del combate contra la bestia, en el idioma del
-- jugador. Los mensajes llegan como claves (Shared/Locale) y se traducen aquí.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local I18n = require(script.Parent.Parent.UI.I18n)
local NetClient = require(ReplicatedStorage.Shared.Net.Client)
local Settings = require(script.Parent.Parent.UI.Settings)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local F = Theme.Fonts
local t = I18n.t

local EncounterController = {}

local announcer: TextLabel
local title: TextLabel
local announceToken = 0
-- Último estado recibido, para redibujar al cambiar de idioma.
local current = { state = "Idle", progressKey = "", progressParams = nil :: any }
local currentAnnounce: { key: string, params: any }? = nil

local function renderTitle()
	local state = current.state
	if state == "Idle" then
		title.Text = ""
	elseif state == "Intro" or current.progressKey == "" then
		title.Text = t("encounter.title")
	elseif state == "Ending" then
		title.Text = t("encounter.ending")
	else
		title.Text = t("encounter.withProgress", {
			progress = { key = current.progressKey, params = current.progressParams },
		})
	end
end

local function onAnnounce(key: string, params: any, seconds: number)
	announceToken += 1
	local token = announceToken
	currentAnnounce = { key = key, params = params }
	announcer.Text = t(key, params)
	announcer.TextTransparency = 1
	TweenService:Create(announcer, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	task.delay(seconds, function()
		if announceToken == token then
			currentAnnounce = nil
			TweenService:Create(announcer, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

-- Temblor largo mientras la Hidra emerge del estanque.
local function rumble(seconds: number, magnitude: number)
	if not Settings.get("cameraShake") then
		return
	end
	task.spawn(function()
		local character = Players.LocalPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid == nil then
			return
		end
		local start = os.clock()
		while os.clock() - start < seconds do
			local fade = 1 - (os.clock() - start) / seconds
			humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * magnitude * fade
			RunService.RenderStepped:Wait()
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

local function onEncounterState(state: string, progressKey: string?, progressParams: any)
	if state == "Intro" and current.state ~= "Intro" then
		rumble(3.5, 0.8)
	end
	current.state = state
	current.progressKey = progressKey or ""
	current.progressParams = progressParams
	renderTitle()
end

function EncounterController.Start(_self: typeof(EncounterController))
	local gui = Theme.create("ScreenGui", { Name = "EncounterHud", ResetOnSpawn = false })

	title = Theme.label({
		Name = "Title",
		Size = UDim2.new(0.6, 0, 0, 28),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Font = F.Title,
		TextColor3 = C.Marble,
		TextStrokeTransparency = 0.3,
		Text = "",
	}, gui)
	announcer = Theme.label({
		Name = "Announcer",
		Size = UDim2.new(0.8, 0, 0, 60),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.14),
		TextWrapped = true,
		Font = F.Heading,
		TextColor3 = C.Gold,
		TextStrokeTransparency = 0.1,
		Text = "",
	}, gui)
	Theme.create("UISizeConstraint", { MaxSize = Vector2.new(900, 60) }, announcer)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	NetClient.on("Announce", onAnnounce)
	NetClient.on("EncounterState", onEncounterState)
	I18n.Changed:Connect(function()
		renderTitle()
		local active = currentAnnounce
		if active then
			announcer.Text = t(active.key, active.params)
		end
	end)
end

return EncounterController
