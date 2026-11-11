--!strict
-- Interfaz de los pilares (docs/design/PILARES.md):
--   progreso  → nivel, rango y barra de experiencia; pantalla de resultados.
--   presumir  → selector de título; noticias de las hazañas de los demás.
--   FOMO sano → edicto semanal con su cuenta atrás y Juegos Imperiales en vivo.
--   inteligencia → aviso de descubrimiento y libro del Códice con acertijos.
--   comunidad → noticias del servidor y ofrendas comunes.
-- Provisional en estilo: la estética definitiva llegará con el arte del juego.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Codex = require(ReplicatedStorage.Shared.Config.Codex)
local DecreeCalendar = require(ReplicatedStorage.Shared.Meta.DecreeCalendar)
local Essences = require(ReplicatedStorage.Shared.Config.Essences)
local NetClient = require(ReplicatedStorage.Shared.Net.Client)
local Progression = require(ReplicatedStorage.Shared.Meta.Progression)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.Progression)
local Titles = require(ReplicatedStorage.Shared.Config.Titles)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local GOLD = Color3.fromRGB(255, 210, 110)
local PARCHMENT = Color3.fromRGB(40, 28, 20)
local PANEL_TRANSPARENCY = 0.25
local NEWS_LINES = 5
local NEWS_TIME = 9
local DISCOVERY_TIME = 6
local RESULTS_TIME = 16

local config = ProgressionConfig :: any

type Profile = {
	level: number,
	xp: number,
	equippedTitle: string,
	unlockedTitles: { string },
	codex: { string },
	bestHydraTime: number,
	hydraKills: number,
	loadout: { weapon: string, essence: string },
	unlockedWeapons: { string },
	unlockedEssences: { string },
	[string]: any,
}

local MetaController = {}

local gui: ScreenGui
local levelLabel: TextLabel
local xpFill: Frame
local xpLabel: TextLabel
local titleButton: TextButton
local codexButton: TextButton
local decreeLabel: TextLabel
local gamesLabel: TextLabel
local newsFrame: Frame
local discoveryFrame: Frame
local resultsFrame: Frame
local codexFrame: ScrollingFrame
local armoryButton: TextButton
local armoryFrame: Frame

local profile: Profile? = nil
local decreeEndsAt = 0
local gamesEndsAt = 0
local discoveryToken = 0
local resultsToken = 0

local function create(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function corner(parent: Instance, radius: number)
	create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function panel(props: { [string]: any }, parent: Instance): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or PARCHMENT
	props.BackgroundTransparency = props.BackgroundTransparency or PANEL_TRANSPARENCY
	props.BorderSizePixel = 0
	local frame = create("Frame", props, parent)
	corner(frame, 8)
	return frame
end

local function label(props: { [string]: any }, parent: Instance): TextLabel
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.4
	if props.TextSize == nil then
		props.TextScaled = true
	end
	return create("TextLabel", props, parent)
end

local function formatTime(seconds: number): string
	local whole = math.floor(seconds)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function titleColor(id: string): Color3
	local title = Titles[id]
	local c = if title then title.color else { 255, 255, 255 }
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Armería ------------------------------------------------------------------

local WEAPON_ORDER = { "Gladius", "Hasta", "Martillo" }
local ESSENCE_ORDER = { "Loba", "Aguila", "Hidra" }

local function armoryEntry(parent: Instance, order: number, title: string, body: string, owned: boolean, selected: boolean, onClick: () -> ())
	local button = create("TextButton", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 76),
		BackgroundColor3 = if selected then Color3.fromRGB(90, 60, 20) else Color3.fromRGB(35, 25, 20),
		BackgroundTransparency = if owned then 0.1 else 0.5,
		BorderSizePixel = 0,
		AutoButtonColor = owned,
		Text = "",
	}, parent)
	corner(button, 6)
	if selected then
		create("UIStroke", { Color = GOLD, Thickness = 2 }, button)
	end
	label({
		Size = UDim2.new(1, -12, 0, 22),
		Position = UDim2.fromOffset(6, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if owned then GOLD else Color3.fromRGB(150, 150, 150),
		Font = Enum.Font.Antique,
		Text = (if owned then "" else "🔒 ") .. title,
	}, button)
	label({
		Size = UDim2.new(1, -12, 1, -30),
		Position = UDim2.fromOffset(6, 28),
		TextScaled = false,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Gotham,
		TextColor3 = if owned then Color3.new(1, 1, 1) else Color3.fromRGB(170, 170, 170),
		Text = body,
	}, button)
	if owned then
		button.Activated:Connect(onClick)
	end
end

local function refreshArmory()
	local current = profile
	if current == nil then
		return
	end
	for _, column in { armoryFrame:FindFirstChild("Weapons"), armoryFrame:FindFirstChild("Essences") } do
		for _, child in (column :: Instance):GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
	end
	local ownedWeapons: { [string]: boolean } = {}
	for _, id in current.unlockedWeapons do
		ownedWeapons[id] = true
	end
	local ownedEssences: { [string]: boolean } = {}
	for _, id in current.unlockedEssences do
		ownedEssences[id] = true
	end
	local loadout = current.loadout

	for order, id in WEAPON_ORDER do
		local weapon = Weapons[id]
		local owned = ownedWeapons[id] == true
		local body = `{weapon.description}\nDefinitiva: {weapon.ultimate.name}. {weapon.ultimate.description}`
		if not owned then
			body = `Se desbloquea en el nivel {weapon.unlockLevel}.\n{weapon.description}`
		end
		armoryEntry(armoryFrame:FindFirstChild("Weapons") :: Instance, order, weapon.displayName, body, owned, loadout.weapon == id, function()
			NetClient.fire("SetLoadout", id, loadout.essence)
		end)
	end
	for order, id in ESSENCE_ORDER do
		local essence = Essences[id]
		local owned = ownedEssences[id] == true
		local body = `{essence.power}\nPasiva: {essence.passive}`
		if not owned then
			body = `{essence.how}\n{essence.power}`
		end
		armoryEntry(armoryFrame:FindFirstChild("Essences") :: Instance, order, essence.name, body, owned, loadout.essence == id, function()
			NetClient.fire("SetLoadout", loadout.weapon, id)
		end)
	end
end

-- Progreso ------------------------------------------------------------------

local function refreshProgress()
	local current = profile
	if current == nil then
		return
	end
	local rank = Progression.rankFor(config, current.level)
	local needed = Progression.xpToNext(config, current.level)
	levelLabel.Text = `Nv {current.level} · {rank.name}`
	if needed > 0 then
		xpFill.Size = UDim2.fromScale(math.clamp(current.xp / needed, 0, 1), 1)
		local nextLevel, unlocks = Progression.nextUnlock(config, current.level)
		local teaser = if nextLevel and unlocks then ` · Nv {nextLevel}: {unlocks[1].name}` else ""
		xpLabel.Text = `{current.xp}/{needed} XP{teaser}`
	else
		xpFill.Size = UDim2.fromScale(1, 1)
		xpLabel.Text = "¡Nivel máximo! Eres una leyenda."
	end

	local title = Titles[current.equippedTitle]
	titleButton.Text = if title then `Título: «{title.name}» ▸` else "Título ▸"
	titleButton.TextColor3 = titleColor(current.equippedTitle)
	codexButton.Text = `Códice {#current.codex}/{#Codex}`
	if armoryFrame and armoryFrame.Visible then
		refreshArmory()
	end
end

local function cycleTitle()
	local current = profile
	if current == nil or #current.unlockedTitles == 0 then
		return
	end
	local index = table.find(current.unlockedTitles, current.equippedTitle) or 0
	local nextTitle = current.unlockedTitles[(index % #current.unlockedTitles) + 1]
	NetClient.fire("EquipTitle", nextTitle)
end

-- Códice ------------------------------------------------------------------

local function refreshCodex()
	for _, child in codexFrame:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local known: { [string]: boolean } = {}
	if profile then
		for _, id in profile.codex do
			known[id] = true
		end
	end
	for order, discovery in Codex do
		local text = if known[discovery.id]
			then `<font color="#FFD26E"><b>{discovery.name}</b></font>\n{discovery.lesson}`
			else `<font color="#999999"><b>???</b></font>\n<i>«{discovery.riddle}»</i>`
		label({
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, 54),
			RichText = true,
			TextScaled = false,
			TextSize = 15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.Gotham,
			Text = text,
		}, codexFrame)
	end
end

-- Noticias ----------------------------------------------------------------

local function pushNews(text: string)
	local line = label({
		Size = UDim2.new(1, 0, 0, 22),
		TextScaled = false,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(255, 235, 200),
		Text = text,
		LayoutOrder = math.floor(os.clock() * 1000),
	}, newsFrame)
	local lines = {}
	for _, child in newsFrame:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(lines, child)
		end
	end
	table.sort(lines, function(a: TextLabel, b: TextLabel)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #lines > NEWS_LINES do
		table.remove(lines, 1):Destroy()
	end
	task.delay(NEWS_TIME, function()
		if line.Parent then
			local tween = TweenService:Create(line, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			line:Destroy()
		end
	end)
end

-- Descubrimientos -----------------------------------------------------------

local function showDiscovery(id: string, count: number, total: number)
	local discovery
	for _, entry in Codex do
		if entry.id == id then
			discovery = entry
		end
	end
	if discovery == nil then
		return
	end
	discoveryToken += 1
	local token = discoveryToken
	local nameLabel = discoveryFrame:FindFirstChild("Name") :: TextLabel
	local lessonLabel = discoveryFrame:FindFirstChild("Lesson") :: TextLabel
	local footer = discoveryFrame:FindFirstChild("Footer") :: TextLabel
	nameLabel.Text = string.upper(discovery.name)
	lessonLabel.Text = discovery.lesson
	footer.Text = `+{discovery.xp} XP · Códice {count}/{total}`
	discoveryFrame.Visible = true
	discoveryFrame.Size = UDim2.fromOffset(380, 120)
	TweenService:Create(discoveryFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back), {
		Size = UDim2.fromOffset(460, 140),
	}):Play()
	task.delay(DISCOVERY_TIME, function()
		if discoveryToken == token then
			discoveryFrame.Visible = false
		end
	end)
end

-- Resultados ----------------------------------------------------------------

local function showResults(results: { [string]: any })
	resultsToken += 1
	local token = resultsToken
	local body = resultsFrame:FindFirstChild("Body") :: TextLabel
	local heading = resultsFrame:FindFirstChild("Heading") :: TextLabel

	heading.Text = if results.won then "¡VICTORIA!" else "DERROTA"
	heading.TextColor3 = if results.won then GOLD else Color3.fromRGB(255, 110, 90)

	local lines = {}
	if results.won then
		local recordText = if results.record
			then `<font color="#FFD26E"><b>¡NUEVO RÉCORD PERSONAL!</b></font>`
			else `Tu récord: {formatTime(results.best)}`
		table.insert(lines, `Tiempo: <b>{formatTime(results.time)}</b> · {recordText}`)
	else
		table.insert(lines, "<i>La arena no olvida. Vuelve más fuerte.</i>")
	end
	table.insert(lines, "")
	for _, line in results.lines do
		if line.amount > 0 then
			table.insert(lines, `{line.label}  <font color="#9BE59B">+{line.amount}</font>`)
		else
			table.insert(lines, `<font color="#FFD26E">{line.label}</font>`)
		end
	end
	table.insert(lines, `<b>Total: +{results.total} XP</b>`)
	table.insert(lines, "")
	if results.level > results.levelBefore then
		table.insert(lines, `<font color="#FFD26E"><b>¡SUBES AL NIVEL {results.level}!</b></font>`)
	end
	for _, unlock in results.unlocks do
		table.insert(lines, `<font color="#C8A0FF">Desbloqueado: {unlock.name}</font>`)
	end
	if results.nextLevel and results.nextUnlocks then
		table.insert(lines, `Próximo: nivel {results.nextLevel} · {results.nextUnlocks[1].name}`)
	end
	body.Text = table.concat(lines, "\n")
	resultsFrame.Visible = true
	task.delay(RESULTS_TIME, function()
		if resultsToken == token then
			resultsFrame.Visible = false
		end
	end)
end

-- Eventos -------------------------------------------------------------------

local function onWorldEvents(state: { [string]: any })
	decreeEndsAt = os.clock() + state.decreeRemaining
	gamesEndsAt = os.clock() + state.gamesRemaining
	decreeLabel.Text = `<b>{state.decreeName}</b>\n{state.decreeDescription}`
		.. `\n<i>Ofrendas al templo: {state.offerings}/{state.goal}</i>`
end

local function tickEvents()
	while true do
		local now = os.clock()
		local decreeLeft = math.max(0, decreeEndsAt - now)
		local gamesLeft = math.max(0, gamesEndsAt - now)
		if gamesLeft > 0 then
			gamesLabel.Visible = true
			gamesLabel.Text = `¡JUEGOS IMPERIALES! XP ×2 · {formatTime(gamesLeft)}`
			-- Parpadeo suave para llamar la atención.
			gamesLabel.TextTransparency = 0.15 + 0.15 * math.sin(now * 4)
		else
			gamesLabel.Visible = false
		end
		local frame = decreeLabel.Parent :: Instance
		local footer = frame:FindFirstChild("Remaining") :: TextLabel?
		if footer then
			footer.Text = if decreeEndsAt > 0
				then `Edicto del César · termina en {DecreeCalendar.formatRemaining(decreeLeft)}`
				else "Edicto del César"
		end
		task.wait(0.25)
	end
end

-- Construcción --------------------------------------------------------------

local function build()
	gui = create("ScreenGui", { Name = "MetaHud", ResetOnSpawn = false }, nil)

	-- Progreso (arriba a la izquierda).
	local progress = panel({ Size = UDim2.fromOffset(300, 62), Position = UDim2.fromOffset(12, 8) }, gui)
	levelLabel = label({
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD,
		Font = Enum.Font.Antique,
		Text = "Nv 1 · Tiro",
	}, progress)
	local bar = panel({
		Size = UDim2.new(1, -16, 0, 10),
		Position = UDim2.fromOffset(8, 32),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 0.2,
	}, progress)
	xpFill = panel({
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(230, 180, 50),
		BackgroundTransparency = 0,
	}, bar)
	xpLabel = label({
		Size = UDim2.new(1, -16, 0, 14),
		Position = UDim2.fromOffset(8, 44),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		Text = "",
	}, progress)

	titleButton = create("TextButton", {
		Size = UDim2.fromOffset(150, 26),
		Position = UDim2.fromOffset(12, 76),
		BackgroundColor3 = PARCHMENT,
		BackgroundTransparency = PANEL_TRANSPARENCY,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "Título ▸",
	}, gui)
	corner(titleButton, 6)
	titleButton.Activated:Connect(cycleTitle)

	codexButton = create("TextButton", {
		Size = UDim2.fromOffset(72, 26),
		Position = UDim2.fromOffset(166, 76),
		BackgroundColor3 = Color3.fromRGB(70, 40, 90),
		BackgroundTransparency = PANEL_TRANSPARENCY,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(220, 190, 255),
		Text = "Códice",
	}, gui)
	corner(codexButton, 6)

	armoryButton = create("TextButton", {
		Size = UDim2.fromOffset(70, 26),
		Position = UDim2.fromOffset(242, 76),
		BackgroundColor3 = Color3.fromRGB(110, 40, 30),
		BackgroundTransparency = PANEL_TRANSPARENCY,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 220, 180),
		Text = "Armería",
	}, gui)
	corner(armoryButton, 6)

	-- Edicto semanal y Juegos Imperiales.
	local decree = panel({ Size = UDim2.fromOffset(300, 96), Position = UDim2.fromOffset(12, 108) }, gui)
	label({
		Name = "Remaining",
		Size = UDim2.new(1, -16, 0, 16),
		Position = UDim2.fromOffset(8, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 140, 110),
		Text = "Edicto del César",
	}, decree)
	decreeLabel = label({
		Size = UDim2.new(1, -16, 1, -24),
		Position = UDim2.fromOffset(8, 22),
		RichText = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Gotham,
		Text = "",
	}, decree)
	gamesLabel = label({
		Size = UDim2.fromOffset(300, 28),
		Position = UDim2.fromOffset(12, 210),
		TextColor3 = GOLD,
		Font = Enum.Font.Antique,
		Visible = false,
		Text = "",
	}, gui)

	-- Noticias (abajo a la derecha).
	newsFrame = create("Frame", {
		Size = UDim2.fromOffset(420, NEWS_LINES * 24),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		BackgroundTransparency = 1,
	}, gui)
	create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 2),
	}, newsFrame)

	-- Aviso de descubrimiento (centro).
	discoveryFrame = panel({
		Size = UDim2.fromOffset(460, 140),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		BackgroundColor3 = Color3.fromRGB(45, 20, 60),
		BackgroundTransparency = 0.1,
		Visible = false,
	}, gui)
	create("UIStroke", { Color = Color3.fromRGB(200, 150, 255), Thickness = 2 }, discoveryFrame)
	label({
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 8),
		TextColor3 = Color3.fromRGB(210, 170, 255),
		Text = "✦ ¡DESCUBRIMIENTO! ✦",
	}, discoveryFrame)
	label({
		Name = "Name",
		Size = UDim2.new(1, 0, 0, 38),
		Position = UDim2.fromOffset(0, 32),
		TextColor3 = GOLD,
		Font = Enum.Font.Antique,
		Text = "",
	}, discoveryFrame)
	label({
		Name = "Lesson",
		Size = UDim2.new(1, -24, 0, 40),
		Position = UDim2.fromOffset(12, 72),
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		Text = "",
	}, discoveryFrame)
	label({
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -24),
		TextColor3 = Color3.fromRGB(155, 229, 155),
		Text = "",
	}, discoveryFrame)

	-- Resultados (centro).
	resultsFrame = panel({
		Size = UDim2.fromOffset(440, 360),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		BackgroundTransparency = 0.1,
		Visible = false,
	}, gui)
	create("UIStroke", { Color = GOLD, Thickness = 2 }, resultsFrame)
	label({
		Name = "Heading",
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 8),
		Font = Enum.Font.Antique,
		Text = "",
	}, resultsFrame)
	label({
		Name = "Body",
		Size = UDim2.new(1, -32, 1, -96),
		Position = UDim2.fromOffset(16, 56),
		RichText = true,
		TextScaled = false,
		TextSize = 16,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Gotham,
		Text = "",
	}, resultsFrame)
	local close = create("TextButton", {
		Size = UDim2.fromOffset(160, 30),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		BackgroundColor3 = Color3.fromRGB(120, 30, 30),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "¡Otra vez!",
	}, resultsFrame)
	corner(close, 6)
	close.Activated:Connect(function()
		resultsFrame.Visible = false
	end)

	-- Libro del Códice.
	codexFrame = create("ScrollingFrame", {
		Size = UDim2.fromOffset(420, 360),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(30, 18, 40),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, #Codex * 60 + 40),
		ScrollBarThickness = 6,
		Visible = false,
	}, gui)
	corner(codexFrame, 8)
	create("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}, codexFrame)
	create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, codexFrame)
	codexButton.Activated:Connect(function()
		codexFrame.Visible = not codexFrame.Visible
		if codexFrame.Visible then
			refreshCodex()
		end
	end)

	-- Armería: dos columnas (armas y esencias).
	armoryFrame = panel({
		Size = UDim2.fromOffset(560, 330),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0.08,
		Visible = false,
	}, gui)
	create("UIStroke", { Color = GOLD, Thickness = 2 }, armoryFrame)
	label({
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 6),
		TextColor3 = GOLD,
		Font = Enum.Font.Antique,
		Text = "ARMERÍA DEL LUDUS",
	}, armoryFrame)
	for index, name in { "Weapons", "Essences" } do
		local column = create("Frame", {
			Name = name,
			Size = UDim2.new(0.5, -18, 1, -50),
			Position = UDim2.new((index - 1) * 0.5, 12, 0, 42),
			BackgroundTransparency = 1,
		}, armoryFrame)
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, column)
	end
	armoryButton.Activated:Connect(function()
		armoryFrame.Visible = not armoryFrame.Visible
		codexFrame.Visible = false
		if armoryFrame.Visible then
			refreshArmory()
		end
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function MetaController.Start(_self: typeof(MetaController))
	build()

	NetClient.on("ProgressUpdate", function(data: Profile)
		profile = data
		refreshProgress()
		if codexFrame.Visible then
			refreshCodex()
		end
	end)
	NetClient.on("MatchResults", showResults)
	NetClient.on("Discovery", showDiscovery)
	NetClient.on("WorldNews", pushNews)
	NetClient.on("WorldEvents", onWorldEvents)

	task.spawn(tickEvents)
end

return MetaController
