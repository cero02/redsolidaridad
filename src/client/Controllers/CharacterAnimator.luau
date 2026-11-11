--!strict
-- Animación de combate por código. Tres capas, de más a menos dependiente del avatar:
--   1. Brazos: gira la articulación del hombro. Admite los dos tipos que usa Roblox:
--      Motor6D (clásico, se gira su C0) y AnimationConstraint (nuevo, se gira su
--      Attachment0).
--   2. Arma: si no hay hombro utilizable, gira la espada sobre la mano.
--   3. Tajo: un destello que barre por delante del personaje. Funciona siempre.
-- Es provisional: se sustituirá por animaciones hechas en el editor de Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local NetClient = require(ReplicatedStorage.Shared.Net.Client)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local ARM_UP = math.rad(170)
local ARM_STRIKE = math.rad(20)
local BLOCK_RAISE = math.rad(85)
local BASH_BACK = math.rad(40)
local BASH_FORWARD = math.rad(105)
local BLOCK_BLEND_SPEED = 14
-- El destello del tajo dura un poco más que el golpe para que se vea.
local SLASH_EXTRA_TIME = 0.12
local SLASH_COLOR = Color3.fromRGB(255, 255, 255)
local BASH_COLOR = Color3.fromRGB(255, 200, 90)

type Attack = { windup: number, active: number, recovery: number, reach: number, [string]: any }

-- Una articulación que se puede girar respecto a su postura original.
type Joint = {
	kind: string,
	apply: (rotation: CFrame) -> (),
	reset: () -> (),
}

type Entry = {
	character: Model,
	isR15: boolean,
	right: Joint?,
	left: Joint?,
	-- Unión de la espada con la mano: solo se anima si no hay hombro derecho.
	grip: Joint?,
	rightMoved: boolean,
	leftMoved: boolean,
	gripMoved: boolean,
	trail: Trail?,
	slash: Part?,
	attack: Attack?,
	weaponId: string,
	attackStart: number,
	heavy: boolean,
	step: number,
	blocking: boolean,
	blockAlpha: number,
}

local localPlayer = Players.LocalPlayer
local log = Log.new("Animator")

local CharacterAnimator = {}

local entries: { [Model]: Entry } = {}

local function makeJoint(instance: Instance?): Joint?
	if instance == nil then
		return nil
	end
	if instance:IsA("JointInstance") then
		-- Motor6D y Weld: la postura base es C0.
		local joint = instance
		local base = joint.C0
		return {
			kind = instance.ClassName,
			apply = function(rotation: CFrame)
				joint.C0 = base * rotation
			end,
			reset = function()
				joint.C0 = base
			end,
		}
	end
	if instance.ClassName == "AnimationConstraint" then
		-- Articulación nueva de los avatares: su base es el Attachment0.
		local attachment = (instance :: any).Attachment0
		if typeof(attachment) == "Instance" and attachment:IsA("Attachment") then
			local base = attachment.CFrame
			return {
				kind = instance.ClassName,
				apply = function(rotation: CFrame)
					attachment.CFrame = base * rotation
				end,
				reset = function()
					attachment.CFrame = base
				end,
			}
		end
	end
	return nil
end

-- Busca una articulación por nombre entre los dos tipos admitidos.
local function findJoint(character: Model, name: string): Joint?
	for _, descendant in character:GetDescendants() do
		if descendant.Name == name then
			local joint = makeJoint(descendant)
			if joint then
				return joint
			end
		end
	end
	return nil
end

local function getEntry(character: Model): Entry
	local entry = entries[character]
	if entry == nil then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local isR15 = humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R15
		local right = findJoint(character, if isR15 then "RightShoulder" else "Right Shoulder")
		local left = findJoint(character, if isR15 then "LeftShoulder" else "Left Shoulder")
		entry = {
			character = character,
			isR15 = isR15,
			right = right,
			left = left,
			grip = nil,
			rightMoved = false,
			leftMoved = false,
			gripMoved = false,
			trail = nil,
			slash = nil,
			attack = nil,
			weaponId = "Gladius",
			attackStart = 0,
			heavy = false,
			step = 1,
			blocking = false,
			blockAlpha = 0,
		}
		entries[character] = entry
		log:info(
			`{character.Name}: avatar {if isR15 then "R15" else "R6"}, hombro derecho = `
				.. `{if right then right.kind else "no encontrado"}, izquierdo = `
				.. `{if left then left.kind else "no encontrado"}`
		)
	end
	return entry
end

-- Texto de diagnóstico para mostrar en pantalla (nil si todo está bien).
function CharacterAnimator.getProblem(character: Model): string?
	local entry = getEntry(character)
	if entry.right == nil then
		return `Aviso: hombro no encontrado (avatar {if entry.isR15 then "R15" else "R6"}). Se anima solo el arma.`
	end
	return nil
end

-- Giro del hombro: `raise` levanta el brazo hacia delante y `spread` lo abre hacia fuera.
-- side = 1 para el brazo derecho, -1 para el izquierdo.
local function armRotation(isR15: boolean, side: number, raise: number, spread: number): CFrame
	if isR15 then
		return CFrame.Angles(raise, 0, side * spread)
	end
	-- En R6 la articulación está girada: levantar el brazo es rotar sobre su eje Z.
	return CFrame.Angles(0, 0, side * raise)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * math.clamp(t, 0, 1)
end

-- Ángulo del brazo a lo largo del ataque: preparar, golpear y recuperar.
local function attackCurve(attack: Attack, elapsed: number, from: number, peak: number, strike: number): number
	if elapsed < attack.windup then
		return lerp(from, peak, elapsed / attack.windup)
	end
	elapsed -= attack.windup
	if elapsed < attack.active then
		return lerp(peak, strike, elapsed / attack.active)
	end
	elapsed -= attack.active
	return lerp(strike, from, elapsed / attack.recovery)
end

local function moveJoint(joint: Joint?, rotation: CFrame?, moved: boolean): boolean
	if joint == nil then
		return false
	end
	if rotation ~= nil then
		joint.apply(rotation)
		return true
	end
	if moved then
		joint.reset()
	end
	return false
end

local function removeSlash(entry: Entry)
	local slash = entry.slash
	if slash then
		slash:Destroy()
		entry.slash = nil
	end
end

-- Destello que barre por delante del personaje durante el golpe.
local function updateSlash(entry: Entry, attack: Attack, elapsed: number)
	local duration = attack.active + SLASH_EXTRA_TIME
	local alpha = (elapsed - attack.windup) / duration
	local root = entry.character:FindFirstChild("HumanoidRootPart")
	if alpha < 0 or alpha > 1 or root == nil or not root:IsA("BasePart") then
		removeSlash(entry)
		return
	end

	local slash = entry.slash
	if slash == nil then
		slash = Instance.new("Part")
		slash.Name = "SlashEffect"
		slash.Anchored = true
		slash.CanCollide = false
		slash.CanQuery = false
		slash.CanTouch = false
		slash.CastShadow = false
		slash.Material = Enum.Material.Neon
		slash.Parent = Workspace
		entry.slash = slash
	end

	local reach = attack.reach
	if entry.weaponId == "Hasta" then
		-- Estocada: una línea que sale disparada hacia delante.
		slash.Color = SLASH_COLOR
		slash.Size = Vector3.new(0.3, 0.3, reach * math.max(0.2, alpha))
		slash.CFrame = root.CFrame * CFrame.new(0.6, 0.3, -(reach * alpha / 2 + 1))
	elseif entry.weaponId == "Martillo" then
		-- Mazazo: barrido vertical ancho de arriba abajo.
		slash.Color = BASH_COLOR
		slash.Size = Vector3.new(attack.width * 0.6, 0.4, reach)
		local sweep = CFrame.Angles(lerp(math.rad(85), math.rad(-15), alpha), 0, 0)
		slash.CFrame = root.CFrame * sweep * CFrame.new(0, 0.4, -(reach / 2 + 0.6))
	elseif entry.heavy then
		-- Golpe de escudo: una onda que avanza.
		slash.Color = BASH_COLOR
		slash.Size = Vector3.new(4 + 2 * alpha, 4 + 2 * alpha, 0.3)
		slash.CFrame = root.CFrame * CFrame.new(0, 0, -(1.5 + reach * alpha))
	else
		slash.Color = SLASH_COLOR
		slash.Size = Vector3.new(0.25, 0.25, reach)
		local sweep: CFrame
		if entry.step == 3 then
			-- Tercer golpe: de arriba abajo.
			sweep = CFrame.Angles(lerp(math.rad(80), math.rad(-35), alpha), 0, 0)
		else
			-- Primer y segundo golpe: barridos horizontales en sentidos opuestos.
			local direction = if entry.step == 2 then -1 else 1
			sweep = CFrame.Angles(0, direction * lerp(math.rad(75), math.rad(-75), alpha), 0)
		end
		slash.CFrame = root.CFrame * sweep * CFrame.new(0, 0.4, -(reach / 2 + 0.8))
	end
	slash.Transparency = 0.15 + 0.8 * alpha
end

function CharacterAnimator.playAttack(character: Model, kind: string, step: number, weaponId: string?)
	local weapon = Weapons[weaponId or "Gladius"] or Weapons.Gladius
	local attack = if kind == "Heavy" then weapon.heavy else weapon.light[step]
	if attack == nil then
		return
	end
	local entry = getEntry(character)
	removeSlash(entry)
	entry.attack = attack :: any
	entry.weaponId = weapon.id
	entry.attackStart = os.clock()
	entry.heavy = kind == "Heavy"
	entry.step = step
	entry.blocking = false
end

function CharacterAnimator.setBlocking(character: Model, blocking: boolean)
	getEntry(character).blocking = blocking
end

-- El equipamiento lo crea el servidor y puede llegar después que el personaje.
local function findEquipment(entry: Entry)
	if entry.trail == nil then
		local trail = entry.character:FindFirstChild("SlashTrail", true)
		if trail and trail:IsA("Trail") then
			entry.trail = trail
		end
	end
	if entry.grip == nil and entry.right == nil then
		entry.grip = makeJoint(entry.character:FindFirstChild("GripWeld", true))
	end
end

local function updateEntry(entry: Entry, deltaTime: number, now: number)
	local target = if entry.blocking then 1 else 0
	entry.blockAlpha = lerp(entry.blockAlpha, target, deltaTime * BLOCK_BLEND_SPEED)
	if entry.blockAlpha < 0.01 and not entry.blocking then
		entry.blockAlpha = 0
	end

	local rightRaise: number? = nil
	local rightSpread = 0
	local leftRaise: number? = if entry.blockAlpha > 0 then BLOCK_RAISE * entry.blockAlpha else nil
	local trailOn = false

	local attack = entry.attack
	if attack ~= nil then
		findEquipment(entry)
		local elapsed = now - entry.attackStart
		local total = attack.windup + attack.active + attack.recovery
		if elapsed >= total then
			entry.attack = nil
			removeSlash(entry)
		else
			updateSlash(entry, attack, elapsed)
			if entry.weaponId == "Hasta" then
				-- La lanza se echa atrás y se proyecta hacia delante.
				rightRaise = attackCurve(attack, elapsed, 0, math.rad(35), math.rad(95))
				trailOn = elapsed >= attack.windup * 0.5 and elapsed <= attack.windup + attack.active + 0.08
			elseif entry.weaponId == "Martillo" then
				-- El martillo sube por encima de la cabeza y cae con todo su peso.
				rightRaise = attackCurve(attack, elapsed, 0, math.rad(190), math.rad(-10))
				trailOn = elapsed >= attack.windup * 0.6 and elapsed <= attack.windup + attack.active + 0.1
			elseif entry.heavy then
				-- Golpe de escudo: el brazo izquierdo retrocede y empuja hacia delante.
				leftRaise = attackCurve(attack, elapsed, 0, BASH_BACK, BASH_FORWARD)
			else
				rightRaise = attackCurve(attack, elapsed, 0, ARM_UP, ARM_STRIKE)
				-- El segundo golpe del combo entra en diagonal; el tercero, más amplio.
				if entry.step == 2 then
					rightSpread = math.rad(35)
				elseif entry.step == 3 then
					rightSpread = math.rad(-20)
				end
				trailOn = elapsed >= attack.windup * 0.5 and elapsed <= attack.windup + attack.active + 0.08
			end
		end
	end

	local rightRotation = if rightRaise ~= nil then armRotation(entry.isR15, 1, rightRaise, rightSpread) else nil
	local leftRotation = if leftRaise ~= nil then armRotation(entry.isR15, -1, leftRaise, 0) else nil
	entry.rightMoved = moveJoint(entry.right, rightRotation, entry.rightMoved)
	entry.leftMoved = moveJoint(entry.left, leftRotation, entry.leftMoved)

	-- Sin hombro: la espada gira sobre la mano (la punta sube y descarga).
	local gripRotation = if rightRaise ~= nil then CFrame.Angles(rightRaise * 0.6, 0, 0) else nil
	entry.gripMoved = moveJoint(entry.grip, gripRotation, entry.gripMoved)

	local trail = entry.trail
	if trail and trail.Enabled ~= trailOn then
		trail.Enabled = trailOn
	end
end

local function characterOf(userId: number): Model?
	local player = Players:GetPlayerByUserId(userId)
	return if player then player.Character else nil
end

function CharacterAnimator.Start(_self: typeof(CharacterAnimator))
	-- Los demás jugadores se animan con los sucesos del servidor. El jugador local se
	-- anima al instante desde CombatController, así que sus propios sucesos se ignoran.
	NetClient.on("CombatEvent", function(kind: string, userId: number, a: any, b: any, c: any)
		if userId == localPlayer.UserId then
			return
		end
		local character = characterOf(userId)
		if character == nil then
			return
		end
		if kind == "Attack" then
			CharacterAnimator.playAttack(character, a, b, c)
		elseif kind == "Block" then
			CharacterAnimator.setBlocking(character, a == true)
		end
	end)

	RunService.Stepped:Connect(function(_time: number, deltaTime: number)
		local now = os.clock()
		for character, entry in entries do
			if character.Parent == nil then
				removeSlash(entry)
				entries[character] = nil
			else
				updateEntry(entry, deltaTime, now)
			end
		end
	end)
end

return CharacterAnimator
