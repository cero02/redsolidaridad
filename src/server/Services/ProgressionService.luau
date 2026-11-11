--!strict
-- Progreso y reconocimiento (pilares progreso y presumir, docs/design/PILARES.md):
-- experiencia, niveles, rangos, desbloqueos y títulos. También muestra a los demás lo
-- que has logrado: placa sobre la cabeza con título y rango, y tabla de jugadores.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EventService = require(script.Parent.EventService)
local NetService = require(script.Parent.NetService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local Progression = require(ReplicatedStorage.Shared.Meta.Progression)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.Progression)
local Schema = require(ServerScriptService.Server.Data.Schema)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Titles = require(ReplicatedStorage.Shared.Config.Titles)

local NAMEPLATE = "ColosseumNameplate"

local config = ProgressionConfig :: any

local ProgressionService = {}

-- Cambiaron los cosméticos desbloqueados de un jugador.
ProgressionService.CosmeticsChanged = Signal.new() :: Signal.Signal<Player>

local function titleColor(id: string): Color3
	local title = Titles[id]
	local color = if title then title.color else { 255, 255, 255 }
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function updateLeaderstats(player: Player, data: Schema.ProfileData)
	local stats = player:FindFirstChild("leaderstats")
	if stats == nil then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		for _, name in { "Nivel", "Victorias" } do
			local value = Instance.new("IntValue")
			value.Name = name
			value.Parent = folder
		end
		folder.Parent = player
		stats = folder
	end
	local level = (stats :: Instance):FindFirstChild("Nivel")
	local wins = (stats :: Instance):FindFirstChild("Victorias")
	if level and level:IsA("IntValue") then
		level.Value = data.level
	end
	if wins and wins:IsA("IntValue") then
		wins.Value = data.stats.hydraKills
	end
end

-- Placa sobre la cabeza: título elegido y rango. Visible para todos.
local function updateNameplate(player: Player, data: Schema.ProfileData)
	local character = player.Character
	local head = if character then character:FindFirstChild("Head") else nil
	if head == nil or not head:IsA("BasePart") then
		return
	end

	local billboard = head:FindFirstChild(NAMEPLATE)
	if billboard == nil then
		local gui = Instance.new("BillboardGui")
		gui.Name = NAMEPLATE
		gui.Size = UDim2.fromOffset(240, 46)
		gui.StudsOffset = Vector3.new(0, 3.2, 0)
		gui.MaxDistance = 80
		gui.Parent = head

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.fromScale(1, 0.55)
		title.BackgroundTransparency = 1
		title.TextScaled = true
		title.Font = Enum.Font.Antique
		title.TextStrokeTransparency = 0
		title.Parent = gui

		local rank = Instance.new("TextLabel")
		rank.Name = "Rank"
		rank.Size = UDim2.fromScale(1, 0.45)
		rank.Position = UDim2.fromScale(0, 0.55)
		rank.BackgroundTransparency = 1
		rank.TextScaled = true
		rank.Font = Enum.Font.GothamBold
		rank.TextColor3 = Color3.new(1, 1, 1)
		rank.TextStrokeTransparency = 0
		rank.Parent = gui
		billboard = gui
	end

	local gui = billboard :: Instance
	local titleLabel = gui:FindFirstChild("Title") :: TextLabel
	local rankLabel = gui:FindFirstChild("Rank") :: TextLabel
	local title = Titles[data.equippedTitle]
	titleLabel.Text = if title then `«{title.name}»` else ""
	titleLabel.TextColor3 = titleColor(data.equippedTitle)
	rankLabel.Text = `Nv {data.level} · {Progression.rankFor(config, data.level).name}`
end

-- Envía al jugador su perfil público y actualiza lo que ven los demás.
function ProgressionService.refresh(player: Player)
	local data = PlayerDataService.get(player)
	if data == nil then
		return
	end
	updateLeaderstats(player, data)
	updateNameplate(player, data)
	NetService.fire("ProgressUpdate", player, Schema.toPublic(data))
end

-- Concede un título. Devuelve true si era nuevo.
function ProgressionService.grantTitle(player: Player, titleId: string): boolean
	local data = PlayerDataService.get(player)
	local title = Titles[titleId]
	if data == nil or title == nil or data.unlockedTitles[titleId] then
		return false
	end
	data.unlockedTitles[titleId] = true
	-- Un título recién ganado se luce: se equipa solo.
	data.equippedTitle = titleId
	EventService.news(`{player.DisplayName} ha obtenido el título «{title.name}».`)
	ProgressionService.refresh(player)
	return true
end

-- Suma experiencia y aplica las subidas de nivel. Devuelve el resultado.
function ProgressionService.grantXp(player: Player, amount: number): Progression.LevelResult?
	local data = PlayerDataService.get(player)
	if data == nil then
		return nil
	end
	local previousRank = Progression.rankFor(config, data.level)
	local result = Progression.addXp(config, data.level, data.xp, amount)
	data.level = result.level
	data.xp = result.xp

	local cosmeticsChanged = false
	for _, unlock in result.unlocks do
		if unlock.kind == "Weapon" then
			data.unlockedWeapons[unlock.id] = true
		elseif unlock.kind == "Essence" then
			data.unlockedEssences[unlock.id] = true
		elseif unlock.kind == "Cosmetic" then
			data.unlockedCosmetics[unlock.id] = true
			cosmeticsChanged = true
		elseif unlock.kind == "Title" then
			ProgressionService.grantTitle(player, unlock.id)
		end
	end

	local rank = Progression.rankFor(config, data.level)
	if rank.id ~= previousRank.id then
		EventService.news(`¡{player.DisplayName} asciende a {rank.name}!`)
	elseif result.levelsGained > 0 then
		EventService.news(`{player.DisplayName} alcanza el nivel {data.level}.`)
	end

	ProgressionService.refresh(player)
	if cosmeticsChanged then
		ProgressionService.CosmeticsChanged:Fire(player)
	end
	return result
end

function ProgressionService.Start(_self: typeof(ProgressionService))
	PlayerDataService.Loaded:Connect(function(player: Player)
		ProgressionService.refresh(player)
		ProgressionService.CosmeticsChanged:Fire(player)
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			character:WaitForChild("Head", 10)
			ProgressionService.refresh(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
		ProgressionService.refresh(player)
	end

	NetService.on("EquipTitle", function(player: Player, titleId: string)
		local data = PlayerDataService.get(player)
		if data and data.unlockedTitles[titleId] and Titles[titleId] then
			data.equippedTitle = titleId
			ProgressionService.refresh(player)
		end
	end)

	-- Cuando el cliente ya escucha, recibe su progreso.
	PlayerDataService.ClientReady:Connect(ProgressionService.refresh)
end

return ProgressionService
