--!strict
-- Combate autoritativo: valida las acciones que piden los jugadores, calcula los golpes
-- en el servidor y resuelve los golpes que reciben. Incluye las tres armas, los poderes
-- de las esencias y las definitivas. Diseño: docs/design/COMBATE.md y
-- docs/design/ARMAS_Y_ESENCIAS.md.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Essences = require(ReplicatedStorage.Shared.Config.Essences)
local FighterState = require(ReplicatedStorage.Shared.Combat.FighterState)
local LoadoutService = require(script.Parent.LoadoutService)
local NetService = require(script.Parent.NetService)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

type Fighter = FighterState.FighterState

-- Lo que hace un objetivo (muñeco, bestia…) cuando un jugador lo golpea.
export type TargetHandler = (attacker: Player, damage: number, stun: number) -> ()

-- Datos de combate de cada jugador que no forman parte de las reglas puras.
type Info = {
	weaponId: string,
	essenceId: string,
	essenceReadyAt: number,
	lastDamagedAt: number,
	speedUntil: number,
}

-- Definitivas (valores de diseño).
local TESTUDO_DURATION = 4
local TESTUDO_RADIUS = 14
local PILA_DISTANCE = 12
local PILA_RADIUS = 8
local PILA_COUNT = 6
local PILA_GAP = 0.2
local PILA_DAMAGE = 20
local QUAKE_RADII = { 8, 13, 18 }
local QUAKE_GAP = 0.35
local QUAKE_DAMAGE = 30
local QUAKE_STUN = 0.5
local AGUILA_STUN = 0.5
local REGEN_TICK = 1

local GOLD = Color3.fromRGB(255, 210, 90)
local POISON = Color3.fromRGB(120, 230, 80)
local WIND = Color3.fromRGB(190, 230, 255)

local CombatService = {}

-- Un jugador ha hecho una parada perfecta.
CombatService.Parried = Signal.new() :: Signal.Signal<Player>

local fighters: { [Player]: Fighter } = {}
local infos: { [Player]: Info } = {}
-- Jugadores caídos: con 0 de vida pero aún no muertos (esperan reanimación).
local downed: { [Player]: boolean } = {}
-- Decide si un jugador que llega a 0 de vida queda caído (true) o muere (false).
local zeroHealthHandler: ((player: Player) -> boolean)? = nil
local targets: { [Model]: TargetHandler } = {}

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function sendState(player: Player, fighter: Fighter)
	local now = os.clock()
	local snapshot: { [string]: any } = fighter:snapshot(now) :: any
	local info = infos[player]
	if info then
		snapshot.weapon = info.weaponId
		snapshot.essence = info.essenceId
		snapshot.essenceReadyIn = math.max(0, info.essenceReadyAt - now)
	end
	NetService.fire("CombatState", player, snapshot)
end

local function syncHumanoid(player: Player, fighter: Fighter)
	local humanoid = getHumanoid(player)
	if humanoid == nil then
		return
	end
	if fighter:isDead() and not downed[player] then
		local handler = zeroHealthHandler
		if handler ~= nil and handler(player) then
			downed[player] = true
			NetService.fire("CombatEvent", player, "Downed", player.UserId)
		end
	end
	if downed[player] then
		-- Caído: no muere todavía, pero no puede moverse.
		humanoid.Health = 1
		humanoid.WalkSpeed = 0
		return
	end
	humanoid.Health = fighter.health
	local speed = if fighter.blocking then Combat.BLOCK_WALK_SPEED else Combat.WALK_SPEED
	local info = infos[player]
	if info and os.clock() < info.speedUntil then
		local essence = Essences[info.essenceId]
		speed *= if essence and essence.speedMultiplier then essence.speedMultiplier else 1
	end
	humanoid.WalkSpeed = speed
end

local function findTarget(part: Instance): Model?
	local current = part.Parent
	while current ~= nil and current ~= Workspace do
		if current:IsA("Model") and targets[current] ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- Efectos visuales (servidor, los ven todos) -------------------------------------------

local function effectPart(size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = "CombatEffect"
	if shape then
		part.Shape = shape
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.35
	part.Size = size
	part.CFrame = cframe
	part.Parent = Workspace
	return part
end

-- Onda en el suelo que se expande y se desvanece.
local function ring(position: Vector3, radius: number, color: Color3)
	local ground = CFrame.new(position.X, position.Y - 2.6, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	local part = effectPart(Vector3.new(0.3, 2, 2), ground, color, Enum.PartType.Cylinder)
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(part, info, { Size = Vector3.new(0.3, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(part, 0.4)
end

-- Cúpula del Testudo pegada al personaje mientras dura.
local function dome(player: Player, duration: number)
	local root = getRoot(player)
	if root == nil then
		return
	end
	local part = effectPart(Vector3.new(9, 9, 9), root.CFrame, GOLD, Enum.PartType.Ball)
	part.Anchored = false
	part.Massless = true
	part.Transparency = 0.75
	part.Material = Enum.Material.ForceField
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	Debris:AddItem(part, duration)
end

-- Daño en zona ----------------------------------------------------------------------

-- Golpea a todos los objetivos dentro de una esfera. Devuelve cuántos alcanzó.
local function hitArea(player: Player, fighter: Fighter, center: Vector3, radius: number, damage: number, stun: number): number
	local character = player.Character
	if character == nil then
		return 0
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local hit: { [Model]: boolean } = {}
	local count = 0
	for _, part in Workspace:GetPartBoundsInRadius(center, radius, params) do
		local model = findTarget(part)
		if model ~= nil and not hit[model] then
			hit[model] = true
			count += 1
			targets[model](player, damage, stun)
			fighter:addDamageDealt(damage)
			NetService.fireAll("CombatEvent", "Hit", player.UserId, math.floor(damage + 0.5), "Area")
		end
	end
	return count
end

-- Ataques normales --------------------------------------------------------------------

local function resolveAttack(player: Player, fighter: Fighter, plan: FighterState.AttackPlan)
	local now = os.clock()
	if fighters[player] ~= fighter or fighter:isDead() or fighter:isStunned(now) then
		return
	end
	local root = getRoot(player)
	local character = player.Character
	if root == nil or character == nil then
		return
	end

	local attack = plan.attack
	local damage = attack.damage * fighter:damageMultiplier(now)
	local info = infos[player]
	if plan.kind == "Heavy" and info then
		local essence = Essences[info.essenceId]
		if essence and essence.heavyBonus then
			damage *= 1 + essence.heavyBonus
		end
	end
	damage = math.floor(damage + 0.5)

	-- Caja delante del personaje, calculada con la posición que conoce el servidor.
	local boxCFrame = root.CFrame * CFrame.new(0, 0, -attack.reach / 2)
	local boxSize = Vector3.new(attack.width, attack.height, attack.reach)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local alreadyHit: { [Model]: boolean } = {}
	for _, part in Workspace:GetPartBoundsInBox(boxCFrame, boxSize, params) do
		local model = findTarget(part)
		if model ~= nil and not alreadyHit[model] then
			alreadyHit[model] = true
			targets[model](player, damage, attack.stun)
			fighter:addDamageDealt(damage)
			NetService.fireAll("CombatEvent", "Hit", player.UserId, damage, plan.kind)
		end
	end
	-- El golpe pesado del Martillo hace temblar el suelo (visual).
	if plan.kind == "Heavy" and info and info.weaponId == "Martillo" then
		ring((root.CFrame * CFrame.new(0, 0, -attack.reach / 2)).Position, attack.width / 2, Color3.fromRGB(230, 200, 150))
	end
	sendState(player, fighter)
end

-- Definitivas ---------------------------------------------------------------------------

local function ultimateTestudo(player: Player)
	local root = getRoot(player)
	if root == nil then
		return
	end
	local now = os.clock()
	-- La formación protege a quien está cerca: el gladiador y sus aliados.
	for other, fighter in fighters do
		local otherRoot = getRoot(other)
		if
			otherRoot
			and not fighter:isDead()
			and (otherRoot.Position - root.Position).Magnitude <= TESTUDO_RADIUS
		then
			fighter:grantInvulnerability(TESTUDO_DURATION, now)
			dome(other, TESTUDO_DURATION)
			if other ~= player then
				NetService.fire("CombatEvent", other, "Ultimate", player.UserId, "TestudoAlly")
			end
		end
	end
end

local function ultimatePila(player: Player, fighter: Fighter)
	local root = getRoot(player)
	if root == nil then
		return
	end
	local center = (root.CFrame * CFrame.new(0, 0, -PILA_DISTANCE)).Position
	ring(center, PILA_RADIUS, GOLD)
	local random = Random.new()
	for _ = 1, PILA_COUNT do
		if fighters[player] ~= fighter then
			return
		end
		-- Una jabalina cae del cielo en un punto de la zona.
		local offset = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)) * PILA_RADIUS * 0.7
		local landing = center + offset
		local javelin = effectPart(
			Vector3.new(0.4, 0.4, 7),
			CFrame.lookAt(landing + Vector3.new(0, 30, 0), landing),
			GOLD,
			nil
		)
		local info = TweenInfo.new(PILA_GAP, Enum.EasingStyle.Linear)
		TweenService:Create(javelin, info, { CFrame = CFrame.lookAt(landing + Vector3.new(0, 1, 0), landing - Vector3.new(0, 30, 0)) })
			:Play()
		Debris:AddItem(javelin, PILA_GAP + 0.6)
		task.wait(PILA_GAP)
		hitArea(player, fighter, center, PILA_RADIUS, PILA_DAMAGE, 0)
	end
end

local function ultimateTerremoto(player: Player, fighter: Fighter)
	for _, radius in QUAKE_RADII do
		local root = getRoot(player)
		if root == nil or fighters[player] ~= fighter then
			return
		end
		ring(root.Position, radius, Color3.fromRGB(230, 200, 150))
		hitArea(player, fighter, root.Position, radius, QUAKE_DAMAGE, QUAKE_STUN)
		task.wait(QUAKE_GAP)
	end
end

-- Esencias -------------------------------------------------------------------------------

local function useEssence(player: Player, fighter: Fighter, info: Info)
	local essence = Essences[info.essenceId]
	if essence == nil then
		return
	end
	local now = os.clock()
	info.essenceReadyAt = now + essence.cooldown

	if essence.id == "Loba" then
		info.speedUntil = now + essence.duration
		fighter:setFreeDodgesUntil(now + essence.duration)
		syncHumanoid(player, fighter)
		task.delay(essence.duration + 0.05, function()
			if fighters[player] == fighter then
				syncHumanoid(player, fighter)
			end
		end)
	elseif essence.id == "Aguila" then
		-- El cliente salta (su personaje lo mueve él); el servidor resuelve la caída.
		task.delay(essence.slamDelay or 0.9, function()
			local root = getRoot(player)
			if root and fighters[player] == fighter and not fighter:isDead() then
				local radius = essence.slamRadius or 8
				ring(root.Position, radius, WIND)
				hitArea(player, fighter, root.Position, radius, essence.slamDamage or 25, AGUILA_STUN)
				sendState(player, fighter)
			end
		end)
	elseif essence.id == "Hidra" then
		fighter:setDamageBonus(essence.damageBonus or 0.3, now + essence.duration)
		local character = player.Character
		local hand = if character then character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") else nil
		if hand and hand:IsA("BasePart") then
			local light = Instance.new("PointLight")
			light.Color = POISON
			light.Range = 10
			light.Brightness = 3
			light.Parent = hand
			Debris:AddItem(light, essence.duration)
		end
	end
	NetService.fireAll("CombatEvent", "Essence", player.UserId, essence.id)
end

-- Creación de luchadores ------------------------------------------------------------------

local function newFighter(player: Player): (Fighter, Info)
	local weaponId, essenceId = LoadoutService.get(player)
	local essence = Essences[essenceId]
	local fighter = FighterState.new(Weapons[weaponId] :: any, Combat :: any, os.clock(), {
		staminaBonus = if essence then essence.staminaBonus else nil,
	})
	local previous = infos[player]
	local info: Info = {
		weaponId = weaponId,
		essenceId = essenceId,
		-- La recarga de la esencia se conserva al reiniciar el luchador.
		essenceReadyAt = if previous and previous.essenceId == essenceId then previous.essenceReadyAt else 0,
		lastDamagedAt = 0,
		speedUntil = 0,
	}
	return fighter, info
end

local function install(player: Player, fighter: Fighter, info: Info)
	fighters[player] = fighter
	infos[player] = info
	downed[player] = nil
	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.Died:Connect(function()
			if fighters[player] == fighter then
				fighters[player] = nil
			end
		end)
	end
	syncHumanoid(player, fighter)
	sendState(player, fighter)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") or player.Character ~= character then
		return
	end
	humanoid.MaxHealth = Combat.MAX_HEALTH
	humanoid.Health = Combat.MAX_HEALTH
	humanoid.WalkSpeed = Combat.WALK_SPEED
	local fighter, info = newFighter(player)
	install(player, fighter, info)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		onCharacterAdded(player, character)
	end)
	local character = player.Character
	if character then
		task.spawn(onCharacterAdded, player, character)
	end
end

-- Pasiva de la Hidra: regenera vida si lleva un rato sin recibir daño.
local function regenLoop()
	while true do
		task.wait(REGEN_TICK)
		local now = os.clock()
		for player, fighter in fighters do
			local info = infos[player]
			local essence = if info then Essences[info.essenceId] else nil
			if
				info
				and essence
				and essence.regenPerSecond
				and not fighter:isDead()
				and not downed[player]
				and fighter.health < Combat.MAX_HEALTH
				and now - info.lastDamagedAt >= (essence.regenDelay or 5)
			then
				fighter:heal(essence.regenPerSecond * REGEN_TICK)
				syncHumanoid(player, fighter)
				sendState(player, fighter)
			end
		end
	end
end

function CombatService.Start(_self: typeof(CombatService))
	NetService.on("CombatAttack", function(player: Player, kind: FighterState.AttackKind)
		local fighter = fighters[player]
		local info = infos[player]
		if fighter == nil or info == nil or downed[player] then
			return
		end
		local plan = fighter:tryAttack(kind, os.clock())
		if plan == nil then
			-- Rechazado: se envía el estado real para corregir la predicción del cliente.
			sendState(player, fighter)
			return
		end
		syncHumanoid(player, fighter)
		NetService.fireAll("CombatEvent", "Attack", player.UserId, plan.kind, plan.step, info.weaponId)
		task.delay(plan.attack.windup, resolveAttack, player, fighter, plan)
	end)

	NetService.on("CombatDodge", function(player: Player)
		local fighter = fighters[player]
		if fighter == nil or downed[player] then
			return
		end
		if fighter:tryDodge(os.clock()) then
			syncHumanoid(player, fighter)
			NetService.fireAll("CombatEvent", "Dodge", player.UserId)
		end
		sendState(player, fighter)
	end)

	NetService.on("CombatBlock", function(player: Player, blocking: boolean)
		local fighter = fighters[player]
		if fighter == nil or downed[player] then
			return
		end
		fighter:setBlocking(blocking, os.clock())
		syncHumanoid(player, fighter)
		NetService.fireAll("CombatEvent", "Block", player.UserId, fighter.blocking)
		sendState(player, fighter)
	end)

	NetService.on("CombatEssence", function(player: Player)
		local fighter = fighters[player]
		local info = infos[player]
		if fighter == nil or info == nil or downed[player] or fighter:isDead() then
			return
		end
		local now = os.clock()
		if now < info.essenceReadyAt - Combat.ACTION_LATENCY_GRACE or fighter:isStunned(now) then
			sendState(player, fighter)
			return
		end
		useEssence(player, fighter, info)
		sendState(player, fighter)
	end)

	NetService.on("CombatUltimate", function(player: Player)
		local fighter = fighters[player]
		local info = infos[player]
		if fighter == nil or info == nil or downed[player] then
			return
		end
		if not fighter:tryUltimate(os.clock()) then
			sendState(player, fighter)
			return
		end
		local weapon = Weapons[info.weaponId]
		NetService.fireAll("CombatEvent", "Ultimate", player.UserId, weapon.ultimate.id)
		sendState(player, fighter)
		if weapon.ultimate.id == "Testudo" then
			ultimateTestudo(player)
		elseif weapon.ultimate.id == "Pila" then
			task.spawn(ultimatePila, player, fighter)
		else
			task.spawn(ultimateTerremoto, player, fighter)
		end
	end)

	-- Al cambiar de equipo en la armería se rehace el luchador (fuera de la arena).
	LoadoutService.Changed:Connect(function(player: Player)
		local old = fighters[player]
		if old == nil or old:isDead() or downed[player] then
			return
		end
		local fighter, info = newFighter(player)
		install(player, fighter, info)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		fighters[player] = nil
		infos[player] = nil
		downed[player] = nil
	end)

	task.spawn(regenLoop)
end

-- Registra un modelo del Workspace como objetivo golpeable por los jugadores.
function CombatService.registerTarget(model: Model, handler: TargetHandler)
	targets[model] = handler
end

function CombatService.unregisterTarget(model: Model)
	targets[model] = nil
end

-- Un enemigo golpea a un jugador en `impactTime` (reloj del servidor, os.clock()).
-- Se resuelve tras el margen de latencia para aceptar defensas hechas a tiempo.
-- `onParried` se llama si el jugador hizo una parada perfecta.
function CombatService.hitPlayer(player: Player, damage: number, impactTime: number, onParried: (() -> ())?)
	local fighter = fighters[player]
	if fighter == nil then
		return
	end
	local delay = math.max(0, impactTime + Combat.DEFENSE_LATENCY_GRACE - os.clock())
	task.delay(delay, function()
		-- Un luchador caído no recibe más golpes.
		if fighters[player] ~= fighter or fighter:isDead() then
			return
		end
		local outcome = fighter:receiveHit(damage, impactTime, os.clock())
		local info = infos[player]
		if info and outcome.damageTaken > 0 then
			info.lastDamagedAt = os.clock()
		end
		syncHumanoid(player, fighter)
		NetService.fire("CombatEvent", player, "Defense", player.UserId, outcome.result, outcome.damageTaken)
		sendState(player, fighter)
		if outcome.result == "Parried" then
			CombatService.Parried:Fire(player)
			if onParried ~= nil then
				onParried()
			end
		end
	end)
end

-- Daño que no se puede esquivar ni bloquear (veneno, entorno). El Testudo lo anula.
function CombatService.damagePlayer(player: Player, amount: number)
	local fighter = fighters[player]
	if fighter == nil or fighter:isDead() then
		return
	end
	local now = os.clock()
	if fighter:isInvulnerable(now) then
		return
	end
	fighter:takeDamage(amount, now)
	local info = infos[player]
	if info then
		info.lastDamagedAt = now
	end
	syncHumanoid(player, fighter)
	NetService.fire("CombatEvent", player, "Defense", player.UserId, "Hit", amount)
	sendState(player, fighter)
end

-- Devuelve al jugador a su estado inicial (vida y aguante al máximo) si está vivo.
function CombatService.resetFighter(player: Player)
	if fighters[player] == nil then
		return
	end
	local fighter, info = newFighter(player)
	install(player, fighter, info)
end

-- Define quién decide si un jugador con 0 de vida queda caído en vez de morir.
function CombatService.setZeroHealthHandler(handler: ((player: Player) -> boolean)?)
	zeroHealthHandler = handler
end

function CombatService.isDowned(player: Player): boolean
	return downed[player] == true
end

-- Levanta a un jugador caído con una fracción de su vida máxima.
function CombatService.revive(player: Player, healthFraction: number)
	local fighter = fighters[player]
	if fighter == nil or not downed[player] then
		return
	end
	downed[player] = nil
	fighter:revive(Combat.MAX_HEALTH * healthFraction, os.clock())
	syncHumanoid(player, fighter)
	NetService.fire("CombatEvent", player, "Revived", player.UserId)
	sendState(player, fighter)
end

-- Remata a un jugador caído (se acabó el tiempo o cayó todo el grupo).
function CombatService.finishOff(player: Player)
	if not downed[player] then
		return
	end
	downed[player] = nil
	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.Health = 0
	end
end

function CombatService.isAlive(player: Player): boolean
	local fighter = fighters[player]
	return fighter ~= nil and not fighter:isDead()
end

return CombatService
