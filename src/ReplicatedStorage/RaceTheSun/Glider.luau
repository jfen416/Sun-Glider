--[[
	Glider (ModuleScript)

	The flight model. The glider always moves forward (-Z) at a constant
	speed, slides sideways with smoothed steering, banks into turns and
	hovers a fixed height above whatever ground is below it. A box is swept
	along each frame's movement; hitting anything steeper than
	Config.CrashSlope ends the run.

	Forward speed ramps up with distance (Config.SpeedGainPer1000Studs).
	glider:Jump() launches it upward; gravity brings it back down, and it
	also falls under gravity when the ground drops away beneath it.

	Hooks for later systems:
	  glider.SpeedMultiplier   -- set > 1 for boosts or faster regions
	  glider:End("Overheat")   -- the Heat module calls this when the engine maxes out
	  glider.Ended             -- event, fires with the reason ("Crash", "Overheat", ...)
	  glider:AddIgnore(folder) -- make non-solid things (rain zones, clouds) invisible to collisions
	  glider.Stepped           -- event, fires with dt after every flight step
	  glider.Distance          -- studs travelled forward this run (for score)
	  glider.Position          -- current position (for obstacle streaming)
]]

local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.FlightConfig)
local ShipBuilder = require(script.Parent.ShipBuilder)

local FORWARD = Vector3.new(0, 0, -1)
local RIGHT = Vector3.new(1, 0, 0)
local MAX_STEP = 1 / 20 -- clamp long frames so a hitch can't tunnel through walls
local EXPLODING_ENDS = { Crash = true, Overheat = true }

local function smoothing(responsiveness: number, dt: number): number
	return 1 - math.exp(-responsiveness * dt)
end

local Glider = {}
Glider.__index = Glider

function Glider.new(startPosition: Vector3)
	local self = setmetatable({}, Glider)

	self.Model = ShipBuilder.build()
	self.Model.Parent = Workspace

	self.Speed = Config.ForwardSpeed

	self._endedEvent = Instance.new("BindableEvent")
	self.Ended = self._endedEvent.Event
	self._steppedEvent = Instance.new("BindableEvent")
	self.Stepped = self._steppedEvent.Event

	self._rayParams = RaycastParams.new()
	self._rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self._ignoreList = { self.Model }
	self._rayParams.FilterDescendantsInstances = self._ignoreList

	self:Reset(startPosition)
	return self
end

function Glider:Reset(startPosition: Vector3)
	self.Position = startPosition
	self.LateralVelocity = 0
	self.VerticalVelocity = 0
	self.Airborne = false
	self.Bank = 0
	self.Yaw = 0
	self.Pitch = 0
	self.Steer = 0 -- -1 (full left) .. 1 (full right), set by the client each frame
	self.SpeedMultiplier = 1
	self.Distance = 0
	self.Alive = true
	self.EndReason = nil

	self.Model.Parent = Workspace
	self:_render()
	for _, descendant in self.Model:GetDescendants() do
		if descendant:IsA("Trail") then
			descendant:Clear()
		end
	end
end

-- Collisions and ground-following skip everything inside this instance.
function Glider:AddIgnore(instance: Instance)
	table.insert(self._ignoreList, instance)
	self._rayParams.FilterDescendantsInstances = self._ignoreList
end

function Glider:GetSpeedRamp(): number
	return math.min(1 + self.Distance / 1000 * Config.SpeedGainPer1000Studs, Config.MaxSpeedRamp)
end

function Glider:GetForwardSpeed(): number
	return self.Speed * self:GetSpeedRamp() * self.SpeedMultiplier
end

-- Current speed as a multiple of the starting speed (1 = start of a run).
function Glider:GetSpeedRatio(): number
	return self:GetForwardSpeed() / Config.ForwardSpeed
end

-- Returns true if the jump happened (only possible while skimming the ground).
function Glider:Jump(): boolean
	if not (self.Alive and Config.JumpEnabled) or self.Airborne then
		return false
	end
	self.Airborne = true
	self.VerticalVelocity = Config.JumpVelocity
	return true
end

function Glider:GetCFrame(): CFrame
	return CFrame.new(self.Position) * CFrame.Angles(0, self.Yaw, 0) * CFrame.Angles(self.Pitch, 0, self.Bank)
end

function Glider:Step(dt: number)
	if not self.Alive then
		return
	end
	dt = math.min(dt, MAX_STEP)

	-- Steering: ease sideways speed toward the target. Letting go or reversing
	-- uses the faster release rate so the glider straightens out crisply.
	local steer = math.clamp(self.Steer, -1, 1)
	local targetLateral = steer * Config.MaxStrafeSpeed
	local releasing = math.abs(targetLateral) < math.abs(self.LateralVelocity)
		or targetLateral * self.LateralVelocity < 0
	local steerRate = if releasing then Config.SteerReleaseResponsiveness else Config.SteerResponsiveness
	self.LateralVelocity += (targetLateral - self.LateralVelocity) * smoothing(steerRate, dt)

	local forwardSpeed = self:GetForwardSpeed()
	local move = (FORWARD * forwardSpeed + RIGHT * self.LateralVelocity) * dt

	-- Collision: sweep the glider's box along this frame's movement.
	local hit = Workspace:Blockcast(CFrame.new(self.Position), Config.CollisionSize, move, self._rayParams)
	if hit and hit.Normal.Y < Config.CrashSlope then
		self.Position += move.Unit * hit.Distance
		self:_render()
		self:End("Crash")
		return
	end

	-- Altitude: hover above the ground, easing over bumps and slopes.
	local nextPosition = self.Position + move
	local currentY = self.Position.Y
	local probeOrigin = nextPosition + Vector3.new(0, Config.HoverHeight, 0)
	local ground = Workspace:Raycast(probeOrigin, Vector3.new(0, -Config.GroundProbeDepth, 0), self._rayParams)
	local targetY = if ground then ground.Position.Y + Config.HoverHeight else currentY

	local newY
	if self.Airborne or targetY < currentY - Config.FallThreshold then
		-- In the air (jumped, or the ground dropped away): gravity takes over until we land.
		self.Airborne = true
		self.VerticalVelocity -= Config.Gravity * dt
		newY = currentY + self.VerticalVelocity * dt
		if self.VerticalVelocity > 0 then
			-- Bonk on ceilings (e.g. jumping under an arch) instead of passing through.
			local halfHeight = Config.CollisionSize.Y / 2
			local ceiling = Workspace:Raycast(
				Vector3.new(nextPosition.X, currentY, nextPosition.Z),
				Vector3.new(0, newY - currentY + halfHeight, 0),
				self._rayParams
			)
			if ceiling then
				newY = math.min(newY, ceiling.Position.Y - halfHeight - 0.1)
				self.VerticalVelocity = 0
			end
		end
		if newY <= targetY then
			newY = targetY
			self.Airborne = false
			self.VerticalVelocity = 0
		end
	else
		newY = currentY + (targetY - currentY) * smoothing(Config.HeightResponsiveness, dt)
		self.VerticalVelocity = (newY - currentY) / dt
	end

	self.Position = Vector3.new(nextPosition.X, newY, nextPosition.Z)
	self.Distance += forwardSpeed * dt

	-- Visual attitude: bank and yaw into the turn, pitch with climbs.
	local lateralFraction = self.LateralVelocity / Config.MaxStrafeSpeed
	self.Bank = -lateralFraction * math.rad(Config.MaxBankAngle)
	self.Yaw = -lateralFraction * math.rad(Config.MaxYawAngle)
	local maxPitch = math.rad(Config.MaxPitchAngle)
	local targetPitch = math.clamp(math.atan2(self.VerticalVelocity, forwardSpeed), -maxPitch, maxPitch)
	self.Pitch += (targetPitch - self.Pitch) * smoothing(8, dt)

	self:_render()
	self._steppedEvent:Fire(dt)
end

function Glider:End(reason: string)
	if not self.Alive then
		return
	end
	self.Alive = false
	self.EndReason = reason

	if EXPLODING_ENDS[reason] then
		local explosion = Instance.new("Explosion")
		explosion.Position = self.Position
		explosion.BlastRadius = 8
		explosion.BlastPressure = 0
		explosion.DestroyJointRadiusPercent = 0
		explosion.Parent = Workspace
		self.Model.Parent = nil
	end

	self._endedEvent:Fire(reason)
end

function Glider:_render()
	self.Model:PivotTo(self:GetCFrame())
end

function Glider:Destroy()
	self.Model:Destroy()
	self._endedEvent:Destroy()
	self._steppedEvent:Destroy()
end

return Glider
