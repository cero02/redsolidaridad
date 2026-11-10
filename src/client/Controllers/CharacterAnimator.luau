--!strict
-- Animación de combate por código: mueve los brazos de los gladiadores al atacar y al
-- bloquear girando la base de la articulación del hombro (Motor6D.C0). Se usa C0 y no
-- Transform porque las animaciones de Roblox reescriben Transform en cada fotograma;
-- C0 se combina con ellas en lugar de competir.
-- Es provisional: se sustituirá por animaciones hechas en el editor de Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NetClient = require(ReplicatedStorage.Shared.Net.Client)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local ARM_UP = math.rad(170)
local ARM_STRIKE = math.rad(20)
local BLOCK_RAISE = math.rad(85)
local BASH_BACK = math.rad(40)
local BASH_FORWARD = math.rad(105)
local BLOCK_BLEND_SPEED = 14

type Attack = { windup: number, active: number, recovery: number, [string]: any }

type Entry = {
	isR15: boolean,
	right: Motor6D?,
	left: Motor6D?,
	-- Posición original de cada articulación, para girar sobre ella y restaurarla.
	rightBase: CFrame,
	leftBase: CFrame,
	rightMoved: boolean,
	leftMoved: boolean,
	trail: Trail?,
	attack: Attack?,
	attackStart: number,
	heavy: boolean,
	step: number,
	blocking: boolean,
	blockAlpha: number,
}

local localPlayer = Players.LocalPlayer

local CharacterAnimator = {}

local entries: { [Model]: Entry } = {}

local function findMotor(character: Model, name: string): Motor6D?
	local found = character:FindFirstChild(name, true)
	return if found and found:IsA("Motor6D") then found else nil
end

local function getEntry(character: Model): Entry
	local entry = entries[character]
	if entry == nil then
		local r15Right = findMotor(character, "RightShoulder")
		local isR15 = r15Right ~= nil
		local right = if isR15 then r15Right else findMotor(character, "Right Shoulder")
		local left = findMotor(character, if isR15 then "LeftShoulder" else "Left Shoulder")
		local trail = character:FindFirstChild("SlashTrail", true)
		entry = {
			isR15 = isR15,
			right = right,
			left = left,
			rightBase = if right then right.C0 else CFrame.identity,
			leftBase = if left then left.C0 else CFrame.identity,
			rightMoved = false,
			leftMoved = false,
			trail = if trail and trail:IsA("Trail") then trail else nil,
			attack = nil,
			attackStart = 0,
			heavy = false,
			step = 1,
			blocking = false,
			blockAlpha = 0,
		}
		entries[character] = entry
	end
	return entry
end

-- Giro del hombro: `raise` levanta el brazo hacia delante y `spread` lo abre hacia fuera.
-- side = 1 para el brazo derecho, -1 para el izquierdo.
local function armTransform(isR15: boolean, side: number, raise: number, spread: number): CFrame
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

function CharacterAnimator.playAttack(character: Model, kind: string, step: number)
	local weapon = Weapons.Gladius
	local attack = if kind == "Heavy" then weapon.heavy else weapon.light[step]
	if attack == nil then
		return
	end
	local entry = getEntry(character)
	entry.attack = attack
	entry.attackStart = os.clock()
	entry.heavy = kind == "Heavy"
	entry.step = step
	entry.blocking = false
end

function CharacterAnimator.setBlocking(character: Model, blocking: boolean)
	getEntry(character).blocking = blocking
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
		local elapsed = now - entry.attackStart
		local total = attack.windup + attack.active + attack.recovery
		if elapsed >= total then
			entry.attack = nil
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

	local right, left = entry.right, entry.left
	if right then
		if rightRaise ~= nil then
			right.C0 = entry.rightBase * armTransform(entry.isR15, 1, rightRaise, rightSpread)
			entry.rightMoved = true
		elseif entry.rightMoved then
			right.C0 = entry.rightBase
			entry.rightMoved = false
		end
	end
	if left then
		if leftRaise ~= nil then
			left.C0 = entry.leftBase * armTransform(entry.isR15, -1, leftRaise, 0)
			entry.leftMoved = true
		elseif entry.leftMoved then
			left.C0 = entry.leftBase
			entry.leftMoved = false
		end
	end
	-- La estela puede llegar después que el personaje: se busca hasta encontrarla.
	if entry.trail == nil and attack ~= nil and right then
		local character = right:FindFirstAncestorOfClass("Model")
		local found = if character then character:FindFirstChild("SlashTrail", true) else nil
		if found and found:IsA("Trail") then
			entry.trail = found
		end
	end
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
	NetClient.on("CombatEvent", function(kind: string, userId: number, a: any, b: any)
		if userId == localPlayer.UserId then
			return
		end
		local character = characterOf(userId)
		if character == nil then
			return
		end
		if kind == "Attack" then
			CharacterAnimator.playAttack(character, a, b)
		elseif kind == "Block" then
			CharacterAnimator.setBlocking(character, a == true)
		end
	end)

	RunService.Stepped:Connect(function(_time: number, deltaTime: number)
		local now = os.clock()
		for character, entry in entries do
			if character.Parent == nil then
				entries[character] = nil
			else
				updateEntry(entry, deltaTime, now)
			end
		end
	end)
end

return CharacterAnimator
