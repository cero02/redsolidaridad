--!strict
-- Coloca en cada personaje un gladius y un escudo hechos de bloques, y los cosméticos que
-- ha desbloqueado (pilar presumir: lo que has logrado se VE). Es solo visual (los golpes
-- los calcula CombatService) y provisional hasta tener modelos de artista.

local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)

local STEEL = Color3.fromRGB(200, 205, 210)
local GOLD = Color3.fromRGB(210, 165, 60)
local LEATHER = Color3.fromRGB(90, 60, 40)
local IMPERIAL_RED = Color3.fromRGB(150, 30, 30)
local BRONZE = Color3.fromRGB(176, 120, 60)
local CHAMPION_GOLD = Color3.fromRGB(230, 185, 70)
local RUDIS_WOOD = Color3.fromRGB(150, 105, 60)

local EquipmentService = {}

local function makePart(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function attach(part: Part, to: BasePart, offset: CFrame)
	part.CFrame = to.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = part
	weld.Parent = part
end

local function equip(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or character:FindFirstChild("Equipment") ~= nil then
		return
	end
	local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
	local hand = character:WaitForChild(if isR15 then "RightHand" else "Right Arm", 10)
	local shieldArm = character:WaitForChild(if isR15 then "LeftLowerArm" else "Left Arm", 10)
	if hand == nil or shieldArm == nil or not hand:IsA("BasePart") or not shieldArm:IsA("BasePart") then
		return
	end

	local equipment = Instance.new("Model")
	equipment.Name = "Equipment"
	equipment.Parent = character

	-- Gladius: apunta hacia delante con el brazo bajado y hacia arriba al levantarlo.
	local gripY = if isR15 then -0.15 else -0.9
	-- La empuñadura se une a la mano con un Weld (el cliente puede girarlo para animar
	-- la espada); la guarda y la hoja van soldadas a la empuñadura.
	local handle = makePart(equipment, "Handle", Vector3.new(0.25, 0.3, 0.9), LEATHER, Enum.Material.Wood)
	handle.CFrame = hand.CFrame * CFrame.new(0, gripY, -0.1)
	local grip = Instance.new("Weld")
	grip.Name = "GripWeld"
	grip.Part0 = hand
	grip.Part1 = handle
	grip.C0 = CFrame.new(0, gripY, -0.1)
	grip.Parent = handle
	local guard = makePart(equipment, "Guard", Vector3.new(1, 0.3, 0.2), GOLD, Enum.Material.Metal)
	attach(guard, handle, CFrame.new(0, 0, -0.5))
	local blade = makePart(equipment, "Blade", Vector3.new(0.18, 0.5, 3), STEEL, Enum.Material.Metal)
	attach(blade, handle, CFrame.new(0, 0, -2.1))

	-- Estela del tajo: el cliente la activa durante el golpe.
	local base = Instance.new("Attachment")
	base.Position = Vector3.new(0, 0, 1.4)
	base.Parent = blade
	local tip = Instance.new("Attachment")
	tip.Position = Vector3.new(0, 0, -1.5)
	tip.Parent = blade
	local trail = Instance.new("Trail")
	trail.Name = "SlashTrail"
	trail.Attachment0 = base
	trail.Attachment1 = tip
	trail.Lifetime = 0.18
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.LightEmission = 0.6
	trail.Enabled = false
	trail.Parent = blade

	-- Escudo en el antebrazo izquierdo, hacia fuera.
	local shield = makePart(equipment, "Shield", Vector3.new(0.25, 2.4, 2), IMPERIAL_RED, Enum.Material.Wood)
	attach(shield, shieldArm, CFrame.new(-0.7, 0, 0))
	local boss = makePart(equipment, "ShieldBoss", Vector3.new(0.7, 0.7, 0.7), GOLD, Enum.Material.Metal)
	boss.Shape = Enum.PartType.Ball
	attach(boss, shieldArm, CFrame.new(-0.85, 0, 0))
end

local function findPart(character: Model, names: { string }): BasePart?
	for _, name in names do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

-- Reconstruye los cosméticos del personaje según lo desbloqueado en el perfil.
local function applyCosmetics(player: Player)
	local character = player.Character
	local data = PlayerDataService.get(player)
	if character == nil or data == nil then
		return
	end
	local old = character:FindFirstChild("Cosmetics")
	if old then
		old:Destroy()
	end
	local owned = data.unlockedCosmetics
	local cosmetics = Instance.new("Model")
	cosmetics.Name = "Cosmetics"
	cosmetics.Parent = character

	local head = findPart(character, { "Head" })
	local torso = findPart(character, { "UpperTorso", "Torso" })
	local equipment = character:FindFirstChild("Equipment")
	local shield = if equipment then equipment:FindFirstChild("Shield") else nil
	local blade = if equipment then equipment:FindFirstChild("Blade") else nil

	if owned.ShieldEmblem and shield and shield:IsA("BasePart") then
		local emblem = makePart(cosmetics, "Emblem", Vector3.new(0.1, 1, 1), GOLD, Enum.Material.Neon)
		attach(emblem, shield, CFrame.new(-0.16, 0, 0) * CFrame.Angles(math.rad(45), 0, 0))
	end
	if head then
		local size = head.Size
		if owned.BronzeHelmet then
			local helmet =
				makePart(cosmetics, "Helmet", size * Vector3.new(1.18, 0.62, 1.18), BRONZE, Enum.Material.Metal)
			attach(helmet, head, CFrame.new(0, size.Y * 0.3, 0))
		end
		if owned.Plume then
			local plume =
				makePart(cosmetics, "Plume", Vector3.new(0.3, size.Y * 0.8, size.Z * 1.3), IMPERIAL_RED, Enum.Material.Fabric)
			attach(plume, head, CFrame.new(0, size.Y * 0.85, 0))
		end
	end
	if torso then
		local size = torso.Size
		if owned.RedCape then
			local cape = makePart(
				cosmetics,
				"Cape",
				Vector3.new(size.X * 0.95, size.Y * 1.7, 0.12),
				IMPERIAL_RED,
				Enum.Material.Fabric
			)
			attach(cape, torso, CFrame.new(0, -size.Y * 0.35, size.Z / 2 + 0.08))
		end
		if owned.ChampionArmor then
			local armor = makePart(
				cosmetics,
				"ChampionArmor",
				size * Vector3.new(1.08, 0.75, 1.12),
				CHAMPION_GOLD,
				Enum.Material.Metal
			)
			attach(armor, torso, CFrame.new(0, size.Y * 0.1, 0))
		end
	end
	if blade and blade:IsA("BasePart") then
		if owned.RudisSword then
			blade.Color = RUDIS_WOOD
			blade.Material = Enum.Material.Wood
		end
		if owned.EmberBlade and blade:FindFirstChild("Embers") == nil then
			local fire = Instance.new("Fire")
			fire.Name = "Embers"
			fire.Size = 2
			fire.Heat = 3
			fire.Color = Color3.fromRGB(255, 120, 40)
			fire.Parent = blade
		end
	end
end

local function onAppearanceLoaded(player: Player, character: Model)
	equip(character)
	applyCosmetics(player)
end

local function onPlayerAdded(player: Player)
	-- Tras cargar la apariencia: antes, Roblox aún puede sustituir las piezas del cuerpo.
	player.CharacterAppearanceLoaded:Connect(function(character: Model)
		onAppearanceLoaded(player, character)
	end)
	local character = player.Character
	if character and player:HasAppearanceLoaded() then
		task.spawn(onAppearanceLoaded, player, character)
	end
end

function EquipmentService.Start(_self: typeof(EquipmentService))
	ProgressionService.CosmeticsChanged:Connect(applyCosmetics)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return EquipmentService
