--!strict
-- Salón de Leyendas (pilar presumir): los mejores tiempos contra la Hidra, grabados en
-- una lápida del foro. Con acceso a la API usa un OrderedDataStore compartido por todos
-- los servidores; sin él (Studio con datos simulados), una clasificación del servidor.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DataConfig = require(ServerScriptService.Server.Data.DataConfig)
local EventService = require(script.Parent.EventService)

local STORE_NAME = "HydraBestTimes_v1"
local TOP_COUNT = 10
local REFRESH_INTERVAL = 60
local BOARD_POSITION = Vector3.new(-34, 0, -8)

type Entry = { userId: number, name: string, time: number }

local LeaderboardService = {}

local store: OrderedDataStore? = nil
local localEntries: { [number]: Entry } = {}
local nameCache: { [number]: string } = {}
local boardLabel: TextLabel? = nil
local lastTop: { Entry } = {}

local function formatTime(seconds: number): string
	local whole = math.floor(seconds)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function nameOf(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and typeof(name) == "string" then name else `Gladiador {userId}`
	nameCache[userId] = result
	return result
end

local function render(top: { Entry })
	local label = boardLabel
	if label == nil then
		return
	end
	local lines = { "<b>SALÓN DE LEYENDAS</b>", "<i>Los más rápidos contra la Hidra</i>", "" }
	if #top == 0 then
		table.insert(lines, "Aún nadie ha vencido a la Hidra.\n¿Serás el primero?")
	end
	for index, entry in top do
		local medal = if index == 1 then "👑 " elseif index <= 3 then "★ " else ""
		table.insert(lines, `{medal}{index}. {entry.name} — {formatTime(entry.time)}`)
	end
	label.Text = table.concat(lines, "\n")
end

local function localTop(): { Entry }
	local list = {}
	for _, entry in localEntries do
		table.insert(list, entry)
	end
	table.sort(list, function(a: Entry, b: Entry)
		return a.time < b.time
	end)
	while #list > TOP_COUNT do
		table.remove(list)
	end
	return list
end

local function fetchTop(): { Entry }?
	local ordered = store
	if ordered == nil then
		return nil
	end
	local ok, result = pcall(function()
		local pages = ordered:GetSortedAsync(true, TOP_COUNT)
		return pages:GetCurrentPage()
	end)
	if not ok or typeof(result) ~= "table" then
		return nil
	end
	local top = {}
	for _, item in result :: { any } do
		local userId = tonumber(item.key)
		if userId then
			-- Se guarda en décimas de segundo (los OrderedDataStore solo admiten enteros).
			table.insert(top, { userId = userId, name = nameOf(userId), time = item.value / 10 })
		end
	end
	return top
end

local function refresh()
	local top = fetchTop() or localTop()
	lastTop = top
	render(top)
end

local function buildBoard()
	local board = Instance.new("Part")
	board.Name = "SalonDeLeyendas"
	board.Anchored = true
	board.Size = Vector3.new(12, 11, 1)
	board.CFrame = CFrame.lookAt(BOARD_POSITION + Vector3.new(0, 6, 0), Vector3.new(0, 6, 10))
	board.Color = Color3.fromRGB(60, 50, 45)
	board.Material = Enum.Material.Slate
	board.Parent = Workspace

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.RichText = true
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.Antique
	label.TextColor3 = Color3.fromRGB(255, 215, 120)
	label.Parent = gui
	boardLabel = label
end

-- Registra un tiempo de victoria. Avisa a todo el servidor si entra en el Salón.
function LeaderboardService.submit(player: Player, seconds: number)
	local userId = player.UserId
	nameCache[userId] = player.DisplayName
	local previous = localEntries[userId]
	if previous == nil or seconds < previous.time then
		localEntries[userId] = { userId = userId, name = player.DisplayName, time = seconds }
	end

	local ordered = store
	if ordered then
		task.spawn(function()
			local tenths = math.floor(seconds * 10)
			pcall(function()
				ordered:UpdateAsync(tostring(userId), function(old: number?)
					if old ~= nil and old <= tenths then
						return nil -- no mejora: no se escribe
					end
					return tenths
				end)
			end)
			refresh()
		end)
	else
		refresh()
	end

	-- ¿Ha entrado en el Salón? Se comprueba con la clasificación conocida.
	local top = localTop()
	for index, entry in top do
		if entry.userId == userId and entry.time == seconds and index <= 3 then
			EventService.news(`¡{player.DisplayName} entra en el podio del Salón de Leyendas (puesto {index})!`)
			break
		end
	end
end

function LeaderboardService.getTop(): { Entry }
	return lastTop
end

function LeaderboardService.Init(_self: typeof(LeaderboardService))
	buildBoard()
	render({})
	local useLive = not RunService:IsStudio() or DataConfig.USE_LIVE_DATA_IN_STUDIO
	if useLive then
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore(STORE_NAME)
		end)
		if ok then
			store = result
		end
	end
end

function LeaderboardService.Start(_self: typeof(LeaderboardService))
	while true do
		refresh()
		task.wait(REFRESH_INTERVAL)
	end
end

return LeaderboardService
