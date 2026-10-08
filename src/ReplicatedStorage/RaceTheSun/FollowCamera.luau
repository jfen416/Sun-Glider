--[[
	FollowCamera (ModuleScript)

	Chase camera that sits behind and above the glider. Forward distance is
	locked so speed never stretches it; sideways and vertical motion lag a
	little so steering reads on screen. Rolls partly with the glider's bank
	and widens the FOV as the glider speeds up. Shake() adds a short
	decaying jolt (used on crashes).
]]

local Workspace = game:GetService("Workspace")

local FollowCamera = {}
FollowCamera.__index = FollowCamera

function FollowCamera.new(settings)
	local self = setmetatable({}, FollowCamera)
	self.Settings = settings
	self:Snap()
	return self
end

-- Jump straight to the target on the next update (use after a restart).
function FollowCamera:Snap()
	self._x = nil
	self._y = nil
	self._roll = 0
	self._shakeStrength = 0
	self._shakeTime = 0
	self._shakeDuration = 0
end

function FollowCamera:Shake(strength: number, duration: number)
	self._shakeStrength = strength
	self._shakeDuration = duration
	self._shakeTime = duration
end

-- Where the camera settles behind a glider that isn't steering: (position, look target).
-- The menu's fly-in swoops to this view.
function FollowCamera:GetRestView(glider): (Vector3, Vector3)
	local s = self.Settings
	local shipPosition: Vector3 = glider.Position
	return shipPosition + Vector3.new(0, s.Height, s.Distance), shipPosition + Vector3.new(0, s.LookHeight, -s.LookAhead)
end

function FollowCamera:Update(dt: number, glider)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	-- The default camera script can switch this back while loading, so keep enforcing it.
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	local s = self.Settings
	local shipPosition: Vector3 = glider.Position
	local targetY = shipPosition.Y + s.Height

	if self._x == nil then
		self._x = shipPosition.X
		self._y = targetY
		camera.FieldOfView = s.BaseFOV
	end

	local alpha = 1 - math.exp(-s.Responsiveness * dt)
	self._x += (shipPosition.X - self._x) * alpha
	self._y += (targetY - self._y) * alpha
	self._roll += (glider.Bank * s.RollFactor - self._roll) * alpha

	local cameraPosition = Vector3.new(self._x, self._y, shipPosition.Z + s.Distance)
	local lookTarget = shipPosition + Vector3.new(0, s.LookHeight, -s.LookAhead)
	if self._shakeTime > 0 then
		self._shakeTime = math.max(self._shakeTime - dt, 0)
		local amount = self._shakeStrength * (self._shakeTime / self._shakeDuration)
		cameraPosition += Vector3.new(
			(math.random() * 2 - 1) * amount,
			(math.random() * 2 - 1) * amount,
			(math.random() * 2 - 1) * amount
		)
	end
	camera.CFrame = CFrame.lookAt(cameraPosition, lookTarget) * CFrame.Angles(0, 0, self._roll)

	local speedRatio = glider:GetSpeedRatio()
	local targetFov = math.clamp(s.BaseFOV + (speedRatio - 1) * s.FOVPerSpeedMultiplier, s.BaseFOV, s.MaxFOV)
	camera.FieldOfView += (targetFov - camera.FieldOfView) * alpha
end

return FollowCamera
