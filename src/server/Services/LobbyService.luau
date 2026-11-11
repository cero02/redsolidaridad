--!strict
-- El Foro: la plaza donde aparecen los gladiadores. Suelo de mármol, columnata,
-- estandartes, la arena de entrenamiento (ludus) y la calzada hacia el Gran Coliseo.
-- También fija la iluminación de atardecer del mundo. Todo generado por código: cuando
-- haya escenario de artistas, este servicio se retira.

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

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
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

local function cylinder(parent: Instance, name: string, radius: number, height: number, position: Vector3, color: Color3, material: Enum.Material): Part
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
	cylinder(parent, "ColumnBase", 1.9, 1, base + Vector3.new(0, 0.5, 0), MARBLE_DARK, Enum.Material.Marble)
	local shaft = cylinder(parent, "Column", 1.4, COLUMN_HEIGHT, base + Vector3.new(0, 1 + COLUMN_HEIGHT / 2, 0), MARBLE, Enum.Material.Marble)
	shaft.CastShadow = true
	part(parent, "Capital", Vector3.new(4, 1.2, 4), CFrame.new(base + Vector3.new(0, COLUMN_HEIGHT + 1.6, 0)), MARBLE_DARK, Enum.Material.Marble)
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
		part(parent, "BannerTrim", Vector3.new(3.1, 0.5, 0.25), banner.CFrame * CFrame.new(0, -4.3, 0), GOLD, Enum.Material.Metal).CanCollide =
			false
		part(parent, "BannerEagle", Vector3.new(1.4, 1.4, 0.25), banner.CFrame * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(45)), GOLD, Enum.Material.Metal).CanCollide =
			false
	end
end

local function buildPlaza(parent: Instance)
	-- Suelo de mármol con un anillo de piedra y el ludus de arena para entrenar.
	cylinder(parent, "PlazaFloor", PLAZA_RADIUS + 4, 0.4, PLAZA_CENTER + Vector3.new(0, 0.2, 0), MARBLE, Enum.Material.Marble)
	cylinder(parent, "PlazaRing", PLAZA_RADIUS - 6, 0.42, PLAZA_CENTER + Vector3.new(0, 0.21, 0), MARBLE_DARK, Enum.Material.Marble)
	cylinder(parent, "PlazaInner", PLAZA_RADIUS - 8, 0.44, PLAZA_CENTER + Vector3.new(0, 0.22, 0), MARBLE, Enum.Material.Marble)
	cylinder(parent, "Ludus", 12, 0.46, Vector3.new(0, 0.23, -20), SAND, Enum.Material.Sand)

	for index = 0, COLUMN_COUNT - 1 do
		local angle = index / COLUMN_COUNT * 2 * math.pi
		if not inGap(angle) then
			local base = PLAZA_CENTER + Vector3.new(math.cos(angle), 0, math.sin(angle)) * PLAZA_RADIUS
			buildColumn(parent, base + Vector3.new(0, 0.4, 0), index % 3 == 0)
		end
	end

	-- Calzada hacia el Gran Coliseo, con antorchas a los lados.
	local roadStart = PLAZA_CENTER.Z - PLAZA_RADIUS
	-- El muro exterior del coliseo está a unos 88 studs de su centro (z = −200).
	local roadEnd = -110
	local roadLength = roadStart - roadEnd
	part(parent, "Road", Vector3.new(12, 0.4, roadLength), CFrame.new(0, 0.2, (roadStart + roadEnd) / 2), STONE, Enum.Material.Cobblestone)
	for z = roadStart - 8, roadEnd + 4, -16 do
		for _, side in { -1, 1 } do
			local post = part(parent, "TorchPost", Vector3.new(0.8, 6, 0.8), CFrame.new(side * 8, 3, z), Color3.fromRGB(80, 60, 40), Enum.Material.Wood)
			local bowl = part(parent, "TorchBowl", Vector3.new(1.6, 0.6, 1.6), post.CFrame * CFrame.new(0, 3.3, 0), Color3.fromRGB(60, 45, 35), Enum.Material.Metal)
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

function LobbyService.Init(_self: typeof(LobbyService))
	local model = Instance.new("Model")
	model.Name = "Foro"
	buildPlaza(model)
	model.Parent = Workspace
	setupLighting()
end

return LobbyService
