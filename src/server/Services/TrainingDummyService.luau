--!strict
-- Muñeco de entrenamiento (hito 1.1): recibe golpes y ataca con aviso previo, para probar
-- ataque, esquiva, bloqueo y parada perfecta antes de construir la Hidra.
-- Es provisional: se retirará cuando exista la primera bestia.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local CodexService = require(script.Parent.CodexService)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local CombatService = require(script.Parent.CombatService)
local Config = require(ServerStorage.ServerOnly.Config.TrainingDummy)
local Homing = require(ServerScriptService.Server.Beasts.Homing)
local NetService = require(script.Parent.NetService)

local COLOR_IDLE = Color3.fromRGB(150, 110, 70)
local COLOR_TELEGRAPH = Color3.fromRGB(220, 40, 40)
local COLOR_STUNNED = Color3.fromRGB(240, 210, 60)
local COLOR_HIT = Color3.fromRGB(255, 255, 255)
local COLOR_DEAD = Color3.fromRGB(70, 70, 70)
local HIT_FLASH_TIME = 0.1

local TrainingDummyService = {}

local body: Part
local label: TextLabel
local health = Config.HEALTH
local telegraphing = false
local stunnedUntil = 0
local hitFlashUntil = 0

local function refresh()
	local now = os.clock()
	if health <= 0 then
		body.Color = COLOR_DEAD
		label.Text = "Derrotado"
	else
		label.Text = `Muñeco {math.ceil(health)}/{Config.HEALTH}`
		if now < hitFlashUntil then
			body.Color = COLOR_HIT
		elseif now < stunnedUntil then
			body.Color = COLOR_STUNNED
		elseif telegraphing then
			body.Color = COLOR_TELEGRAPH
		else
			body.Color = COLOR_IDLE
		end
	end
end

local function refreshAfter(seconds: number)
	task.delay(seconds + 0.02, refresh)
end

local function stun(duration: number)
	if duration > 0 then
		stunnedUntil = math.max(stunnedUntil, os.clock() + duration)
		refreshAfter(duration)
	end
end

local function onDamaged(_attacker: Player, damage: number, stunTime: number)
	if health <= 0 then
		return
	end
	health = math.max(0, health - damage)
	hitFlashUntil = os.clock() + HIT_FLASH_TIME
	refreshAfter(HIT_FLASH_TIME)
	stun(stunTime)
	if health <= 0 then
		task.delay(Config.RESPAWN_TIME, function()
			health = Config.HEALTH
			refresh()
		end)
	end
	refresh()
end

local function playersInRange(): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			if (root.Position - body.Position).Magnitude <= Config.ATTACK_RANGE then
				table.insert(result, player)
			end
		end
	end
	return result
end

local function canAct(): boolean
	return health > 0 and os.clock() >= stunnedUntil
end

local function build()
	local model = Instance.new("Model")
	model.Name = "TrainingDummy"

	body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(3, 6, 2)
	body.Anchored = true
	body.Position = Vector3.new(Config.POSITION[1], Config.POSITION[2], Config.POSITION[3])
	body.Parent = model
	model.PrimaryPart = body

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 44)
	billboard.StudsOffset = Vector3.new(0, 4.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = body

	label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = billboard

	refresh()
	model.Parent = Workspace
	CombatService.registerTarget(model, onDamaged)
end

-- Bola de fuego de práctica -------------------------------------------------------

local function makeBall(position: Vector3, color: Color3): Part
	local ball = Instance.new("Part")
	ball.Name = "Fireball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(2.4, 2.4, 2.4)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Position = position
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 0
	fire.Color = color
	fire.Parent = ball
	ball.Parent = Workspace
	return ball
end

local function burst(position: Vector3)
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = 3
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = Workspace
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Devuelta con una parada perfecta: vuelve al muñeco, lo daña y lo aturde.
local function reflect(player: Player, from: Vector3)
	local settings = Config.FIREBALL
	CodexService.discover(player, "IgnisReflexus")
	local ball = makeBall(from, Color3.fromRGB(255, 230, 120))
	local position = from
	local started = os.clock()
	while os.clock() - started < 3 do
		local deltaTime = RunService.Heartbeat:Wait()
		local offset = body.Position - position
		if offset.Magnitude <= 2.5 then
			break
		end
		position += offset.Unit * math.min(offset.Magnitude, settings.REFLECT_SPEED * deltaTime)
		ball.Position = position
	end
	ball:Destroy()
	burst(body.Position)
	onDamaged(player, settings.REFLECT_DAMAGE, settings.REFLECT_STUN)
end

local function launchFireball(target: Player)
	local settings = Config.FIREBALL
	local origin = body.Position + Vector3.new(0, 2, 0)
	local floorY = body.Position.Y - body.Size.Y / 2
	local ball = makeBall(origin, Color3.fromRGB(255, 120, 30))
	local maxTurn = math.rad(settings.TURN_RATE)
	local position = origin
	local direction: Homing.Vec = { x = 0, y = 0, z = 1 }
	local root = getRoot(target)
	if root then
		local toTarget = root.Position - origin
		direction = Homing.normalize({ x = toTarget.X, y = 0, z = toTarget.Z })
	end
	local started = os.clock()

	while os.clock() - started < settings.LIFETIME do
		local deltaTime = RunService.Heartbeat:Wait()
		local targetRoot = getRoot(target)
		if targetRoot then
			local aim = Vector3.new(targetRoot.Position.X, floorY + settings.HEIGHT, targetRoot.Position.Z) - position
			direction = Homing.steer(direction, { x = aim.X, y = aim.Y, z = aim.Z }, maxTurn * deltaTime)
		end
		position += Vector3.new(direction.x, direction.y, direction.z) * settings.SPEED * deltaTime
		ball.Position = position

		for _, player in Players:GetPlayers() do
			local playerRoot = getRoot(player)
			if playerRoot and (playerRoot.Position - position).Magnitude <= settings.RADIUS then
				ball:Destroy()
				burst(position)
				local hitPosition = position
				CombatService.hitPlayer(player, settings.DAMAGE, os.clock(), function()
					task.spawn(reflect, player, hitPosition)
				end)
				return
			end
		end
		if position.Y <= floorY + 0.3 then
			break
		end
	end
	if ball.Parent then
		burst(position)
		ball:Destroy()
	end
end

-- El jugador más cercano dentro del alcance de la bola de fuego (o nil).
local function fireballTarget(): Player?
	local best: Player? = nil
	local bestDistance = Config.FIREBALL.RANGE
	for _, player in Players:GetPlayers() do
		local root = getRoot(player)
		-- No se lanza a quien está en la arena: el muñeco solo entrena en el foro.
		if root and player:GetAttribute("InArena") ~= true then
			local distance = (root.Position - body.Position).Magnitude
			if distance <= bestDistance then
				best = player
				bestDistance = distance
			end
		end
	end
	return best
end

function TrainingDummyService.Start(_self: typeof(TrainingDummyService))
	build()

	local attackCount = 0
	while true do
		task.wait(Config.ATTACK_INTERVAL)
		attackCount += 1
		local fireTarget = if attackCount % 2 == 0 and canAct() then fireballTarget() else nil
		if fireTarget then
			-- Aviso naranja y bola de fuego que persigue al gladiador.
			telegraphing = true
			body.Color = Color3.fromRGB(255, 140, 40)
			NetService.fire("CombatEvent", fireTarget, "Telegraph", 0, Config.FIREBALL.TELEGRAPH)
			task.wait(Config.FIREBALL.TELEGRAPH)
			telegraphing = false
			refresh()
			if canAct() then
				task.spawn(launchFireball, fireTarget)
			end
		elseif canAct() and #playersInRange() > 0 then
			-- Aviso: el muñeco se pone rojo y los clientes reciben el tiempo hasta el golpe.
			telegraphing = true
			refresh()
			local impactTime = os.clock() + Config.TELEGRAPH_TIME
			NetService.fireAll("CombatEvent", "Telegraph", 0, Config.TELEGRAPH_TIME)
			task.wait(Config.TELEGRAPH_TIME)
			telegraphing = false
			refresh()

			if canAct() then
				for _, player in playersInRange() do
					CombatService.hitPlayer(player, Config.ATTACK_DAMAGE, impactTime, function()
						stun(Combat.PARRY_STUN)
						refresh()
					end)
				end
			end
		end
	end
end

return TrainingDummyService
