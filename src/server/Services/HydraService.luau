--!strict
-- Da cuerpo a la Hidra de Lerna: construye su modelo de bloques, ejecuta sus ataques con
-- aviso previo y aplica las reglas de HydraLogic. Tres fases: las tres cabezas, la furia
-- (cinco cabezas y ataques nuevos) y la cabeza inmortal, que solo se vence enterrándola
-- bajo la roca. Todo ocurre en el servidor. Diseño: docs/design/HIDRA.md.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ArenaConfig = require(ServerStorage.ServerOnly.Config.Arena)
local ArenaService = require(script.Parent.ArenaService)
local CombatService = require(script.Parent.CombatService)
local Config = require(ServerStorage.ServerOnly.Config.Hydra)
local HydraLogic = require(ServerScriptService.Server.Beasts.HydraLogic)
local Homing = require(ServerScriptService.Server.Beasts.Homing)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local HEAD_TAG = "HydraHead"

-- Paleta inspirada en la referencia del equipo: escamas grafito, vientre color hueso.
local SKIN = Color3.fromRGB(58, 58, 64)
local SKIN_DARK = Color3.fromRGB(34, 34, 38)
local BONE = Color3.fromRGB(178, 162, 136)
local TOOTH = Color3.fromRGB(236, 230, 214)
local MOUTH = Color3.fromRGB(110, 20, 22)
local GOLD_DARK = Color3.fromRGB(190, 140, 40)
local SKIN_TELEGRAPH = Color3.fromRGB(255, 90, 40)
local SKIN_STUNNED = Color3.fromRGB(240, 210, 60)
local SKIN_HIT = Color3.fromRGB(255, 255, 255)
local GOLD = Color3.fromRGB(255, 200, 60)
local GOLD_STUNNED = Color3.fromRGB(150, 140, 120)
local EYES = Color3.fromRGB(255, 230, 60)
local STUMP_BLEEDING = Color3.fromRGB(200, 30, 30)
local STUMP_BURNT = Color3.fromRGB(25, 20, 20)
local MARKER_DANGER = Color3.fromRGB(255, 40, 40)
local MARKER_POISON = Color3.fromRGB(110, 220, 60)
local MARKER_WATER = Color3.fromRGB(150, 220, 255)
local IRON = Color3.fromRGB(90, 90, 95)

local REST_HEIGHT = 15
local REST_DISTANCE = 9
local GROUND_HEIGHT = 2.6
local HINT_COOLDOWN = 4
local ROMAN = { "I", "II", "III", "IV" }

type BiteSettings = {
	TELEGRAPH: number,
	DAMAGE: number,
	RANGE: number,
	WIDTH: number,
	LUNGE_TIME: number,
	RECOVERY: number,
	PARRY_STUN: number,
	RETURN_TIME: number,
	[string]: any,
}

type HeadRecord = {
	slot: number,
	immortal: boolean,
	direction: Vector3,
	model: Model,
	part: Part,
	-- Piezas decorativas soldadas a la cabeza (ojos, fauces, crestas…).
	decor: { BasePart },
	-- Transparencia original de cada pieza (los modelos 3D pueden traer piezas translúcidas).
	decorTransparency: { [BasePart]: number },
	-- Con modelo 3D la zona de golpe es invisible y el aviso de color va en un Highlight.
	customModel: boolean,
	highlight: Highlight?,
	billboard: BillboardGui,
	label: TextLabel,
	-- Solo las cabezas mortales tienen muñón.
	stumpModel: Model?,
	stump: Part?,
	stumpBillboard: BillboardGui?,
	stumpLabel: TextLabel?,
	baseColor: Color3,
	restCFrame: CFrame,
	busy: boolean,
	groundedUntil: number,
}

type Chain = { model: Model, post: Part, link: Part, health: number, broken: boolean }
type AttackMemory = { lastAttackedAt: number, consecutive: number }
type Mode = "Heads" | "Immortal"

local HydraService = {}

-- La Hidra ha sido vencida.
HydraService.Defeated = Signal.new() :: Signal.Signal<()>
-- (texto, segundos, jugador o nil para todos los participantes).
HydraService.Announcement = Signal.new() :: Signal.Signal<string, number, Player?>
-- Texto de progreso para la interfaz.
HydraService.Progress = Signal.new() :: Signal.Signal<string>
-- Hazaña que puede revelar un secreto del Códice: (jugador o nil para todo el grupo, id).
HydraService.Feat = Signal.new() :: Signal.Signal<Player?, string>
-- Se ha superado una fase (1, 2 o 3).
HydraService.PhaseCleared = Signal.new() :: Signal.Signal<number>

export type Modifiers = {
	attackIntervalScale: number,
	regrowTimeScale: number,
	damageTakenScale: number,
}

local model: Model? = nil
local markers: Folder? = nil
local rock: Part? = nil
local logic: HydraLogic.Hydra? = nil
local heads: { [number]: HeadRecord } = {}
local immortalHead: HeadRecord? = nil
local chains: { Chain } = {}
local getParticipants: () -> { Player } = function()
	return {}
end

local active = false
local runId = 0
local mode: Mode = "Heads"
local attacking = false
local nextAttackAt = 0
local lastPattern: HydraLogic.Pattern? = nil
local repeatCount = 0
local severedOnce = false
local cloudReadyAt = 0
local fireballReadyAt = 0
local fireballVolleys = 0
local nextExtinguishAt = 0
local immortalStunnedUntil = 0
local immortalStunnedOnce = false
local immortalBites = 0
local brokenChains = 0
local random = Random.new()

-- Modificadores del Decreto del César activo.
local attackIntervalScale = 1
local damageScale = 1
local lastCauterizeAt: { [Player]: number } = {}
local DUPLEX_WINDOW = 10

local litUntil: { [Player]: number } = {}
local attackMemory: { [Player]: AttackMemory } = {}
local lastHintAt: { [Player]: number } = {}

local function isRunning(id: number): boolean
	return active and runId == id
end

local function flat(position: Vector3): Vector3
	local center = ArenaService.getCenter()
	return Vector3.new(position.X, center.Y, position.Z)
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function announce(text: string, seconds: number, player: Player?)
	HydraService.Announcement:Fire(text, seconds, player)
end

-- Pista personal, como mucho una cada pocos segundos para no saturar.
local function hint(player: Player, text: string)
	local now = os.clock()
	local last = lastHintAt[player]
	if last == nil or now - last >= HINT_COOLDOWN then
		lastHintAt[player] = now
		announce(text, 3, player)
	end
end

local function fireProgress()
	local hydra = logic
	if hydra == nil then
		return
	end
	if mode == "Immortal" then
		HydraService.Progress:Fire(`La cabeza inmortal · Cadenas rotas {brokenChains}/{#chains}`)
	else
		local numeral = ROMAN[hydra.phase] or tostring(hydra.phase)
		HydraService.Progress:Fire(
			`Fase {numeral} · Cuellos cauterizados {hydra.cauterizedCount}/{hydra.requiredCount}`
		)
	end
end

local function tween(part: Part, goal: CFrame, seconds: number, style: Enum.EasingStyle)
	local info = TweenInfo.new(seconds, style, Enum.EasingDirection.Out)
	TweenService:Create(part, info, { CFrame = goal }):Play()
end

-- Distancia horizontal de un punto al segmento a-b.
local function distanceToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local lengthSquared = ab:Dot(ab)
	if lengthSquared < 0.001 then
		return (point - a).Magnitude
	end
	local t = math.clamp((point - a):Dot(ab) / lengthSquared, 0, 1)
	return (point - (a + ab * t)).Magnitude
end

local function makeMarker(size: Vector3, cframe: CFrame, color: Color3, cylinder: boolean): Part
	local part = Instance.new("Part")
	part.Name = "Marker"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.65
	part.Size = size
	part.CFrame = cframe
	if cylinder then
		part.Shape = Enum.PartType.Cylinder
	end
	part.Parent = markers
	return part
end

local function makeCircleMarker(position: Vector3, radius: number, color: Color3): Part
	local cframe = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return makeMarker(Vector3.new(0.2, radius * 2, radius * 2), cframe, color, true)
end

local function makeBillboard(parent: Instance, offsetY: number): (BillboardGui, TextLabel)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 36)
	billboard.StudsOffset = Vector3.new(0, offsetY, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 200
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = ""
	label.Parent = billboard
	return billboard, label
end

local function setHeadColor(record: HeadRecord, color: Color3)
	record.part.Color = color
	local highlight = record.highlight
	if highlight then
		-- La cabeza dorada siempre brilla; las demás solo durante avisos y golpes.
		highlight.FillColor = color
		highlight.Enabled = record.part.Transparency < 1 and (record.immortal or color ~= record.baseColor)
	end
end

local function setHeadVisible(record: HeadRecord, visible: boolean)
	-- Con modelo 3D la zona de golpe nunca se ve, pero sigue recibiendo golpes.
	record.part.Transparency = if visible and not record.customModel then 0 else 1
	record.part.CanQuery = visible
	for _, piece in record.decor do
		piece.Transparency = if visible then record.decorTransparency[piece] or 0 else 1
	end
	record.billboard.Enabled = visible
	local highlight = record.highlight
	if highlight then
		highlight.Enabled = visible and (record.immortal or record.part.Color ~= record.baseColor)
	end
end

local function setStumpState(record: HeadRecord, state: "Hidden" | "Bleeding" | "Burnt")
	local stump, billboard, label = record.stump, record.stumpBillboard, record.stumpLabel
	if stump == nil or billboard == nil or label == nil then
		return
	end
	stump.Transparency = if state == "Hidden" then 1 else 0
	stump.CanQuery = state == "Bleeding"
	stump.Color = if state == "Burnt" then STUMP_BURNT else STUMP_BLEEDING
	stump.Material = if state == "Burnt" then Enum.Material.Slate else Enum.Material.Neon
	billboard.Enabled = state ~= "Hidden"
	if state == "Burnt" then
		label.Text = "Cauterizado"
	end
end

local function refreshHeadLabel(record: HeadRecord)
	local hydra = logic
	if hydra and not record.immortal then
		record.label.Text = `{math.ceil(hydra.heads[record.slot].health)}`
	end
end

-- ¿Puede esta cabeza atacar o recibir golpes ahora mismo?
local function headUsable(record: HeadRecord): boolean
	if record.immortal then
		return mode == "Immortal"
	end
	local hydra = logic
	return hydra ~= nil and mode == "Heads" and hydra.heads[record.slot].status == "Alive"
end

local function refreshAllHeads()
	local hydra = logic
	if hydra == nil then
		return
	end
	for slot, record in heads do
		local alive = mode == "Heads" and hydra.heads[slot].status == "Alive"
		setHeadVisible(record, alive)
		if alive then
			refreshHeadLabel(record)
		end
	end
	local golden = immortalHead
	if golden then
		setHeadVisible(golden, mode == "Immortal")
	end
end

-- Devuelve todas las cabezas a su postura inicial y oculta los muñones.
local function resetHeadPoses()
	for _, record in heads do
		record.busy = false
		record.groundedUntil = 0
		record.part.CFrame = record.restCFrame
		setHeadColor(record, record.baseColor)
		setStumpState(record, "Hidden")
	end
	local golden = immortalHead
	if golden then
		golden.busy = false
		golden.groundedUntil = 0
		golden.part.CFrame = golden.restCFrame
		setHeadColor(golden, golden.baseColor)
	end
end

local mainLoop: (id: number) -> ()
local buildBody: (parent: Instance, center: Vector3) -> Part

-- Corta todos los ataques en curso, oculta a la Hidra y, tras una pausa, prepara la
-- siguiente fase con `setup` y reanuda el combate.
local function restartAfter(seconds: number, setup: () -> ())
	runId += 1
	local id = runId
	attacking = false
	local folder = markers
	if folder then
		folder:ClearAllChildren()
	end
	for _, record in heads do
		setHeadVisible(record, false)
		setStumpState(record, "Hidden")
	end

	task.delay(seconds, function()
		if not isRunning(id) then
			return
		end
		setup()
		resetHeadPoses()
		refreshAllHeads()
		fireProgress()
		task.spawn(mainLoop, id)
	end)
end

local function finish()
	active = false
	runId += 1
	local folder = markers
	if folder then
		folder:ClearAllChildren()
	end
	for _, record in heads do
		setHeadVisible(record, false)
		setStumpState(record, "Hidden")
	end

	-- La roca cae y entierra la cabeza inmortal.
	local center = ArenaService.getCenter()
	local golden = immortalHead
	local stone = rock
	if golden and stone and mode == "Immortal" then
		golden.part.CFrame = CFrame.new(center + Vector3.new(0, 4, 0))
		local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(stone, info, { Position = center + Vector3.new(0, 9, 0) }):Play()
		task.delay(0.7, function()
			setHeadVisible(golden, false)
		end)
	end
	if mode == "Immortal" then
		HydraService.PhaseCleared:Fire(#Config.PHASES + 1)
		HydraService.Feat:Fire(nil, "SaxumCadit")
	end
	HydraService.Defeated:Fire()
end

local function startImmortalPhase()
	announce("Las cabezas se retiran… algo dorado asciende desde el fondo.", Config.PHASE_TRANSITION_TIME, nil)
	restartAfter(Config.PHASE_TRANSITION_TIME, function()
		mode = "Immortal"
		immortalStunnedUntil = 0
		immortalStunnedOnce = false
		immortalBites = 0
		fireballReadyAt = os.clock() + 6
		lastPattern = nil
		repeatCount = 0
		ArenaService.relightAllBraziers()
		announce("¡LA CABEZA INMORTAL! Ningún acero puede cortarla…", 5, nil)
	end)
end

local function startNextHeadPhase()
	announce("La Hidra se hunde… ¡y el agua empieza a hervir!", Config.PHASE_TRANSITION_TIME, nil)
	restartAfter(Config.PHASE_TRANSITION_TIME, function()
		lastPattern = nil
		repeatCount = 0
		cloudReadyAt = os.clock() + 6
		fireballReadyAt = os.clock() + 8
		nextExtinguishAt = os.clock() + Config.EXTINGUISH_INTERVAL
		announce("¡LA FURIA DE LA HIDRA! Cinco cabezas emergen del pantano.", 5, nil)
	end)
end

local function isWeaponLit(player: Player): boolean
	local untilTime = litUntil[player]
	return untilTime ~= nil and os.clock() < untilTime
end

local function onStumpHit(record: HeadRecord, attacker: Player)
	local hydra = logic
	if hydra == nil or not active or mode ~= "Heads" then
		return
	end
	if not isWeaponLit(attacker) then
		hint(attacker, "El cuello vuelve a crecer… ¡Enciende tu arma en un brasero!")
		return
	end
	if not hydra:cauterize(record.slot) then
		return
	end
	setStumpState(record, "Burnt")
	fireProgress()

	HydraService.Feat:Fire(attacker, "IgnisPurgat")
	local now = os.clock()
	local previous = lastCauterizeAt[attacker]
	if previous ~= nil and now - previous <= DUPLEX_WINDOW then
		HydraService.Feat:Fire(attacker, "DuplexSigillum")
	end
	lastCauterizeAt[attacker] = now

	if hydra:isPhaseCleared() then
		HydraService.PhaseCleared:Fire(hydra.phase)
	end
	if not hydra:isPhaseCleared() then
		announce(`¡Cuello cauterizado! ({hydra.cauterizedCount}/{hydra.requiredCount})`, 3, nil)
	elseif hydra:advancePhase() then
		startNextHeadPhase()
	else
		startImmortalPhase()
	end
end

local function onHeadHit(record: HeadRecord, damage: number)
	local hydra = logic
	if hydra == nil or not active or mode ~= "Heads" then
		return
	end
	local result = hydra:damageHead(record.slot, damage, os.clock())
	if result == "Ignored" then
		return
	end
	refreshHeadLabel(record)

	if result == "Severed" then
		setHeadVisible(record, false)
		setStumpState(record, "Bleeding")
		if not severedOnce then
			severedOnce = true
			announce("¡Una cabeza ha caído! Pero el cuello aún palpita…", 4, nil)
		else
			announce("¡Otra cabeza cortada!", 2.5, nil)
		end
		return
	end

	local previous = record.part.Color
	setHeadColor(record, SKIN_HIT)
	task.delay(0.1, function()
		if record.part.Color == SKIN_HIT then
			setHeadColor(record, if previous == SKIN_HIT then record.baseColor else previous)
		end
	end)
end

local function stunImmortal(by: Player?)
	local golden = immortalHead
	if golden == nil or mode ~= "Immortal" then
		return
	end
	if by then
		HydraService.Feat:Fire(by, "CaputAureum")
	end
	immortalStunnedUntil = os.clock() + Config.IMMORTAL.STUN
	golden.groundedUntil = immortalStunnedUntil
	setHeadColor(golden, GOLD_STUNNED)
	golden.label.Text = "ATURDIDA"
	if not immortalStunnedOnce then
		immortalStunnedOnce = true
		announce("¡Está aturdida! ¡LAS CADENAS! ¡Soltad la roca sobre ella!", 5, nil)
	else
		announce("¡Aturdida! ¡A las cadenas!", 2.5, nil)
	end
end

local function onImmortalHit(attacker: Player, stun: number)
	local golden = immortalHead
	if golden == nil or not active or mode ~= "Immortal" then
		return
	end
	local now = os.clock()
	if now < immortalStunnedUntil then
		hint(attacker, "No puede morir… ¡pero la roca sí puede enterrarla! ¡Las cadenas!")
	elseif now < golden.groundedUntil and stun >= 0.5 then
		-- Un golpe pesado mientras está en el suelo la aturde.
		stunImmortal(attacker)
	else
		hint(attacker, "Tu acero rebota en sus escamas doradas. Un golpe PESADO cuando caiga al suelo…")
	end
end

local function onChainHit(chain: Chain, attacker: Player, damage: number)
	if chain.broken or not active then
		return
	end
	if mode ~= "Immortal" then
		hint(attacker, "Una cadena enorme sujeta la roca sobre el estanque. Ahora no cede.")
		return
	end
	if os.clock() >= immortalStunnedUntil then
		hint(attacker, "La cabeza dorada vigila las cadenas. ¡Atúrdela primero!")
		return
	end

	chain.health -= damage
	chain.post.Color = SKIN_HIT
	task.delay(0.1, function()
		if not chain.broken then
			chain.post.Color = IRON
		end
	end)
	if chain.health > 0 then
		return
	end

	chain.broken = true
	chain.link:Destroy()
	chain.post.Color = STUMP_BURNT
	chain.post.CanQuery = false
	brokenChains += 1
	fireProgress()
	if brokenChains >= #chains then
		finish()
	else
		announce(`¡Cadena rota! ({brokenChains}/{#chains}) La roca se tambalea…`, 3, nil)
	end
end

-- Modelos 3D opcionales -----------------------------------------------------------
-- Si en ServerStorage existe una carpeta "HydraModels" con modelos llamados "Head",
-- "GoldenHead" o "Body", se usan en lugar de los bloques. Guía: docs/ARTE_3D.md.
-- El frente de cada modelo debe mirar hacia su LookVector (−Z); si no, se puede corregir
-- con el atributo numérico "Rotacion" (grados alrededor del eje vertical).

local CUSTOM_FOLDER = "HydraModels"

local function findCustomModel(name: string): Model?
	local folder = ServerStorage:FindFirstChild(CUSTOM_FOLDER)
	local found = if folder then folder:FindFirstChild(name) else nil
	return if found and found:IsA("Model") then found else nil
end

-- Clona un modelo, lo escala para que su tamaño mayor sea `targetSize`, lo coloca en
-- `cframe` y lo suelda a `anchor`. Elimina cualquier script que traiga (seguridad: los
-- modelos de la Creator Store pueden incluir código ajeno).
local function attachCustomModel(
	source: Model,
	parent: Instance,
	anchor: BasePart?,
	cframe: CFrame,
	targetSize: number
): { BasePart }
	local clone = source:Clone()
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	local extents = clone:GetExtentsSize()
	local largest = math.max(extents.X, extents.Y, extents.Z)
	if largest > 0 then
		clone:ScaleTo(clone:GetScale() * targetSize / largest)
	end
	local rotation = source:GetAttribute("Rotacion")
	local turn = if typeof(rotation) == "number" then CFrame.Angles(0, math.rad(rotation), 0) else CFrame.identity
	clone:PivotTo(cframe * turn)

	local parts: { BasePart } = {}
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			descendant.Massless = true
			if anchor then
				descendant.Anchored = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = anchor
				weld.Part1 = descendant
				weld.Parent = descendant
			else
				descendant.Anchored = true
			end
			table.insert(parts, descendant)
		end
	end
	clone.Parent = parent
	return parts
end

-- Pieza decorativa soldada a `anchor`, colocada con `offset` respecto a `base`.
local function decorPart(
	parent: Instance,
	anchor: BasePart,
	base: CFrame,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local piece = Instance.new("Part")
	piece.Name = name
	if shape then
		piece.Shape = shape
	end
	piece.Size = size
	piece.Color = color
	piece.Material = material
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
	piece.Massless = true
	piece.CFrame = base * offset
	piece.Parent = parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = piece
	weld.Parent = piece
	return piece
end

-- Cabeza de dragón: hocico, fauces abiertas con colmillos, ojos, cejas, cuernos y cresta.
-- La pieza principal (`anchor`) sigue siendo la zona de golpe; el resto es decoración.
local function buildHeadDecor(parent: Instance, anchor: BasePart, base: CFrame, s: number, immortal: boolean): { Part }
	local scales = if immortal then GOLD_DARK else SKIN_DARK
	local belly = if immortal then GOLD else BONE
	local skin = if immortal then GOLD else SKIN
	local slate = if immortal then Enum.Material.Metal else Enum.Material.Slate
	local pieces: { Part } = {}
	local function add(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material,
		shape: Enum.PartType?
	)
		table.insert(pieces, decorPart(parent, anchor, base, name, size * s, offset, color, material, shape))
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * s, y * s, z * s)
	end

	-- Hocico y mandíbula abierta (el frente de la cabeza es -Z).
	add("Snout", Vector3.new(3.2, 1.8, 3.6), at(0, 0.5, -5.1), skin, slate)
	add("Nostrils", Vector3.new(2.2, 0.5, 0.6), at(0, 1.2, -6.7), scales, slate)
	add("Jaw", Vector3.new(2.9, 0.9, 5.4), at(0, -2.5, -3.9) * CFrame.Angles(math.rad(-24), 0, 0), belly, slate)
	add("Mouth", Vector3.new(2.6, 0.3, 4.2), at(0, -1.5, -4.2) * CFrame.Angles(math.rad(-10), 0, 0), MOUTH, Enum.Material.SmoothPlastic)
	add("Throat", Vector3.new(3.2, 0.5, 5.5), at(0, -2.3, 0.6), belly, slate)
	for index = 0, 3 do
		local z = -3.9 - index * 0.85
		for _, side in { -1, 1 } do
			add("Fang", Vector3.new(0.28, 0.85, 0.28), at(side * 1.25, -0.75, z), TOOTH, Enum.Material.SmoothPlastic)
			add(
				"Fang",
				Vector3.new(0.26, 0.7, 0.26),
				at(side * 1.15, -1.75, z + 0.4) * CFrame.Angles(math.rad(-24), 0, 0),
				TOOTH,
				Enum.Material.SmoothPlastic
			)
		end
	end

	-- Ojos que brillan bajo cejas afiladas.
	for _, side in { -1, 1 } do
		add(
			"Eye",
			Vector3.new(0.9, 0.9, 0.9),
			at(side * 1.75, 1.15, -2.7),
			if immortal then Color3.fromRGB(255, 60, 60) else EYES,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		add(
			"Brow",
			Vector3.new(1.4, 0.45, 1.8),
			at(side * 1.7, 1.85, -2.6) * CFrame.Angles(0, 0, side * math.rad(-18)),
			scales,
			slate
		)
		-- Cuernos hacia atrás.
		add(
			"Horn",
			Vector3.new(0.6, 0.6, 3.4),
			at(side * 1.5, 2.4, 2.4) * CFrame.Angles(math.rad(28), side * math.rad(-12), 0),
			belly,
			slate
		)
	end

	-- Cresta de púas en la nuca y gola lateral.
	for index = 0, 3 do
		local height = 2.6 - index * 0.35
		add(
			"Crest",
			Vector3.new(0.35, height, 1.1),
			at(0, 2.25 + height / 2 - 0.3, -0.8 + index * 1.3) * CFrame.Angles(math.rad(35), 0, 0),
			scales,
			slate
		)
	end
	for _, side in { -1, 1 } do
		for index = 0, 2 do
			add(
				"Frill",
				Vector3.new(0.3, 1.8 - index * 0.3, 0.9),
				at(side * 2.4, 0.4 - index * 0.7, 2.2 + index * 0.4) * CFrame.Angles(math.rad(40), 0, side * math.rad(-55)),
				scales,
				slate
			)
		end
	end
	return pieces
end

local function buildHead(parent: Instance, slot: number, immortal: boolean): HeadRecord
	local center = ArenaService.getCenter()
	local pondRadius = ArenaService.getPondRadius()
	-- Los cuellos se reparten en abanico hacia la entrada de los gladiadores (+Z).
	local angle = if immortal then math.rad(90) else math.rad(90 + (slot - (Config.MAX_SLOTS + 1) / 2) * 38)
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local scale = if immortal then 1.5 else 1
	local baseColor = if immortal then GOLD else SKIN

	local restPosition = center
		+ direction * REST_DISTANCE
		+ Vector3.new(0, REST_HEIGHT + (if immortal then 4 else 0), 0)
	local restCFrame = CFrame.lookAt(restPosition, restPosition + direction + Vector3.new(0, -0.35, 0))

	local headModel = Instance.new("Model")
	headModel.Name = if immortal then "ImmortalHead" else `Head{slot}`

	local part = Instance.new("Part")
	part.Name = "Head"
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(4.5, 4.5, 7) * scale
	part.Color = baseColor
	part.Material = if immortal then Enum.Material.Neon else Enum.Material.Slate
	part.CFrame = restCFrame
	part:SetAttribute("NeckBase", center + direction * 4 + Vector3.new(0, 4, 0))
	part.Parent = headModel
	headModel.PrimaryPart = part

	local customHead = findCustomModel(if immortal then "GoldenHead" else "Head")
		or (if immortal then findCustomModel("Head") else nil)
	local decor: { BasePart }
	local decorTransparency: { [BasePart]: number } = {}
	local highlight: Highlight? = nil
	if customHead then
		decor = attachCustomModel(customHead, headModel, part, restCFrame, part.Size.Magnitude * 1.15)
		for _, piece in decor do
			decorTransparency[piece] = piece.Transparency
		end
		local glow = Instance.new("Highlight")
		glow.FillTransparency = 0.45
		glow.OutlineTransparency = 0.2
		glow.Enabled = false
		glow.Parent = headModel
		highlight = glow
	else
		decor = buildHeadDecor(headModel, part, restCFrame, scale, immortal) :: any
	end

	local billboard, label = makeBillboard(part, 4 * scale)
	if immortal then
		label.Text = "INMORTAL"
		label.TextColor3 = GOLD
	end
	CollectionService:AddTag(part, HEAD_TAG)
	headModel.Parent = parent

	local record: HeadRecord = {
		slot = slot,
		immortal = immortal,
		direction = direction,
		model = headModel,
		part = part,
		decor = decor,
		decorTransparency = decorTransparency,
		customModel = customHead ~= nil,
		highlight = highlight,
		billboard = billboard,
		label = label,
		stumpModel = nil,
		stump = nil,
		stumpBillboard = nil,
		stumpLabel = nil,
		baseColor = baseColor,
		restCFrame = restCFrame,
		busy = false,
		groundedUntil = 0,
	}

	if immortal then
		CombatService.registerTarget(headModel, function(attacker: Player, _damage: number, stun: number)
			onImmortalHit(attacker, stun)
		end)
		return record
	end

	-- El muñón queda al borde del estanque, al alcance de los gladiadores.
	local stumpModel = Instance.new("Model")
	stumpModel.Name = `Stump{slot}`
	local stump = Instance.new("Part")
	stump.Name = "Stump"
	stump.Anchored = true
	stump.CanCollide = false
	stump.Size = Vector3.new(4, 5, 4)
	stump.CFrame = CFrame.new(center + direction * (pondRadius + 3) + Vector3.new(0, 2.5, 0))
	stump.Parent = stumpModel
	stumpModel.PrimaryPart = stump
	local stumpBillboard, stumpLabel = makeBillboard(stump, 4.5)
	stumpModel.Parent = parent

	record.stumpModel = stumpModel
	record.stump = stump
	record.stumpBillboard = stumpBillboard
	record.stumpLabel = stumpLabel

	CombatService.registerTarget(headModel, function(_attacker: Player, damage: number, _stun: number)
		onHeadHit(record, damage)
	end)
	CombatService.registerTarget(stumpModel, function(attacker: Player, _damage: number, _stun: number)
		onStumpHit(record, attacker)
	end)
	return record
end

-- La roca suspendida sobre el estanque y las cadenas que la sujetan.
local function buildRockAndChains(parent: Instance)
	local settings = Config.IMMORTAL
	local center = ArenaService.getCenter()
	local rockPosition = center + Vector3.new(0, settings.ROCK_HEIGHT, 0)

	local stone = Instance.new("Part")
	stone.Name = "Rock"
	stone.Shape = Enum.PartType.Ball
	stone.Size = Vector3.new(24, 24, 24)
	stone.Anchored = true
	stone.CanCollide = false
	stone.CanQuery = false
	stone.Color = Color3.fromRGB(110, 105, 100)
	stone.Material = Enum.Material.Slate
	stone.Position = rockPosition
	stone.Parent = parent
	rock = stone

	chains = {}
	for index = 1, settings.CHAIN_COUNT do
		local angle = math.rad(30 + (index - 1) * (360 / settings.CHAIN_COUNT))
		local base = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * settings.CHAIN_RADIUS

		local chainModel = Instance.new("Model")
		chainModel.Name = `Chain{index}`

		local post = Instance.new("Part")
		post.Name = "Post"
		post.Anchored = true
		post.Size = Vector3.new(3, 7, 3)
		post.Color = IRON
		post.Material = Enum.Material.Metal
		post.CFrame = CFrame.new(base + Vector3.new(0, 3.5, 0))
		post.Parent = chainModel
		chainModel.PrimaryPart = post

		local top = base + Vector3.new(0, 7, 0)
		local link = Instance.new("Part")
		link.Name = "Link"
		link.Anchored = true
		link.CanCollide = false
		link.CanQuery = false
		link.CastShadow = false
		link.Color = IRON
		link.Material = Enum.Material.Metal
		link.Size = Vector3.new(0.7, 0.7, (rockPosition - top).Magnitude)
		link.CFrame = CFrame.lookAt((top + rockPosition) / 2, rockPosition)
		link.Parent = chainModel

		chainModel.Parent = parent

		local chain: Chain = {
			model = chainModel,
			post = post,
			link = link,
			health = settings.CHAIN_HEALTH,
			broken = false,
		}
		table.insert(chains, chain)
		CombatService.registerTarget(chainModel, function(attacker: Player, damage: number, _stun: number)
			onChainHit(chain, attacker, damage)
		end)
	end
end

local function handleRegrow(event: HydraLogic.RegrowEvent)
	local hydra = logic
	if hydra == nil then
		return
	end
	for _, slot in { event.slot, event.newSlot :: number } do
		local record = heads[slot]
		if record then
			record.busy = false
			record.part.CFrame = record.restCFrame
			setHeadColor(record, record.baseColor)
			setStumpState(record, "Hidden")
		end
	end
	refreshAllHeads()

	if hydra.phase == 1 and #hydra:aliveSlots() >= Config.MAX_SLOTS then
		HydraService.Feat:Fire(nil, "HydraMultiplex")
	end

	if hydra.regrowCount >= Config.HINT_AFTER_REGROWS then
		announce("¡Vuelven a crecer! Solo el FUEGO de los braseros sella sus cuellos.", 5, nil)
	elseif event.newSlot ~= nil then
		announce("¡Córtale una cabeza y crecerán dos!", 4, nil)
	else
		announce("¡La cabeza ha vuelto a crecer!", 3, nil)
	end
end

local function updateStumpTimers(now: number)
	local hydra = logic
	if hydra == nil or mode ~= "Heads" then
		return
	end
	for slot, record in heads do
		local head = hydra.heads[slot]
		local label = record.stumpLabel
		if head.status == "Severed" and label then
			label.Text = `¡Fuego! {math.max(0, math.ceil(head.regrowAt - now))}`
		end
	end
end

-- Mordisco: una cabeza se echa atrás, marca una franja en el suelo y se lanza.
-- Después queda en el suelo unos segundos: es la ocasión de golpearla.
local function bite(id: number, record: HeadRecord, targetPosition: Vector3, settings: BiteSettings)
	local center = ArenaService.getCenter()
	local pondRadius = ArenaService.getPondRadius()

	local offset = targetPosition - center
	local distance = offset.Magnitude
	local direction = if distance > 1 then offset.Unit else record.direction
	local reach = math.clamp(distance, pondRadius + 4, settings.RANGE)
	local startPosition = center + direction * pondRadius
	local landPosition = center + direction * reach
	local endPosition = landPosition + direction * 4
	local length = (endPosition - startPosition).Magnitude

	record.busy = true
	local impactTime = os.clock() + settings.TELEGRAPH

	local middle = (startPosition + endPosition) / 2 + Vector3.new(0, 0.15, 0)
	local marker = makeMarker(
		Vector3.new(settings.WIDTH, 0.2, length),
		CFrame.lookAt(middle, middle + direction),
		MARKER_DANGER,
		false
	)
	setHeadColor(record, SKIN_TELEGRAPH)
	tween(record.part, record.restCFrame * CFrame.new(0, 3, 4), 0.4, Enum.EasingStyle.Quad)

	task.wait(settings.TELEGRAPH - settings.LUNGE_TIME)
	if not isRunning(id) or not headUsable(record) then
		marker:Destroy()
		record.busy = false
		return
	end

	local groundPosition = landPosition + Vector3.new(0, GROUND_HEIGHT, 0)
	tween(
		record.part,
		CFrame.lookAt(groundPosition, groundPosition + direction),
		settings.LUNGE_TIME,
		Enum.EasingStyle.Linear
	)
	task.wait(settings.LUNGE_TIME)
	marker:Destroy()
	if not isRunning(id) then
		record.busy = false
		return
	end

	setHeadColor(record, record.baseColor)
	record.groundedUntil = os.clock() + settings.RECOVERY
	for _, player in getParticipants() do
		local root = getRoot(player)
		if root and distanceToSegment(flat(root.Position), startPosition, endPosition) <= settings.WIDTH / 2 + 1 then
			CombatService.hitPlayer(player, settings.DAMAGE * damageScale, impactTime, function()
				-- Parada perfecta: la cabeza queda aturdida más tiempo.
				if not isRunning(id) or not headUsable(record) then
					return
				end
				if record.immortal then
					stunImmortal(player)
				else
					record.groundedUntil = os.clock() + settings.PARRY_STUN
					setHeadColor(record, SKIN_STUNNED)
				end
			end)
		end
	end

	-- La recuperación va en su propio hilo para no frenar el siguiente ataque.
	task.spawn(function()
		while isRunning(id) and headUsable(record) and os.clock() < record.groundedUntil do
			task.wait(0.1)
		end
		if isRunning(id) and headUsable(record) then
			setHeadColor(record, record.baseColor)
			if record.immortal then
				record.label.Text = "INMORTAL"
			end
			tween(record.part, record.restCFrame, settings.RETURN_TIME, Enum.EasingStyle.Quad)
			task.wait(settings.RETURN_TIME)
		end
		record.busy = false
	end)
end

-- Escupitajo: marca un círculo y deja un charco de veneno que daña a quien lo pise.
local function spit(id: number, targetPosition: Vector3)
	local settings = Config.SPIT
	local marker = makeCircleMarker(targetPosition, settings.RADIUS, MARKER_POISON)

	task.wait(settings.TELEGRAPH)
	if not isRunning(id) then
		marker:Destroy()
		return
	end
	marker.Transparency = 0.3

	task.spawn(function()
		local ticks = math.floor(settings.DURATION / settings.TICK)
		for _ = 1, ticks do
			task.wait(settings.TICK)
			if not isRunning(id) then
				break
			end
			for _, player in getParticipants() do
				local root = getRoot(player)
				if root and (flat(root.Position) - targetPosition).Magnitude <= settings.RADIUS then
					CombatService.damagePlayer(player, settings.DAMAGE_PER_TICK * damageScale)
				end
			end
		end
		marker:Destroy()
	end)
end

-- Coletazo: marca una zona junto al estanque. Se evita saliendo, esquivando o saltando.
local function tailSweep(id: number, targetPosition: Vector3)
	local settings = Config.TAIL
	local center = ArenaService.getCenter()
	local offset = targetPosition - center
	local direction = if offset.Magnitude > 1 then offset.Unit else Vector3.zAxis
	local zoneCenter = center + direction * (ArenaService.getPondRadius() + settings.RADIUS * 0.6)

	local impactTime = os.clock() + settings.TELEGRAPH
	local marker = makeCircleMarker(zoneCenter, settings.RADIUS, MARKER_DANGER)

	task.wait(settings.TELEGRAPH)
	if not isRunning(id) then
		marker:Destroy()
		return
	end

	for _, player in getParticipants() do
		local root = getRoot(player)
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if root and humanoid and (flat(root.Position) - zoneCenter).Magnitude <= settings.RADIUS then
			-- Quien está en el aire salta por encima de la cola.
			if humanoid.FloorMaterial ~= Enum.Material.Air then
				CombatService.hitPlayer(player, settings.DAMAGE * damageScale, impactTime)
			else
				HydraService.Feat:Fire(player, "Saltus")
			end
		end
	end

	marker.Color = Color3.new(1, 1, 1)
	marker.Transparency = 0.2
	Debris:AddItem(marker, 0.2)
end

-- Nube tóxica (fase 2): niebla venenosa sobre la mitad de la arena con más gladiadores.
local function toxicCloud(id: number, positions: { Vector3 })
	local settings = Config.CLOUD
	local center = ArenaService.getCenter()
	local radius = ArenaConfig.RADIUS
	cloudReadyAt = os.clock() + settings.COOLDOWN

	local balance = 0
	for _, position in positions do
		balance += if position.X >= center.X then 1 else -1
	end
	local axis = if balance >= 0 then Vector3.xAxis else -Vector3.xAxis

	announce("¡La Hidra inhala! ¡Huid de la niebla!", settings.TELEGRAPH + 1, nil)
	for _, record in heads do
		if headUsable(record) and not record.busy then
			setHeadColor(record, MARKER_POISON)
		end
	end
	local marker = makeMarker(
		Vector3.new(radius, 0.2, radius * 2),
		CFrame.new(center + axis * (radius / 2) + Vector3.new(0, 0.12, 0)),
		MARKER_POISON,
		false
	)

	task.wait(settings.TELEGRAPH)
	for _, record in heads do
		if record.part.Color == MARKER_POISON then
			setHeadColor(record, record.baseColor)
		end
	end
	if not isRunning(id) then
		marker:Destroy()
		return
	end
	marker.Transparency = 0.4

	task.spawn(function()
		local ticks = math.floor(settings.DURATION / settings.TICK)
		for _ = 1, ticks do
			task.wait(settings.TICK)
			if not isRunning(id) then
				break
			end
			for _, player in getParticipants() do
				local root = getRoot(player)
				if root and (flat(root.Position) - center):Dot(axis) > 0 then
					CombatService.damagePlayer(player, settings.DAMAGE_PER_TICK * damageScale)
				end
			end
		end
		marker:Destroy()
	end)
end

-- Inmersión (fase 2): burbujas bajo un gladiador y la Hidra emerge de golpe.
local function dive(id: number, targetPosition: Vector3)
	local settings = Config.DIVE
	local impactTime = os.clock() + settings.TELEGRAPH
	local marker = makeCircleMarker(targetPosition, settings.RADIUS, MARKER_WATER)

	task.wait(settings.TELEGRAPH)
	if not isRunning(id) then
		marker:Destroy()
		return
	end
	for _, player in getParticipants() do
		local root = getRoot(player)
		if root and (flat(root.Position) - targetPosition).Magnitude <= settings.RADIUS then
			CombatService.hitPlayer(player, settings.DAMAGE * damageScale, impactTime)
		end
	end

	-- Columna de agua (solo visual).
	marker.Size = Vector3.new(14, settings.RADIUS * 2, settings.RADIUS * 2)
	marker.CFrame = CFrame.new(targetPosition + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(90))
	marker.Transparency = 0.45
	Debris:AddItem(marker, 0.35)
end

-- Bolas de fuego -----------------------------------------------------------------

local function toVec(v: Vector3): Homing.Vec
	return { x = v.X, y = v.Y, z = v.Z }
end

local function fromVec(v: Homing.Vec): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

local function makeFireball(position: Vector3, color: Color3): Part
	local ball = Instance.new("Part")
	ball.Name = "Fireball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(3, 3, 3)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Position = position
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 0
	fire.Color = color
	fire.Parent = ball
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 3
	light.Parent = ball
	ball.Parent = markers
	return ball
end

-- Explosión solo visual: sin empuje ni daño a las articulaciones.
local function burst(position: Vector3)
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = 4
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = Workspace
end

-- La bola devuelta con una parada perfecta vuela hacia una cabeza y la castiga.
local function reflectFireball(id: number, reflector: Player, from: Vector3)
	local settings = Config.FIREBALL
	local target: HeadRecord? = nil
	if mode == "Immortal" then
		target = immortalHead
	else
		local best = math.huge
		for _, record in heads do
			if headUsable(record) then
				local distance = (record.part.Position - from).Magnitude
				if distance < best then
					best = distance
					target = record
				end
			end
		end
	end
	local record = target
	if record == nil then
		return
	end

	HydraService.Feat:Fire(reflector, "IgnisReflexus")
	local ball = makeFireball(from, Color3.fromRGB(255, 230, 120))
	local position = from
	local started = os.clock()
	while isRunning(id) and os.clock() - started < 3 do
		local deltaTime = RunService.Heartbeat:Wait()
		local offset = record.part.Position - position
		if offset.Magnitude <= 4 then
			break
		end
		position += offset.Unit * math.min(offset.Magnitude, settings.REFLECT_SPEED * deltaTime)
		ball.Position = position
	end
	ball:Destroy()
	if not isRunning(id) or not headUsable(record) then
		return
	end
	burst(record.part.Position)
	if record.immortal then
		stunImmortal(reflector)
	else
		onHeadHit(record, settings.REFLECT_DAMAGE)
	end
end

-- Una bola que persigue a `target`. Choca con el primer gladiador que toque.
local function launchFireball(id: number, origin: Vector3, target: Player)
	local settings = Config.FIREBALL
	local floorY = ArenaService.getCenter().Y
	local maxTurn = math.rad(settings.TURN_RATE)
	local ball = makeFireball(origin, Color3.fromRGB(255, 120, 30))

	local position = origin
	local aim = origin + Vector3.new(0, -1, 0)
	local root = getRoot(target)
	if root then
		aim = Vector3.new(root.Position.X, floorY + settings.HEIGHT, root.Position.Z)
	end
	local direction = toVec((aim - origin).Unit)
	local started = os.clock()

	while isRunning(id) and os.clock() - started < settings.LIFETIME do
		local deltaTime = RunService.Heartbeat:Wait()
		local targetRoot = getRoot(target)
		if targetRoot and CombatService.isAlive(target) then
			aim = Vector3.new(targetRoot.Position.X, floorY + settings.HEIGHT, targetRoot.Position.Z)
		end
		direction = Homing.steer(direction, toVec(aim - position), maxTurn * deltaTime)
		position += fromVec(direction) * settings.SPEED * deltaTime
		ball.Position = position

		for _, player in getParticipants() do
			local playerRoot = getRoot(player)
			if
				playerRoot
				and CombatService.isAlive(player)
				and (playerRoot.Position - position).Magnitude <= settings.RADIUS
			then
				ball:Destroy()
				burst(position)
				local hitPosition = position
				CombatService.hitPlayer(player, settings.DAMAGE * damageScale, os.clock(), function()
					task.spawn(reflectFireball, id, player, hitPosition)
				end)
				return
			end
		end

		if position.Y <= floorY + 0.5 then
			break
		end
	end
	if ball.Parent then
		burst(position)
		ball:Destroy()
	end
end

local function fireballs(id: number, target: Player, sources: { HeadRecord })
	local settings = Config.FIREBALL
	fireballReadyAt = os.clock() + settings.COOLDOWN
	if #sources == 0 then
		return
	end
	fireballVolleys += 1
	if fireballVolleys == 1 then
		announce("¡Bolas de fuego! Te persiguen… pero giran despacio.", 3, nil)
	elseif fireballVolleys == settings.HINT_AFTER then
		announce("Dicen que un escudo en el instante justo devuelve el fuego a su dueño…", 4, nil)
	end

	for _, record in sources do
		setHeadColor(record, SKIN_TELEGRAPH)
	end
	task.wait(settings.TELEGRAPH)
	for _, record in sources do
		if headUsable(record) then
			setHeadColor(record, record.baseColor)
		end
	end

	for index = 1, settings.COUNT do
		if not isRunning(id) then
			return
		end
		local record = sources[((index - 1) % #sources) + 1]
		if headUsable(record) then
			local mouth = record.part.CFrame * CFrame.new(0, 0, -record.part.Size.Z / 2 - 1.5)
			task.spawn(launchFireball, id, mouth.Position, target)
		end
		task.wait(settings.GAP)
	end
end

local function runAttack(id: number)
	local hydra = logic
	if hydra == nil then
		return
	end
	local center = ArenaService.getCenter()
	local now = os.clock()
	local biteSettings: BiteSettings = if mode == "Immortal" then Config.IMMORTAL :: any else Config.BITE :: any

	-- Situación de los gladiadores en pie.
	local players = {}
	local positions = {}
	local nearCount, farCount = 0, 0
	for _, player in getParticipants() do
		local root = getRoot(player)
		if root and CombatService.isAlive(player) then
			local position = flat(root.Position)
			local distance = (position - center).Magnitude
			table.insert(players, player)
			table.insert(positions, position)
			if distance <= Config.TAIL.NEAR_RANGE then
				nearCount += 1
			end
			if distance > biteSettings.RANGE then
				farCount += 1
			end
		end
	end
	if #players == 0 then
		return
	end

	local freeHeads = {}
	if mode == "Immortal" then
		local golden = immortalHead
		if golden and not golden.busy and now >= immortalStunnedUntil then
			table.insert(freeHeads, golden)
		end
	else
		for _, slot in hydra:aliveSlots() do
			if not heads[slot].busy then
				table.insert(freeHeads, heads[slot])
			end
		end
	end

	local pattern = HydraLogic.choosePattern({
		canBite = #freeHeads > 0 and farCount < #players,
		nearCount = nearCount,
		farCount = farCount,
		lastPattern = lastPattern,
		repeatCount = repeatCount,
		-- La cabeza inmortal solo usa los ataques básicos.
		phase = if mode == "Immortal" then 1 else hydra.phase,
		freeHeads = #freeHeads,
		cloudReady = now >= cloudReadyAt,
		-- Bolas de fuego desde la furia, también con la cabeza inmortal.
		allowFireball = mode == "Immortal" or hydra.phase >= 2,
		fireballReady = now >= fireballReadyAt,
	}, random:NextNumber())

	if pattern == lastPattern then
		repeatCount += 1
	else
		lastPattern = pattern
		repeatCount = 1
	end

	if pattern == "Cloud" then
		toxicCloud(id, positions)
		return
	end

	-- Candidatos según el ataque: mordiscos y coletazo necesitan alcance.
	local candidates = {}
	local infos = {}
	for index, player in players do
		local distance = (positions[index] - center).Magnitude
		local eligible = true
		if pattern == "Bite" or pattern == "Chain" then
			eligible = distance <= biteSettings.RANGE
		elseif pattern == "Tail" then
			eligible = distance <= Config.TAIL.NEAR_RANGE
		end
		if eligible then
			local memory = attackMemory[player]
			table.insert(candidates, index)
			table.insert(infos, {
				timeSinceAttacked = if memory then now - memory.lastAttackedAt else 20,
				consecutive = if memory then memory.consecutive else 0,
			})
		end
	end
	if #candidates == 0 then
		return
	end

	local chosen = candidates[HydraLogic.chooseTarget(infos, random:NextNumber())]
	local target = players[chosen]
	local targetPosition = positions[chosen]

	-- Memoria para repartir los ataques entre los jugadores.
	for _, player in players do
		local memory = attackMemory[player]
		if player == target then
			attackMemory[player] = {
				lastAttackedAt = now,
				consecutive = if memory then memory.consecutive + 1 else 1,
			}
		elseif memory then
			memory.consecutive = 0
		end
	end

	if pattern == "Bite" then
		local record = freeHeads[random:NextInteger(1, #freeHeads)]
		if record.immortal then
			immortalBites += 1
			if immortalBites == 3 and not immortalStunnedOnce then
				announce("El anunciador: «¡Una parada perfecta podría aturdirla!»", 4, nil)
			end
		end
		bite(id, record, targetPosition, biteSettings)
	elseif pattern == "Chain" then
		-- Hasta tres cabezas muerden una tras otra, cada una donde esté el gladiador.
		for index = 1, math.min(3, #freeHeads) do
			local root = getRoot(target)
			if root == nil or not isRunning(id) then
				break
			end
			task.spawn(bite, id, freeHeads[index], flat(root.Position), biteSettings)
			task.wait(Config.CHAIN_GAP)
		end
		task.wait(biteSettings.TELEGRAPH)
	elseif pattern == "Tail" then
		tailSweep(id, targetPosition)
	elseif pattern == "Dive" then
		dive(id, targetPosition)
	elseif pattern == "Fireball" then
		local sources = freeHeads
		if #sources == 0 then
			for _, record in heads do
				if headUsable(record) then
					table.insert(sources, record)
				end
			end
		end
		fireballs(id, target, sources)
	else
		spit(id, targetPosition)
	end
end

-- En la furia, la Hidra apaga un brasero de vez en cuando (siempre queda uno encendido).
local function extinguishBrazier()
	local lit = {}
	for index = 1, ArenaService.getBrazierCount() do
		if ArenaService.isBrazierLit(index) then
			table.insert(lit, index)
		end
	end
	if #lit > 1 then
		ArenaService.setBrazierLit(lit[random:NextInteger(1, #lit)], false)
		announce("¡La Hidra ha apagado un brasero! Reavivad el fuego.", 3.5, nil)
	end
end

function mainLoop(id: number)
	local hydra = logic :: HydraLogic.Hydra
	local center = ArenaService.getCenter()
	local pondRadius = ArenaService.getPondRadius()
	local nextPondTick = os.clock() + Config.POND_TICK
	nextAttackAt = os.clock() + Config.FIRST_ATTACK_DELAY

	while isRunning(id) do
		local now = os.clock()

		if mode == "Heads" then
			for _, event in hydra:update(now) do
				handleRegrow(event)
			end
			updateStumpTimers(now)

			if hydra.phase >= 2 and now >= nextExtinguishAt then
				nextExtinguishAt = now + Config.EXTINGUISH_INTERVAL
				extinguishBrazier()
			end
		end

		-- El estanque está envenenado.
		if now >= nextPondTick then
			nextPondTick = now + Config.POND_TICK
			for _, player in getParticipants() do
				local root = getRoot(player)
				if root and (flat(root.Position) - center).Magnitude < pondRadius - 1 then
					CombatService.damagePlayer(player, Config.POND_DAMAGE_PER_TICK * damageScale)
				end
			end
		end

		if not attacking and now >= nextAttackAt then
			attacking = true
			task.spawn(function()
				runAttack(id)
				-- Si la fase cambió mientras tanto, este hilo ya no manda.
				if runId == id then
					attacking = false
					nextAttackAt = os.clock() + Config.ATTACK_INTERVAL * attackIntervalScale
				end
			end)
		end

		task.wait(0.1)
	end
end

local function lightWeapon(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	litUntil[player] = os.clock() + Config.WEAPON_LIT_TIME

	local hand = character:FindFirstChild("RightHand")
		or character:FindFirstChild("Right Arm")
		or character:FindFirstChild("HumanoidRootPart")
	if hand and hand:IsA("BasePart") then
		local old = hand:FindFirstChild("WeaponFire")
		if old then
			old:Destroy()
		end
		local fire = Instance.new("Fire")
		fire.Name = "WeaponFire"
		fire.Size = 4
		fire.Heat = 8
		fire.Parent = hand
		Debris:AddItem(fire, Config.WEAPON_LIT_TIME)
	end
	announce(`¡Arma en llamas! ({Config.WEAPON_LIT_TIME} s)`, 2, player)
end

function HydraService.Start(_self: typeof(HydraService))
	ArenaService.BrazierTriggered:Connect(lightWeapon)
end

-- Cuerpo de cuatro patas con garras, púas en el lomo y cola rizada. Mira hacia la entrada
-- de los gladiadores (+Z). Solo decorativo: no recibe golpes.
function buildBody(parent: Instance, center: Vector3): Part
	local customBody = findCustomModel("Body")
	if customBody then
		-- Ancla invisible (el cuerpo no recibe golpes) y el modelo anclado en su sitio.
		local anchor = Instance.new("Part")
		anchor.Name = "Body"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.CFrame = CFrame.lookAt(center + Vector3.new(0, 7, -4), center + Vector3.new(0, 7, 10))
		anchor.Parent = parent
		local parts = attachCustomModel(customBody, parent, nil, anchor.CFrame, 30)
		-- El cuerpo sí bloquea el paso para que no se atraviese.
		for _, piece in parts do
			piece.CanCollide = true
		end
		return anchor
	end
	local function piece(
		name: string,
		size: Vector3,
		cframe: CFrame,
		color: Color3,
		shape: Enum.PartType?,
		collide: boolean?
	): Part
		local part = Instance.new("Part")
		part.Name = name
		if shape then
			part.Shape = shape
		end
		part.Size = size
		part.CFrame = cframe
		part.Color = color
		part.Material = Enum.Material.Slate
		part.Anchored = true
		part.CanCollide = collide ~= false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Parent = parent
		return part
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(center + Vector3.new(x, y, z))
	end

	-- Tronco: pecho y cadera redondeados unidos por el lomo.
	local torso = piece("Body", Vector3.new(13, 9, 16), at(0, 6, -3), SKIN)
	torso.CastShadow = true
	piece("Chest", Vector3.new(13, 13, 13), at(0, 6.5, 4), SKIN, Enum.PartType.Ball)
	piece("Hips", Vector3.new(12, 12, 12), at(0, 6, -10), SKIN, Enum.PartType.Ball)
	piece("Belly", Vector3.new(10, 1.2, 18), at(0, 1.7, -3), BONE)

	-- Patas con garras.
	for _, leg in { { 6.2, 5 }, { -6.2, 5 }, { 6.2, -11 }, { -6.2, -11 } } do
		local x, z = leg[1], leg[2]
		local side = if x > 0 then 1 else -1
		piece("Thigh", Vector3.new(4, 7, 4.5), at(x, 5, z) * CFrame.Angles(0, 0, side * math.rad(-14)), SKIN)
		piece("Shin", Vector3.new(3, 5, 3), at(x + side * 1.4, 1.2, z + 0.8), SKIN_DARK)
		for claw = -1, 1 do
			piece(
				"Claw",
				Vector3.new(0.5, 0.5, 2.2),
				at(x + side * 1.4 + claw * 0.9, -0.6, z + 2.8) * CFrame.Angles(math.rad(-20), 0, 0),
				BONE,
				nil,
				false
			)
		end
	end

	-- Púas del lomo.
	for index = 0, 8 do
		local z = 7 - index * 2.4
		local height = 3.8 - math.abs(index - 3) * 0.35
		piece(
			"Spine",
			Vector3.new(0.6, height, 1.6),
			at(0, 11.5 + height / 2 - 0.8, z) * CFrame.Angles(math.rad(30), 0, 0),
			SKIN_DARK,
			nil,
			false
		)
	end

	-- Cola que se enrosca hacia arriba, con púas.
	local tail = {
		{ 0, 5, -16, 7 },
		{ 0, 5.5, -20, 6 },
		{ 1, 6.5, -23.5, 5 },
		{ 2.5, 8.5, -26, 4.2 },
		{ 4, 11, -27.2, 3.4 },
		{ 5, 13.6, -26.6, 2.7 },
		{ 5.4, 15.8, -25, 2 },
	}
	for _, segment in tail do
		local x, y, z, size = segment[1], segment[2], segment[3], segment[4]
		piece("Tail", Vector3.new(size, size, size), at(x, y, z), SKIN, Enum.PartType.Ball, false)
		piece(
			"TailSpine",
			Vector3.new(0.45, size * 0.7, size * 0.35),
			at(x, y + size * 0.55, z) * CFrame.Angles(math.rad(25), 0, 0),
			SKIN_DARK,
			nil,
			false
		)
	end
	for fan = -1, 1 do
		piece(
			"TailTip",
			Vector3.new(0.4, 3, 1),
			at(5.6, 17.5, -24) * CFrame.Angles(math.rad(-20), 0, fan * math.rad(30)),
			SKIN_DARK,
			nil,
			false
		)
	end
	return torso
end

-- Crea la Hidra en el estanque. `participants` devuelve los gladiadores de la partida.
function HydraService.spawn(participants: () -> { Player }, modifiers: Modifiers?)
	HydraService.despawn()
	getParticipants = participants
	attackIntervalScale = if modifiers then modifiers.attackIntervalScale else 1
	damageScale = if modifiers then modifiers.damageTakenScale else 1
	local regrowScale = if modifiers then modifiers.regrowTimeScale else 1
	table.clear(lastCauterizeAt)

	local center = ArenaService.getCenter()
	local hydraModel = Instance.new("Model")
	hydraModel.Name = "Hydra"

	local body = buildBody(hydraModel, center)
	hydraModel.PrimaryPart = body

	local folder = Instance.new("Folder")
	folder.Name = "Markers"
	folder.Parent = hydraModel
	markers = folder

	mode = "Heads"
	brokenChains = 0
	fireballVolleys = 0
	local logicConfig = table.clone(Config) :: any
	logicConfig.REGROW_TIME = Config.REGROW_TIME * regrowScale
	logic = HydraLogic.new(logicConfig)
	heads = {}
	for slot = 1, Config.MAX_SLOTS do
		heads[slot] = buildHead(hydraModel, slot, false)
	end
	immortalHead = buildHead(hydraModel, 0, true)
	buildRockAndChains(hydraModel)
	resetHeadPoses()
	refreshAllHeads()
	ArenaService.relightAllBraziers()

	hydraModel.Parent = Workspace
	model = hydraModel
	fireProgress()
end

-- Empieza a atacar.
function HydraService.begin()
	if logic == nil or active then
		return
	end
	active = true
	runId += 1
	attacking = false
	lastPattern = nil
	repeatCount = 0
	severedOnce = false
	table.clear(attackMemory)
	table.clear(lastHintAt)
	task.spawn(mainLoop, runId)
end

function HydraService.despawn()
	active = false
	runId += 1
	for _, record in heads do
		CombatService.unregisterTarget(record.model)
		local stumpModel = record.stumpModel
		if stumpModel then
			CombatService.unregisterTarget(stumpModel)
		end
	end
	local golden = immortalHead
	if golden then
		CombatService.unregisterTarget(golden.model)
	end
	for _, chain in chains do
		CombatService.unregisterTarget(chain.model)
	end
	heads = {}
	chains = {}
	immortalHead = nil
	logic = nil
	markers = nil
	rock = nil
	local current = model
	if current then
		current:Destroy()
	end
	model = nil
	ArenaService.relightAllBraziers()
end

return HydraService
