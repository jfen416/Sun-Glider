--[[
	ShipBuilder (ModuleScript)

	Builds the glider model out of plain parts so the game works with no
	imported assets. The model faces -Z with its pivot at the origin.
	Swap this out for a real mesh later; Glider only needs a Model with a
	PrimaryPart.
]]

local ShipBuilder = {}

local function makePart(model: Model, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = model
	return part
end

local function addTrail(tip: Part)
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 0.2, tip.Size.Z / 2)
	top.Parent = tip

	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -0.2, tip.Size.Z / 2)
	bottom.Parent = tip

	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.35
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 220, 170))
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.LightEmission = 1
	trail.Parent = tip
end

function ShipBuilder.build(): Model
	local model = Instance.new("Model")
	model.Name = "Glider"

	local root = makePart(model, {
		Name = "Root",
		Size = Vector3.one,
		Transparency = 1,
		CFrame = CFrame.new(),
	})
	model.PrimaryPart = root

	makePart(model, {
		Name = "Fuselage",
		Size = Vector3.new(1.6, 0.9, 7),
		CFrame = CFrame.new(0, 0.3, -0.5),
		Color = Color3.fromRGB(40, 44, 52),
	})

	makePart(model, {
		Name = "Wings",
		Size = Vector3.new(12, 0.25, 3.5),
		CFrame = CFrame.new(0, 0, 1),
		Color = Color3.fromRGB(30, 60, 140),
		Reflectance = 0.2,
	})

	makePart(model, {
		Name = "Canopy",
		Size = Vector3.new(1.1, 0.6, 2),
		CFrame = CFrame.new(0, 0.9, -2),
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
	})

	makePart(model, {
		Name = "Fin",
		Size = Vector3.new(0.2, 1.2, 1.5),
		CFrame = CFrame.new(0, 1.1, 2.2),
		Color = Color3.fromRGB(40, 44, 52),
	})

	local engine = makePart(model, {
		Name = "Engine",
		Size = Vector3.new(0.9, 0.5, 0.25),
		CFrame = CFrame.new(0, 0.3, 3.1),
		Color = Color3.fromRGB(80, 220, 255),
		Material = Enum.Material.Neon,
	})
	local light = Instance.new("PointLight")
	light.Color = engine.Color
	light.Brightness = 2
	light.Range = 8
	light.Parent = engine

	for _, side in { -1, 1 } do
		local tip = makePart(model, {
			Name = if side < 0 then "WingTipLeft" else "WingTipRight",
			Size = Vector3.new(0.35, 0.5, 3.5),
			CFrame = CFrame.new(side * 6.1, 0, 1),
			Color = Color3.fromRGB(255, 140, 40),
			Material = Enum.Material.Neon,
		})
		addTrail(tip)
	end

	return model
end

return ShipBuilder
