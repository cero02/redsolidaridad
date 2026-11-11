--!strict
-- Pantalla de inicio: lo primero que ve el jugador. Cámara que sobrevuela el Gran
-- Coliseo, título, ficha del gladiador (progreso y presumir), edicto de la semana y Juegos
-- Imperiales (FOMO sano) y botones: Luchar, Armería, Códice y Ajustes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Codex = require(ReplicatedStorage.Shared.Config.Codex)
local DecreeCalendar = require(ReplicatedStorage.Shared.Meta.DecreeCalendar)
local MetaController = require(script.Parent.MetaController)
local NetClient = require(ReplicatedStorage.Shared.Net.Client)
local Progression = require(ReplicatedStorage.Shared.Meta.Progression)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.Progression)
local Settings = require(script.Parent.Parent.UI.Settings)
local Theme = require(script.Parent.Parent.UI.Theme)
local Titles = require(ReplicatedStorage.Shared.Config.Titles)
local Version = require(ReplicatedStorage.Shared.Version)

local C = Theme.Colors
local F = Theme.Fonts
local CAMERA_STEP = "ColosseumMenuCamera"
local ORBIT_RADIUS = 115
local ORBIT_HEIGHT = 48
local ORBIT_SPEED = 0.06
-- Interfaces del juego que se ocultan mientras el menú está abierto.
local GAME_GUIS = { MetaHud = true, CombatHud = true, EncounterHud = true, MenuButton = true, Onboarding = true }

local localPlayer = Players.LocalPlayer
local config = ProgressionConfig :: any

local MainMenuController = {}

local gui: ScreenGui
local fade: Frame
local settingsPanel: Frame
local cardName: TextLabel
local cardTitle: TextLabel
local cardRank: TextLabel
local cardXpFill: Frame
local cardXpText: TextLabel
local cardStats: TextLabel
local decreeName: TextLabel
local decreeText: TextLabel
local gamesText: TextLabel
local menuButtonGui: ScreenGui
local open = false
local orbitAngle = 0
local decreeEndsAt = 0
local gamesEndsAt = 0

local function formatTime(seconds: number): string
	local whole = math.floor(seconds)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function setGameGuis(enabled: boolean)
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	for _, child in playerGui:GetChildren() do
		if child:IsA("ScreenGui") and GAME_GUIS[child.Name] then
			child.Enabled = enabled
		end
	end
	menuButtonGui.Enabled = enabled
end

local function setControls(enabled: boolean)
	-- Módulo de control estándar de Roblox (PlayerScripts.PlayerModule).
	pcall(function()
		local playerModule = require(localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: any) :: any
		local controls = playerModule:GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

local function arenaCenter(): Vector3
	local arena = Workspace:FindFirstChild("GranColiseo")
	local sand = if arena then arena:FindFirstChild("Sand") else nil
	if sand and sand:IsA("BasePart") then
		return sand.Position
	end
	return Vector3.new(0, 0, -200)
end

local function startCamera()
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local center = arenaCenter()
	RunService:BindToRenderStep(CAMERA_STEP, Enum.RenderPriority.Camera.Value + 1, function(deltaTime: number)
		orbitAngle += deltaTime * ORBIT_SPEED
		local position = center + Vector3.new(math.cos(orbitAngle) * ORBIT_RADIUS, ORBIT_HEIGHT, math.sin(orbitAngle) * ORBIT_RADIUS)
		camera.CFrame = CFrame.lookAt(position, center + Vector3.new(0, 6, 0))
	end)
end

local function stopCamera()
	RunService:UnbindFromRenderStep(CAMERA_STEP)
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

-- Fundido a negro, cambio y vuelta a la imagen.
local function fadeThen(action: () -> ())
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad)
	fade.Visible = true
	fade.BackgroundTransparency = 1
	local fadeIn = TweenService:Create(fade, info, { BackgroundTransparency = 0 })
	fadeIn:Play()
	fadeIn.Completed:Wait()
	action()
	local fadeOut = TweenService:Create(fade, info, { BackgroundTransparency = 1 })
	fadeOut:Play()
	fadeOut.Completed:Wait()
	fade.Visible = false
end

local function closeMenu(after: (() -> ())?)
	if not open then
		return
	end
	open = false
	task.spawn(fadeThen, function()
		gui.Enabled = false
		settingsPanel.Visible = false
		stopCamera()
		setControls(true)
		setGameGuis(true)
		if after then
			after()
		end
	end)
end

local function openMenu()
	if open then
		return
	end
	if localPlayer:GetAttribute("InArena") == true then
		return
	end
	open = true
	task.spawn(fadeThen, function()
		setGameGuis(false)
		setControls(false)
		startCamera()
		gui.Enabled = true
	end)
end

-- Ficha del gladiador -------------------------------------------------------------

local function onProfile(profile: { [string]: any })
	cardName.Text = string.upper(localPlayer.DisplayName)
	local title = Titles[profile.equippedTitle or ""]
	cardTitle.Text = if title then `«{title.name}»` else ""
	if title then
		cardTitle.TextColor3 = Color3.fromRGB(title.color[1], title.color[2], title.color[3])
	end
	local level = profile.level or 1
	local rank = Progression.rankFor(config, level)
	cardRank.Text = `Nivel {level} · {rank.name}`
	local needed = Progression.xpToNext(config, level)
	local xp = profile.xp or 0
	cardXpFill.Size = UDim2.fromScale(if needed > 0 then math.clamp(xp / needed, 0, 1) else 1, 1)
	local nextLevel, unlocks = Progression.nextUnlock(config, level)
	cardXpText.Text = if needed > 0
		then `{xp}/{needed} XP` .. (if nextLevel and unlocks then ` · Nv {nextLevel}: {unlocks[1].name}` else "")
		else "Nivel máximo: eres una leyenda"
	local best = profile.bestHydraTime or 0
	local codexCount = if profile.codex then #profile.codex else 0
	cardStats.Text = `Hidras vencidas: {profile.hydraKills or 0}   ·   Mejor tiempo: `
		.. (if best > 0 then formatTime(best) else "—")
		.. `\nCódice: {codexCount}/{#Codex} secretos`
end

local function onWorldEvents(state: { [string]: any })
	decreeEndsAt = os.clock() + (state.decreeRemaining or 0)
	gamesEndsAt = os.clock() + (state.gamesRemaining or 0)
	decreeName.Text = state.decreeName or ""
	decreeText.Text = state.decreeDescription or ""
end

local function tick()
	while true do
		if open then
			local now = os.clock()
			local remaining = math.max(0, decreeEndsAt - now)
			local games = math.max(0, gamesEndsAt - now)
			if games > 0 then
				gamesText.Text = `¡JUEGOS IMPERIALES EN CURSO! Experiencia ×2 · {formatTime(games)}`
				gamesText.TextColor3 = C.Gold
			elseif decreeEndsAt > 0 then
				gamesText.Text = `El edicto cambia en {DecreeCalendar.formatRemaining(remaining)}`
				gamesText.TextColor3 = C.Muted
			end
		end
		task.wait(0.5)
	end
end

-- Construcción -------------------------------------------------------------------

local function toggleRow(parent: Instance, order: number, text: string, setting: string)
	local row = Theme.create("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
	}, parent)
	Theme.label({
		Size = UDim2.fromScale(0.7, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = F.Heading,
		Text = text,
	}, row)
	local button = Theme.button("", "secondary", {
		Size = UDim2.fromScale(0.28, 0.8),
		Position = UDim2.fromScale(0.72, 0.1),
	}, row)
	local function refresh()
		local on = Settings.get(setting)
		button.Text = if on then "SÍ" else "NO"
		button.TextColor3 = if on then C.Gold else C.Muted
	end
	button.Activated:Connect(function()
		Settings.toggle(setting)
		refresh()
	end)
	refresh()
end

local function build()
	gui = Theme.create("ScreenGui", {
		Name = "MainMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		Enabled = false,
	})

	-- Viñeta: oscurece los bordes para que el texto se lea sobre el coliseo.
	local vignette = Theme.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}, gui)
	Theme.create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.45, 0.65),
			NumberSequenceKeypoint.new(0.62, 0.9),
			NumberSequenceKeypoint.new(1, 0.25),
		}),
	}, vignette)

	-- Columna izquierda: título y botones.
	local left = Theme.create("Frame", {
		Size = UDim2.fromScale(0.42, 0.86),
		Position = UDim2.fromScale(0.05, 0.08),
		BackgroundTransparency = 1,
	}, gui)
	Theme.create("UISizeConstraint", { MaxSize = Vector2.new(560, 700) }, left)
	Theme.label({
		Size = UDim2.fromScale(1, 0.17),
		Font = F.Title,
		TextColor3 = C.Gold,
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "COLOSSEUM",
	}, left)
	Theme.label({
		Size = UDim2.fromScale(0.8, 0.06),
		Position = UDim2.fromScale(0.005, 0.17),
		Font = F.Heading,
		TextColor3 = C.Marble,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "RISE OF THE BEASTS",
	}, left)
	Theme.divider({ Size = UDim2.new(0.8, 0, 0, 2), Position = UDim2.fromScale(0, 0.25) }, left)
	Theme.label({
		Size = UDim2.fromScale(0.85, 0.07),
		Position = UDim2.fromScale(0, 0.27),
		Font = F.Heading,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = "Entras como gladiador. Combates como guerrero.\nEvolucionas como una leyenda.",
	}, left)

	local buttons = Theme.create("Frame", {
		Size = UDim2.fromScale(0.62, 0.5),
		Position = UDim2.fromScale(0, 0.4),
		BackgroundTransparency = 1,
	}, left)
	Theme.create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0.035, 0),
	}, buttons)
	local play = Theme.button("⚔  LUCHAR", "primary", { LayoutOrder = 1, Size = UDim2.fromScale(1, 0.22) }, buttons)
	local armory = Theme.button("ARMERÍA", "secondary", { LayoutOrder = 2, Size = UDim2.fromScale(1, 0.16) }, buttons)
	local codex = Theme.button("CÓDICE", "secondary", { LayoutOrder = 3, Size = UDim2.fromScale(1, 0.16) }, buttons)
	local settings = Theme.button("AJUSTES", "ghost", { LayoutOrder = 4, Size = UDim2.fromScale(1, 0.16) }, buttons)

	play.Activated:Connect(function()
		closeMenu(nil)
	end)
	armory.Activated:Connect(function()
		closeMenu(MetaController.openArmory)
	end)
	codex.Activated:Connect(function()
		closeMenu(MetaController.openCodex)
	end)
	settings.Activated:Connect(function()
		settingsPanel.Visible = not settingsPanel.Visible
	end)

	-- Columna derecha: ficha del gladiador y edicto.
	local card = Theme.panel({
		Size = UDim2.fromScale(0.3, 0.5),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.95, 0.12),
	}, gui)
	Theme.create("UISizeConstraint", { MinSize = Vector2.new(300, 280), MaxSize = Vector2.new(440, 420) }, card)
	Theme.create("UIPadding", {
		PaddingTop = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
	}, card)
	Theme.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, card)
	Theme.label({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 16), Font = F.Bold, TextColor3 = C.Muted, Text = "TU GLADIADOR", TextXAlignment = Enum.TextXAlignment.Left }, card)
	cardName = Theme.label({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 30), Font = F.Title, TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, card)
	cardTitle = Theme.label({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 20), Font = F.Heading, TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, card)
	cardRank = Theme.label({ LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 20), Font = F.Bold, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Text = "Nivel 1 · Tiro" }, card)
	local bar = Theme.create("Frame", { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = C.Ink, BorderSizePixel = 0 }, card)
	Theme.corner(bar, 5)
	cardXpFill = Theme.create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold, BorderSizePixel = 0 }, bar)
	Theme.corner(cardXpFill, 5)
	cardXpText = Theme.label({ LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 16), TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, card)
	cardStats = Theme.label({ LayoutOrder = 7, Size = UDim2.new(1, 0, 0, 34), TextScaled = false, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, card)
	Theme.divider({ LayoutOrder = 8 }, card)
	Theme.label({ LayoutOrder = 9, Size = UDim2.new(1, 0, 0, 16), Font = F.Bold, TextColor3 = C.RedLight, Text = "EDICTO DEL CÉSAR", TextXAlignment = Enum.TextXAlignment.Left }, card)
	decreeName = Theme.label({ LayoutOrder = 10, Size = UDim2.new(1, 0, 0, 22), Font = F.Heading, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, card)
	decreeText = Theme.label({ LayoutOrder = 11, Size = UDim2.new(1, 0, 0, 34), TextScaled = false, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "" }, card)
	gamesText = Theme.label({ LayoutOrder = 12, Size = UDim2.new(1, 0, 0, 16), Font = F.Bold, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, card)

	-- Ajustes.
	settingsPanel = Theme.panel({
		Size = UDim2.fromOffset(380, 150),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Visible = false,
	}, gui)
	Theme.create("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
	}, settingsPanel)
	Theme.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, settingsPanel)
	Theme.label({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 22), Font = F.Title, TextColor3 = C.Gold, Text = "AJUSTES" }, settingsPanel)
	toggleRow(settingsPanel, 1, "Temblor de cámara", "cameraShake")
	toggleRow(settingsPanel, 2, "Modo ligero (equipos modestos)", "lightMode")

	Theme.label({
		Size = UDim2.new(0.3, 0, 0, 16),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(0.98, 0.98),
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = `v{Version}`,
	}, gui)

	fade = Theme.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 50,
	}, nil)

	-- El fundido vive en su propia pantalla para verse por encima de todo.
	local fadeGui = Theme.create("ScreenGui", {
		Name = "MenuFade",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 50,
	})
	fade.Parent = fadeGui

	-- Botón para volver al menú durante el juego.
	menuButtonGui = Theme.create("ScreenGui", { Name = "MenuButton", ResetOnSpawn = false, Enabled = false })
	local menuButton = Theme.button("☰ MENÚ", "ghost", {
		Size = UDim2.fromOffset(84, 28),
		Position = UDim2.fromOffset(320, 8),
	}, menuButtonGui)
	menuButton.Activated:Connect(openMenu)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	gui.Parent = playerGui
	fadeGui.Parent = playerGui
	menuButtonGui.Parent = playerGui

	-- Las interfaces del juego que aparezcan mientras el menú está abierto, ocultas.
	playerGui.ChildAdded:Connect(function(child: Instance)
		if open and child:IsA("ScreenGui") and GAME_GUIS[child.Name] then
			child.Enabled = false
		end
	end)
end

function MainMenuController.Start(_self: typeof(MainMenuController))
	build()
	NetClient.on("ProfileReady", onProfile)
	NetClient.on("ProgressUpdate", onProfile)
	NetClient.on("WorldEvents", onWorldEvents)
	cardName.Text = string.upper(localPlayer.DisplayName)

	-- El coliseo lo genera el servidor: se espera a que exista para la cámara.
	Workspace:WaitForChild("GranColiseo", 10)
	Settings.reapply()
	open = false
	openMenu()
	task.spawn(tick)
end

return MainMenuController
