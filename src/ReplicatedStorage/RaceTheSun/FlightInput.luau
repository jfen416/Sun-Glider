--[[
	FlightInput (ModuleScript)

	Turns keyboard, gamepad and touch into one steer value from -1 to 1.
	  Keyboard: A / D or Left / Right arrows
	  Gamepad:  left thumbstick or D-pad
	  Touch:    hold the left or right half of the screen
	JumpRequested fires on Space, W, Up arrow or gamepad A (touch uses an on-screen button).
	RestartRequested fires on R, Space, Enter, gamepad A or Start, or any tap.
]]

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.FlightConfig)

local LEFT_KEYS = {
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.Left] = true,
	[Enum.KeyCode.DPadLeft] = true,
}
local RIGHT_KEYS = {
	[Enum.KeyCode.D] = true,
	[Enum.KeyCode.Right] = true,
	[Enum.KeyCode.DPadRight] = true,
}
local JUMP_KEYS = {
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.Up] = true,
	[Enum.KeyCode.ButtonA] = true,
}
local RESTART_KEYS = {
	[Enum.KeyCode.R] = true,
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.Return] = true,
	[Enum.KeyCode.ButtonA] = true,
	[Enum.KeyCode.ButtonStart] = true,
}

local function touchSide(input: InputObject): number
	local camera = Workspace.CurrentCamera
	local halfWidth = if camera then camera.ViewportSize.X / 2 else 0
	return if input.Position.X < halfWidth then -1 else 1
end

local FlightInput = {}
FlightInput.__index = FlightInput

function FlightInput.new()
	local self = setmetatable({}, FlightInput)

	self._held = {} -- KeyCode -> true while held
	self._gamepadX = 0
	self._touches = {} -- InputObject -> -1 or 1
	self._restartEvent = Instance.new("BindableEvent")
	self.RestartRequested = self._restartEvent.Event
	self._jumpEvent = Instance.new("BindableEvent")
	self.JumpRequested = self._jumpEvent.Event

	self._connections = {
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if input.UserInputType == Enum.UserInputType.Touch then
				if not gameProcessed then
					self._touches[input] = touchSide(input)
					self._restartEvent:Fire()
				end
				return
			end
			if UserInputService:GetFocusedTextBox() then
				return
			end
			local keyCode = input.KeyCode
			if LEFT_KEYS[keyCode] or RIGHT_KEYS[keyCode] then
				self._held[keyCode] = true
			end
			if JUMP_KEYS[keyCode] then
				self._jumpEvent:Fire()
			end
			if RESTART_KEYS[keyCode] then
				self._restartEvent:Fire()
			end
		end),

		UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				if self._touches[input] then
					self._touches[input] = touchSide(input)
				end
			elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
				local x = input.Position.X
				local deadzone = Config.GamepadDeadzone
				if math.abs(x) < deadzone then
					self._gamepadX = 0
				else
					self._gamepadX = math.sign(x) * (math.abs(x) - deadzone) / (1 - deadzone)
				end
			end
		end),

		UserInputService.InputEnded:Connect(function(input)
			self._touches[input] = nil
			self._held[input.KeyCode] = nil
			if input.KeyCode == Enum.KeyCode.Thumbstick1 then
				self._gamepadX = 0
			end
		end),

		UserInputService.GamepadDisconnected:Connect(function()
			self._gamepadX = 0
		end),

		-- Alt-tabbing can swallow key-up events; drop everything so nothing sticks.
		UserInputService.WindowFocusReleased:Connect(function()
			table.clear(self._held)
			table.clear(self._touches)
			self._gamepadX = 0
		end),
	}

	return self
end

function FlightInput:GetSteer(): number
	local keyboard = 0
	for keyCode in self._held do
		if LEFT_KEYS[keyCode] then
			keyboard -= 1
		elseif RIGHT_KEYS[keyCode] then
			keyboard += 1
		end
	end
	if keyboard ~= 0 then
		return math.clamp(keyboard, -1, 1)
	end

	if self._gamepadX ~= 0 then
		return self._gamepadX
	end

	local touch = 0
	for _, side in self._touches do
		touch += side
	end
	return math.clamp(touch, -1, 1)
end

function FlightInput:Destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._restartEvent:Destroy()
	self._jumpEvent:Destroy()
end

-- For on-screen buttons (the mobile jump button).
function FlightInput:RequestJump()
	self._jumpEvent:Fire()
end

return FlightInput
