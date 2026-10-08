--[[
	HeatHud (ModuleScript)

	On-screen overheat meter. A bar at the bottom of the screen fills from
	green through orange to red as the engine heats up, and shows when you
	are cooling (in shade or rain). From Config.Heat.WarningFraction an
	"OVERHEATING" warning appears with a red pulse around the screen; from
	CriticalFraction it becomes a fast-flashing "CRITICAL HEAT" alarm.
]]

local Config = require(script.Parent.FlightConfig)

local COOL_COLOR = Color3.fromRGB(70, 200, 120)
local WARM_COLOR = Color3.fromRGB(255, 170, 40)
local HOT_COLOR = Color3.fromRGB(255, 50, 40)
local COOLING_COLOR = Color3.fromRGB(90, 180, 255)

local function heatColor(fraction: number): Color3
	if fraction < 0.5 then
		return COOL_COLOR:Lerp(WARM_COLOR, fraction / 0.5)
	end
	return WARM_COLOR:Lerp(HOT_COLOR, (fraction - 0.5) / 0.5)
end

local HeatHud = {}
HeatHud.__index = HeatHud

function HeatHud.new(gui: ScreenGui)
	local self = setmetatable({}, HeatHud)
	self._time = 0

	-- Red pulse around the screen edges while overheating.
	local vignette = Instance.new("Frame")
	vignette.Name = "HeatWarningGlow"
	-- Inset by 20px each side; the 40px stroke draws outward and fills the screen edge.
	vignette.AnchorPoint = Vector2.new(0.5, 0.5)
	vignette.Position = UDim2.fromScale(0.5, 0.5)
	vignette.Size = UDim2.new(1, -40, 1, -40)
	vignette.BackgroundTransparency = 1
	vignette.ZIndex = 0
	local glow = Instance.new("UIStroke")
	glow.Color = HOT_COLOR
	glow.Thickness = 40
	glow.Transparency = 1
	glow.Parent = vignette
	vignette.Parent = gui
	self._glow = glow

	-- Meter: label, track and fill.
	local meter = Instance.new("Frame")
	meter.Name = "HeatMeter"
	meter.AnchorPoint = Vector2.new(0.5, 1)
	meter.Position = UDim2.new(0.5, 0, 1, -24)
	meter.Size = UDim2.fromOffset(360, 22)
	meter.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	meter.BackgroundTransparency = 0.35
	meter.Parent = gui
	local meterCorner = Instance.new("UICorner")
	meterCorner.CornerRadius = UDim.new(0, 6)
	meterCorner.Parent = meter
	local meterStroke = Instance.new("UIStroke")
	meterStroke.Color = Color3.new(1, 1, 1)
	meterStroke.Transparency = 0.6
	meterStroke.Thickness = 1.5
	meterStroke.Parent = meter
	self._meter = meter
	self._meterStroke = meterStroke

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = COOL_COLOR
	fill.BorderSizePixel = 0
	fill.Parent = meter
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill
	self._fill = fill

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = "ENGINE HEAT"
	label.ZIndex = 2
	label.Parent = meter
	self._label = label

	-- Big warning text above the meter.
	local warning = Instance.new("TextLabel")
	warning.Name = "HeatWarning"
	warning.AnchorPoint = Vector2.new(0.5, 1)
	warning.Position = UDim2.new(0.5, 0, 1, -56)
	warning.Size = UDim2.fromOffset(500, 40)
	warning.BackgroundTransparency = 1
	warning.Font = Enum.Font.GothamBlack
	warning.TextSize = 30
	warning.TextColor3 = HOT_COLOR
	warning.TextStrokeTransparency = 0.2
	warning.Text = ""
	warning.Parent = gui
	self._warning = warning

	return self
end

-- Lift the meter and warning above another bottom-centre element (the mobile jump button).
function HeatHud:SetBottomOffset(pixels: number)
	self._meter.Position = UDim2.new(0.5, 0, 1, -24 - pixels)
	self._warning.Position = UDim2.new(0.5, 0, 1, -56 - pixels)
end

function HeatHud:SetVisible(visible: boolean)
	self._meter.Visible = visible
	self._warning.Visible = visible
	if not visible then
		self._glow.Transparency = 1
	end
end

function HeatHud:Update(dt: number, heat)
	self._time += dt
	local s = Config.Heat
	local fraction = heat:GetFraction()

	self._fill.Size = UDim2.fromScale(fraction, 1)
	self._fill.BackgroundColor3 = heatColor(fraction)

	if heat.CoolingSource == "Rain" then
		self._label.Text = "COOLING  ·  RAIN"
		self._meterStroke.Color = COOLING_COLOR
		self._meterStroke.Transparency = 0
	elseif heat.CoolingSource == "Shade" then
		self._label.Text = "COOLING  ·  SHADE"
		self._meterStroke.Color = COOLING_COLOR
		self._meterStroke.Transparency = 0
	else
		self._label.Text = "ENGINE HEAT"
		self._meterStroke.Color = Color3.new(1, 1, 1)
		self._meterStroke.Transparency = 0.6
	end

	if fraction >= s.CriticalFraction and heat.CoolingSource == nil then
		-- Fast flash: text and edge glow blink about 4 times a second.
		local on = math.sin(self._time * 25) > 0
		self._warning.Text = "!! CRITICAL HEAT !!"
		self._warning.TextTransparency = if on then 0 else 0.7
		self._glow.Transparency = if on then 0.2 else 0.8
	elseif fraction >= s.WarningFraction then
		-- Slow pulse.
		local pulse = (math.sin(self._time * 6) + 1) / 2
		self._warning.Text = if heat.CoolingSource then "COOLING DOWN" else "! OVERHEATING !"
		self._warning.TextTransparency = 0.3 * pulse
		self._glow.Transparency = 0.55 + 0.4 * pulse
	else
		self._warning.Text = ""
		self._glow.Transparency = 1
	end
end

return HeatHud
