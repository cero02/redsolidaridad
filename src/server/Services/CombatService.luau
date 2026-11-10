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
	if humanoid then
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
		sendState(player, fighter)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		fighters[player] = nil
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
		if fighters[player] ~= fighter then
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

return CombatService
