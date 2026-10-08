--[[
	MainMenu (ModuleScript)

	The main menu screen: cinematic black bars, the game title and three
	buttons down the left (Fly, Customize, Options). Customize and Options
	open a simple "coming soon" panel for now.

	menu.FlyPressed fires when Fly is clicked. menu:Hide() slides the menu
	away and opens the black bars for the fly-in; menu.Fade is the black
	frame MenuCamera dims between shots.
]]

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HOVER_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PANEL_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local MainMenu = {}
MainMenu.__index = MainMenu

local function tween(instance: Instance, info: TweenInfo, goals: { [string]: any })
	local t = TweenService:Create(instance, info, goals)
	t:Play()
	return t
end

local function makeFrame(parent: Instance, name: string, props: { [string]: any }): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	for key, value in props do
		(frame :: any)[key] = value
	end
	frame.Parent = parent
	return frame
end

function MainMenu.new(playerGui: Instance, settings)
	local self = setmetatable({}, MainMenu)
	self.Settings = settings
	self._flyEvent = Instance.new("BindableEvent")
	self.FlyPressed = self._flyEvent.Event
	self._hidden = false

	local gui = Instance.new("ScreenGui")
	gui.Name = "MainMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = playerGui
	self.Gui = gui

	-- Black fade used by the camera between shots (sits under everything else).
	self.Fade = makeFrame(gui, "Fade", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		ZIndex = 1,
	})

	-- Cinematic black bars.
	local barHeight = settings.LetterboxHeight
	self._topBar = makeFrame(gui, "TopBar", {
		Size = UDim2.fromScale(1, barHeight),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ZIndex = 2,
	})
	self._bottomBar = makeFrame(gui, "BottomBar", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, barHeight),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ZIndex = 2,
	})

	-- Everything on the left fades and slides together.
	local content = Instance.new("CanvasGroup")
	content.Name = "Content"
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundTransparency = 1
	content.ZIndex = 3
	content.Parent = gui
	self._content = content

	-- Dark shading behind the text so it reads over any shot.
	local shade = makeFrame(content, "Shade", {
		Size = UDim2.fromScale(0.55, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
	})
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = shade

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.new(0.07, 0, 0.2, 0)
	title.Size = UDim2.fromOffset(600, 80)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 64
	title.TextColor3 = Color3.fromRGB(255, 244, 225)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = settings.Title
	title.Parent = content
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = settings.AccentColor
	titleStroke.Thickness = 2
	titleStroke.Transparency = 0.3
	titleStroke.Parent = title

	local list = makeFrame(content, "Buttons", {
		Position = UDim2.new(0.07, 0, 0.2, 110),
		Size = UDim2.fromOffset(340, 240),
		BackgroundTransparency = 1,
	})
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	self._flyButton = self:_makeButton(list, "Fly", 1, function()
		self:_onFly()
	end)
	self:_makeButton(list, "Customize", 2, function()
		self:_openPanel("CUSTOMIZE")
	end)
	self:_makeButton(list, "Options", 3, function()
		self:_openPanel("OPTIONS")
	end)

	self:_makePanel(content)

	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = self._flyButton
	end
	return self
end

function MainMenu:_makeButton(parent: Instance, text: string, order: number, onClick: () -> ()): TextButton
	local accent = self.Settings.AccentColor

	local holder = makeFrame(parent, text .. "Holder", {
		Size = UDim2.fromOffset(340, 60),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	})

	local button = Instance.new("TextButton")
	button.Name = text
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.TextSize = 32
	button.TextColor3 = Color3.fromRGB(235, 235, 235)
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.Text = string.upper(text)
	button.ZIndex = 2
	button.Parent = holder
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 22)
	padding.Parent = button

	-- Sun-coloured bar on the left that sweeps across on hover.
	local fill = makeFrame(holder, "Fill", {
		Size = UDim2.new(0, 5, 1, 0),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.1,
		ZIndex = 1,
	})

	local function setHover(on: boolean)
		tween(fill, HOVER_INFO, {
			Size = if on then UDim2.fromScale(1, 1) else UDim2.new(0, 5, 1, 0),
			BackgroundTransparency = if on then 0.25 else 0.1,
		})
		tween(button, HOVER_INFO, {
			Position = if on then UDim2.fromOffset(14, 0) else UDim2.fromOffset(0, 0),
			TextColor3 = if on then Color3.fromRGB(30, 20, 10) else Color3.fromRGB(235, 235, 235),
		})
	end

	button.MouseEnter:Connect(function()
		setHover(true)
	end)
	button.MouseLeave:Connect(function()
		setHover(false)
	end)
	button.SelectionGained:Connect(function()
		setHover(true)
	end)
	button.SelectionLost:Connect(function()
		setHover(false)
	end)
	button.Activated:Connect(function()
		if not self._hidden then
			onClick()
		end
	end)
	return button
end

-- A simple "coming soon" panel shared by Customize and Options.
function MainMenu:_makePanel(parent: Instance)
	local panel = Instance.new("CanvasGroup")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.62, 0.5)
	panel.Size = UDim2.fromOffset(420, 240)
	panel.BackgroundColor3 = Color3.fromRGB(15, 12, 10)
	panel.BackgroundTransparency = 0.15
	panel.GroupTransparency = 1
	panel.Visible = false
	panel.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = self.Settings.AccentColor
	stroke.Thickness = 2
	stroke.Parent = panel

	local heading = Instance.new("TextLabel")
	heading.Name = "Heading"
	heading.Position = UDim2.fromOffset(0, 24)
	heading.Size = UDim2.new(1, 0, 0, 40)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBlack
	heading.TextSize = 32
	heading.TextColor3 = Color3.new(1, 1, 1)
	heading.Parent = panel

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(0, 80)
	body.Size = UDim2.new(1, 0, 0, 30)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextSize = 20
	body.TextColor3 = Color3.fromRGB(200, 200, 200)
	body.Text = "Coming soon"
	body.Parent = panel

	local back = Instance.new("TextButton")
	back.Name = "Back"
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.new(0.5, 0, 1, -24)
	back.Size = UDim2.fromOffset(160, 46)
	back.BackgroundColor3 = self.Settings.AccentColor
	back.Font = Enum.Font.GothamBold
	back.TextSize = 22
	back.TextColor3 = Color3.fromRGB(30, 20, 10)
	back.Text = "BACK"
	back.Parent = panel
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 8)
	backCorner.Parent = back
	back.Activated:Connect(function()
		self:_closePanel()
	end)

	self._panel = panel
	self._panelHeading = heading
	self._panelBack = back
end

function MainMenu:_openPanel(heading: string)
	self._panelHeading.Text = heading
	self._panel.Visible = true
	self._panel.Position = UDim2.new(0.62, 0, 0.5, 20)
	tween(self._panel, PANEL_INFO, { GroupTransparency = 0, Position = UDim2.fromScale(0.62, 0.5) })
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = self._panelBack
	end
end

function MainMenu:_closePanel()
	local t = tween(self._panel, PANEL_INFO, { GroupTransparency = 1 })
	t.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			self._panel.Visible = false
		end
	end)
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = self._flyButton
	end
end

function MainMenu:_onFly()
	self._flyEvent:Fire()
end

-- Slide the menu away and open the black bars for the fly-in.
function MainMenu:Hide(duration: number)
	self._hidden = true
	GuiService.SelectedObject = nil
	local fast = TweenInfo.new(duration * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local slow = TweenInfo.new(duration * 0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	tween(self._content, fast, { GroupTransparency = 1, Position = UDim2.fromOffset(-80, 0) })
	tween(self._topBar, slow, { Size = UDim2.fromScale(1, 0) })
	tween(self._bottomBar, slow, { Size = UDim2.fromScale(1, 0) })
	task.delay(duration, function()
		if self._hidden then
			self.Gui.Enabled = false
		end
	end)
end

-- Bring the menu back (for a future "back to menu" button).
function MainMenu:Show()
	self._hidden = false
	self.Gui.Enabled = true
	self._content.GroupTransparency = 0
	self._content.Position = UDim2.fromOffset(0, 0)
	self._panel.Visible = false
	self._panel.GroupTransparency = 1
	self._topBar.Size = UDim2.fromScale(1, self.Settings.LetterboxHeight)
	self._bottomBar.Size = UDim2.fromScale(1, self.Settings.LetterboxHeight)
	self.Fade.BackgroundTransparency = 0
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = self._flyButton
	end
end

function MainMenu:Destroy()
	self.Gui:Destroy()
	self._flyEvent:Destroy()
end

return MainMenu
