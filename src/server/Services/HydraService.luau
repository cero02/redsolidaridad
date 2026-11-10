--!strict
-- Da cuerpo a la Hidra de Lerna (fase 1): construye su modelo de bloques, ejecuta sus
-- ataques con aviso previo y aplica las reglas de HydraLogic (cortar, cauterizar,
-- regenerar). Todo ocurre en el servidor. Diseño: docs/design/HIDRA.md.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ArenaService = require(script.Parent.ArenaService)
local CombatService = require(script.Parent.CombatService)
local Config = require(ServerStorage.ServerOnly.Config.Hydra)
local HydraLogic = require(ServerScriptService.Server.Beasts.HydraLogic)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local HEAD_TAG = "HydraHead"

local SKIN = Color3.fromRGB(45, 95, 60)
local SKIN_TELEGRAPH = Color3.fromRGB(255, 90, 40)
local SKIN_STUNNED = Color3.fromRGB(240, 210, 60)
local SKIN_HIT = Color3.fromRGB(255, 255, 255)
local EYES = Color3.fromRGB(255, 230, 60)
local STUMP_BLEEDING = Color3.fromRGB(200, 30, 30)
local STUMP_BURNT = Color3.fromRGB(25, 20, 20)
local MARKER_DANGER = Color3.fromRGB(255, 40, 40)
local MARKER_POISON = Color3.fromRGB(110, 220, 60)

local HEAD_SIZE = Vector3.new(4.5, 4.5, 7)
local REST_HEIGHT = 15
local REST_DISTANCE = 9
local GROUND_HEIGHT = 2.6

type HeadRecord = {
	slot: number,
	direction: Vector3,
	model: Model,
	part: Part,
	eyes: { Part },
	billboard: BillboardGui,
	label: TextLabel,
	stumpModel: Model,
	stump: Part,
	stumpBillboard: BillboardGui,
	stumpLabel: TextLabel,
	restCFrame: CFrame,
	busy: boolean,
	groundedUntil: number,
}

type AttackMemory = { lastAttackedAt: number, consecutive: number }

local HydraService = {}

-- La fase ha sido superada.
HydraService.Defeated = Signal.new() :: Signal.Signal<()>
-- (texto, segundos, jugador o nil para todos los participantes).
HydraService.Announcement = Signal.new() :: Signal.Signal<string, number, Player?>
-- (cuellos cauterizados, necesarios).
HydraService.Progress = Signal.new() :: Signal.Signal<number, number>

local model: Model? = nil
local markers: Folder? = nil
local logic: HydraLogic.Hydra? = nil
local heads: { [number]: HeadRecord } = {}
local getParticipants: () -> { Player } = function()
	return {}
end

local active = false
local runId = 0
local attacking = false
local nextAttackAt = 0
local lastPattern: HydraLogic.Pattern? = nil
local repeatCount = 0
local severedOnce = false
local random = Random.new()

local litUntil: { [Player]: number } = {}
local attackMemory: { [Player]: AttackMemory } = {}

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
end

local function setHeadVisible(record: HeadRecord, visible: boolean)
	record.part.Transparency = if visible then 0 else 1
	record.part.CanQuery = visible
	for _, eye in record.eyes do
		eye.Transparency = if visible then 0 else 1
	end
	record.billboard.Enabled = visible
end

local function setStumpState(record: HeadRecord, state: "Hidden" | "Bleeding" | "Burnt")
	record.stump.Transparency = if state == "Hidden" then 1 else 0
	record.stump.CanQuery = state == "Bleeding"
	record.stump.Color = if state == "Burnt" then STUMP_BURNT else STUMP_BLEEDING
	record.stump.Material = if state == "Burnt" then Enum.Material.Slate else Enum.Material.Neon
	record.stumpBillboard.Enabled = state ~= "Hidden"
	if state == "Burnt" then
		record.stumpLabel.Text = "Cauterizado"
	end
end

local function refreshHeadLabel(record: HeadRecord)
	local hydra = logic
	if hydra then
		record.label.Text = `{math.ceil(hydra.heads[record.slot].health)}`
	end
end

local function finish()
	active = false
	runId += 1
	for _, record in heads do
		setHeadVisible(record, false)
		if record.stump.Material == Enum.Material.Neon then
			setStumpState(record, "Hidden")
		end
	end
	local folder = markers
	if folder then
		folder:ClearAllChildren()
	end
	HydraService.Defeated:Fire()
end

local function isWeaponLit(player: Player): boolean
	local untilTime = litUntil[player]
	return untilTime ~= nil and os.clock() < untilTime
end

local function onStumpHit(record: HeadRecord, attacker: Player)
	local hydra = logic
	if hydra == nil or not active then
		return
	end
	if not isWeaponLit(attacker) then
		announce("El cuello vuelve a crecer… ¡Enciende tu arma en un brasero!", 3, attacker)
		return
	end
	if hydra:cauterize(record.slot) then
		setStumpState(record, "Burnt")
		HydraService.Progress:Fire(hydra.cauterizedCount, Config.CAUTERIZE_REQUIRED)
		if hydra:isDefeated() then
			finish()
		else
			announce(`¡Cuello cauterizado! ({hydra.cauterizedCount}/{Config.CAUTERIZE_REQUIRED})`, 3, nil)
		end
	end
end

local function onHeadHit(record: HeadRecord, damage: number)
	local hydra = logic
	if hydra == nil or not active then
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
			setHeadColor(record, if previous == SKIN_HIT then SKIN else previous)
		end
	end)
end

local function buildHead(parent: Instance, slot: number): HeadRecord
	local center = ArenaService.getCenter()
	local pondRadius = ArenaService.getPondRadius()
	-- Los cuellos se reparten en abanico hacia la entrada de los gladiadores (+Z).
	local angle = math.rad(90 + (slot - (Config.MAX_SLOTS + 1) / 2) * 38)
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))

	local restPosition = center + direction * REST_DISTANCE + Vector3.new(0, REST_HEIGHT, 0)
	local restCFrame = CFrame.lookAt(restPosition, restPosition + direction + Vector3.new(0, -0.35, 0))

	local headModel = Instance.new("Model")
	headModel.Name = `Head{slot}`

	local part = Instance.new("Part")
	part.Name = "Head"
	part.Anchored = true
	part.CanCollide = false
	part.Size = HEAD_SIZE
	part.Color = SKIN
	part.Material = Enum.Material.Slate
	part.CFrame = restCFrame
	part:SetAttribute("NeckBase", center + direction * 4 + Vector3.new(0, 4, 0))
	part.Parent = headModel
	headModel.PrimaryPart = part

	local eyes = {}
	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(1, 1, 1)
		eye.Color = EYES
		eye.Material = Enum.Material.Neon
		eye.CanCollide = false
		eye.CanQuery = false
		eye.CanTouch = false
		eye.Massless = true
		eye.CFrame = restCFrame * CFrame.new(side * 1.6, 1.2, -2.6)
		eye.Parent = headModel

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = eye
		weld.Parent = eye
		table.insert(eyes, eye)
	end

	local billboard, label = makeBillboard(part, 4)
	CollectionService:AddTag(part, HEAD_TAG)
	headModel.Parent = parent

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

	local record: HeadRecord = {
		slot = slot,
		direction = direction,
		model = headModel,
		part = part,
		eyes = eyes,
		billboard = billboard,
		label = label,
		stumpModel = stumpModel,
		stump = stump,
		stumpBillboard = stumpBillboard,
		stumpLabel = stumpLabel,
		restCFrame = restCFrame,
		busy = false,
		groundedUntil = 0,
	}

	CombatService.registerTarget(headModel, function(_attacker: Player, damage: number, _stun: number)
		onHeadHit(record, damage)
	end)
	CombatService.registerTarget(stumpModel, function(attacker: Player, _damage: number, _stun: number)
		onStumpHit(record, attacker)
	end)
	return record
end

local function refreshAllHeads()
	local hydra = logic
	if hydra == nil then
		return
	end
	for slot, record in heads do
		local status = hydra.heads[slot].status
		setHeadVisible(record, status == "Alive")
		if status == "Alive" then
			refreshHeadLabel(record)
		end
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
			setHeadColor(record, SKIN)
			setStumpState(record, "Hidden")
		end
	end
	refreshAllHeads()

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
	if hydra == nil then
		return
	end
	for slot, record in heads do
		local head = hydra.heads[slot]
		if head.status == "Severed" then
			record.stumpLabel.Text = `¡Fuego! {math.max(0, math.ceil(head.regrowAt - now))}`
		end
	end
end

-- Mordisco: una cabeza se echa atrás, marca una franja en el suelo y se lanza.
-- Después queda en el suelo unos segundos: es la ocasión de golpearla.
local function bite(id: number, record: HeadRecord, targetPosition: Vector3)
	local settings = Config.BITE
	local hydra = logic :: HydraLogic.Hydra
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
	if not isRunning(id) or hydra.heads[record.slot].status ~= "Alive" then
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

	setHeadColor(record, SKIN)
	record.groundedUntil = os.clock() + settings.RECOVERY
	for _, player in getParticipants() do
		local root = getRoot(player)
		if root and distanceToSegment(flat(root.Position), startPosition, endPosition) <= settings.WIDTH / 2 + 1 then
			CombatService.hitPlayer(player, settings.DAMAGE, impactTime, function()
				-- Parada perfecta: la cabeza queda aturdida más tiempo.
				if hydra.heads[record.slot].status == "Alive" then
					record.groundedUntil = os.clock() + settings.PARRY_STUN
					setHeadColor(record, SKIN_STUNNED)
				end
			end)
		end
	end

	-- La recuperación va en su propio hilo para no frenar el siguiente ataque.
	task.spawn(function()
		while isRunning(id) and hydra.heads[record.slot].status == "Alive" and os.clock() < record.groundedUntil do
			task.wait(0.1)
		end
		if isRunning(id) and hydra.heads[record.slot].status == "Alive" then
			setHeadColor(record, SKIN)
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
					CombatService.damagePlayer(player, settings.DAMAGE_PER_TICK)
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
				CombatService.hitPlayer(player, settings.DAMAGE, impactTime)
			end
		end
	end

	marker.Color = Color3.new(1, 1, 1)
	marker.Transparency = 0.2
	Debris:AddItem(marker, 0.2)
end

local function runAttack(id: number)
	local hydra = logic
	if hydra == nil then
		return
	end
	local settings = Config
	local center = ArenaService.getCenter()
	local now = os.clock()

	-- Situación de los gladiadores vivos.
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
			if distance <= settings.TAIL.NEAR_RANGE then
				nearCount += 1
			end
			if distance > settings.BITE.RANGE then
				farCount += 1
			end
		end
	end
	if #players == 0 then
		return
	end

	local freeHeads = {}
	for _, slot in hydra:aliveSlots() do
		if not heads[slot].busy then
			table.insert(freeHeads, heads[slot])
		end
	end

	local pattern = HydraLogic.choosePattern({
		canBite = #freeHeads > 0 and farCount < #players,
		nearCount = nearCount,
		farCount = farCount,
		lastPattern = lastPattern,
		repeatCount = repeatCount,
	}, random:NextNumber())

	if pattern == lastPattern then
		repeatCount += 1
	else
		lastPattern = pattern
		repeatCount = 1
	end

	-- Candidatos según el ataque: el mordisco y el coletazo necesitan alcance.
	local candidates = {}
	local infos = {}
	for index, player in players do
		local distance = (positions[index] - center).Magnitude
		local eligible = true
		if pattern == "Bite" then
			eligible = distance <= settings.BITE.RANGE
		elseif pattern == "Tail" then
			eligible = distance <= settings.TAIL.NEAR_RANGE
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
		bite(id, freeHeads[random:NextInteger(1, #freeHeads)], targetPosition)
	elseif pattern == "Tail" then
		tailSweep(id, targetPosition)
	else
		spit(id, targetPosition)
	end
end

local function mainLoop(id: number)
	local hydra = logic :: HydraLogic.Hydra
	local center = ArenaService.getCenter()
	local pondRadius = ArenaService.getPondRadius()
	local nextPondTick = os.clock() + Config.POND_TICK
	nextAttackAt = os.clock() + Config.FIRST_ATTACK_DELAY

	while isRunning(id) do
		local now = os.clock()

		for _, event in hydra:update(now) do
			handleRegrow(event)
		end
		updateStumpTimers(now)

		-- El estanque está envenenado.
		if now >= nextPondTick then
			nextPondTick = now + Config.POND_TICK
			for _, player in getParticipants() do
				local root = getRoot(player)
				if root and (flat(root.Position) - center).Magnitude < pondRadius - 1 then
					CombatService.damagePlayer(player, Config.POND_DAMAGE_PER_TICK)
				end
			end
		end

		if not attacking and now >= nextAttackAt then
			attacking = true
			task.spawn(function()
				runAttack(id)
				attacking = false
				nextAttackAt = os.clock() + Config.ATTACK_INTERVAL
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

-- Crea la Hidra en el estanque. `participants` devuelve los gladiadores de la partida.
function HydraService.spawn(participants: () -> { Player })
	HydraService.despawn()
	getParticipants = participants

	local center = ArenaService.getCenter()
	local hydraModel = Instance.new("Model")
	hydraModel.Name = "Hydra"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(20, 20, 20)
	body.Anchored = true
	body.CanQuery = false
	body.Color = SKIN
	body.Material = Enum.Material.Slate
	body.Position = center + Vector3.new(0, 1, 0)
	body.Parent = hydraModel
	hydraModel.PrimaryPart = body

	local folder = Instance.new("Folder")
	folder.Name = "Markers"
	folder.Parent = hydraModel
	markers = folder

	logic = HydraLogic.new(Config :: any)
	heads = {}
	for slot = 1, Config.MAX_SLOTS do
		local record = buildHead(hydraModel, slot)
		heads[slot] = record
		setStumpState(record, "Hidden")
	end
	refreshAllHeads()

	hydraModel.Parent = Workspace
	model = hydraModel
	HydraService.Progress:Fire(0, Config.CAUTERIZE_REQUIRED)
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
	task.spawn(mainLoop, runId)
end

function HydraService.despawn()
	active = false
	runId += 1
	for _, record in heads do
		CombatService.unregisterTarget(record.model)
		CombatService.unregisterTarget(record.stumpModel)
	end
	heads = {}
	logic = nil
	markers = nil
	local current = model
	if current then
		current:Destroy()
	end
	model = nil
end

return HydraService
