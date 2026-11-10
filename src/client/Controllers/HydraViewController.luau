--!strict
-- Dibuja en el cliente los cuellos de la Hidra: una cadena de esferas que une el cuerpo
-- con cada cabeza siguiendo una curva. Es solo visual; las cabezas (y sus golpes) las
-- controla el servidor.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HEAD_TAG = "HydraHead"
local SEGMENTS = 9
local NECK_COLOR = Color3.fromRGB(40, 85, 55)

local HydraViewController = {}

local necks: { [BasePart]: { Part } } = {}

local function createNeck(): { Part }
	local segments = {}
	for index = 1, SEGMENTS do
		local segment = Instance.new("Part")
		segment.Name = "HydraNeck"
		segment.Shape = Enum.PartType.Ball
		-- Más grueso junto al cuerpo, más fino junto a la cabeza.
		local size = 4.6 - 1.4 * (index / SEGMENTS)
		segment.Size = Vector3.new(size, size, size)
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false
		segment.Color = NECK_COLOR
		segment.Material = Enum.Material.Slate
		segment.Parent = Workspace
		table.insert(segments, segment)
	end
	return segments
end

local function update()
	for _, head in CollectionService:GetTagged(HEAD_TAG) do
		if head:IsA("BasePart") and head:IsDescendantOf(Workspace) then
			local segments = necks[head]
			if segments == nil then
				segments = createNeck()
				necks[head] = segments
			end

			local base = head:GetAttribute("NeckBase")
			local visible = head.Transparency < 1 and typeof(base) == "Vector3"
			if visible then
				local p0 = base :: Vector3
				local p2 = head.Position
				-- Punto de control elevado: el cuello se arquea como el de una serpiente.
				local p1 = (p0 + p2) / 2 + Vector3.new(0, 7, 0)
				for index, segment in segments do
					local t = index / (SEGMENTS + 1)
					local a = p0:Lerp(p1, t)
					local b = p1:Lerp(p2, t)
					segment.Position = a:Lerp(b, t)
					segment.Transparency = 0
				end
			else
				for _, segment in segments do
					segment.Transparency = 1
				end
			end
		end
	end

	-- Limpia los cuellos de cabezas que ya no existen.
	for head, segments in necks do
		if not head:IsDescendantOf(Workspace) then
			for _, segment in segments do
				segment:Destroy()
			end
			necks[head] = nil
		end
	end
end

function HydraViewController.Start(_self: typeof(HydraViewController))
	RunService.RenderStepped:Connect(update)
end

return HydraViewController
