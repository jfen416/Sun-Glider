--[[
	FlightClient (LocalScript, StarterPlayer > StarterPlayerScripts)

	Runs the game loop on the player's device: main menu, cinematic fly-in,
	countdown, fly, crash, restart. Wires input to the glider, drives the camera, test track and
	engine heat, orbs and the sun, and shows the HUD (distance, speed, heat meter,
	orb counter, messages). Collected orbs are reported to CurrencyService
	on the server, which keeps and saves the total.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local modules = ReplicatedStorage:WaitForChild("RaceTheSun")

local Config = require(modules:WaitForChild("FlightConfig"))
local Glider = require(modules:WaitForChild("Glider"))
local FlightInput = require(modules:WaitForChild("FlightInput"))
local FollowCamera = require(modules:WaitForChild("FollowCamera"))
local TestTrack = require(modules:WaitForChild("TestTrack"))
local Heat = require(modules:WaitForChild("Heat"))
local HeatHud = require(modules:WaitForChild("HeatHud"))
local Orbs = require(modules:WaitForChild("Orbs"))
local OrbHud = require(modules:WaitForChild("OrbHud"))
local Sun = require(modules:WaitForChild("Sun"))
local MainMenu = require(modules:WaitForChild("MainMenu"))
local MenuCamera = require(modules:WaitForChild("MenuCamera"))

-- Created by CurrencyService on the server; nil until it arrives.
local collectRemote: RemoteEvent? = nil
task.spawn(function()
	collectRemote = ReplicatedStorage:WaitForChild(Config.Orbs.RemoteName, 30) :: RemoteEvent?
end)

-- Turn off Roblox's default movement controls (this also hides the mobile thumbstick).
task.spawn(function()
	local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
	if playerModule then
		pcall(function()
			require(playerModule):GetControls():Disable()
		end)
	end
end)

-- HUD -----------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "FlightHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(name: string, position: UDim2, size: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = ""
	label.Parent = gui
	return label
end

local distanceLabel = makeLabel("Distance", UDim2.new(0.5, 0, 0, 40), UDim2.fromOffset(300, 40), 28)
local speedLabel = makeLabel("Speed", UDim2.new(0.5, 0, 0, 72), UDim2.fromOffset(300, 24), 18)
local messageLabel = makeLabel("Message", UDim2.fromScale(0.5, 0.4), UDim2.fromOffset(600, 200), 36)

-- Game objects --------------------------------------------------------------
local startPosition = Config.Track.Origin + Vector3.new(0, Config.HoverHeight, 0)
local track = TestTrack.new(Config.Track)
local glider = Glider.new(startPosition)
local input = FlightInput.new()
local followCamera = FollowCamera.new(Config.Camera)
glider:AddIgnore(track.CoolingZones) -- rain and clouds are not solid
local heat = Heat.new(glider, track.CoolingZones)
local heatHud = HeatHud.new(gui)
local sun = Sun.new() -- swells and reddens with engine heat
local orbs = Orbs.new(glider, { track.CoolingZones }) -- rain zones must not block orb placement
local orbHud = OrbHud.new(gui)
local runOrbs = 0

orbs.Collected:Connect(function(kind: string, value: number)
	runOrbs += value
	orbHud:SetRun(runOrbs)
	if kind == "Special" then
		orbHud:Popup("+" .. value, Config.Orbs.Kinds.Special.Color)
	end
	if collectRemote then
		collectRemote:FireServer(kind)
	end
end)

local function refreshOrbTotal()
	orbHud:SetTotal(player:GetAttribute("OrbTotal"))
end
player:GetAttributeChangedSignal("OrbTotal"):Connect(refreshOrbTotal)
refreshOrbTotal()

-- The engine glows hotter as heat builds.
local engine = glider.Model:FindFirstChild("Engine") :: BasePart?
local engineCoolColor = if engine then engine.Color else Color3.new(1, 1, 1)
local ENGINE_HOT_COLOR = Color3.fromRGB(255, 60, 30)

-- On phones and tablets, a jump button (taps on it don't count as steering).
if Config.JumpEnabled and UserInputService.TouchEnabled then
	local jumpButton = Instance.new("TextButton")
	jumpButton.Name = "JumpButton"
	jumpButton.AnchorPoint = Vector2.new(0.5, 1)
	jumpButton.Position = UDim2.new(0.5, 0, 1, -30)
	jumpButton.Size = UDim2.fromOffset(110, 110)
	jumpButton.BackgroundColor3 = Color3.new(0, 0, 0)
	jumpButton.BackgroundTransparency = 0.5
	jumpButton.Font = Enum.Font.GothamBold
	jumpButton.TextSize = 22
	jumpButton.TextColor3 = Color3.new(1, 1, 1)
	jumpButton.Text = "JUMP"
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = jumpButton
	jumpButton.Parent = gui
	jumpButton.Activated:Connect(function()
		input:RequestJump()
	end)
	heatHud:SetBottomOffset(130) -- keep the heat meter above the jump button
end

-- Main menu ------------------------------------------------------------------
local menu = MainMenu.new(player:WaitForChild("PlayerGui"), Config.Menu)
local menuCamera = MenuCamera.new(Config.Menu, menu.Fade)
local menuFocus = CFrame.new(startPosition) -- the plane rests here while the menu shows
local menuTime = 0
gui.Enabled = false -- the in-run HUD stays hidden until the fly-in ends

-- Float and gently bank the plane in the menu; amount fades to 0 for the fly-in.
local function poseMenuGlider(amount: number)
	local bob = math.sin(menuTime * 1.3) * Config.Menu.PlaneBob * amount
	local bank = math.sin(menuTime * 0.7) * math.rad(Config.Menu.PlaneSway) * amount
	glider.Model:PivotTo(menuFocus * CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, bank))
end

local state = "menu" -- "menu" | "intro" | "countdown" | "flying" | "ended"
local endedAt = 0
local runId = 0

local function startRun()
	runId += 1
	local thisRun = runId

	state = "countdown"
	glider:Reset(startPosition)
	heat:Reset()
	followCamera:Snap()
	track:Update(glider.Position)
	orbs:Reset() -- new random orb layout every run
	runOrbs = 0
	orbHud:SetRun(0)

	for count = Config.CountdownSeconds, 1, -1 do
		messageLabel.Text = tostring(count)
		task.wait(1)
		if runId ~= thisRun then
			return
		end
	end

	state = "flying"
	messageLabel.Text = "GO!"
	task.delay(0.6, function()
		if runId == thisRun and state == "flying" then
			messageLabel.Text = ""
		end
	end)
end

glider.Ended:Connect(function(reason: string)
	state = "ended"
	endedAt = os.clock()
	if reason == "Crash" or reason == "Overheat" then
		followCamera:Shake(Config.Camera.CrashShake, Config.Camera.CrashShakeTime)
	end
	local title = if reason == "Crash"
		then "CRASHED"
		elseif reason == "Overheat" then "ENGINE OVERHEATED"
		else string.upper(reason)
	messageLabel.Text = string.format(
		"%s\nDistance: %d\nOrbs: %d\n\nPress R, A or tap to fly again",
		title,
		math.floor(glider.Distance),
		runOrbs
	)
end)

menu.FlyPressed:Connect(function()
	if state ~= "menu" then
		return
	end
	state = "intro"
	menu:Hide(Config.Menu.FlyTransitionTime)
	local restPosition, restLook = followCamera:GetRestView(glider)
	menuCamera:StartTransition(restPosition, restLook, Config.Camera.BaseFOV)
end)

menuCamera.Finished:Connect(function()
	gui.Enabled = true
	task.spawn(startRun)
end)

input.JumpRequested:Connect(function()
	if state == "flying" then
		glider:Jump()
	end
end)

input.RestartRequested:Connect(function()
	if state == "ended" and os.clock() - endedAt >= Config.RestartDelay then
		task.spawn(startRun)
	end
end)

RunService:BindToRenderStep("RaceTheSunFlight", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	if state == "flying" then
		glider.Steer = input:GetSteer()
		glider:Step(dt)
		heat:Update(dt)
	end
	heatHud:Update(dt, heat)
	if engine then
		engine.Color = engineCoolColor:Lerp(ENGINE_HOT_COLOR, heat:GetFraction())
	end
	track:Update(glider.Position)
	orbs:Update(dt)
	if state == "menu" or state == "intro" then
		menuTime += dt
		local progress = menuCamera:GetTransitionProgress()
		poseMenuGlider(if progress then 1 - progress else 1)
		menuCamera:Update(dt, menuFocus)
	else
		followCamera:Update(dt, glider)
	end
	sun:Update(dt, heat:GetFraction()) -- after the camera, so it stays fixed in the sky
	distanceLabel.Text = string.format("%d", math.floor(glider.Distance))
	speedLabel.Text = string.format("speed x%.2f", glider:GetSpeedRatio())
end)

-- Start on the main menu: lay out the track and orbs around the resting plane.
track:Update(startPosition)
