--[[
	Orbs (ModuleScript)

	Collectible currency orbs. Groups of glowing orbs (straight trails,
	S-curves, diagonals and small clusters) are placed ahead of the glider as
	it flies. Most are regular orbs; a rare few are larger special orbs worth
	more, and some of those float at jump height.

	Every run gets a fresh random layout (unseeded Random on Reset), separate
	from the track seed. Orbs that would overlap an obstacle are skipped.

	orbs.Collected fires with (kind, value, position) when the glider flies
	through one. Kinds and values live in Config.Orbs.Kinds.
]]

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.FlightConfig)

local GROUP_SHAPES = { "Line", "SCurve", "Diagonal", "Cluster" }
local POP_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local Orbs = {}
Orbs.__index = Orbs

-- ignore: instances that must not block orb placement (e.g. track.CoolingZones).
function Orbs.new(glider, ignore: { Instance })
	local self = setmetatable({}, Orbs)
	self.Glider = glider
	self.Settings = Config.Orbs

	self.Folder = Instance.new("Folder")
	self.Folder.Name = "Orbs"
	self.Folder.Parent = Workspace

	self._collectedEvent = Instance.new("BindableEvent")
	self.Collected = self._collectedEvent.Event

	local exclude = { self.Folder, glider.Model }
	for _, instance in ignore do
		table.insert(exclude, instance)
	end
	self._overlapParams = OverlapParams.new()
	self._overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	self._overlapParams.FilterDescendantsInstances = exclude

	self._active = {} -- { { Part, Light, Kind, Base, Phase } }
	self:Reset()
	return self
end

-- Clear all orbs and start a new random layout from the glider's position.
function Orbs:Reset()
	for _, orb in self._active do
		orb.Part:Destroy()
	end
	table.clear(self._active)

	local position: Vector3 = self.Glider.Position
	self._rng = Random.new()
	self._flyY = position.Y
	self._nextGroupZ = position.Z - self.Settings.FirstGroupDistance
	self._lastPosition = position
	self._time = 0
end

-- Offsets (X sideways, Z forward along -Z) for each orb in a group.
function Orbs:_groupOffsets(shape: string, count: number): { Vector3 }
	local rng = self._rng
	local spacing = self.Settings.OrbSpacing
	local offsets = {}

	if shape == "Line" then
		for i = 0, count - 1 do
			table.insert(offsets, Vector3.new(0, 0, -i * spacing))
		end
	elseif shape == "Diagonal" then
		local direction = if rng:NextNumber() < 0.5 then -1 else 1
		for i = 0, count - 1 do
			table.insert(offsets, Vector3.new(direction * i * spacing * 0.6, 0, -i * spacing))
		end
	elseif shape == "SCurve" then
		local amplitude = rng:NextNumber(20, 40)
		for i = 0, count - 1 do
			local t = i / math.max(count - 1, 1)
			table.insert(offsets, Vector3.new(math.sin(t * math.pi * 2) * amplitude, 0, -i * spacing))
		end
	else -- Cluster
		for _ = 1, math.min(count, 6) do
			table.insert(offsets, Vector3.new(rng:NextNumber(-15, 15), 0, rng:NextNumber(-30, 0)))
		end
	end

	return offsets
end

function Orbs:_spawnOrb(kind: string, position: Vector3)
	local info = self.Settings.Kinds[kind]
	local radius = info.Size / 2
	if #Workspace:GetPartBoundsInRadius(position, radius + 2, self._overlapParams) > 0 then
		return -- inside or touching an obstacle
	end

	local part = Instance.new("Part")
	part.Name = kind .. "Orb"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * info.Size
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = info.Color

	local light = Instance.new("PointLight")
	light.Color = info.Color
	light.Brightness = 2
	light.Range = info.Size * 3
	light.Parent = part

	part.Parent = self.Folder
	table.insert(self._active, {
		Part = part,
		Light = light,
		Kind = kind,
		Base = position,
		Phase = self._rng:NextNumber(0, math.pi * 2),
	})
end

-- Places one group starting at z; returns how far (in studs) the group reaches forward.
function Orbs:_spawnGroup(z: number): number
	local s = self.Settings
	local rng = self._rng
	local x = self.Glider.Position.X + rng:NextNumber(-s.GroupSideRange, s.GroupSideRange)
	local shape = GROUP_SHAPES[rng:NextInteger(1, #GROUP_SHAPES)]
	local count = rng:NextInteger(s.OrbsPerGroup[1], s.OrbsPerGroup[2])

	local length = 0
	for _, offset in self:_groupOffsets(shape, count) do
		local kind = if rng:NextNumber() < s.SpecialChance then "Special" else "Regular"
		local y = self._flyY
		if kind == "Special" and rng:NextNumber() < s.SpecialJumpChance then
			y += s.JumpHeight
		end
		self:_spawnOrb(kind, Vector3.new(x + offset.X, y, z + offset.Z))
		length = math.max(length, -offset.Z)
	end
	return length
end

function Orbs:_collect(index: number)
	local orb = table.remove(self._active, index)
	local value = self.Settings.Kinds[orb.Kind].Value

	-- Quick swell-and-fade pop.
	local part = orb.Part
	TweenService:Create(part, POP_INFO, { Size = part.Size * 2, Transparency = 1 }):Play()
	TweenService:Create(orb.Light, POP_INFO, { Brightness = 0 }):Play()
	task.delay(POP_INFO.Time + 0.05, function()
		part:Destroy()
	end)

	self._collectedEvent:Fire(orb.Kind, value, orb.Base)
end

local function distanceToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local segment = b - a
	local lengthSquared = segment:Dot(segment)
	if lengthSquared < 1e-6 then
		return (point - a).Magnitude
	end
	local t = math.clamp((point - a):Dot(segment) / lengthSquared, 0, 1)
	return (point - (a + segment * t)).Magnitude
end

-- Call every frame: places new groups ahead, collects, despawns and bobs orbs.
function Orbs:Update(dt: number)
	local s = self.Settings
	local glider = self.Glider
	local position: Vector3 = glider.Position
	self._time += dt

	while self._nextGroupZ > position.Z - s.SpawnAhead do
		local length = self:_spawnGroup(self._nextGroupZ)
		self._nextGroupZ -= length + self._rng:NextNumber(s.GroupSpacing[1], s.GroupSpacing[2])
	end

	-- Check against the whole path since last frame so fast frames can't skip orbs.
	local lastPosition = self._lastPosition
	self._lastPosition = position

	local active = self._active
	for i = #active, 1, -1 do
		local orb = active[i]
		if orb.Base.Z > position.Z + s.DespawnBehind then
			orb.Part:Destroy()
			table.remove(active, i)
		elseif glider.Alive and distanceToSegment(orb.Base, lastPosition, position) <= s.CollectRadius then
			self:_collect(i)
		else
			local bob = math.sin(self._time * s.BobSpeed + orb.Phase) * s.BobHeight
			orb.Part.Position = orb.Base + Vector3.new(0, bob, 0)
		end
	end
end

function Orbs:Destroy()
	self.Folder:Destroy()
	table.clear(self._active)
	self._collectedEvent:Destroy()
end

return Orbs
