--[[
	OrbHud (ModuleScript)

	Orb counter in the top-right corner: orbs collected this run (big) and
	the saved total (small, from the server). Popup() shows a floating
	"+10" style message when a special orb is collected.
]]

local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.FlightConfig)

local POPUP_INFO = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local OrbHud = {}
OrbHud.__index = OrbHud

local function makeText(parent: Instance, name: string, position: UDim2, size: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(1, 0)
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.Text = ""
	label.Parent = parent
	return label
end

function OrbHud.new(gui: ScreenGui)
	local self = setmetatable({}, OrbHud)
	self._gui = gui

	local panel = Instance.new("Frame")
	panel.Name = "OrbCounter"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -20, 0, 20)
	panel.Size = UDim2.fromOffset(220, 64)
	panel.BackgroundTransparency = 1
	panel.Parent = gui

	-- Small glowing dot as the orb icon.
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(1, 0.5)
	icon.Position = UDim2.new(1, 0, 0, 18)
	icon.Size = UDim2.fromOffset(20, 20)
	icon.BackgroundColor3 = Config.Orbs.Kinds.Regular.Color
	icon.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = icon
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.4
	stroke.Thickness = 1.5
	stroke.Parent = icon

	self._runLabel = makeText(panel, "RunOrbs", UDim2.new(1, -30, 0, 0), UDim2.fromOffset(190, 36), 30)
	self._totalLabel = makeText(panel, "TotalOrbs", UDim2.new(1, 0, 0, 38), UDim2.fromOffset(220, 22), 16)

	self:SetRun(0)
	self:SetTotal(nil)
	return self
end

function OrbHud:SetRun(count: number)
	self._runLabel.Text = tostring(count)
end

-- total is nil until the server has loaded the saved amount.
function OrbHud:SetTotal(total: number?)
	self._totalLabel.Text = if total then string.format("TOTAL  %d", total) else "TOTAL  ..."
end

function OrbHud:Popup(text: string, color: Color3)
	local label = Instance.new("TextLabel")
	label.Name = "OrbPopup"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.3)
	label.Size = UDim2.fromOffset(200, 50)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 40
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = self._gui

	local tween = TweenService:Create(label, POPUP_INFO, {
		Position = UDim2.new(0.5, 0, 0.3, -50),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween.Completed:Connect(function()
		label:Destroy()
	end)
	tween:Play()
end

return OrbHud
