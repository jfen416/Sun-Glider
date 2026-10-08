--[[
	MenuCamera (ModuleScript)

	Cinematic camera for the main menu. It plays Config.Menu.Shots in a loop:
	each shot drifts slowly from one spot to another around the plane while
	looking at it, with a quick fade to black between shots.

	StartTransition() swoops from wherever the camera is to the chase-camera
	view along a curved path, then fires Finished so the run can begin.

	Shot positions are offsets from the plane (the plane faces -Z, +X is its
	right, +Y is up).
]]

local Workspace = game:GetService("Workspace")

local MenuCamera = {}
MenuCamera.__index = MenuCamera

local function smoothstep(t: number): number
	return t * t * (3 - 2 * t)
end

local function easeInOutCubic(t: number): number
	return if t < 0.5 then 4 * t * t * t else 1 - (-2 * t + 2) ^ 3 / 2
end

-- fade: a full-screen black Frame the camera dims between shots.
function MenuCamera.new(settings, fade: Frame)
	local self = setmetatable({}, MenuCamera)
	self.Settings = settings
	self._fade = fade
	self._finishedEvent = Instance.new("BindableEvent")
	self.Finished = self._finishedEvent.Event
	self:Reset()
	return self
end

-- Start the shot loop again from the first shot.
function MenuCamera:Reset()
	self._mode = "shots"
	self._shotIndex = 1
	self._shotTime = 0
	self._position = nil
	self._look = nil
end

-- Fly from the current view to restPosition, looking at restLook.
function MenuCamera:StartTransition(restPosition: Vector3, restLook: Vector3, restFov: number)
	local camera = Workspace.CurrentCamera
	self._mode = "transition"
	self._transitionTime = 0
	self._fromPosition = self._position or restPosition
	self._fromLook = self._look or restLook
	self._fromFov = if camera then camera.FieldOfView else restFov
	self._toPosition = restPosition
	self._toLook = restLook
	self._toFov = restFov
end

-- How far through the fly-in we are (0..1), or nil when not transitioning.
function MenuCamera:GetTransitionProgress(): number?
	if self._mode ~= "transition" then
		return nil
	end
	return math.clamp(self._transitionTime / self.Settings.FlyTransitionTime, 0, 1)
end

function MenuCamera:_applyView(camera: Camera, position: Vector3, look: Vector3, fov: number)
	self._position = position
	self._look = look
	camera.CFrame = CFrame.lookAt(position, look)
	camera.FieldOfView = fov
end

function MenuCamera:_updateShots(dt: number, camera: Camera, focus: CFrame)
	local s = self.Settings
	local shot = s.Shots[self._shotIndex]
	self._shotTime += dt
	if self._shotTime >= shot.Duration then
		self._shotTime = 0
		self._shotIndex = self._shotIndex % #s.Shots + 1
		shot = s.Shots[self._shotIndex]
	end

	local t = self._shotTime / shot.Duration
	local offset = shot.From:Lerp(shot.To, smoothstep(t))
	self:_applyView(camera, focus:PointToWorldSpace(offset), focus:PointToWorldSpace(shot.Look), shot.FOV)

	-- Dip to black at the start and end of each shot.
	local fadeIn = math.clamp(self._shotTime / s.ShotFade, 0, 1)
	local fadeOut = math.clamp((shot.Duration - self._shotTime) / s.ShotFade, 0, 1)
	self._fade.BackgroundTransparency = math.min(fadeIn, fadeOut)
end

function MenuCamera:_updateTransition(dt: number, camera: Camera)
	self._transitionTime += dt
	local t = math.clamp(self._transitionTime / self.Settings.FlyTransitionTime, 0, 1)
	local e = easeInOutCubic(t)

	-- Curve up and out around the plane instead of cutting straight through it.
	local a, b = self._fromPosition, self._toPosition
	local middle = (a + b) / 2
	local away = Vector3.new(middle.X - self._toLook.X, 0, 0)
	if away.Magnitude < 1 then
		away = Vector3.new(1, 0, 0)
	end
	local control = middle + away.Unit * self.Settings.FlyTransitionSwing + Vector3.new(0, self.Settings.FlyTransitionLift, 0)
	local position = a:Lerp(control, e):Lerp(control:Lerp(b, e), e)

	local look = self._fromLook:Lerp(self._toLook, e)
	local fov = self._fromFov + (self._toFov - self._fromFov) * e
	self:_applyView(camera, position, look, fov)

	-- Clear any shot fade quickly.
	self._fade.BackgroundTransparency = math.min(1, self._fade.BackgroundTransparency + dt * 4)

	if t >= 1 then
		self._mode = "done"
		self._fade.BackgroundTransparency = 1
		self._finishedEvent:Fire()
	end
end

-- Call every frame while the menu or fly-in is showing. focus is the plane's resting CFrame.
function MenuCamera:Update(dt: number, focus: CFrame)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	if self._mode == "shots" then
		self:_updateShots(dt, camera, focus)
	elseif self._mode == "transition" then
		self:_updateTransition(dt, camera)
	end
end

function MenuCamera:Destroy()
	self._finishedEvent:Destroy()
end

return MenuCamera
