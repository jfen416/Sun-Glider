--[[
	FlightConfig (ModuleScript)

	Every tuning number for the glider, camera and test track lives here.
	Change values while playtesting; no other script needs editing.
]]

local FlightConfig = {
	-- Forward motion --------------------------------------------------------
	ForwardSpeed = 160, -- studs per second at the start of a run
	SpeedGainPer1000Studs = 0.05, -- the run speeds up as you go (+5% every 1000 studs)
	MaxSpeedRamp = 1.8, -- cap on that ramp (1.8 = 80% faster than the start)

	-- Steering -------------------------------------------------------------
	MaxStrafeSpeed = 120, -- sideways studs per second at full steer
	SteerResponsiveness = 6.5, -- how fast you reach full sideways speed (higher = snappier)
	SteerReleaseResponsiveness = 9.5, -- how fast you straighten out or reverse when you let go
	MaxBankAngle = 40, -- degrees of roll at full sideways speed
	MaxYawAngle = 10, -- degrees the nose turns into a steer
	MaxPitchAngle = 20, -- degrees the nose tilts when climbing or dropping

	-- Altitude -------------------------------------------------------------
	HoverHeight = 6, -- studs above the ground the glider skims at
	HeightResponsiveness = 10, -- how quickly it follows the ground height
	GroundProbeDepth = 200, -- how far down to look for ground
	Gravity = 180, -- studs/s² pulling you down after a jump or off a ledge
	FallThreshold = 2, -- studs above hover height before gravity takes over

	-- Jump -----------------------------------------------------------------
	JumpEnabled = true,
	JumpVelocity = 75, -- upward studs per second at take-off (clears ~15 studs)

	-- Collision ------------------------------------------------------------
	CollisionSize = Vector3.new(10, 2, 7), -- box swept forward each frame (X = wingspan)
	CrashSlope = 0.6, -- surfaces whose normal.Y is below this count as walls

	-- Input ----------------------------------------------------------------
	GamepadDeadzone = 0.15,

	-- Run flow -------------------------------------------------------------
	CountdownSeconds = 3,
	RestartDelay = 0.75, -- seconds after a crash before restart input is accepted

	-- Camera ---------------------------------------------------------------
	Camera = {
		Distance = 24, -- studs behind the glider
		Height = 8, -- studs above the glider
		LookAhead = 40, -- studs in front of the glider the camera aims at
		LookHeight = 2,
		Responsiveness = 6, -- how tightly the camera follows sideways and vertical motion
		RollFactor = 0.35, -- share of the glider's bank the camera copies
		BaseFOV = 70,
		MaxFOV = 90,
		FOVPerSpeedMultiplier = 20, -- FOV added per +1.0 of speed above the starting speed
		CrashShake = 1.5, -- studs of camera shake on a crash
		CrashShakeTime = 0.5, -- seconds the crash shake lasts
	},

	-- Main menu ------------------------------------------------------------
	Menu = {
		Title = "SUN GLIDER", -- placeholder game name on the menu
		AccentColor = Color3.fromRGB(255, 180, 60), -- button highlight colour
		LetterboxHeight = 0.09, -- cinematic black bars (share of screen height)
		ShotFade = 0.45, -- seconds of fade to black between camera shots
		FlyTransitionTime = 2.4, -- seconds for the swoop into the chase camera
		FlyTransitionSwing = 18, -- how far sideways the swoop curves out
		FlyTransitionLift = 10, -- how far up the swoop curves
		PlaneBob = 0.6, -- studs the plane floats up and down in the menu
		PlaneSway = 6, -- degrees the plane gently banks in the menu

		-- Camera shots, played in order and looped. Offsets are from the plane:
		-- +X right, +Y up, -Z ahead of the nose. The camera drifts From -> To
		-- over Duration seconds while looking at Look.
		Shots = {
			{ -- low side pass
				From = Vector3.new(-26, 2, 14), To = Vector3.new(-24, 4, -10),
				Look = Vector3.new(0, 1, 0), FOV = 55, Duration = 6,
			},
			{ -- close on the nose
				From = Vector3.new(7, 1.5, -15), To = Vector3.new(-6, 2.5, -12),
				Look = Vector3.new(0, 0.5, 0), FOV = 45, Duration = 5,
			},
			{ -- behind the plane, facing the sun
				From = Vector3.new(5, 1.5, 24), To = Vector3.new(-4, 4, 32),
				Look = Vector3.new(0, 6, -40), FOV = 65, Duration = 6,
			},
			{ -- high sweep over the top
				From = Vector3.new(22, 28, 18), To = Vector3.new(-18, 24, 6),
				Look = Vector3.new(0, 0, -4), FOV = 60, Duration = 6,
			},
		},
	},

	-- Test track (placeholder until procedural obstacles arrive) -----------
	Track = {
		Origin = Vector3.new(0, 200, 0), -- top surface of the ground at the start line
		Seed = 12345,
		ChunkSize = 512,
		ChunksAhead = 6,
		ChunksBehind = 1,
		ChunksSide = 2,
		GroundThickness = 4,
		GroundColorA = Color3.fromRGB(214, 196, 160),
		GroundColorB = Color3.fromRGB(200, 182, 146),
		ObstaclesPerChunk = 22,
		ObstacleMinSize = Vector3.new(6, 12, 6),
		ObstacleMaxSize = Vector3.new(30, 80, 30),
		StartClearDistance = 400, -- no obstacles this close to the start line

		-- Shaded arches (fly underneath to cool the engine)
		ArchesPerChunk = { 1, 2 }, -- random count per chunk, min and max
		ArchWidth = { 40, 60 }, -- gap between the pillars
		ArchLength = { 90, 160 }, -- how long the shaded roof is (longer = more cooling)
		ArchClearance = 22, -- height of the roof's underside above the ground

		-- Rain clouds (fly through the rain to cool the engine)
		RainCloudChance = 0.6, -- chance of a rain cloud in each chunk
		RainCloudSize = { Vector3.new(80, 0, 140), Vector3.new(140, 0, 240) }, -- footprint, min and max
		RainCloudHeight = 55, -- cloud base above the ground
	},

	-- Engine heat ----------------------------------------------------------
	Heat = {
		Max = 100,
		HeatPerSecond = 5, -- heat gained in open sun at the starting speed (~20s from cold to boom)
		ScaleWithSpeed = true, -- heat builds faster as the run speeds up
		ShadeCoolPerSecond = 35, -- cooling under an arch (or anything overhead)
		RainCoolPerSecond = 50, -- cooling inside a rain cloud
		ShadeCheckHeight = 80, -- how far above the glider to look for shade
		WarningFraction = 0.7, -- "OVERHEATING" warning from 70% heat
		CriticalFraction = 0.9, -- "CRITICAL" flashing from 90% heat
	},

	-- Sun (reacts to engine heat) -----------------------------------------
	Sun = {
		Elevation = 14, -- degrees above the horizon, straight ahead
		Distance = 1500, -- studs from the camera (it moves with you, so you never reach it)
		Size = 380, -- core diameter in studs at that distance
		Halos = { -- glowing layers around the core (Scale x Size, see-through amount)
			{ Scale = 1.25, Transparency = 0.55 },
			{ Scale = 1.7, Transparency = 0.8 },
			{ Scale = 2.5, Transparency = 0.92 },
		},
		CoolColor = Color3.fromRGB(255, 236, 170), -- cold engine: yellow-white
		HotColor = Color3.fromRGB(255, 70, 30), -- max heat: angry red
		HotGrowth = 0.35, -- the sun is 35% bigger at max heat
		HotHaloGrowth = 0.3, -- halos spread a further 30% at max heat
		HotHaloBrighten = 0.25, -- halos get this much less see-through at max heat
		HeatResponsiveness = 3, -- how quickly the sun follows the heat meter
		BoilSpeed = 1.3, -- halo shimmer
		BoilAmount = 0.04,
		CriticalPulseSpeed = 9, -- throb speed at critical heat
		CriticalPulseGrowth = 0.12, -- extra size at the peak of each throb
		BloomIntensity = { 0.6, 1.6 }, -- screen glow, cold and max heat
		RaysIntensity = { 0.08, 0.3 }, -- sun rays, cold and max heat
		Glare = { 1, 4 }, -- Atmosphere glare around the sun, cold and max heat
		Haze = { 1, 2.5 }, -- Atmosphere heat haze, cold and max heat
		HotTint = Color3.fromRGB(255, 205, 170), -- screen tint at max heat
		HotBrightness = 0.05,
	},

	-- Orbs (currency) ------------------------------------------------------
	Orbs = {
		Kinds = {
			Regular = { Value = 1, Color = Color3.fromRGB(80, 230, 255), Size = 3 },
			Special = { Value = 10, Color = Color3.fromRGB(255, 200, 40), Size = 5 },
		},
		SpecialChance = 0.04, -- share of orbs that are special (about 1 in 25)
		SpecialJumpChance = 0.5, -- share of specials that float at jump height
		JumpHeight = 13, -- how far above normal flying height those specials float
		CollectRadius = 7, -- studs from the glider's centre
		FirstGroupDistance = 250, -- first group this far ahead of the start line
		SpawnAhead = 2000, -- keep orbs placed this far ahead of the glider
		DespawnBehind = 150, -- remove orbs this far behind the glider
		GroupSpacing = { 80, 220 }, -- gap between one group's end and the next group's start
		GroupSideRange = 200, -- groups appear up to this far left/right of the glider
		OrbsPerGroup = { 5, 10 },
		OrbSpacing = 18, -- studs between orbs in a group
		BobHeight = 0.6,
		BobSpeed = 3,

		-- Saving (CurrencyService on the server)
		RemoteName = "RaceTheSunCollectOrb",
		DataStoreName = "RaceTheSunOrbs",
		MaxCollectsPerSecond = 20,
		SaveInterval = 60, -- seconds between autosaves
	},
}

return FlightConfig
