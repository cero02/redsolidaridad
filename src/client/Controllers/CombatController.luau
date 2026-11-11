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

local CharacterAnimator = require(script.Parent.CharacterAnimator)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local CombatHud = require(script.Parent.Parent.UI.CombatHud)
local Settings = require(script.Parent.Parent.UI.Settings)
local Essences = require(ReplicatedStorage.Shared.Config.Essences)
local FighterState = require(ReplicatedStorage.Shared.Combat.FighterState)
local NetClient = require(ReplicatedStorage.Shared.Net.Client)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

-- Muestra la zona de golpe como una caja de color (solo para depurar).
local SHOW_DEBUG_HITBOX = false

local HIT_SHAKE = 0.25
local HURT_SHAKE = 0.5
local SHAKE_TIME = 0.15

local ACTION_ATTACK = "ColosseumAttack"
local ACTION_BLOCK = "ColosseumBlock"
local ACTION_DODGE = "ColosseumDodge"
local ACTION_ESSENCE = "ColosseumEssence"
local ACTION_ULTIMATE = "ColosseumUltimate"

-- Salto del Picado (Esencia del Águila).
local EAGLE_UP_SPEED = 70
local EAGLE_UP_TIME = 0.3

local DEFENSE_MESSAGES: { [string]: { text: string, color: Color3 } } = {
	Dodged = { text = "¡Esquivado!", color = Color3.fromRGB(120, 200, 255) },
	Parried = { text = "¡PARADA PERFECTA!", color = Color3.fromRGB(255, 215, 80) },
	Blocked = { text = "Bloqueado", color = Color3.fromRGB(200, 200, 200) },
	GuardBroken = { text = "¡Guardia rota!", color = Color3.fromRGB(255, 120, 60) },
	Hit = { text = "¡Golpeado!", color = Color3.fromRGB(255, 70, 70) },
	Shielded = { text = "¡Testudo!", color = Color3.fromRGB(255, 215, 80) },
}

local localPlayer = Players.LocalPlayer

local CombatController = {}

local fighter: FighterState.FighterState? = nil
local attackPressedAt: number? = nil
-- Equipo actual (lo dicta el servidor en cada CombatState).
local weaponId = "Gladius"
local essenceId = "Loba"
local essenceReadyAt = 0
local diagnosticShown = false

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

-- Temblor breve de cámara para dar peso a los golpes.
local function shake(magnitude: number)
	if not Settings.get("cameraShake") then
		return
	end
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil then
		return
	end
	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < SHAKE_TIME do
			humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 2 * magnitude
			RunService.RenderStepped:Wait()
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

local push: (velocityVector: Vector3, duration: number) -> ()

local function requestAttack(kind: FighterState.AttackKind)
	local state = fighter
	if state == nil then
		return
	end
	local plan = state:tryAttack(kind, os.clock())
	if plan ~= nil then
		NetClient.fire("CombatAttack", kind)
		showHitbox(plan)
		local character = localPlayer.Character
		if character then
			CharacterAnimator.playAttack(character, plan.kind, plan.step, weaponId)
			-- Estocada a la carrera de la Hasta: impulso hacia delante.
			local lunge = plan.attack.lunge
			local root = getRoot()
			if lunge and root then
				task.delay(plan.attack.windup * 0.5, function()
					local look = root.CFrame.LookVector
					push(Vector3.new(look.X, 0, look.Z).Unit * lunge, plan.attack.active + 0.08)
				end)
			end
			-- Diagnóstico en pantalla, una sola vez, si el avatar no se puede animar.
			if not diagnosticShown then
				diagnosticShown = true
				local problem = CharacterAnimator.getProblem(character)
				if problem then
					CombatHud.showMessage(problem, Color3.fromRGB(255, 200, 90))
				end
			end
		end
	end
end

-- Empuja al propio personaje (su física la controla este cliente).
function push(velocityVector: Vector3, duration: number)
	local root = getRoot()
	if root == nil then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.MaxForce = 100000
	velocity.VectorVelocity = velocityVector
	velocity.Parent = root
	Debris:AddItem(velocity, duration)
	Debris:AddItem(attachment, duration)
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
	push(direction * Combat.DODGE_SPEED, Combat.DODGE_DURATION)
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
	local character = localPlayer.Character
	if inputState == Enum.UserInputState.Begin then
		state:setBlocking(true, os.clock())
		NetClient.fire("CombatBlock", true)
		if character then
			CharacterAnimator.setBlocking(character, state.blocking)
		end
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		state:setBlocking(false, os.clock())
		NetClient.fire("CombatBlock", false)
		if character then
			CharacterAnimator.setBlocking(character, false)
		end
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
		shake(HIT_SHAKE)
	elseif kind == "Defense" and userId == localPlayer.UserId then
		local info = DEFENSE_MESSAGES[a]
		if info then
			CombatHud.showMessage(info.text, info.color)
		end
		if a == "Hit" or a == "GuardBroken" then
			shake(HURT_SHAKE)
		end
	elseif kind == "Downed" and userId == localPlayer.UserId then
		CombatHud.showMessage("Has caído…", Color3.fromRGB(255, 70, 70))
	elseif kind == "Revived" and userId == localPlayer.UserId then
		CombatHud.showMessage("¡En pie, gladiador!", Color3.fromRGB(255, 215, 80))
	elseif kind == "Telegraph" then
		CombatHud.showMessage("¡Cuidado!", Color3.fromRGB(255, 90, 90))
	elseif kind == "Ultimate" and a == "TestudoAlly" then
		CombatHud.showMessage("¡Un aliado te cubre con su Testudo!", Color3.fromRGB(255, 215, 80))
	elseif kind == "Ultimate" and userId == localPlayer.UserId then
		local weapon = Weapons[weaponId]
		CombatHud.showMessage(`¡{string.upper(weapon.ultimate.name)}!`, Color3.fromRGB(255, 215, 80))
		shake(HURT_SHAKE)
	end
end

local function newFighter()
	local essence = Essences[essenceId]
	fighter = FighterState.new(Weapons[weaponId] :: any, Combat :: any, os.clock(), {
		staminaBonus = if essence then essence.staminaBonus else nil,
	})
end

local function onEssence(_name: string, inputState: Enum.UserInputState, _input: InputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if os.clock() < essenceReadyAt then
		CombatHud.showMessage("Esencia recargándose…", Color3.fromRGB(200, 200, 200))
		return Enum.ContextActionResult.Pass
	end
	NetClient.fire("CombatEssence")
	-- Predicción: la recarga empieza ya; el servidor la corrige si no la aceptó.
	local essence = Essences[essenceId]
	if essence then
		essenceReadyAt = os.clock() + essence.cooldown
		if essence.id == "Aguila" then
			push(Vector3.new(0, EAGLE_UP_SPEED, 0), EAGLE_UP_TIME)
		end
	end
	return Enum.ContextActionResult.Pass
end

local function onUltimate(_name: string, inputState: Enum.UserInputState, _input: InputObject)
	local state = fighter
	if inputState ~= Enum.UserInputState.Begin or state == nil then
		return Enum.ContextActionResult.Pass
	end
	if state.ultimate < Combat.ULTIMATE_MAX then
		CombatHud.showMessage("La definitiva aún no está cargada", Color3.fromRGB(200, 200, 200))
		return Enum.ContextActionResult.Pass
	end
	NetClient.fire("CombatUltimate")
	return Enum.ContextActionResult.Pass
end

function CombatController.Start(_self: typeof(CombatController))
	CombatHud.create()

	localPlayer.CharacterAdded:Connect(newFighter)
	if localPlayer.Character then
		newFighter()
	end

	NetClient.on("CombatState", function(snapshot: { [string]: any })
		-- Si cambió el equipo (armería), se rehace la predicción con la nueva arma.
		if snapshot.weapon and (snapshot.weapon ~= weaponId or snapshot.essence ~= essenceId) then
			weaponId = snapshot.weapon
			essenceId = snapshot.essence
			newFighter()
		end
		if snapshot.essenceReadyIn ~= nil then
			essenceReadyAt = os.clock() + snapshot.essenceReadyIn
		end
		local state = fighter
		if state ~= nil then
			state:applySnapshot(snapshot :: any, os.clock())
			-- Si el servidor bajó la guardia (guardia rota, aturdimiento), se refleja.
			local character = localPlayer.Character
			if character and not snapshot.blocking then
				CharacterAnimator.setBlocking(character, false)
			end
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
	ContextActionService:BindAction(ACTION_ESSENCE, onEssence, true, Enum.KeyCode.Z, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction(ACTION_ULTIMATE, onUltimate, true, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle(ACTION_DODGE, "Esquivar")
	ContextActionService:SetTitle(ACTION_ESSENCE, "Esencia")
	ContextActionService:SetTitle(ACTION_ULTIMATE, "Definitiva")

	RunService.Heartbeat:Connect(function()
		local state = fighter
		if state ~= nil then
			local snapshot = state:snapshot(os.clock())
			CombatHud.update(snapshot.health, snapshot.stamina, snapshot.ultimate, snapshot.maxStamina)
			local essence = Essences[essenceId]
			local weapon = Weapons[weaponId]
			local remaining = essenceReadyAt - os.clock()
			CombatHud.updateAbilities(
				if essence
					then (if remaining > 0
						then `Z · {essence.name}: {math.ceil(remaining)} s`
						else `Z · {essence.name}: lista`)
					else "",
				if weapon
					then (if snapshot.ultimate >= Combat.ULTIMATE_MAX
						then `R · {weapon.ultimate.name}: ¡LISTA!`
						else `R · {weapon.ultimate.name}: {math.floor(snapshot.ultimate)} %`)
					else "",
				snapshot.ultimate >= Combat.ULTIMATE_MAX
			)
		end
	end)
end

return CombatController
