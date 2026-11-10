--!strict
-- Entrada y respuesta visual del combate. Predice el resultado al instante con el mismo
-- FighterState que usa el servidor y se corrige con el estado que este envía.
-- Nunca decide daño: solo pide acciones. Diseño: docs/design/COMBATE.md.

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local CombatHud = require(script.Parent.Parent.UI.CombatHud)
local FighterState = require(ReplicatedStorage.Shared.Combat.FighterState)
local NetClient = require(ReplicatedStorage.Shared.Net.Client)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

-- Muestra la zona de golpe mientras no haya animaciones. Quitar cuando existan.
local SHOW_DEBUG_HITBOX = true

local ACTION_ATTACK = "ColosseumAttack"
local ACTION_BLOCK = "ColosseumBlock"
local ACTION_DODGE = "ColosseumDodge"

local DEFENSE_MESSAGES: { [string]: { text: string, color: Color3 } } = {
	Dodged = { text = "¡Esquivado!", color = Color3.fromRGB(120, 200, 255) },
	Parried = { text = "¡PARADA PERFECTA!", color = Color3.fromRGB(255, 215, 80) },
	Blocked = { text = "Bloqueado", color = Color3.fromRGB(200, 200, 200) },
	GuardBroken = { text = "¡Guardia rota!", color = Color3.fromRGB(255, 120, 60) },
	Hit = { text = "¡Golpeado!", color = Color3.fromRGB(255, 70, 70) },
}

local localPlayer = Players.LocalPlayer

local CombatController = {}

local fighter: FighterState.FighterState? = nil
local attackPressedAt: number? = nil

local function getRoot(): BasePart?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function showHitbox(plan: FighterState.AttackPlan)
	if not SHOW_DEBUG_HITBOX then
		return
	end
	local attack = plan.attack
	task.delay(attack.windup, function()
		local root = getRoot()
		if root == nil then
			return
		end
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.Neon
		part.Transparency = 0.7
		part.Color = if plan.kind == "Heavy" then Color3.fromRGB(255, 140, 40) else Color3.fromRGB(255, 255, 255)
		part.Size = Vector3.new(attack.width, attack.height, attack.reach)
		part.CFrame = root.CFrame * CFrame.new(0, 0, -attack.reach / 2)
		part.Parent = Workspace
		Debris:AddItem(part, attack.active)
	end)
end

local function requestAttack(kind: FighterState.AttackKind)
	local state = fighter
	if state == nil then
		return
	end
	local plan = state:tryAttack(kind, os.clock())
	if plan ~= nil then
		NetClient.fire("CombatAttack", kind)
		showHitbox(plan)
	end
end

local function dash()
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = getRoot()
	if humanoid == nil or root == nil then
		return
	end

	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		-- Sin dirección: paso atrás.
		direction = -root.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit

	-- POR VERIFICAR en Studio: ajustar fuerza y sensación del impulso.
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.MaxForce = 100000
	velocity.VectorVelocity = direction * Combat.DODGE_SPEED
	velocity.Parent = root
	Debris:AddItem(velocity, Combat.DODGE_DURATION)
	Debris:AddItem(attachment, Combat.DODGE_DURATION)
end

local function onAttack(_name: string, inputState: Enum.UserInputState, _input: InputObject)
	if inputState == Enum.UserInputState.Begin then
		attackPressedAt = os.clock()
	elseif inputState == Enum.UserInputState.End then
		local pressedAt = attackPressedAt
		attackPressedAt = nil
		if pressedAt ~= nil then
			local held = os.clock() - pressedAt
			requestAttack(if held >= Combat.HEAVY_HOLD_TIME then "Heavy" else "Light")
		end
	end
	return Enum.ContextActionResult.Pass
end

local function onBlock(_name: string, inputState: Enum.UserInputState, _input: InputObject)
	local state = fighter
	if state == nil then
		return Enum.ContextActionResult.Pass
	end
	if inputState == Enum.UserInputState.Begin then
		state:setBlocking(true, os.clock())
		NetClient.fire("CombatBlock", true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		state:setBlocking(false, os.clock())
		NetClient.fire("CombatBlock", false)
	end
	return Enum.ContextActionResult.Pass
end

local function onDodge(_name: string, inputState: Enum.UserInputState, _input: InputObject)
	local state = fighter
	if state ~= nil and inputState == Enum.UserInputState.Begin then
		if state:tryDodge(os.clock()) then
			NetClient.fire("CombatDodge")
			dash()
		end
	end
	return Enum.ContextActionResult.Pass
end

local function onCombatEvent(kind: string, userId: number, a: any, _b: any)
	if kind == "Hit" and userId == localPlayer.UserId then
		CombatHud.showMessage(`-{a}`, Color3.fromRGB(255, 255, 255))
	elseif kind == "Defense" and userId == localPlayer.UserId then
		local info = DEFENSE_MESSAGES[a]
		if info then
			CombatHud.showMessage(info.text, info.color)
		end
	elseif kind == "Telegraph" then
		CombatHud.showMessage("¡Cuidado!", Color3.fromRGB(255, 90, 90))
	end
end

local function newFighter()
	fighter = FighterState.new(Weapons.Gladius :: any, Combat :: any, os.clock())
end

function CombatController.Start(_self: typeof(CombatController))
	CombatHud.create()

	localPlayer.CharacterAdded:Connect(newFighter)
	if localPlayer.Character then
		newFighter()
	end

	NetClient.on("CombatState", function(snapshot: FighterState.Snapshot)
		local state = fighter
		if state ~= nil then
			state:applySnapshot(snapshot, os.clock())
		end
	end)
	NetClient.on("CombatEvent", onCombatEvent)

	ContextActionService:BindAction(
		ACTION_ATTACK,
		onAttack,
		true,
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.ButtonR1
	)
	ContextActionService:BindAction(
		ACTION_BLOCK,
		onBlock,
		true,
		Enum.UserInputType.MouseButton2,
		Enum.KeyCode.F,
		Enum.KeyCode.ButtonL1
	)
	ContextActionService:BindAction(ACTION_DODGE, onDodge, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle(ACTION_ATTACK, "Atacar")
	ContextActionService:SetTitle(ACTION_BLOCK, "Bloquear")
	ContextActionService:SetTitle(ACTION_DODGE, "Esquivar")

	RunService.Heartbeat:Connect(function()
		local state = fighter
		if state ~= nil then
			local snapshot = state:snapshot(os.clock())
			CombatHud.update(snapshot.health, snapshot.stamina, snapshot.ultimate)
		end
	end)
end

return CombatController
