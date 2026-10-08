--[[
	Heat (ModuleScript)

	The engine overheat mechanic. Heat builds steadily while the glider is
	in open sun (faster as the run speeds up) and drains while it is cooling:
	  Shade: anything solid directly overhead, such as an arch roof
	  Rain:  inside a rain cloud's zone (an invisible part with the
	         attribute Cooling = "Rain")
	Reaching Config.Heat.Max ends the run with glider:End("Overheat").

	Read heat.Value, heat:GetFraction() (0..1) and heat.CoolingSource
	("Shade", "Rain" or nil) for the HUD.
]]

local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.FlightConfig)

local Heat = {}
Heat.__index = Heat

-- coolingZones: folder holding rain zones and other non-solid effects.
function Heat.new(glider, coolingZones: Instance)
	local self = setmetatable({}, Heat)
	self.Glider = glider
	self.Settings = Config.Heat

	self._shadeParams = RaycastParams.new()
	self._shadeParams.FilterType = Enum.RaycastFilterType.Exclude
	self._shadeParams.FilterDescendantsInstances = { glider.Model, coolingZones }

	self._zoneParams = OverlapParams.new()
	self._zoneParams.FilterType = Enum.RaycastFilterType.Include
	self._zoneParams.FilterDescendantsInstances = { coolingZones }

	self:Reset()
	return self
end

function Heat:Reset()
	self.Value = 0
	self.CoolingSource = nil
end

function Heat:GetFraction(): number
	return self.Value / self.Settings.Max
end

function Heat:_findCooling(): string?
	local position: Vector3 = self.Glider.Position

	for _, part in Workspace:GetPartBoundsInRadius(position, 2, self._zoneParams) do
		if part:GetAttribute("Cooling") == "Rain" then
			return "Rain"
		end
	end

	local overhead = Workspace:Raycast(position, Vector3.new(0, self.Settings.ShadeCheckHeight, 0), self._shadeParams)
	if overhead then
		return "Shade"
	end

	return nil
end

function Heat:Update(dt: number)
	local glider = self.Glider
	if not glider.Alive then
		return
	end
	local s = self.Settings

	self.CoolingSource = self:_findCooling()
	if self.CoolingSource == "Rain" then
		self.Value -= s.RainCoolPerSecond * dt
	elseif self.CoolingSource == "Shade" then
		self.Value -= s.ShadeCoolPerSecond * dt
	else
		local rate = s.HeatPerSecond
		if s.ScaleWithSpeed then
			rate *= glider:GetSpeedRatio()
		end
		self.Value += rate * dt
	end
	self.Value = math.clamp(self.Value, 0, s.Max)

	if self.Value >= s.Max then
		glider:End("Overheat")
	end
end

return Heat
