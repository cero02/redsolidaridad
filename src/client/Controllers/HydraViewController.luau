--!strict
-- Dibuja en el cliente los cuellos de la Hidra: una cadena de esferas que une el cuerpo
-- con cada cabeza siguiendo una curva. Escamas negras por detrás y garganta color hueso
-- por delante (estilo de la referencia oficial). Solo visual: las cabezas y sus golpes
-- los controla el servidor.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HEAD_TAG = "HydraHead"
local SEGMENTS = 10
local WOBBLE = 0.9
local SCALES = Color3.fromRGB(46, 46, 52)
local THROAT = Color3.fromRGB(196, 180, 150)
local GOLD = Color3.fromRGB(230, 180, 60)

type Neck = { scales: { Part }, throat: { Part } }

local HydraViewController = {}

local necks: { [BasePart]: Neck } = {}

local function ball(size: number, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = "HydraNeck"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = color
	part.Material = Enum.Material.Slate
	part.Parent = Workspace
	return part
end

local function createNeck(golden: boolean): Neck
	local neck: Neck = { scales = {}, throat = {} }
	for index = 1, SEGMENTS do
		-- Más grueso junto al cuerpo, más fino junto a la cabeza.
		local size = 5.2 - 1.8 * (index / SEGMENTS)
		table.insert(neck.scales, ball(size, if golden then GOLD else SCALES))
		table.insert(neck.throat, ball(size * 0.82, if golden then GOLD:Lerp(THROAT, 0.5) else THROAT))
	end
	return neck
end

local function setVisible(neck: Neck, visible: boolean)
	local transparency = if visible then 0 else 1
	for index = 1, SEGMENTS do
		neck.scales[index].Transparency = transparency
		neck.throat[index].Transparency = transparency
	end
end

local function update()
	local time = os.clock()
	for _, head in CollectionService:GetTagged(HEAD_TAG) do
		if head:IsA("BasePart") and head:IsDescendantOf(Workspace) then
			local neck = necks[head]
			if neck == nil then
				neck = createNeck(head.Parent ~= nil and head.Parent.Name == "ImmortalHead")
				necks[head] = neck
			end

			local base = head:GetAttribute("NeckBase")
			local visible = head:GetAttribute("Alive") == true and typeof(base) == "Vector3"
			setVisible(neck, visible)
			if visible then
				local p0 = base :: Vector3
				local p2 = head.Position
				-- Punto de control elevado: el cuello se arquea como el de una serpiente.
				local p1 = (p0 + p2) / 2 + Vector3.new(0, 7, 0)
				-- La garganta mira hacia donde mira la cabeza.
				local look = head.CFrame.LookVector
				local front = Vector3.new(look.X, 0, look.Z)
				front = if front.Magnitude > 0.01 then front.Unit else Vector3.zAxis
				local phase = p0.X * 0.37 + p0.Z * 0.21
				for index = 1, SEGMENTS do
					local t = index / (SEGMENTS + 1)
					local a = p0:Lerp(p1, t)
					local b = p1:Lerp(p2, t)
					-- Ondulación: cada cuello se mece a su ritmo; nula en los extremos.
					local sway = math.sin(math.pi * t) * WOBBLE
					local offset = Vector3.new(
						math.sin(time * 1.7 + index * 0.6 + phase),
						math.cos(time * 1.3 + index * 0.5 + phase) * 0.5,
						math.cos(time * 1.5 + index * 0.7 + phase)
					) * sway
					local position = a:Lerp(b, t) + offset
					local scales = neck.scales[index]
					scales.Position = position
					neck.throat[index].Position = position + front * scales.Size.X * 0.22
				end
			end
		end
	end

	-- Limpia los cuellos de cabezas que ya no existen.
	for head, neck in necks do
		if not head:IsDescendantOf(Workspace) then
			for index = 1, SEGMENTS do
				neck.scales[index]:Destroy()
				neck.throat[index]:Destroy()
			end
			necks[head] = nil
		end
	end
end

function HydraViewController.Start(_self: typeof(HydraViewController))
	RunService.RenderStepped:Connect(update)
end

return HydraViewController
