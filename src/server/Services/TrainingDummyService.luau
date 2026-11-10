--!strict
-- Muñeco de entrenamiento (hito 1.1): recibe golpes y ataca con aviso previo, para probar
-- ataque, esquiva, bloqueo y parada perfecta antes de construir la Hidra.
-- Es provisional: se retirará cuando exista la primera bestia.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local CombatService = require(script.Parent.CombatService)
local Config = require(ServerStorage.ServerOnly.Config.TrainingDummy)
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

function TrainingDummyService.Start(_self: typeof(TrainingDummyService))
	build()

	while true do
		task.wait(Config.ATTACK_INTERVAL)
		if canAct() and #playersInRange() > 0 then
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
