--[[
	Sun (ModuleScript)

	A giant blazing sun low on the horizon ahead of the glider. It is a glowing
	core with layered flaring halos, kept a fixed distance from the camera so
	it hangs in the sky and is never reached.

	It reacts to engine heat: as heat:GetFraction() rises the sun swells,
	turns from yellow-white to angry red, the halos flare, and the screen
	glare and warm tint grow. From Config.Heat.CriticalFraction it throbs.

	The real Roblox sun is lined up with it (Lighting time and latitude are
	picked so the light comes from the same direction), so shadows and sun
	rays match. The default sun disc is hidden.
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.FlightConfig)

local FORWARD = Vector3.new(0, 0, -1)

local function smoothing(responsiveness: number, dt: number): number
	return 1 - math.exp(-responsiveness * dt)
end

-- Find a Lighting time and latitude whose sun direction is closest to target.
local function alignLightingSun(target: Vector3)
	local bestClock, bestLatitude, bestDot = Lighting.ClockTime, Lighting.GeographicLatitude, -math.huge
	for latitude = -80, 80, 4 do
		Lighting.GeographicLatitude = latitude
		for clock = 4, 20, 0.1 do
			Lighting.ClockTime = clock
			local dot = Lighting:GetSunDirection():Dot(target)
			if dot > bestDot then
				bestClock, bestLatitude, bestDot = clock, latitude, dot
			end
		end
	end
	Lighting.GeographicLatitude = bestLatitude
	Lighting.ClockTime = bestClock
	return Lighting:GetSunDirection()
end

local function findOrCreate(className: string, name: string): Instance
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = Lighting
	return instance
end

local function makeBall(name: string, size: number, color: Color3, transparency: number, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * size
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local Sun = {}
Sun.__index = Sun

function Sun.new()
	local self = setmetatable({}, Sun)
	local s = Config.Sun
	self.Settings = s
	self._heat = 0
	self._time = 0

	-- Direction to the sun: straight ahead, raised by Elevation degrees.
	local elevation = math.rad(s.Elevation)
	local wanted = (FORWARD * math.cos(elevation) + Vector3.yAxis * math.sin(elevation)).Unit
	local actual = alignLightingSun(wanted)
	-- Keep the visible sun exactly ahead; use the real light only if it is close.
	self.Direction = if actual:Dot(wanted) > 0.98 then actual else wanted

	-- Sky: hide the default sun disc so only ours shows.
	local sky = findOrCreate("Sky", "RaceTheSunSky") :: Sky
	sky.CelestialBodiesShown = false

	self._bloom = findOrCreate("BloomEffect", "RaceTheSunBloom") :: BloomEffect
	self._rays = findOrCreate("SunRaysEffect", "RaceTheSunRays") :: SunRaysEffect
	self._tint = Instance.new("ColorCorrectionEffect")
	self._tint.Name = "RaceTheSunHeatTint"
	self._tint.Parent = Lighting
	self._atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") :: Atmosphere?
	self._atmosphereColor = if self._atmosphere then self._atmosphere.Color else nil
	self._bloom.Threshold = 0.9
	self._bloom.Size = 40

	-- The sun itself: a core and layered halos.
	self.Model = Instance.new("Model")
	self.Model.Name = "Sun"
	self._core = makeBall("Core", s.Size, s.CoolColor, 0, self.Model)
	self._halos = {}
	for i, halo in s.Halos do
		local part = makeBall("Halo" .. i, s.Size * halo.Scale, s.CoolColor, halo.Transparency, self.Model)
		table.insert(self._halos, { Part = part, Scale = halo.Scale, Transparency = halo.Transparency, Phase = i * 1.7 })
	end
	self.Model.Parent = Workspace

	self:Update(0, 0)
	return self
end

-- Call every frame after the camera has moved. heatFraction is 0..1.
function Sun:Update(dt: number, heatFraction: number)
	local s = self.Settings
	self._time += dt
	self._heat += (heatFraction - self._heat) * smoothing(s.HeatResponsiveness, dt)
	local heat = self._heat
	local t = self._time

	-- Throb when the engine is critical.
	local throb = 0
	if heatFraction >= Config.Heat.CriticalFraction then
		throb = (math.sin(t * s.CriticalPulseSpeed) + 1) / 2
	end

	local color = s.CoolColor:Lerp(s.HotColor, heat)
	local scale = 1 + s.HotGrowth * heat + s.CriticalPulseGrowth * throb

	local camera = Workspace.CurrentCamera
	local center = (if camera then camera.CFrame.Position else Vector3.zero) + self.Direction * s.Distance

	self._core.Size = Vector3.one * s.Size * scale
	self._core.Color = color
	self._core.Position = center

	-- Halos boil gently and flare brighter as heat rises.
	for _, halo in self._halos do
		local boil = 1 + math.sin(t * s.BoilSpeed + halo.Phase) * s.BoilAmount
		halo.Part.Size = Vector3.one * s.Size * halo.Scale * scale * (1 + s.HotHaloGrowth * heat) * boil
		halo.Part.Transparency = halo.Transparency - (s.HotHaloBrighten * heat + 0.05 * throb)
		halo.Part.Color = color
		halo.Part.Position = center
	end

	-- Screen effects: glare, sun rays and a warm tint that build with heat.
	self._bloom.Intensity = s.BloomIntensity[1] + (s.BloomIntensity[2] - s.BloomIntensity[1]) * heat + 0.3 * throb
	self._rays.Intensity = s.RaysIntensity[1] + (s.RaysIntensity[2] - s.RaysIntensity[1]) * heat
	self._rays.Spread = 0.6 + 0.3 * heat
	self._tint.TintColor = Color3.new(1, 1, 1):Lerp(s.HotTint, heat)
	self._tint.Brightness = s.HotBrightness * heat
	if self._atmosphere then
		self._atmosphere.Glare = s.Glare[1] + (s.Glare[2] - s.Glare[1]) * heat
		self._atmosphere.Haze = s.Haze[1] + (s.Haze[2] - s.Haze[1]) * heat
		self._atmosphere.Color = self._atmosphereColor:Lerp(s.HotTint, heat)
	end
end

function Sun:Destroy()
	self.Model:Destroy()
	self._tint:Destroy()
end

return Sun
