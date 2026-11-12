--!strict
-- Construye por código el Gran Coliseo (versión de bloques) y la puerta del foro.
-- Así el mundo aparece al pulsar Play sin montar nada a mano en Studio. Cuando exista un
-- escenario hecho por artistas, este servicio solo localizará sus puntos clave.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ServerStorage.ServerOnly.Config.Arena)
local ServerText = require(game:GetService("ServerScriptService").Server.Localization.ServerText)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local SAND = Color3.fromRGB(214, 190, 140)
local STONE = Color3.fromRGB(180, 170, 150)
local STONE_DARK = Color3.fromRGB(120, 110, 100)
local WATER = Color3.fromRGB(30, 80, 70)
local IMPERIAL_RED = Color3.fromRGB(150, 30, 30)
local CROWD_COLORS = {
	Color3.fromRGB(230, 225, 210),
	Color3.fromRGB(150, 30, 30),
	Color3.fromRGB(200, 160, 60),
	Color3.fromRGB(90, 70, 50),
	Color3.fromRGB(60, 90, 140),
}

local ArenaService = {}

-- Un jugador usa la puerta del foro.
ArenaService.GateTriggered = Signal.new() :: Signal.Signal<Player>
-- Un jugador enciende su arma en un brasero.
ArenaService.BrazierTriggered = Signal.new() :: Signal.Signal<Player>
-- Un jugador reaviva un brasero apagado.
ArenaService.BrazierRelit = Signal.new() :: Signal.Signal<Player>

local center = Vector3.new(Config.CENTER[1], Config.FLOOR_Y, Config.CENTER[3])

type Brazier = { fire: Fire, light: PointLight, prompt: ProximityPrompt, lit: boolean }
local braziers: { Brazier } = {}

local function applyBrazier(brazier: Brazier)
	brazier.fire.Enabled = brazier.lit
	brazier.light.Enabled = brazier.lit
	ServerText.setWorld(
		brazier.prompt,
		"ActionText",
		if brazier.lit then "world.brazier.light" else "world.brazier.rekindle"
	)
	brazier.prompt.HoldDuration = if brazier.lit then 0.4 else 2
end

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Disco horizontal: los cilindros de Roblox tienen el eje en X, así que se giran 90°.
local function makeDisc(
	parent: Instance,
	name: string,
	radius: number,
	thickness: number,
	topY: number,
	color: Color3,
	material: Enum.Material
): Part
	local position = Vector3.new(center.X, topY - thickness / 2, center.Z)
	local part = makePart(
		parent,
		name,
		Vector3.new(thickness, radius * 2, radius * 2),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Anillo de bloques mirando al centro (muros y gradas).
local function makeRing(
	parent: Instance,
	name: string,
	radius: number,
	height: number,
	depth: number,
	color: Color3,
	material: Enum.Material
)
	local segments = 40
	local length = 2 * math.pi * (radius + depth / 2) / segments + 0.4
	for index = 0, segments - 1 do
		local angle = index / segments * 2 * math.pi
		local position = center
			+ Vector3.new(
				math.cos(angle) * radius,
				height / 2 - Config.FLOOR_Y,
				math.sin(angle) * radius
			)
		local lookAt = Vector3.new(center.X, position.Y, center.Z)
		local segment = makePart(
			parent,
			name,
			Vector3.new(length, height, depth),
			CFrame.lookAt(position, lookAt),
			color,
			material
		)
		-- Sin sombras: el coliseo es grande y así rinde mejor en equipos modestos.
		segment.CastShadow = false
	end
end

-- `action` y `object` son claves de idioma (Shared/Locale).
local function addPrompt(
	parent: Instance,
	action: string,
	object: string,
	hold: number
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	ServerText.setWorld(prompt, "ActionText", action)
	ServerText.setWorld(prompt, "ObjectText", object)
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function addSign(parent: Instance, text: string, offsetY: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(320, 60)
	billboard.StudsOffset = Vector3.new(0, offsetY, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 150
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.Antique
	label.TextColor3 = Color3.fromRGB(255, 220, 130)
	label.TextStrokeTransparency = 0
	label.Parent = billboard
	ServerText.setWorld(label, "Text", text)
end

local function buildBraziers(parent: Instance)
	for index = 0, 3 do
		local angle = math.rad(45 + index * 90)
		local base = center
			+ Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.BRAZIER_RADIUS

		makePart(
			parent,
			"BrazierBase",
			Vector3.new(3, 3, 3),
			CFrame.new(base + Vector3.new(0, 1.5, 0)),
			STONE_DARK,
			Enum.Material.Slate
		)
		local bowl = makePart(
			parent,
			"BrazierBowl",
			Vector3.new(4.5, 1, 4.5),
			CFrame.new(base + Vector3.new(0, 3.5, 0)),
			Color3.fromRGB(60, 45, 35),
			Enum.Material.Metal
		)

		local fire = Instance.new("Fire")
		fire.Size = 9
		fire.Heat = 12
		fire.Parent = bowl

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 170, 80)
		light.Range = 28
		light.Brightness = 2
		light.Parent = bowl

		local prompt = addPrompt(bowl, "world.brazier.light", "world.brazier.object", 0.4)
		local brazier: Brazier = { fire = fire, light = light, prompt = prompt, lit = true }
		table.insert(braziers, brazier)
		prompt.Triggered:Connect(function(player: Player)
			if brazier.lit then
				ArenaService.BrazierTriggered:Fire(player)
			else
				brazier.lit = true
				applyBrazier(brazier)
				ArenaService.BrazierRelit:Fire(player)
			end
		end)
	end
end

local function buildCrowd(parent: Instance, tiers: { { radius: number, height: number } })
	local random = Random.new(117)
	for _ = 1, Config.CROWD_SIZE do
		local tier = tiers[random:NextInteger(1, #tiers)]
		local angle = random:NextNumber(0, 2 * math.pi)
		local position = center
			+ Vector3.new(
				math.cos(angle) * tier.radius,
				tier.height - Config.FLOOR_Y + 1.5,
				math.sin(angle) * tier.radius
			)
		local spectator = makePart(
			parent,
			"Spectator",
			Vector3.new(1.6, 3, 1.6),
			CFrame.new(position),
			CROWD_COLORS[random:NextInteger(1, #CROWD_COLORS)],
			Enum.Material.SmoothPlastic
		)
		spectator.CanCollide = false
		spectator.CanQuery = false
		spectator.CanTouch = false
		spectator.CastShadow = false
	end
end

local function buildArena()
	local model = Instance.new("Model")
	model.Name = "GranColiseo"
	-- Los lugares nuevos usan StreamingEnabled: sin esto el cliente solo recibe las piezas
	-- cercanas al jugador (que empieza en el Foro) y no ve el coliseo desde el menú ni
	-- encuentra al público. Persistent lo envía entero y nunca lo descarga.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	makeDisc(model, "Sand", Config.RADIUS + 2, 4, Config.FLOOR_Y, SAND, Enum.Material.Sand)

	local pond = makeDisc(
		model,
		"Pond",
		Config.POND_RADIUS,
		0.6,
		Config.FLOOR_Y + 0.3,
		WATER,
		Enum.Material.Glass
	)
	pond.CanCollide = false
	pond.CanQuery = false
	pond.Transparency = 0.25

	makeRing(
		model,
		"Wall",
		Config.RADIUS + 1.5,
		Config.WALL_HEIGHT,
		3,
		STONE,
		Enum.Material.Sandstone
	)

	-- Gradas: tres escalones cada vez más altos y alejados.
	local tiers = {}
	for tier = 1, 3 do
		local radius = Config.RADIUS + 1.5 + tier * 7
		local height = Config.WALL_HEIGHT - 4 + tier * 5
		makeRing(model, "Stands", radius, height, 7, STONE, Enum.Material.Sandstone)
		table.insert(tiers, { radius = radius, height = height })
	end
	makeRing(
		model,
		"OuterWall",
		Config.RADIUS + 1.5 + 4 * 7 - 1.5,
		Config.WALL_HEIGHT + 20,
		4,
		STONE_DARK,
		Enum.Material.Sandstone
	)

	buildBraziers(model)
	buildCrowd(model, tiers)
	model.Parent = Workspace
end

local function buildLobbyGate()
	local model = Instance.new("Model")
	model.Name = "PuertaDelColiseo"

	local base = Vector3.new(Config.LOBBY_GATE[1], Config.LOBBY_GATE[2], Config.LOBBY_GATE[3])
	for _, side in { -1, 1 } do
		makePart(
			model,
			"Pillar",
			Vector3.new(2, 12, 2),
			CFrame.new(base + Vector3.new(side * 5, 6, 0)),
			STONE,
			Enum.Material.Sandstone
		)
	end
	local lintel = makePart(
		model,
		"Lintel",
		Vector3.new(14, 2.5, 3),
		CFrame.new(base + Vector3.new(0, 13.2, 0)),
		IMPERIAL_RED,
		Enum.Material.Sandstone
	)
	addSign(lintel, "world.sign", 3)

	local door = makePart(
		model,
		"Door",
		Vector3.new(8, 12, 0.6),
		CFrame.new(base + Vector3.new(0, 6, 0)),
		Color3.fromRGB(255, 190, 90),
		Enum.Material.Neon
	)
	door.Transparency = 0.6
	door.CanCollide = false

	local prompt = addPrompt(door, "world.gate.action", "world.gate.object", 0.5)
	prompt.Triggered:Connect(function(player: Player)
		ArenaService.GateTriggered:Fire(player)
	end)

	model.Parent = Workspace
end

function ArenaService.Init(_self: typeof(ArenaService))
	buildArena()
	buildLobbyGate()
end

function ArenaService.getBrazierCount(): number
	return #braziers
end

function ArenaService.isBrazierLit(index: number): boolean
	return braziers[index].lit
end

function ArenaService.setBrazierLit(index: number, lit: boolean)
	local brazier = braziers[index]
	brazier.lit = lit
	applyBrazier(brazier)
end

function ArenaService.relightAllBraziers()
	for index = 1, #braziers do
		ArenaService.setBrazierLit(index, true)
	end
end

-- Centro de la arena a la altura del suelo.
function ArenaService.getCenter(): Vector3
	return center
end

function ArenaService.getPondRadius(): number
	return Config.POND_RADIUS
end

-- Punto de entrada de los gladiadores, mirando al centro. `index` los reparte en fila.
function ArenaService.getEntryCFrame(index: number): CFrame
	local offset = (index - 1) * 5
	local position = center + Vector3.new(offset, 3.5, Config.ENTRY_DISTANCE)
	return CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z))
end

function ArenaService.getLobbyCFrame(): CFrame
	return CFrame.new(Config.LOBBY_RETURN[1], Config.LOBBY_RETURN[2], Config.LOBBY_RETURN[3])
end

return ArenaService
