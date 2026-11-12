--!strict
-- Interfaz de juego de los pilares (docs/design/PILARES.md), en el idioma del jugador:
--   progreso      → ficha de nivel y experiencia; pantalla de resultados.
--   presumir      → noticias de las hazañas de los demás.
--   FOMO sano     → aviso de Juegos Imperiales en directo.
--   inteligencia  → aviso de descubrimiento y libro del Códice con acertijos.
--   comunidad     → noticias del servidor.
-- También la armería. Estilo común en UI/Theme.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Bus = require(script.Parent.Parent.UI.Bus)
local Codex = require(ReplicatedStorage.Shared.Config.Codex)
local I18n = require(script.Parent.Parent.UI.I18n)
local NetClient = require(ReplicatedStorage.Shared.Net.Client)
local Progression = require(ReplicatedStorage.Shared.Meta.Progression)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.Progression)
local Settings = require(script.Parent.Parent.UI.Settings)
local Theme = require(script.Parent.Parent.UI.Theme)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local C = Theme.Colors
local F = Theme.Fonts
local t = I18n.t
local config = ProgressionConfig :: any

local NEWS_LINES = 5
local NEWS_TIME = 10
local DISCOVERY_TIME = 6
local RESULTS_TIME = 25
local WEAPON_ORDER = { "Gladius", "Hasta", "Martillo" }
local ESSENCE_ORDER = { "Loba", "Aguila", "Hidra" }

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
	settings: { [string]: any }?,
	[string]: any,
}

local MetaController = {}

local gui: ScreenGui
local levelLabel: TextLabel
local xpFill: Frame
local xpLabel: TextLabel
local menuButton: TextButton
local armoryButton: TextButton
local codexButton: TextButton
local gamesLabel: TextLabel
local newsFrame: Frame
local discoveryFrame: Frame
local resultsFrame: Frame
local codexFrame: Frame
local codexList: ScrollingFrame
local codexProgress: TextLabel
local armoryFrame: Frame
local armoryColumns: { [string]: Frame } = {}
local staticLabels: { { object: any, key: string } } = {}

local profile: Profile? = nil
local gamesEndsAt = 0
local discoveryToken = 0
local resultsToken = 0
local lastResults: { [string]: any }? = nil

local function formatTime(seconds: number): string
	local whole = math.floor(seconds)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- Texto fijo que se redibuja al cambiar de idioma.
local function static(object: any, key: string)
	object.Text = t(key)
	table.insert(staticLabels, { object = object, key = key })
end

local function modal(size: UDim2, parent: Instance): Frame
	local frame = Theme.panel({
		Size = size,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0.04,
		Visible = false,
	}, parent)
	Theme.create("UISizeConstraint", { MaxSize = Vector2.new(620, 520) }, frame)
	return frame
end

local function closeButton(parent: Frame, onClose: () -> ())
	local button = Theme.button("✕", "ghost", {
		Size = UDim2.fromOffset(32, 32),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		ZIndex = 5,
	}, parent)
	button.Activated:Connect(onClose)
end

-- Ficha de progreso --------------------------------------------------------------------

local function refreshProgress()
	local current = profile
	if current == nil then
		return
	end
	levelLabel.Text = t("hud.level", { level = current.level, rank = Progression.rankRef(config, current.level) })
	local needed = Progression.xpToNext(config, current.level)
	if needed > 0 then
		xpFill.Size = UDim2.fromScale(math.clamp(current.xp / needed, 0, 1), 1)
		local nextLevel, unlocks = Progression.nextUnlock(config, current.level)
		if nextLevel and unlocks then
			xpLabel.Text = t("hud.xpNext", {
				xp = current.xp,
				needed = needed,
				level = nextLevel,
				unlock = Progression.unlockRef(unlocks[1]),
			})
		else
			xpLabel.Text = t("hud.xp", { xp = current.xp, needed = needed })
		end
	else
		xpFill.Size = UDim2.fromScale(1, 1)
		xpLabel.Text = t("hud.maxLevel")
	end
	codexButton.Text = t("hud.codex", { count = #current.codex, total = #Codex })
end

-- Códice ---------------------------------------------------------------------------------

local function refreshCodex()
	for _, child in codexList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local known: { [string]: boolean } = {}
	local current = profile
	if current then
		for _, id in current.codex do
			known[id] = true
		end
	end
	local count = 0
	for order, discovery in Codex do
		local found = known[discovery.id] == true
		if found then
			count += 1
		end
		local entry = Theme.create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 58),
			BackgroundColor3 = if found then C.PanelLight else C.Ink,
			BackgroundTransparency = if found then 0.2 else 0.5,
			BorderSizePixel = 0,
		}, codexList)
		Theme.corner(entry, 6)
		Theme.label({
			Size = UDim2.new(1, -16, 0, 22),
			Position = UDim2.fromOffset(8, 4),
			Font = F.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if found then C.Gold else C.Muted,
			Text = if found then discovery.name else "? ? ?",
		}, entry)
		Theme.label({
			Size = UDim2.new(1, -16, 0, 28),
			Position = UDim2.fromOffset(8, 26),
			TextScaled = false,
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Font = if found then F.Body else F.Heading,
			TextColor3 = if found then C.Text else C.Muted,
			Text = if found
				then t(`codex.{discovery.id}.lesson`)
				else `«{t(`codex.{discovery.id}.riddle`)}»`,
		}, entry)
	end
	codexProgress.Text = t("codexui.progress", { count = count, total = #Codex })
end

local function openCodex()
	armoryFrame.Visible = false
	resultsFrame.Visible = false
	codexFrame.Visible = true
	refreshCodex()
end

-- Armería --------------------------------------------------------------------------------

local function armoryEntry(
	parent: Instance,
	order: number,
	title: string,
	body: string,
	owned: boolean,
	selected: boolean,
	onClick: () -> ()
)
	local button = Theme.create("TextButton", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 92),
		BackgroundColor3 = if selected then C.PanelLight else C.Ink,
		BackgroundTransparency = if owned then 0.1 else 0.45,
		BorderSizePixel = 0,
		AutoButtonColor = owned,
		Text = "",
	}, parent)
	Theme.corner(button, 8)
	Theme.stroke(button, if selected then C.Gold else C.GoldDark, if selected then 2 else 1, if selected then 0 else 0.6)
	Theme.label({
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.fromOffset(8, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if owned then C.Gold else C.Muted,
		Font = F.Title,
		Text = (if owned then "" else "🔒 ") .. title .. (if selected then `  ·  {t("armory.equipped")}` else ""),
	}, button)
	Theme.label({
		Size = UDim2.new(1, -16, 1, -36),
		Position = UDim2.fromOffset(8, 32),
		TextScaled = false,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = F.Body,
		TextColor3 = if owned then C.Text else C.Muted,
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
	for _, column in armoryColumns do
		for _, child in column:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
	end
	local loadout = current.loadout
	for order, id in WEAPON_ORDER do
		local weapon = Weapons[id]
		local owned = table.find(current.unlockedWeapons, id) ~= nil
		local ultimate = weapon.ultimate.id
		local body = if owned
			then `{t(`weapon.{id}.desc`)}\n{t("armory.ultimate", {
				name = { key = `ultimate.{ultimate}.name` },
				desc = { key = `ultimate.{ultimate}.desc` },
			})}`
			else `{t("armory.unlockLevel", { level = weapon.unlockLevel })}\n{t(`weapon.{id}.desc`)}`
		armoryEntry(armoryColumns.Weapons, order, t(`weapon.{id}.name`), body, owned, loadout.weapon == id, function()
			NetClient.fire("SetLoadout", id, loadout.essence)
		end)
	end
	for order, id in ESSENCE_ORDER do
		local owned = table.find(current.unlockedEssences, id) ~= nil
		local body = if owned
			then `{t(`essence.{id}.power`)}\n{t("armory.passive", { passive = { key = `essence.{id}.passive` } })}`
			else `{t(`essence.{id}.how`)}\n{t(`essence.{id}.power`)}`
		armoryEntry(armoryColumns.Essences, order, t(`essence.{id}.name`), body, owned, loadout.essence == id, function()
			NetClient.fire("SetLoadout", loadout.weapon, id)
		end)
	end
end

local function openArmory()
	codexFrame.Visible = false
	resultsFrame.Visible = false
	armoryFrame.Visible = true
	refreshArmory()
end

-- Noticias -------------------------------------------------------------------------------

local function pushNews(key: string, params: { [string]: any }?)
	local line = Theme.label({
		Size = UDim2.new(1, 0, 0, 22),
		TextScaled = false,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = F.Heading,
		TextColor3 = C.Marble,
		TextStrokeTransparency = 0.4,
		Text = t(key, params),
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

-- Descubrimientos ------------------------------------------------------------------------

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
	lessonLabel.Text = t(`codex.{id}.lesson`)
	footer.Text = t("discovery.footer", { xp = discovery.xp, count = count, total = total })
	discoveryFrame.Visible = true
	discoveryFrame.Size = UDim2.fromOffset(400, 130)
	TweenService:Create(discoveryFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back), {
		Size = UDim2.fromOffset(480, 150),
	}):Play()
	task.delay(DISCOVERY_TIME, function()
		if discoveryToken == token then
			discoveryFrame.Visible = false
		end
	end)
end

-- Resultados -----------------------------------------------------------------------------

local function renderResults()
	local results = lastResults
	if results == nil then
		return
	end
	local heading = resultsFrame:FindFirstChild("Heading") :: TextLabel
	local body = resultsFrame:FindFirstChild("Body") :: TextLabel
	heading.Text = t(if results.won then "results.victory" else "results.defeat")
	heading.TextColor3 = if results.won then C.Gold else C.RedLight

	local lines = {}
	if results.won then
		local record = if results.record
			then `<font color="#FFD26E"><b>{t("results.newRecord")}</b></font>`
			else t("results.yourRecord", { time = formatTime(results.best) })
		table.insert(lines, `<b>{t("results.time", { time = formatTime(results.time) })}</b>  ·  {record}`)
	else
		table.insert(lines, `<i>{t("results.defeatLine")}</i>`)
	end
	table.insert(lines, "")
	for _, line in results.lines do
		local text = t(line.key, line.params)
		if line.amount > 0 then
			table.insert(lines, `{text}  <font color="#9BE59B">+{line.amount}</font>`)
		else
			table.insert(lines, `<font color="#FFD26E">{text}</font>`)
		end
	end
	table.insert(lines, `<b>{t("results.total", { xp = results.total })}</b>`)
	table.insert(lines, "")
	if results.level > results.levelBefore then
		table.insert(lines, `<font color="#FFD26E"><b>{t("results.levelUp", { level = results.level })}</b></font>`)
	end
	for _, unlock in results.unlocks do
		table.insert(lines, `<font color="#C8A0FF">{t("results.unlocked", { unlock = unlock })}</font>`)
	end
	if results.nextLevel and results.nextUnlock then
		table.insert(lines, t("results.next", { level = results.nextLevel, unlock = results.nextUnlock }))
	end
	body.Text = table.concat(lines, "\n")
end

local function showResults(results: { [string]: any })
	lastResults = results
	resultsToken += 1
	local token = resultsToken
	codexFrame.Visible = false
	armoryFrame.Visible = false
	renderResults()
	resultsFrame.Visible = true
	task.delay(RESULTS_TIME, function()
		if resultsToken == token then
			resultsFrame.Visible = false
		end
	end)
end

-- Eventos --------------------------------------------------------------------------------

local function tickEvents()
	while true do
		local now = os.clock()
		local gamesLeft = math.max(0, gamesEndsAt - now)
		if gamesLeft > 0 then
			gamesLabel.Visible = true
			gamesLabel.Text = t("hud.games", { time = formatTime(gamesLeft) })
			gamesLabel.TextTransparency = 0.1 + 0.15 * math.sin(now * 4)
		else
			gamesLabel.Visible = false
		end
		task.wait(0.25)
	end
end

-- Construcción ---------------------------------------------------------------------------

local function build()
	gui = Theme.create("ScreenGui", { Name = "MetaHud", ResetOnSpawn = false })

	-- Ficha de progreso (arriba a la izquierda).
	local chip = Theme.panel({ Size = UDim2.fromOffset(300, 60), Position = UDim2.fromOffset(12, 8) }, gui)
	levelLabel = Theme.label({
		Size = UDim2.new(1, -20, 0, 24),
		Position = UDim2.fromOffset(10, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Gold,
		Font = F.Title,
		Text = "",
	}, chip)
	local bar = Theme.create("Frame", {
		Size = UDim2.new(1, -20, 0, 8),
		Position = UDim2.fromOffset(10, 31),
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
	}, chip)
	Theme.corner(bar, 4)
	xpFill = Theme.create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold, BorderSizePixel = 0 }, bar)
	Theme.corner(xpFill, 4)
	xpLabel = Theme.label({
		Size = UDim2.new(1, -20, 0, 14),
		Position = UDim2.fromOffset(10, 42),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Muted,
		Text = "",
	}, chip)

	-- Botonera bajo la ficha.
	local dock = Theme.create("Frame", {
		Size = UDim2.fromOffset(300, 30),
		Position = UDim2.fromOffset(12, 74),
		BackgroundTransparency = 1,
	}, gui)
	Theme.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, dock)
	menuButton = Theme.button("", "secondary", { LayoutOrder = 1, Size = UDim2.fromOffset(84, 30) }, dock)
	static(menuButton, "hud.menu")
	armoryButton = Theme.button("", "secondary", { LayoutOrder = 2, Size = UDim2.fromOffset(98, 30) }, dock)
	static(armoryButton, "hud.armory")
	codexButton = Theme.button("", "secondary", { LayoutOrder = 3, Size = UDim2.fromOffset(104, 30) }, dock)
	menuButton.Activated:Connect(function()
		Bus.OpenMenu:Fire()
	end)
	armoryButton.Activated:Connect(function()
		if armoryFrame.Visible then
			armoryFrame.Visible = false
		else
			openArmory()
		end
	end)
	codexButton.Activated:Connect(function()
		if codexFrame.Visible then
			codexFrame.Visible = false
		else
			openCodex()
		end
	end)

	-- Juegos Imperiales (arriba al centro, solo cuando están activos).
	gamesLabel = Theme.label({
		Size = UDim2.fromOffset(480, 30),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		TextColor3 = C.Gold,
		Font = F.Title,
		TextStrokeTransparency = 0.2,
		Visible = false,
		Text = "",
	}, gui)

	-- Noticias (abajo a la derecha).
	newsFrame = Theme.create("Frame", {
		Size = UDim2.fromOffset(440, NEWS_LINES * 24),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		BackgroundTransparency = 1,
	}, gui)
	Theme.create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 2),
	}, newsFrame)

	-- Aviso de descubrimiento.
	discoveryFrame = Theme.panel({
		Size = UDim2.fromOffset(480, 150),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		BackgroundColor3 = Color3.fromRGB(40, 18, 56),
		BackgroundTransparency = 0.05,
		Visible = false,
	}, gui)
	local discoveryStroke = discoveryFrame:FindFirstChildOfClass("UIStroke")
	if discoveryStroke then
		discoveryStroke.Color = C.Purple
		discoveryStroke.Thickness = 2
		discoveryStroke.Transparency = 0
	end
	static(
		Theme.label({ Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 10), Font = F.Bold, TextColor3 = C.Purple }, discoveryFrame),
		"discovery.header"
	)
	Theme.label({
		Name = "Name",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 34),
		TextColor3 = C.Gold,
		Font = F.Title,
		Text = "",
	}, discoveryFrame)
	Theme.label({
		Name = "Lesson",
		Size = UDim2.new(1, -28, 0, 40),
		Position = UDim2.fromOffset(14, 76),
		TextWrapped = true,
		Font = F.Heading,
		Text = "",
	}, discoveryFrame)
	Theme.label({
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -26),
		TextColor3 = C.Green,
		Font = F.Bold,
		Text = "",
	}, discoveryFrame)

	-- Resultados.
	resultsFrame = modal(UDim2.fromOffset(470, 420), gui)
	Theme.label({
		Name = "Heading",
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.fromOffset(0, 10),
		Font = F.Title,
		Text = "",
	}, resultsFrame)
	Theme.divider({ Size = UDim2.new(0.8, 0, 0, 2), Position = UDim2.new(0.1, 0, 0, 62) }, resultsFrame)
	Theme.label({
		Name = "Body",
		Size = UDim2.new(1, -40, 1, -140),
		Position = UDim2.fromOffset(20, 72),
		RichText = true,
		TextScaled = false,
		TextSize = 16,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = F.Heading,
		Text = "",
	}, resultsFrame)
	local again = Theme.button("", "primary", {
		Size = UDim2.fromOffset(230, 44),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
	}, resultsFrame)
	static(again, "results.again")
	again.Activated:Connect(function()
		resultsFrame.Visible = false
		-- Directo a la arena: el servidor espera a que acabe la partida anterior si hace falta.
		task.delay(0.5, function()
			NetClient.fire("QuickJoin")
		end)
	end)
	closeButton(resultsFrame, function()
		resultsFrame.Visible = false
	end)

	-- Códice.
	codexFrame = modal(UDim2.fromOffset(480, 440), gui)
	static(
		Theme.label({ Size = UDim2.new(1, -60, 0, 30), Position = UDim2.fromOffset(16, 12), Font = F.Title, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left }, codexFrame),
		"codexui.title"
	)
	codexProgress = Theme.label({
		Size = UDim2.new(1, -32, 0, 16),
		Position = UDim2.fromOffset(16, 44),
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, codexFrame)
	codexList = Theme.create("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -78),
		Position = UDim2.fromOffset(12, 68),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromScale(0, 0),
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.GoldDark,
	}, codexFrame)
	Theme.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, codexList)
	closeButton(codexFrame, function()
		codexFrame.Visible = false
	end)

	-- Armería.
	armoryFrame = modal(UDim2.fromOffset(600, 400), gui)
	static(
		Theme.label({ Size = UDim2.new(1, -60, 0, 30), Position = UDim2.fromOffset(16, 12), Font = F.Title, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left }, armoryFrame),
		"armory.title"
	)
	for index, name in { "Weapons", "Essences" } do
		static(
			Theme.label({
				Size = UDim2.new(0.5, -24, 0, 16),
				Position = UDim2.new((index - 1) * 0.5, 14, 0, 48),
				Font = F.Bold,
				TextColor3 = C.Muted,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, armoryFrame),
			if name == "Weapons" then "armory.weapons" else "armory.essences"
		)
		local column = Theme.create("Frame", {
			Name = name,
			Size = UDim2.new(0.5, -20, 1, -78),
			Position = UDim2.new((index - 1) * 0.5, 12, 0, 68),
			BackgroundTransparency = 1,
		}, armoryFrame)
		Theme.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, column)
		armoryColumns[name] = column
	end
	closeButton(armoryFrame, function()
		armoryFrame.Visible = false
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- Al cambiar de idioma se redibuja todo.
local function relabel()
	for _, item in staticLabels do
		item.object.Text = t(item.key)
	end
	refreshProgress()
	if codexFrame.Visible then
		refreshCodex()
	end
	if armoryFrame.Visible then
		refreshArmory()
	end
	if resultsFrame.Visible then
		renderResults()
	end
end

local function onProfile(data: Profile)
	profile = data
	Settings.load(data.settings)
	refreshProgress()
	if codexFrame.Visible then
		refreshCodex()
	end
	if armoryFrame.Visible then
		refreshArmory()
	end
	Bus.Profile:Fire(data)
end

-- Abre la armería o el Códice desde otras pantallas (menú de inicio).
function MetaController.openArmory()
	if armoryFrame then
		openArmory()
	end
end

function MetaController.openCodex()
	if codexFrame then
		openCodex()
	end
end

function MetaController.Start(_self: typeof(MetaController))
	build()
	NetClient.on("ProfileReady", onProfile)
	NetClient.on("ProgressUpdate", onProfile)
	NetClient.on("MatchResults", showResults)
	NetClient.on("Discovery", showDiscovery)
	NetClient.on("WorldNews", pushNews)
	NetClient.on("WorldEvents", function(state: { [string]: any })
		gamesEndsAt = os.clock() + (state.gamesRemaining or 0)
	end)
	I18n.Changed:Connect(relabel)
	task.spawn(tickEvents)
end

return MetaController
