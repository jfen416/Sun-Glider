--[[
	TestTrack (ModuleScript)

	Placeholder world so flight can be playtested right away. It builds an
	endless flat plain of 512-stud chunks around the glider and deletes
	chunks left behind. Each chunk gets:
	  - random blocks to dodge
	  - shaded arches (long roofs on two pillars) to fly under and cool off
	  - sometimes a rain cloud whose rain cools the engine
	Chunks are seeded by their grid position, so the same seed always gives
	the same layout.

	Rain clouds and their cooling zones live in track.CoolingZones, a
	separate folder that the glider ignores for collisions and that Heat
	checks for rain.

	Built on the client on purpose: Race the Sun is single-player, so the
	world never needs to replicate, and it avoids StreamingEnabled hiding
	parts far from the (absent) character. The real procedural obstacle
	generator can replace this module with the same new/Update/Destroy shape.
]]

local Workspace = game:GetService("Workspace")

local OBSTACLE_COLORS = {
	Color3.fromRGB(235, 235, 240),
	Color3.fromRGB(190, 192, 200),
	Color3.fromRGB(120, 124, 135),
	Color3.fromRGB(70, 72, 82),
	Color3.fromRGB(255, 120, 60),
}
local ARCH_COLOR = Color3.fromRGB(60, 72, 96)
local ARCH_TRIM_COLOR = Color3.fromRGB(90, 190, 255)
local CLOUD_COLOR = Color3.fromRGB(120, 128, 140)
local RAIN_COLOR = Color3.fromRGB(170, 210, 255)

local function chunkKey(cx: number, cz: number): string
	return cx .. "," .. cz
end

local function rangeNumber(rng: Random, range: { number }): number
	return rng:NextNumber(range[1], range[2])
end

local TestTrack = {}
TestTrack.__index = TestTrack

function TestTrack.new(settings)
	local self = setmetatable({}, TestTrack)
	self.Settings = settings
	self.Folder = Instance.new("Folder")
	self.Folder.Name = "TestTrack"
	self.Folder.Parent = Workspace
	self.CoolingZones = Instance.new("Folder")
	self.CoolingZones.Name = "CoolingZones"
	self.CoolingZones.Parent = self.Folder
	self._chunks = {} -- key -> { Folder, Zones }
	self._centerKey = nil
	return self
end

local function makeBlock(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Non-solid decoration/zone part: never collides or blocks the glider.
local function makeEffectPart(parent: Instance, size: Vector3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Parent = parent
	return part
end

-- Two pillars and a long roof running along the flight direction (-Z).
function TestTrack:_buildArch(parent: Instance, rng: Random, x: number, z: number): { Vector3 }
	local s = self.Settings
	local groundY = s.Origin.Y
	local width = rangeNumber(rng, s.ArchWidth)
	local length = rangeNumber(rng, s.ArchLength)
	local clearance = s.ArchClearance
	local pillarWidth = 6
	local roofThickness = 5

	for _, side in { -1, 1 } do
		local pillarX = x + side * (width / 2 + pillarWidth / 2)
		makeBlock(
			parent,
			Vector3.new(pillarWidth, clearance + roofThickness, length),
			CFrame.new(pillarX, groundY + (clearance + roofThickness) / 2, z),
			ARCH_COLOR
		)
	end

	local roofWidth = width + pillarWidth * 2
	makeBlock(
		parent,
		Vector3.new(roofWidth, roofThickness, length),
		CFrame.new(x, groundY + clearance + roofThickness / 2, z),
		ARCH_COLOR
	)
	-- Glowing trim on the entrance so arches read as "cool zone" from afar.
	makeBlock(
		parent,
		Vector3.new(roofWidth, 1, 1),
		CFrame.new(x, groundY + clearance - 0.5, z + length / 2 - 0.5),
		ARCH_TRIM_COLOR,
		Enum.Material.Neon
	)

	-- Footprint (with margin) so random blocks don't spawn inside the arch.
	return { Vector3.new(x, 0, z), Vector3.new(roofWidth / 2 + 12, 0, length / 2 + 40) }
end

-- A puffy cloud with rain falling from it, plus an invisible cooling zone underneath.
function TestTrack:_buildRainCloud(zones: { Instance }, rng: Random, x: number, z: number)
	local s = self.Settings
	local groundY = s.Origin.Y
	local minSize: Vector3, maxSize: Vector3 = s.RainCloudSize[1], s.RainCloudSize[2]
	local sizeX = rng:NextNumber(minSize.X, maxSize.X)
	local sizeZ = rng:NextNumber(minSize.Z, maxSize.Z)
	local baseY = groundY + s.RainCloudHeight

	-- Cooling zone: from the ground up to the cloud base.
	local zone = makeEffectPart(
		self.CoolingZones,
		Vector3.new(sizeX, s.RainCloudHeight, sizeZ),
		CFrame.new(x, groundY + s.RainCloudHeight / 2, z)
	)
	zone.Name = "RainZone"
	zone.Transparency = 1
	zone:SetAttribute("Cooling", "Rain")
	table.insert(zones, zone)

	-- Rain: a flat emitter at the cloud base.
	local rainSource = makeEffectPart(self.CoolingZones, Vector3.new(sizeX, 1, sizeZ), CFrame.new(x, baseY, z))
	rainSource.Name = "RainSource"
	rainSource.Transparency = 1
	rainSource.CanQuery = false
	local rain = Instance.new("ParticleEmitter")
	rain.Shape = Enum.ParticleEmitterShape.Box
	rain.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Speed = NumberRange.new(90, 110)
	rain.Lifetime = NumberRange.new(s.RainCloudHeight / 100)
	rain.Rate = math.min(math.floor(sizeX * sizeZ / 40), 400)
	rain.Size = NumberSequence.new(0.35)
	rain.Color = ColorSequence.new(RAIN_COLOR)
	rain.Transparency = NumberSequence.new(0.2)
	rain.LightEmission = 0.3
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.Parent = rainSource
	table.insert(zones, rainSource)

	-- Cloud: overlapping grey balls (they cast a shadow that marks the rain area).
	local puffs = math.floor(sizeX * sizeZ / 2500) + 4
	for _ = 1, puffs do
		local diameter = rng:NextNumber(30, 55)
		local puff = makeEffectPart(
			self.CoolingZones,
			Vector3.one * diameter,
			CFrame.new(
				x + rng:NextNumber(-sizeX / 2, sizeX / 2),
				baseY + diameter * 0.35 + rng:NextNumber(0, 8),
				z + rng:NextNumber(-sizeZ / 2, sizeZ / 2)
			)
		)
		puff.Name = "CloudPuff"
		puff.Shape = Enum.PartType.Ball
		puff.Color = CLOUD_COLOR
		puff.Material = Enum.Material.SmoothPlastic
		puff.Transparency = 0.1
		puff.CastShadow = true
		puff.CanQuery = false
		table.insert(zones, puff)
	end
end

local function insideAny(footprints: { { Vector3 } }, x: number, z: number, pad: number): boolean
	for _, footprint in footprints do
		local center, half = footprint[1], footprint[2]
		if math.abs(x - center.X) < half.X + pad and math.abs(z - center.Z) < half.Z + pad then
			return true
		end
	end
	return false
end

function TestTrack:_buildChunk(cx: number, cz: number)
	local s = self.Settings
	local size = s.ChunkSize
	local origin: Vector3 = s.Origin
	local minX = origin.X + cx * size
	local minZ = origin.Z + cz * size

	local chunk = Instance.new("Folder")
	chunk.Name = chunkKey(cx, cz)
	local zones = {}

	makeBlock(
		chunk,
		Vector3.new(size, s.GroundThickness, size),
		CFrame.new(minX + size / 2, origin.Y - s.GroundThickness / 2, minZ + size / 2),
		if (cx + cz) % 2 == 0 then s.GroundColorA else s.GroundColorB
	)

	local rng = Random.new(s.Seed + cx * 73856093 + cz * 19349663)
	local function nearStart(x: number, z: number): boolean
		return z - origin.Z > -s.StartClearDistance and math.abs(x - origin.X) < s.StartClearDistance
	end

	-- Arches first, so blocks can avoid them.
	local footprints = {}
	for _ = 1, rng:NextInteger(s.ArchesPerChunk[1], s.ArchesPerChunk[2]) do
		local x = minX + rng:NextNumber(60, size - 60)
		local z = minZ + rng:NextNumber(100, size - 100)
		if not nearStart(x, z) and not insideAny(footprints, x, z, 40) then
			table.insert(footprints, self:_buildArch(chunk, rng, x, z))
		end
	end

	if rng:NextNumber() < s.RainCloudChance then
		local x = minX + rng:NextNumber(0, size)
		local z = minZ + rng:NextNumber(0, size)
		if not nearStart(x, z) then
			self:_buildRainCloud(zones, rng, x, z)
		end
	end

	local minSize: Vector3 = s.ObstacleMinSize
	local maxSize: Vector3 = s.ObstacleMaxSize
	for _ = 1, s.ObstaclesPerChunk do
		local blockSize = Vector3.new(
			rng:NextNumber(minSize.X, maxSize.X),
			rng:NextNumber(minSize.Y, maxSize.Y),
			rng:NextNumber(minSize.Z, maxSize.Z)
		)
		local x = minX + rng:NextNumber(0, size)
		local z = minZ + rng:NextNumber(0, size)
		local color = OBSTACLE_COLORS[rng:NextInteger(1, #OBSTACLE_COLORS)]

		local blocked = nearStart(x, z) or insideAny(footprints, x, z, math.max(blockSize.X, blockSize.Z) / 2)
		if not blocked then
			makeBlock(chunk, blockSize, CFrame.new(x, origin.Y + blockSize.Y / 2, z), color)
		end
	end

	chunk.Parent = self.Folder
	return { Folder = chunk, Zones = zones }
end

-- Call every frame with the glider position; only does work when it enters a new chunk.
function TestTrack:Update(position: Vector3)
	local s = self.Settings
	local relative = position - s.Origin
	local cx = math.floor(relative.X / s.ChunkSize)
	local cz = math.floor(relative.Z / s.ChunkSize)
	local centerKey = chunkKey(cx, cz)
	if centerKey == self._centerKey then
		return
	end
	self._centerKey = centerKey

	local wanted = {}
	for x = cx - s.ChunksSide, cx + s.ChunksSide do
		-- Forward is -Z, so "ahead" means lower chunk indices.
		for z = cz - s.ChunksAhead, cz + s.ChunksBehind do
			local key = chunkKey(x, z)
			wanted[key] = true
			if not self._chunks[key] then
				self._chunks[key] = self:_buildChunk(x, z)
			end
		end
	end

	for key, chunk in self._chunks do
		if not wanted[key] then
			chunk.Folder:Destroy()
			for _, zone in chunk.Zones do
				zone:Destroy()
			end
			self._chunks[key] = nil
		end
	end
end

function TestTrack:Destroy()
	self.Folder:Destroy()
	table.clear(self._chunks)
end

return TestTrack
