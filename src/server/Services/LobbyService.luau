--!strict
-- El mundo fuera del coliseo, generado por código para no depender de la plantilla de
-- Studio: retira la Baseplate y el punto de aparición de Studio, crea suelo, horizonte
-- (colinas y cipreses), el Foro (plaza de mármol, columnata, estandartes, estatua del
-- campeón, calzada hacia el Gran Coliseo), el punto de aparición y la luz de atardecer.
-- Cuando haya escenario de artistas, este servicio se retira.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local MARBLE = Color3.fromRGB(232, 224, 208)
local MARBLE_DARK = Color3.fromRGB(196, 186, 168)
local SAND = Color3.fromRGB(214, 190, 140)
local IMPERIAL_RED = Color3.fromRGB(140, 24, 24)
local GOLD = Color3.fromRGB(212, 168, 70)
local STONE = Color3.fromRGB(150, 140, 125)

-- Centro y radio de la plaza (la puerta del coliseo está en x=16, z=-8).
local PLAZA_CENTER = Vector3.new(0, 0, -6)
local PLAZA_RADIUS = 52
local COLUMN_COUNT = 24
local COLUMN_HEIGHT = 18
-- Huecos en la columnata: hacia el coliseo (−Z) y hacia el punto de aparición (+Z).
local GAP_ANGLES = { math.rad(270), math.rad(90) }
local GAP_WIDTH = math.rad(20)

local LobbyService = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function cylinder(
	parent: Instance,
	name: string,
	radius: number,
	height: number,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local p = part(
		parent,
		name,
		Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function inGap(angle: number): boolean
	for _, gap in GAP_ANGLES do
		local delta = math.abs((angle - gap + math.pi) % (2 * math.pi) - math.pi)
		if delta < GAP_WIDTH then
			return true
		end
	end
	return false
end

local function buildColumn(parent: Instance, base: Vector3, withBanner: boolean)
	cylinder(
		parent,
		"ColumnBase",
		1.9,
		1,
		base + Vector3.new(0, 0.5, 0),
		MARBLE_DARK,
		Enum.Material.Marble
	)
	local shaft = cylinder(
		parent,
		"Column",
		1.4,
		COLUMN_HEIGHT,
		base + Vector3.new(0, 1 + COLUMN_HEIGHT / 2, 0),
		MARBLE,
		Enum.Material.Marble
	)
	shaft.CastShadow = true
	part(
		parent,
		"Capital",
		Vector3.new(4, 1.2, 4),
		CFrame.new(base + Vector3.new(0, COLUMN_HEIGHT + 1.6, 0)),
		MARBLE_DARK,
		Enum.Material.Marble
	)
	if withBanner then
		-- Estandarte rojo con franja dorada, mirando al centro de la plaza.
		local facing = CFrame.lookAt(base, Vector3.new(PLAZA_CENTER.X, base.Y, PLAZA_CENTER.Z))
		local banner = part(
			parent,
			"Banner",
			Vector3.new(3, 9, 0.2),
			facing * CFrame.new(0, COLUMN_HEIGHT - 4, -1.6),
			IMPERIAL_RED,
			Enum.Material.Fabric
		)
		banner.CanCollide = false
		part(
			parent,
			"BannerTrim",
			Vector3.new(3.1, 0.5, 0.25),
			banner.CFrame * CFrame.new(0, -4.3, 0),
			GOLD,
			Enum.Material.Metal
		).CanCollide =
			false
		part(
			parent,
			"BannerEagle",
			Vector3.new(1.4, 1.4, 0.25),
			banner.CFrame * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(45)),
			GOLD,
			Enum.Material.Metal
		).CanCollide =
			false
	end
end

local BRONZE = Color3.fromRGB(150, 98, 48)

-- Estatua de bronce de un gladiador alzando el gladius sobre un pedestal de mármol.
local function buildStatue(parent: Instance, base: Vector3)
	local model = Instance.new("Model")
	model.Name = "ChampionStatue"
	local facing = CFrame.lookAt(base, Vector3.new(base.X, base.Y, base.Z + 10))
	local function piece(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material,
		shape: Enum.PartType?
	)
		local p = part(model, name, size, facing * offset, color, material)
		if shape then
			p.Shape = shape
		end
		return p
	end
	piece("Pedestal", Vector3.new(7, 5, 7), CFrame.new(0, 2.5, 0), MARBLE, Enum.Material.Marble)
	piece(
		"PedestalTrim",
		Vector3.new(7.6, 0.8, 7.6),
		CFrame.new(0, 5.2, 0),
		MARBLE_DARK,
		Enum.Material.Marble
	)
	piece(
		"LegLeft",
		Vector3.new(1.3, 5, 1.3),
		CFrame.new(-0.9, 8, 0.4) * CFrame.Angles(math.rad(-8), 0, 0),
		BRONZE,
		Enum.Material.Metal
	)
	piece(
		"LegRight",
		Vector3.new(1.3, 5, 1.3),
		CFrame.new(0.9, 8, -0.6) * CFrame.Angles(math.rad(10), 0, 0),
		BRONZE,
		Enum.Material.Metal
	)
	piece("Torso", Vector3.new(3.2, 4, 1.8), CFrame.new(0, 12.4, 0), BRONZE, Enum.Material.Metal)
	piece(
		"Head",
		Vector3.new(1.8, 1.8, 1.8),
		CFrame.new(0, 15.3, 0),
		BRONZE,
		Enum.Material.Metal,
		Enum.PartType.Ball
	)
	piece(
		"Helmet",
		Vector3.new(0.4, 1.6, 2.2),
		CFrame.new(0, 16.4, 0),
		IMPERIAL_RED,
		Enum.Material.Fabric
	)
	-- Brazo derecho en alto con el gladius.
	piece(
		"ArmRight",
		Vector3.new(1.1, 4, 1.1),
		CFrame.new(2.2, 15, 0) * CFrame.Angles(0, 0, math.rad(-20)),
		BRONZE,
		Enum.Material.Metal
	)
	piece(
		"Sword",
		Vector3.new(0.3, 4.5, 0.6),
		CFrame.new(3.1, 19, 0) * CFrame.Angles(0, 0, math.rad(-20)),
		GOLD,
		Enum.Material.Metal
	)
	-- Brazo izquierdo con el escudo.
	piece(
		"ArmLeft",
		Vector3.new(1.1, 3.6, 1.1),
		CFrame.new(-2.1, 11.8, 0.4),
		BRONZE,
		Enum.Material.Metal
	)
	piece(
		"Shield",
		Vector3.new(0.5, 4.2, 3.4),
		CFrame.new(-2.9, 11.6, 0.6),
		IMPERIAL_RED,
		Enum.Material.Wood
	)
	piece(
		"ShieldBoss",
		Vector3.new(1, 1, 1),
		CFrame.new(-3.2, 11.6, 0.6),
		GOLD,
		Enum.Material.Metal,
		Enum.PartType.Ball
	)
	model.Parent = parent
end

local function buildPlaza(parent: Instance)
	-- Suelo de mármol con un anillo de piedra y el ludus de arena para entrenar.
	cylinder(
		parent,
		"PlazaFloor",
		PLAZA_RADIUS + 4,
		0.4,
		PLAZA_CENTER + Vector3.new(0, 0.2, 0),
		MARBLE,
		Enum.Material.Marble
	)
	cylinder(
		parent,
		"PlazaRing",
		PLAZA_RADIUS - 6,
		0.42,
		PLAZA_CENTER + Vector3.new(0, 0.21, 0),
		MARBLE_DARK,
		Enum.Material.Marble
	)
	cylinder(
		parent,
		"PlazaInner",
		PLAZA_RADIUS - 8,
		0.44,
		PLAZA_CENTER + Vector3.new(0, 0.22, 0),
		MARBLE,
		Enum.Material.Marble
	)
	cylinder(parent, "StatueRing", 12, 0.46, Vector3.new(0, 0.23, -20), SAND, Enum.Material.Sand)
	buildStatue(parent, Vector3.new(0, 0.45, -20))

	for index = 0, COLUMN_COUNT - 1 do
		local angle = index / COLUMN_COUNT * 2 * math.pi
		if not inGap(angle) then
			local base = PLAZA_CENTER
				+ Vector3.new(math.cos(angle), 0, math.sin(angle)) * PLAZA_RADIUS
			buildColumn(parent, base + Vector3.new(0, 0.4, 0), index % 3 == 0)
		end
	end

	-- Calzada hacia el Gran Coliseo, con antorchas a los lados.
	local roadStart = PLAZA_CENTER.Z - PLAZA_RADIUS
	-- El muro exterior del coliseo está a unos 88 studs de su centro (z = −200).
	local roadEnd = -110
	local roadLength = roadStart - roadEnd
	part(
		parent,
		"Road",
		Vector3.new(12, 0.4, roadLength),
		CFrame.new(0, 0.2, (roadStart + roadEnd) / 2),
		STONE,
		Enum.Material.Cobblestone
	)
	for z = roadStart - 8, roadEnd + 4, -16 do
		for _, side in { -1, 1 } do
			local post = part(
				parent,
				"TorchPost",
				Vector3.new(0.8, 6, 0.8),
				CFrame.new(side * 8, 3, z),
				Color3.fromRGB(80, 60, 40),
				Enum.Material.Wood
			)
			local bowl = part(
				parent,
				"TorchBowl",
				Vector3.new(1.6, 0.6, 1.6),
				post.CFrame * CFrame.new(0, 3.3, 0),
				Color3.fromRGB(60, 45, 35),
				Enum.Material.Metal
			)
			local fire = Instance.new("Fire")
			fire.Size = 4
			fire.Heat = 6
			fire.Parent = bowl
		end
	end
end

-- Atardecer romano: luz cálida, bruma suave y un poco de brillo.
local function setupLighting()
	Lighting.ClockTime = 17.2
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(70, 55, 45)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 120, 95)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.4

	local function ensure(className: string, name: string): Instance
		local existing = Lighting:FindFirstChild(name)
		if existing and existing.ClassName == className then
			return existing
		end
		local instance = Instance.new(className)
		instance.Name = name
		instance.Parent = Lighting
		return instance
	end

	local atmosphere = ensure("Atmosphere", "ColosseumAtmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(230, 190, 150)
	atmosphere.Decay = Color3.fromRGB(150, 100, 70)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.2

	local color = ensure("ColorCorrectionEffect", "ColosseumColor") :: ColorCorrectionEffect
	color.Brightness = 0.02
	color.Contrast = 0.08
	color.Saturation = 0.08
	color.TintColor = Color3.fromRGB(255, 244, 228)

	local bloom = ensure("BloomEffect", "ColosseumBloom") :: BloomEffect
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.6

	local rays = ensure("SunRaysEffect", "ColosseumSunRays") :: SunRaysEffect
	rays.Intensity = 0.04
	rays.Spread = 0.6
end

-- Quita lo que trae la plantilla de Studio (Baseplate y punto de aparición con la
-- textura de Roblox) para que el juego tenga siempre su propio aspecto.
local function removeTemplate()
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") or (child:IsA("BasePart") and child.Name == "Baseplate") then
			child:Destroy()
		end
	end
end

-- Suelo, colinas lejanas y cipreses alrededor del Foro.
local function buildLand(parent: Instance)
	local ground = part(
		parent,
		"Ground",
		Vector3.new(2048, 4, 2048),
		CFrame.new(0, -2, -100),
		Color3.fromRGB(132, 116, 78),
		Enum.Material.Ground
	)
	ground.CastShadow = false

	local random = Random.new(753)
	-- Colinas en el horizonte (solo decorado).
	for index = 0, 13 do
		local angle = index / 14 * 2 * math.pi + random:NextNumber(-0.1, 0.1)
		local distance = random:NextNumber(520, 700)
		local width = random:NextNumber(180, 320)
		local height = random:NextNumber(40, 95)
		local position = Vector3.new(
			math.cos(angle) * distance,
			height / 2 - 6,
			-100 + math.sin(angle) * distance
		)
		local hill = part(
			parent,
			"Hill",
			Vector3.new(width, height, width * 0.6),
			CFrame.lookAt(position, Vector3.new(0, position.Y, -100))
				* CFrame.Angles(math.rad(-12), 0, 0),
			Color3.fromRGB(110, 118, 72):Lerp(Color3.fromRGB(150, 130, 92), random:NextNumber()),
			Enum.Material.Grass
		)
		hill.CanCollide = false
		hill.CastShadow = false
	end

	-- Cipreses: tronco y copa alargada.
	local function cypress(position: Vector3, scale: number)
		local trunk = part(
			parent,
			"CypressTrunk",
			Vector3.new(0.8, 3, 0.8) * scale,
			CFrame.new(position + Vector3.new(0, 1.5 * scale, 0)),
			Color3.fromRGB(90, 66, 44),
			Enum.Material.Wood
		)
		trunk.CastShadow = false
		local crown = cylinder(
			parent,
			"CypressCrown",
			1.7 * scale,
			12 * scale,
			position + Vector3.new(0, 8.5 * scale, 0),
			Color3.fromRGB(46, 72, 44),
			Enum.Material.Grass
		)
		crown.CastShadow = false
		crown.CanCollide = false
	end
	for index = 0, 27 do
		local angle = index / 28 * 2 * math.pi
		local distance = PLAZA_RADIUS + 18 + random:NextNumber(0, 14)
		local position = PLAZA_CENTER + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
		-- Sin árboles sobre la calzada hacia el coliseo.
		if math.abs(position.X) > 12 or position.Z > PLAZA_CENTER.Z then
			cypress(position, random:NextNumber(0.9, 1.3))
		end
	end
	-- A los lados de la calzada.
	for z = PLAZA_CENTER.Z - PLAZA_RADIUS - 14, -100, -22 do
		for _, side in { -1, 1 } do
			cypress(Vector3.new(side * 16, 0, z), 1.1)
		end
	end
end

-- Punto de aparición propio en el Foro: invisible y sin escudo de fuerza.
local function buildSpawn(parent: Instance)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ForumSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.5, 14)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = parent
end

function LobbyService.Init(_self: typeof(LobbyService))
	removeTemplate()
	local model = Instance.new("Model")
	model.Name = "Foro"
	buildLand(model)
	buildPlaza(model)
	buildSpawn(model)
	model.Parent = Workspace
	setupLighting()
end

return LobbyService
