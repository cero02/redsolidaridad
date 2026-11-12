--!strict
-- El público del Gran Coliseo cobra vida en el cliente: se balancea siempre y salta y
-- celebra cuando pasa algo grande (cabeza cortada, cuello cauterizado, parada perfecta,
-- victoria). Solo visual y local. Con el modo ligero el público no se ve y no se anima.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local NetClient = require(ReplicatedStorage.Shared.Net.Client)
local Settings = require(script.Parent.Parent.UI.Settings)

-- Avisos del anunciador que hacen saltar al público.
local CHEER_KEYS = {
	["ann.firstSevered"] = 1,
	["ann.severed"] = 0.7,
	["ann.cauterized"] = 1,
	["ann.chainBroken"] = 1,
	["ann.stunned"] = 0.8,
	["ann.victory"] = 1.5,
	["ann.intro"] = 1,
	["ann.fury"] = 1,
	["ann.immortal"] = 1,
	["ann.revived"] = 0.8,
}
local EXCITEMENT_DECAY = 0.45
-- Solo se anima si la cámara está cerca del coliseo.
local ANIMATE_DISTANCE = 450

type Spectator = { part: BasePart, base: CFrame, phase: number, speed: number }

local CrowdController = {}

local spectators: { Spectator } = {}
local excitement = 0
local center = Vector3.new(0, 0, -200)

local function collect()
	local arena = Workspace:WaitForChild("GranColiseo", 15)
	if arena == nil then
		return
	end
	local sand = arena:FindFirstChild("Sand")
	if sand and sand:IsA("BasePart") then
		center = sand.Position
	end
	local random = Random.new()
	for _, child in arena:GetChildren() do
		if child.Name == "Spectator" and child:IsA("BasePart") then
			table.insert(spectators, {
				part = child,
				base = child.CFrame,
				phase = random:NextNumber(0, 2 * math.pi),
				speed = random:NextNumber(1.4, 2.6),
			})
		end
	end
end

local function cheer(amount: number)
	excitement = math.min(1.5, excitement + amount)
end

local function update(deltaTime: number)
	if #spectators == 0 or Settings.get("lightMode") then
		return
	end
	local camera = Workspace.CurrentCamera
	if (camera.CFrame.Position - center).Magnitude > ANIMATE_DISTANCE then
		return
	end
	excitement = math.max(0, excitement - deltaTime * EXCITEMENT_DECAY)
	local time = os.clock()
	for _, spectator in spectators do
		local wave = math.sin(time * spectator.speed + spectator.phase)
		-- En calma: un leve vaivén. Emocionado: saltos.
		local jump = math.max(0, wave) * excitement * 1.6
		local sway = wave * 0.12
		spectator.part.CFrame = spectator.base
			* CFrame.new(0, jump, 0)
			* CFrame.Angles(0, 0, sway * (1 - excitement * 0.5))
	end
end

function CrowdController.Start(_self: typeof(CrowdController))
	task.spawn(collect)
	NetClient.on("Announce", function(key: string)
		local amount = CHEER_KEYS[key]
		if amount then
			cheer(amount)
		end
	end)
	NetClient.on("CombatEvent", function(kind: string, userId: number, a: any)
		if kind == "Defense" and a == "Parried" then
			cheer(0.6)
		elseif kind == "Ultimate" and userId == Players.LocalPlayer.UserId then
			cheer(1)
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return CrowdController
