local SlideController = {}

local initialized = false

function SlideController:Init()
	if initialized then return end
	initialized = true

	-- ============================================
	-- SERVICES
	-- ============================================
	local Players          = game:GetService("Players")
	local UserInputService = game:GetService("UserInputService")
	local TweenService     = game:GetService("TweenService")
	local RunService       = game:GetService("RunService")

	local player    = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid  = character:WaitForChild("Humanoid")
	local animator  = humanoid:WaitForChild("Animator")
	local hrp       = character:WaitForChild("HumanoidRootPart")
	local camera    = workspace.CurrentCamera

	-- ============================================
	-- SETTINGS
	-- ============================================
	local Config = {
		SlideSpeed      = 45,
		SlideDuration   = 0.85,
		SlideCooldown   = 1.0,
		SlideHipHeight  = -0.9,
		MinSpeedToSlide = 4,
		CameraTiltAngle = 6,
		SlideAnimationId = "rbxassetid://2436646739",
	}

	-- ============================================
	-- STATE
	-- ============================================
	local isSliding   = false
	local canSlide    = true
	local slideConn   = nil
	local slideTrack  = nil
	local normalHip   = humanoid.HipHeight
	local normalSpeed = humanoid.WalkSpeed

	-- ============================================
	-- ANIMATION
	-- ============================================
	local slideAnim = Instance.new("Animation")
	slideAnim.AnimationId = Config.SlideAnimationId

	local function loadAnimation()
		if slideTrack then
			slideTrack:Destroy()
		end
		slideTrack = animator:LoadAnimation(slideAnim)
		slideTrack.Priority = Enum.AnimationPriority.Action
		slideTrack.Looped   = false
	end

	loadAnimation()

	-- ============================================
	-- FUNCTIONS
	-- ============================================
	local function tiltCamera(angle)
		TweenService:Create(camera, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
			CFrame = camera.CFrame * CFrame.Angles(0, 0, math.rad(angle))
		}):Play()
	end

	local function stopSlide()
		if not isSliding then return end
		isSliding = false

		if slideTrack and slideTrack.IsPlaying then
			slideTrack:Stop(0.2)
		end

		if slideConn then
			slideConn:Disconnect()
			slideConn = nil
		end

		TweenService:Create(humanoid, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			HipHeight = normalHip,
			WalkSpeed = normalSpeed
		}):Play()

		canSlide = false
		task.delay(Config.SlideCooldown, function()
			canSlide = true
		end)
	end

	local function startSlide()
		if isSliding or not canSlide then return end

		local vel = hrp.AssemblyLinearVelocity

		isSliding = true

		if slideTrack and not slideTrack.IsPlaying then
			slideTrack:Play(0.1)
		end

		local dir = Vector3.new(vel.X, 0, vel.Z).Unit

		TweenService:Create(humanoid, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
			HipHeight = Config.SlideHipHeight,
			WalkSpeed = Config.SlideSpeed
		}):Play()

		hrp.AssemblyLinearVelocity = Vector3.new(
			dir.X * Config.SlideSpeed,
			hrp.AssemblyLinearVelocity.Y,
			dir.Z * Config.SlideSpeed
		)

		tiltCamera(Config.CameraTiltAngle)

		local elapsed = 0
		slideConn = RunService.Heartbeat:Connect(function(dt)
			if not isSliding then
				slideConn:Disconnect()
				return
			end

			elapsed = elapsed + dt
			local t = math.clamp(elapsed / Config.SlideDuration, 0, 1)

			humanoid.WalkSpeed = Config.SlideSpeed * (1 - t) + normalSpeed * t

			if elapsed >= Config.SlideDuration then
				tiltCamera(-Config.CameraTiltAngle)

				if slideTrack and slideTrack.IsPlaying then
					slideTrack:Stop(0.15)
				end

				stopSlide()
			end
		end)
	end

	-- ============================================
	-- INPUT
	-- ============================================
	UserInputService.InputBegan:Connect(function(input, gpe)
		-- Tidak pakai 'if gpe then return end' agar klik kiri selalu trigger slide
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			startSlide()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if isSliding then
				tiltCamera(-Config.CameraTiltAngle)
				stopSlide()
			end
		end
	end)

	-- ============================================
	-- MOBILE UI
	-- ============================================
	local gui = Instance.new("ScreenGui")
	gui.Name = "SlideGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player.PlayerGui

	local btn = Instance.new("ImageButton")
	btn.Size = UDim2.new(0, 80, 0, 80)
	btn.Position = UDim2.new(1, -200, 1, -130)
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	btn.BackgroundTransparency = 0.25
	btn.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 200, 50)
	stroke.Thickness = 2.5
	stroke.Parent = btn

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 0.55, 0)
	icon.Position = UDim2.new(0, 0, 0.08, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "▼▼"
	icon.TextColor3 = Color3.fromRGB(255, 220, 60)
	icon.TextScaled = true
	icon.Font = Enum.Font.GothamBold
	icon.Parent = btn

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0.3, 0)
	lbl.Position = UDim2.new(0, 0, 0.65, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "SLIDE"
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.Parent = btn

	local function pressEffect(pressing)
		TweenService:Create(btn, TweenInfo.new(0.08), {
			Size = pressing and UDim2.new(0, 70, 0, 70) or UDim2.new(0, 80, 0, 80),
			BackgroundTransparency = pressing and 0.05 or 0.25
		}):Play()
	end

	btn.MouseButton1Down:Connect(function()
		pressEffect(true)
		startSlide()
	end)

	btn.MouseButton1Up:Connect(function()
		pressEffect(false)
		if isSliding then
			tiltCamera(-Config.CameraTiltAngle)
			stopSlide()
		end
	end)

	-- ============================================
	-- RESPAWN
	-- ============================================
	player.CharacterAdded:Connect(function(newChar)
		character  = newChar
		humanoid   = newChar:WaitForChild("Humanoid")
		animator   = humanoid:WaitForChild("Animator")
		hrp        = newChar:WaitForChild("HumanoidRootPart")

		isSliding  = false
		canSlide   = true
		normalHip  = humanoid.HipHeight
		normalSpeed = humanoid.WalkSpeed

		if slideConn then
			slideConn:Disconnect()
			slideConn = nil
		end

		loadAnimation()
	end)

	print("[SlideController] ✅ Loaded via Module")
end

return SlideController