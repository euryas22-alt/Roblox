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
	SlideSpeed       = 45,
	SlideDuration    = 1.4,
	SlideCooldown    = 1.0,
	SlideHipHeight   = -0.9,
	CameraTiltAngle  = 6,
	SlideAnimationId = "rbxassetid://90262328649285",
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

-- Camera roll state
local cameraRoll       = 0   -- nilai roll saat ini (radian)
local cameraRollTarget = 0   -- target roll (radian)

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
-- CAMERA ROLL (berjalan setelah camera controller Roblox)
-- Prioritas Camera+1 agar dieksekusi SETELAH kamera mengikuti player
-- sehingga kamera selalu mengikuti player, lalu roll ditambahkan di atasnya
-- ============================================
RunService:BindToRenderStep("SlideCameraRoll", Enum.RenderPriority.Camera.Value + 1, function(dt)
	-- Interpolasi roll menuju target secara smooth
	cameraRoll = cameraRoll + (cameraRollTarget - cameraRoll) * math.min(1, dt * 12)

	-- Terapkan roll hanya jika cukup besar (hindari noise)
	if math.abs(cameraRoll) > 0.0005 then
		camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, cameraRoll)
	end
end)

-- ============================================
-- FUNCTIONS
-- ============================================
local function setTargetRoll(angle)
	cameraRollTarget = math.rad(angle)
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

	isSliding = true

	if slideTrack and not slideTrack.IsPlaying then
		slideTrack:Play(0.1)
	end

	-- Baca durasi dari animasi; fallback ke Config.SlideDuration jika belum ter-stream
	local slideDuration = (slideTrack and slideTrack.Length > 0.01)
		and slideTrack.Length
		or Config.SlideDuration

	local vel     = hrp.AssemblyLinearVelocity
	local flatVel = Vector3.new(vel.X, 0, vel.Z)

	-- Jika diam, pakai arah depan kamera
	local dir
	if flatVel.Magnitude > 0.1 then
		dir = flatVel.Unit
	else
		local camLook = camera.CFrame.LookVector
		dir = Vector3.new(camLook.X, 0, camLook.Z).Unit
	end

	TweenService:Create(humanoid, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
		HipHeight = Config.SlideHipHeight,
		WalkSpeed = Config.SlideSpeed
	}):Play()

	hrp.AssemblyLinearVelocity = Vector3.new(
		dir.X * Config.SlideSpeed,
		hrp.AssemblyLinearVelocity.Y,
		dir.Z * Config.SlideSpeed
	)

	setTargetRoll(Config.CameraTiltAngle)

	-- === TRIGGER UTAMA: animasi selesai → otomatis stop slide ===
	if slideTrack then
		local conn
		conn = slideTrack.Stopped:Connect(function()
			conn:Disconnect()
			if isSliding then
				setTargetRoll(0)
				stopSlide()
			end
		end)
	end

	-- === FALLBACK: timer heartbeat jika animasi Length = 0 (belum ter-stream) ===
	local elapsed = 0
	slideConn = RunService.Heartbeat:Connect(function(dt)
		if not isSliding then
			slideConn:Disconnect()
			return
		end

		elapsed = elapsed + dt
		local t = math.clamp(elapsed / slideDuration, 0, 1)
		humanoid.WalkSpeed = Config.SlideSpeed * (1 - t) + normalSpeed * t

		-- Safety fallback: paksa stop jika melebihi durasi
		if elapsed >= slideDuration then
			setTargetRoll(0)
			if slideTrack and slideTrack.IsPlaying then
				slideTrack:Stop(0.15)
			end
			stopSlide()
		end
	end)
end

-- ============================================
-- INPUT (Klik Kiri)
-- ============================================
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		startSlide()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if isSliding then
			setTargetRoll(0)
			stopSlide()
		end
	end
end)

-- ============================================
-- MOBILE UI (Tombol SLIDE)
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
		setTargetRoll(0)
		stopSlide()
	end
end)

-- ============================================
-- RESPAWN
-- ============================================
player.CharacterAdded:Connect(function(newChar)
	character   = newChar
	humanoid    = newChar:WaitForChild("Humanoid")
	animator    = humanoid:WaitForChild("Animator")
	hrp         = newChar:WaitForChild("HumanoidRootPart")

	isSliding   = false
	canSlide    = true
	normalHip   = humanoid.HipHeight
	normalSpeed = humanoid.WalkSpeed

	if slideConn then
		slideConn:Disconnect()
		slideConn = nil
	end

	loadAnimation()
end)

print("[SlideController] ✅ Loaded langsung di LocalScript")