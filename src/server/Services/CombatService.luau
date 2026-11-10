--!strict
-- Combate autoritativo: valida las acciones que piden los jugadores, calcula los golpes
-- en el servidor y resuelve los golpes que reciben. Diseño: docs/design/COMBATE.md.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local FighterState = require(ReplicatedStorage.Shared.Combat.FighterState)
local NetService = require(script.Parent.NetService)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

type Fighter = FighterState.FighterState

-- Lo que hace un objetivo (muñeco, bestia…) cuando un jugador lo golpea.
export type TargetHandler = (attacker: Player, damage: number, stun: number) -> ()

local CombatService = {}

local fighters: { [Player]: Fighter } = {}
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
	NetService.fire("CombatState", player, fighter:snapshot(os.clock()))
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
	else
		humanoid.Health = fighter.health
		humanoid.WalkSpeed = if fighter.blocking then Combat.BLOCK_WALK_SPEED else Combat.WALK_SPEED
	end
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
			targets[model](player, attack.damage, attack.stun)
			fighter:addDamageDealt(attack.damage)
			NetService.fireAll("CombatEvent", "Hit", player.UserId, attack.damage, plan.kind)
		end
	end
	sendState(player, fighter)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") or player.Character ~= character then
		return
	end

	-- Hito 1.1: todos usan el Gladius. El equipamiento del perfil llega en el hito 1.4.
	local fighter = FighterState.new(Weapons.Gladius :: any, Combat :: any, os.clock())
	fighters[player] = fighter
	downed[player] = nil

	humanoid.MaxHealth = Combat.MAX_HEALTH
	humanoid.Health = Combat.MAX_HEALTH
	humanoid.WalkSpeed = Combat.WALK_SPEED
	humanoid.Died:Connect(function()
		if fighters[player] == fighter then
			fighters[player] = nil
		end
	end)

	sendState(player, fighter)
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

function CombatService.Start(_self: typeof(CombatService))
	NetService.on("CombatAttack", function(player: Player, kind: FighterState.AttackKind)
		local fighter = fighters[player]
		if fighter == nil then
			return
		end
		local plan = fighter:tryAttack(kind, os.clock())
		if plan == nil then
			-- Rechazado: se envía el estado real para corregir la predicción del cliente.
			sendState(player, fighter)
			return
		end
		syncHumanoid(player, fighter)
		NetService.fireAll("CombatEvent", "Attack", player.UserId, plan.kind, plan.step)
		task.delay(plan.attack.windup, resolveAttack, player, fighter, plan)
	end)

	NetService.on("CombatDodge", function(player: Player)
		local fighter = fighters[player]
		if fighter == nil then
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
		if fighter == nil then
			return
		end
		fighter:setBlocking(blocking, os.clock())
		syncHumanoid(player, fighter)
		NetService.fireAll("CombatEvent", "Block", player.UserId, fighter.blocking)
		sendState(player, fighter)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		fighters[player] = nil
		downed[player] = nil
	end)
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
		syncHumanoid(player, fighter)
		NetService.fire("CombatEvent", player, "Defense", player.UserId, outcome.result, outcome.damageTaken)
		sendState(player, fighter)
		if outcome.result == "Parried" and onParried ~= nil then
			onParried()
		end
	end)
end

-- Daño que no se puede esquivar ni bloquear (veneno, entorno).
function CombatService.damagePlayer(player: Player, amount: number)
	local fighter = fighters[player]
	if fighter == nil or fighter:isDead() then
		return
	end
	fighter:takeDamage(amount)
	syncHumanoid(player, fighter)
	NetService.fire("CombatEvent", player, "Defense", player.UserId, "Hit", amount)
	sendState(player, fighter)
end

-- Devuelve al jugador a su estado inicial (vida y aguante al máximo) si está vivo.
function CombatService.resetFighter(player: Player)
	local old = fighters[player]
	if old == nil then
		return
	end
	local fighter = FighterState.new(Weapons.Gladius :: any, Combat :: any, os.clock())
	fighters[player] = fighter
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
