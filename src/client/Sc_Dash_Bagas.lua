local DashController = {}

local initialized = false

function DashController:Init()
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
		DashSpeed        = 45,
		DashDuration     = 0.4,   -- Lebih pendek dari slide, lebih cocok untuk dash
		DashCooldown     = 1.0,
		DashHipHeight    = -0.9,
		MinSpeedToDash   = 4,
		CameraTiltAngle  = 6,
		DashAnimationId  = "rbxassetid://2436646739",
	}

	-- ============================================
	-- STATE
	-- ============================================
	local isDashing   = false
	local canDash     = true
	local dashConn    = nil
	local dashTrack   = nil
	local normalHip   = humanoid.HipHeight
	local normalSpeed = humanoid.WalkSpeed

	-- ============================================
	-- ANIMATION
	-- ============================================
	local dashAnim = Instance.new("Animation")
	dashAnim.AnimationId = Config.DashAnimationId

	local function loadAnimation()
		if dashTrack then
			dashTrack:Destroy()
		end
		dashTrack = animator:LoadAnimation(dashAnim)
		dashTrack.Priority = Enum.AnimationPriority.Action
		dashTrack.Looped   = false
	end

	loadAnimation()

	-- ============================================
	-- FUNCTIONS
	-- ============================================
	-- tiltCamera dihapus karena menyebabkan kamera miring ke kiri (roll sumbu Z)

	local function stopDash()
		if not isDashing then return end
		isDashing = false

		if dashTrack and dashTrack.IsPlaying then
			dashTrack:Stop(0.2)
		end

		if dashConn then
			dashConn:Disconnect()
			dashConn = nil
		end

		TweenService:Create(humanoid, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			HipHeight = normalHip,
			WalkSpeed = normalSpeed
		}):Play()

		canDash = false
		task.delay(Config.DashCooldown, function()
			canDash = true
		end)
	end

	local function startDash()
		if isDashing or not canDash then return end

		local vel = hrp.AssemblyLinearVelocity
		local flatVel = Vector3.new(vel.X, 0, vel.Z)

		-- Jika diam, gunakan arah depan kamera sebagai arah dash
		local dir
		if flatVel.Magnitude > 0.1 then
			dir = flatVel.Unit
		else
			local camLook = camera.CFrame.LookVector
			dir = Vector3.new(camLook.X, 0, camLook.Z).Unit
		end

		isDashing = true

		if dashTrack and not dashTrack.IsPlaying then
			dashTrack:Play(0.1)
		end

		TweenService:Create(humanoid, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
			HipHeight = Config.DashHipHeight,
			WalkSpeed = Config.DashSpeed
		}):Play()

		hrp.AssemblyLinearVelocity = Vector3.new(
			dir.X * Config.DashSpeed,
			hrp.AssemblyLinearVelocity.Y,
			dir.Z * Config.DashSpeed
		)



		local elapsed = 0
		dashConn = RunService.Heartbeat:Connect(function(dt)
			if not isDashing then
				dashConn:Disconnect()
				return
			end

			elapsed = elapsed + dt
			local t = math.clamp(elapsed / Config.DashDuration, 0, 1)

			humanoid.WalkSpeed = Config.DashSpeed * (1 - t) + normalSpeed * t

			if elapsed >= Config.DashDuration then


				if dashTrack and dashTrack.IsPlaying then
					dashTrack:Stop(0.15)
				end

				stopDash()
			end
		end)
	end

	-- ============================================
	-- INPUT
	-- ============================================
	UserInputService.InputBegan:Connect(function(input, gpe)
		-- Tidak pakai 'if gpe then return end' agar klik kiri selalu trigger dash
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			startDash()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if isDashing then
				stopDash()
			end
		end
	end)

	-- ============================================
	-- MOBILE UI
	-- ============================================
	local gui = Instance.new("ScreenGui")
	gui.Name = "DashGui"
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
	icon.Text = "▶▶"
	icon.TextColor3 = Color3.fromRGB(255, 220, 60)
	icon.TextScaled = true
	icon.Font = Enum.Font.GothamBold
	icon.Parent = btn

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0.3, 0)
	lbl.Position = UDim2.new(0, 0, 0.65, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "DASH"
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
		startDash()
	end)

	btn.MouseButton1Up:Connect(function()
		pressEffect(false)
		if isDashing then
			stopDash()
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

		isDashing  = false
		canDash    = true
		normalHip  = humanoid.HipHeight
		normalSpeed = humanoid.WalkSpeed

		if dashConn then
			dashConn:Disconnect()
			dashConn = nil
		end

		loadAnimation()
	end)

	print("[DashController] ✅ Loaded via Module")
end

return DashController