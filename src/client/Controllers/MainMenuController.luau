--!strict
-- Pantalla de inicio: lo primero que ve el jugador.
--   · Cámara que sobrevuela el Gran Coliseo y música del tema principal.
--   · Logotipo dorado animado y lema.
--   · Botones: Desafiar a la Hidra (directo a la arena), Entrenar en el Foro, Armería,
--     Códice y Ajustes (idioma, música, temblor de cámara, modo ligero).
--   · Ficha del gladiador (progreso y presumir, con selector de título), Edicto del César
--     y Juegos Imperiales (FOMO sano) y noticias del servidor (comunidad).
-- Todo en el idioma del jugador y redibujado al cambiarlo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Bus = require(script.Parent.Parent.UI.Bus)
local Codex = require(ReplicatedStorage.Shared.Config.Codex)
local DecreeCalendar = require(ReplicatedStorage.Shared.Meta.DecreeCalendar)
local I18n = require(script.Parent.Parent.UI.I18n)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local MetaController = require(script.Parent.MetaController)
local MusicController = require(script.Parent.MusicController)
local NetClient = require(ReplicatedStorage.Shared.Net.Client)
local Progression = require(ReplicatedStorage.Shared.Meta.Progression)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.Progression)
local Settings = require(script.Parent.Parent.UI.Settings)
local Theme = require(script.Parent.Parent.UI.Theme)
local Titles = require(ReplicatedStorage.Shared.Config.Titles)
local Version = require(ReplicatedStorage.Shared.Version)

local C = Theme.Colors
local F = Theme.Fonts
local t = I18n.t
local config = ProgressionConfig :: any

local CAMERA_STEP = "ColosseumMenuCamera"
local ORBIT_RADIUS = 118
local ORBIT_HEIGHT = 46
local ORBIT_SPEED = 0.05
local NEWS_LINES = 4
-- Interfaces del juego que se ocultan mientras el menú está abierto.
local GAME_GUIS = { MetaHud = true, CombatHud = true, EncounterHud = true, Onboarding = true }
-- Espera máxima al módulo de controles de Roblox: nunca debe bloquear el menú.
local CONTROLS_TIMEOUT = 10

local log = Log.new("MainMenu")

local localPlayer = Players.LocalPlayer

local MainMenuController = {}

local gui: ScreenGui
local fade: Frame
local logo: TextLabel
local subtitle: TextLabel
local buttonsFrame: Frame
local settingsPanel: Frame
local settingsRows: { [string]: TextButton } = {}
local cardName: TextLabel
local cardTitle: TextButton
local cardRank: TextLabel
local cardXpFill: Frame
local cardXpText: TextLabel
local cardStats: TextLabel
local decreeName: TextLabel
local decreeText: TextLabel
local gamesText: TextLabel
local newsList: Frame
local staticLabels: { { object: any, key: string } } = {}
local open = false
local busy = false
local orbitAngle = 0
local decreeId: string? = nil
local decreeEndsAt = 0
local gamesEndsAt = 0
local profile: { [string]: any }? = nil
local news: { { key: string, params: any } } = {}

local function formatTime(seconds: number): string
	local whole = math.floor(seconds)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function static(object: any, key: string)
	object.Text = t(key)
	table.insert(staticLabels, { object = object, key = key })
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
end

local function setControls(enabled: boolean)
	-- Módulo de control estándar de Roblox (PlayerScripts.PlayerModule). Se busca en otro
	-- hilo y con tiempo límite: si tarda o no existe, el menú se abre igualmente (antes la
	-- espera sin límite dejaba la pantalla en negro tras el fundido).
	task.spawn(function()
		local ok, err = pcall(function()
			local playerScripts = localPlayer:WaitForChild("PlayerScripts", CONTROLS_TIMEOUT)
			local module = if playerScripts
				then playerScripts:WaitForChild("PlayerModule", CONTROLS_TIMEOUT)
				else nil
			if module == nil or not module:IsA("ModuleScript") then
				return
			end
			local playerModule = require(module :: any) :: any
			local controls = playerModule:GetControls()
			if enabled then
				controls:Enable()
			else
				controls:Disable()
			end
		end)
		if not ok then
			log:warn(`No se pudieron cambiar los controles: {err}`)
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
	RunService:BindToRenderStep(
		CAMERA_STEP,
		Enum.RenderPriority.Camera.Value + 1,
		function(deltaTime: number)
			orbitAngle += deltaTime * ORBIT_SPEED
			-- Ligera subida y bajada para dar vida al plano.
			local height = ORBIT_HEIGHT + math.sin(orbitAngle * 2.3) * 6
			local position = center
				+ Vector3.new(
					math.cos(orbitAngle) * ORBIT_RADIUS,
					height,
					math.sin(orbitAngle) * ORBIT_RADIUS
				)
			camera.CFrame = CFrame.lookAt(position, center + Vector3.new(0, 8, 0))
		end
	)
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
	local fadeIn = TweenService:Create(fade, info, { BackgroundTransparency = 0 })
	fadeIn:Play()
	fadeIn.Completed:Wait()
	-- Pase lo que pase en `action`, la pantalla vuelve: nunca se queda en negro.
	local ok, err = pcall(action)
	if not ok then
		log:error(`Error al cambiar de pantalla: {err}`)
	end
	local fadeOut = TweenService:Create(fade, info, { BackgroundTransparency = 1 })
	fadeOut:Play()
	fadeOut.Completed:Wait()
	fade.Visible = false
end

-- Entrada animada: el logotipo baja con un brillo y los botones aparecen uno a uno.
local function animateIn()
	logo.Position = UDim2.fromScale(0, -0.05)
	logo.TextTransparency = 1
	subtitle.TextTransparency = 1
	TweenService:Create(logo, TweenInfo.new(0.9, Enum.EasingStyle.Quint), {
		Position = UDim2.fromScale(0, 0),
		TextTransparency = 0,
	}):Play()
	TweenService
		:Create(subtitle, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { TextTransparency = 0 })
		:Play()
	local gradient = logo:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Offset = Vector2.new(-1, 0)
		TweenService
			:Create(
				gradient,
				TweenInfo.new(1.6, Enum.EasingStyle.Sine),
				{ Offset = Vector2.new(1, 0) }
			)
			:Play()
	end
	local order = 0
	for _, child in buttonsFrame:GetChildren() do
		if child:IsA("TextButton") then
			order += 1
			local finalTransparency = child.BackgroundTransparency
			child.BackgroundTransparency = 1
			child.TextTransparency = 1
			task.delay(0.25 + order * 0.08, function()
				TweenService:Create(child, TweenInfo.new(0.3), {
					BackgroundTransparency = finalTransparency,
					TextTransparency = 0,
				}):Play()
			end)
		end
	end
end

local function closeMenu(after: (() -> ())?)
	if not open or busy then
		return
	end
	open = false
	busy = true
	task.spawn(fadeThen, function()
		gui.Enabled = false
		settingsPanel.Visible = false
		stopCamera()
		setControls(true)
		setGameGuis(true)
		MusicController.setMenuOpen(false)
		Bus.MenuVisibility:Fire(false)
		if after then
			after()
		end
	end)
	task.delay(0.8, function()
		busy = false
	end)
end

local function openMenu()
	if open or busy then
		return
	end
	if localPlayer:GetAttribute("InArena") == true then
		return
	end
	open = true
	busy = true
	task.spawn(fadeThen, function()
		setGameGuis(false)
		setControls(false)
		startCamera()
		gui.Enabled = true
		MusicController.setMenuOpen(true)
		Bus.MenuVisibility:Fire(true)
		animateIn()
	end)
	task.delay(0.8, function()
		busy = false
	end)
end

-- Ficha del gladiador -------------------------------------------------------------------

local function refreshCard()
	cardName.Text = string.upper(localPlayer.DisplayName)
	local current = profile
	if current == nil then
		return
	end
	local titleId = current.equippedTitle or ""
	local title = Titles[titleId]
	cardTitle.Text = if title
		then `«{t(`title.{titleId}.name`)}»  {if #(current.unlockedTitles or {}) > 1
			then "▸"
			else ""}`
		else ""
	if title then
		cardTitle.TextColor3 = Color3.fromRGB(title.color[1], title.color[2], title.color[3])
	end
	local level = current.level or 1
	cardRank.Text = t("menu.level", { level = level, rank = Progression.rankRef(config, level) })
	local needed = Progression.xpToNext(config, level)
	local xp = current.xp or 0
	cardXpFill.Size = UDim2.fromScale(if needed > 0 then math.clamp(xp / needed, 0, 1) else 1, 1)
	local nextLevel, unlocks = Progression.nextUnlock(config, level)
	cardXpText.Text = if needed <= 0
		then t("hud.maxLevel")
		elseif nextLevel and unlocks then t("hud.xpNext", {
			xp = xp,
			needed = needed,
			level = nextLevel,
			unlock = Progression.unlockRef(unlocks[1]),
		})
		else t("hud.xp", { xp = xp, needed = needed })
	local best = current.bestHydraTime or 0
	cardStats.Text = t("menu.stats", {
		kills = current.hydraKills or 0,
		best = if best > 0 then formatTime(best) else "—",
	}) .. "\n" .. t("menu.codexStats", { count = #(current.codex or {}), total = #Codex })
end

local function cycleTitle()
	local current = profile
	if current == nil or current.unlockedTitles == nil or #current.unlockedTitles < 2 then
		return
	end
	local index = table.find(current.unlockedTitles, current.equippedTitle) or 0
	NetClient.fire("EquipTitle", current.unlockedTitles[(index % #current.unlockedTitles) + 1])
end

local function refreshDecree()
	if decreeId then
		decreeName.Text = t(`decree.{decreeId}.name`)
		decreeText.Text = t(`decree.{decreeId}.desc`)
	end
end

local function refreshNews()
	for _, child in newsList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if #news == 0 then
		Theme.label({
			Size = UDim2.new(1, 0, 0, 18),
			TextScaled = false,
			TextSize = 14,
			Font = F.Heading,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = t("menu.noNews"),
		}, newsList)
		return
	end
	for index = #news, math.max(1, #news - NEWS_LINES + 1), -1 do
		local item = news[index]
		Theme.label({
			LayoutOrder = #news - index,
			Size = UDim2.new(1, 0, 0, 34),
			TextScaled = false,
			TextSize = 14,
			TextWrapped = true,
			Font = F.Heading,
			TextColor3 = if index == #news then C.Text else C.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = `• {t(item.key, item.params)}`,
		}, newsList)
	end
end

local function tick()
	while true do
		if open then
			local now = os.clock()
			local games = math.max(0, gamesEndsAt - now)
			if games > 0 then
				gamesText.Text = t("menu.gamesActive", { time = formatTime(games) })
				gamesText.TextColor3 = C.Gold
			elseif decreeEndsAt > 0 then
				gamesText.Text = t("menu.edictEnds", {
					remaining = DecreeCalendar.formatRemaining(math.max(0, decreeEndsAt - now)),
				})
				gamesText.TextColor3 = C.Muted
			end
		end
		task.wait(0.5)
	end
end

-- Ajustes ---------------------------------------------------------------------------------

local function settingValueText(name: string): string
	local value = Settings.get(name)
	if name == "language" then
		return if value == "auto" then t("settings.auto") else t(`lang.{value}`)
	elseif name == "music" then
		return `{math.floor((value or 0) * 100 + 0.5)}%`
	end
	return if value then t("settings.on") else t("settings.off")
end

local function refreshSettings()
	for name, button in settingsRows do
		local value = Settings.get(name)
		button.Text = settingValueText(name)
		button.TextColor3 = if value == false or value == 0 then C.Muted else C.Gold
	end
end

local function settingRow(
	parent: Instance,
	order: number,
	key: string,
	name: string,
	onClick: () -> ()
)
	local row = Theme.create("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
	}, parent)
	static(
		Theme.label({
			Size = UDim2.fromScale(0.62, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = F.Heading,
		}, row),
		key
	)
	local button = Theme.button("", "secondary", {
		Size = UDim2.fromScale(0.36, 0.82),
		Position = UDim2.fromScale(0.64, 0.09),
	}, row)
	button.Activated:Connect(function()
		onClick()
		refreshSettings()
	end)
	settingsRows[name] = button
end

-- Construcción ------------------------------------------------------------------------------

local function build()
	gui = Theme.create("ScreenGui", {
		Name = "MainMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		Enabled = false,
	})

	-- Viñeta: oscurece los lados para que el texto se lea sobre el coliseo.
	local vignette = Theme.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
	}, gui)
	Theme.create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.42, 0.6),
			NumberSequenceKeypoint.new(0.6, 0.85),
			NumberSequenceKeypoint.new(1, 0.15),
		}),
	}, vignette)

	-- Columna izquierda: logotipo, lema y botones.
	local left = Theme.create("Frame", {
		Size = UDim2.fromScale(0.42, 0.86),
		Position = UDim2.fromScale(0.05, 0.07),
		BackgroundTransparency = 1,
	}, gui)
	Theme.create("UISizeConstraint", { MaxSize = Vector2.new(580, 760) }, left)

	local logoHolder =
		Theme.create("Frame", { Size = UDim2.fromScale(1, 0.17), BackgroundTransparency = 1 }, left)
	logo = Theme.label({
		Size = UDim2.fromScale(1, 1),
		Font = F.Title,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.35,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "COLOSSEUM",
	}, logoHolder)
	-- Oro con un brillo que recorre las letras.
	Theme.create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.GoldDark),
			ColorSequenceKeypoint.new(0.45, C.Gold),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 250, 225)),
			ColorSequenceKeypoint.new(0.55, C.Gold),
			ColorSequenceKeypoint.new(1, C.GoldDark),
		}),
	}, logo)
	subtitle = Theme.label({
		Size = UDim2.fromScale(0.8, 0.055),
		Position = UDim2.fromScale(0.005, 0.175),
		Font = F.Heading,
		TextColor3 = C.Marble,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "— RISE OF THE BEASTS —",
	}, left)
	Theme.divider({ Size = UDim2.new(0.8, 0, 0, 2), Position = UDim2.fromScale(0, 0.245) }, left)
	static(
		Theme.label({
			Size = UDim2.fromScale(0.85, 0.075),
			Position = UDim2.fromScale(0, 0.265),
			Font = F.Heading,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
		}, left),
		"menu.tagline"
	)

	buttonsFrame = Theme.create("Frame", {
		Size = UDim2.fromScale(0.66, 0.56),
		Position = UDim2.fromScale(0, 0.39),
		BackgroundTransparency = 1,
	}, left)
	Theme.create(
		"UIListLayout",
		{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0.028, 0) },
		buttonsFrame
	)
	local challenge = Theme.button(
		"",
		"primary",
		{ LayoutOrder = 1, Size = UDim2.fromScale(1, 0.2) },
		buttonsFrame
	)
	static(challenge, "menu.challenge")
	local train = Theme.button(
		"",
		"secondary",
		{ LayoutOrder = 2, Size = UDim2.fromScale(1, 0.14) },
		buttonsFrame
	)
	static(train, "menu.train")
	local armory = Theme.button(
		"",
		"secondary",
		{ LayoutOrder = 3, Size = UDim2.fromScale(1, 0.14) },
		buttonsFrame
	)
	static(armory, "menu.armory")
	local codex = Theme.button(
		"",
		"secondary",
		{ LayoutOrder = 4, Size = UDim2.fromScale(1, 0.14) },
		buttonsFrame
	)
	static(codex, "menu.codex")
	local settings = Theme.button(
		"",
		"ghost",
		{ LayoutOrder = 5, Size = UDim2.fromScale(1, 0.14) },
		buttonsFrame
	)
	static(settings, "menu.settings")

	challenge.Activated:Connect(function()
		closeMenu(function()
			NetClient.fire("QuickJoin")
		end)
	end)
	train.Activated:Connect(function()
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
		refreshSettings()
	end)

	-- Columna derecha: ficha del gladiador, edicto y noticias.
	local right = Theme.create("Frame", {
		Size = UDim2.fromScale(0.32, 0.84),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.96, 0.08),
		BackgroundTransparency = 1,
	}, gui)
	Theme.create(
		"UISizeConstraint",
		{ MinSize = Vector2.new(320, 0), MaxSize = Vector2.new(440, 760) },
		right
	)
	Theme.create(
		"UIListLayout",
		{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) },
		right
	)

	local card = Theme.panel({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 200) }, right)
	Theme.create("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
	}, card)
	Theme.create(
		"UIListLayout",
		{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) },
		card
	)
	static(
		Theme.label({
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 14),
			Font = F.Bold,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, card),
		"menu.yourGladiator"
	)
	cardName = Theme.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 30),
		Font = F.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, card)
	cardTitle = Theme.create("TextButton", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = F.Heading,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Text,
		Text = "",
	}, card)
	cardTitle.Activated:Connect(cycleTitle)
	cardRank = Theme.label({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 20),
		Font = F.Bold,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, card)
	local bar = Theme.create("Frame", {
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
	}, card)
	Theme.corner(bar, 5)
	cardXpFill = Theme.create(
		"Frame",
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold, BorderSizePixel = 0 },
		bar
	)
	Theme.corner(cardXpFill, 5)
	cardXpText = Theme.label({
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 15),
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, card)
	cardStats = Theme.label({
		LayoutOrder = 7,
		Size = UDim2.new(1, 0, 0, 36),
		TextScaled = false,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, card)

	local edict = Theme.panel({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 122) }, right)
	Theme.create("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
	}, edict)
	Theme.create(
		"UIListLayout",
		{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) },
		edict
	)
	static(
		Theme.label({
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 14),
			Font = F.Bold,
			TextColor3 = C.RedLight,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, edict),
		"menu.edict"
	)
	decreeName = Theme.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 22),
		Font = F.Title,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, edict)
	decreeText = Theme.label({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 36),
		TextScaled = false,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
	}, edict)
	gamesText = Theme.label({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 16),
		Font = F.Bold,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, edict)

	local newsPanel = Theme.panel({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 190) }, right)
	Theme.create("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
	}, newsPanel)
	static(
		Theme.label({
			Size = UDim2.new(1, 0, 0, 14),
			Font = F.Bold,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, newsPanel),
		"menu.news"
	)
	newsList = Theme.create("Frame", {
		Size = UDim2.new(1, 0, 1, -28),
		Position = UDim2.fromOffset(0, 22),
		BackgroundTransparency = 1,
	}, newsPanel)
	Theme.create(
		"UIListLayout",
		{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) },
		newsList
	)

	-- Ajustes.
	settingsPanel = Theme.panel({
		Size = UDim2.fromOffset(420, 250),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		BackgroundTransparency = 0.04,
		Visible = false,
		ZIndex = 20,
	}, gui)
	Theme.create("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 18),
	}, settingsPanel)
	Theme.create(
		"UIListLayout",
		{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) },
		settingsPanel
	)
	static(
		Theme.label(
			{ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 26), Font = F.Title, TextColor3 = C.Gold },
			settingsPanel
		),
		"settings.title"
	)
	settingRow(settingsPanel, 1, "settings.language", "language", function()
		Settings.cycle("language", Settings.LANGUAGE_OPTIONS)
	end)
	settingRow(settingsPanel, 2, "settings.music", "music", function()
		Settings.cycle("music", Settings.MUSIC_OPTIONS)
	end)
	settingRow(settingsPanel, 3, "settings.shake", "cameraShake", function()
		Settings.toggle("cameraShake")
	end)
	settingRow(settingsPanel, 4, "settings.light", "lightMode", function()
		Settings.toggle("lightMode")
	end)
	local closeSettings =
		Theme.button("", "ghost", { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 30) }, settingsPanel)
	static(closeSettings, "ui.close")
	closeSettings.Activated:Connect(function()
		settingsPanel.Visible = false
	end)

	Theme.label({
		Size = UDim2.fromOffset(200, 16),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -10),
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = `v{Version}`,
	}, gui)

	-- El fundido vive en su propia pantalla para verse por encima de todo.
	local fadeGui = Theme.create("ScreenGui", {
		Name = "MenuFade",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 50,
	})
	fade = Theme.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
	}, fadeGui)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	gui.Parent = playerGui
	fadeGui.Parent = playerGui

	-- Las interfaces del juego que aparezcan mientras el menú está abierto, ocultas.
	playerGui.ChildAdded:Connect(function(child: Instance)
		if open and child:IsA("ScreenGui") and GAME_GUIS[child.Name] then
			child.Enabled = false
		end
	end)
end

local function relabel()
	for _, item in staticLabels do
		item.object.Text = t(item.key)
	end
	refreshCard()
	refreshDecree()
	refreshNews()
	refreshSettings()
end

function MainMenuController.Start(_self: typeof(MainMenuController))
	build()
	cardName.Text = string.upper(localPlayer.DisplayName)
	refreshNews()
	refreshSettings()

	Bus.Profile:Connect(function(data: any)
		profile = data
		refreshCard()
		refreshSettings()
	end)
	Bus.OpenMenu:Connect(openMenu)
	NetClient.on("WorldEvents", function(state: { [string]: any })
		decreeId = state.decreeId
		decreeEndsAt = os.clock() + (state.decreeRemaining or 0)
		gamesEndsAt = os.clock() + (state.gamesRemaining or 0)
		refreshDecree()
	end)
	NetClient.on("WorldNews", function(key: string, params: any)
		table.insert(news, { key = key, params = params })
		while #news > NEWS_LINES do
			table.remove(news, 1)
		end
		if open then
			refreshNews()
		end
	end)
	I18n.Changed:Connect(relabel)
	Settings.Changed:Connect(refreshSettings)

	-- El coliseo lo genera el servidor: se espera a que exista para la cámara.
	Workspace:WaitForChild("GranColiseo", 10)
	Settings.reapply()
	openMenu()
	task.spawn(tick)
end

return MainMenuController
