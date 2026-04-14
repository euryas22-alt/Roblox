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
	DashSpeed       = 65,     -- kecepatan burst awal (Genshin-like)
	DashDuration    = 0.4,    -- durasi singkat & snappy
	DashCooldown    = 0.7,    -- cooldown
	CameraTiltAngle = 10,     -- tilt lebih dramatis
	NormalFOV       = 70,     -- FOV default
	DashFOV         = 85,     -- FOV melebar saat dash (efek kecepatan)
	DashAnimationId = "rbxassetid://90262328649285",
}

-- ============================================
-- STATE
-- ============================================
local isDashing  = false
local canDash    = true
local dashConn   = nil
local slideTrack = nil
local normalHip  = humanoid.HipHeight
local normalSpeed = humanoid.WalkSpeed

-- Camera roll state
local cameraRoll       = 0
local cameraRollTarget = 0

-- ============================================
-- ANIMATION
-- ============================================
local slideAnim = Instance.new("Animation")
slideAnim.AnimationId = Config.DashAnimationId

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

-- Set FOV kamera dengan smooth tween
local function setFOV(fov)
	TweenService:Create(camera, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
		FieldOfView = fov
	}):Play()
end

-- I-frames: set CanCollide pada semua limb karakter
local function setCharacterCollision(enabled)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = enabled
		end
	end
end

local function stopDash()
	if not isDashing then return end
	isDashing = false

	-- Blend out animasi dash
	if slideTrack and slideTrack.IsPlaying then
		slideTrack:Stop(0.2)
	end

	if dashConn then
		dashConn:Disconnect()
		dashConn = nil
	end

	-- Kembalikan collision (i-frames selesai)
	setCharacterCollision(true)

	-- Kembalikan kamera
	setTargetRoll(0)
	setFOV(Config.NormalFOV)

	-- Langsung restore WalkSpeed → langsung lari (Genshin-like)
	humanoid.WalkSpeed = normalSpeed

	canDash = false
	task.delay(Config.DashCooldown, function()
		canDash = true
	end)
end

local function startDash()
	if isDashing or not canDash then return end

	isDashing = true

	if slideTrack and not slideTrack.IsPlaying then
		slideTrack:Play(0.05)  -- blend in cepat untuk feel snappy
	end

	-- Arah dash: dari velocity atau depan kamera
	local vel     = hrp.AssemblyLinearVelocity
	local flatVel = Vector3.new(vel.X, 0, vel.Z)
	local dir
	if flatVel.Magnitude > 0.1 then
		dir = flatVel.Unit
	else
		local camLook = camera.CFrame.LookVector
		dir = Vector3.new(camLook.X, 0, camLook.Z).Unit
	end

	-- WalkSpeed = 0 saat dash (velocity dikontrol manual)
	humanoid.WalkSpeed = 0

	-- I-frames: matikan collision semua limb selama dash
	setCharacterCollision(false)

	-- Efek kamera: tilt + FOV melebar
	setTargetRoll(Config.CameraTiltAngle)
	setFOV(Config.DashFOV)

	-- Burst velocity awal
	hrp.AssemblyLinearVelocity = Vector3.new(
		dir.X * Config.DashSpeed,
		hrp.AssemblyLinearVelocity.Y,
		dir.Z * Config.DashSpeed
	)

	-- Trigger utama: animasi selesai → stop dash
	if slideTrack then
		local conn
		conn = slideTrack.Stopped:Connect(function()
			conn:Disconnect()
			if isDashing then stopDash() end
		end)
	end

	-- Heartbeat: exponential decay velocity (burst cepat lalu smooth ke 0)
	local elapsed = 0
	dashConn = RunService.Heartbeat:Connect(function(dt)
		if not isDashing then
			dashConn:Disconnect()
			return
		end

		elapsed = elapsed + dt
		local t = math.clamp(elapsed / Config.DashDuration, 0, 1)

		-- Exponential decay: kecepatan turun cepat di akhir (seperti Genshin)
		local easeOut = 1 - (1 - t)^3
		local currentSpeed = Config.DashSpeed * (1 - easeOut)
		hrp.AssemblyLinearVelocity = Vector3.new(
			dir.X * currentSpeed,
			hrp.AssemblyLinearVelocity.Y,
			dir.Z * currentSpeed
		)

		-- Safety stop
		if elapsed >= Config.DashDuration then
			stopDash()
		end
	end)
end

-- ============================================
-- INPUT (Klik Kiri)
-- ============================================
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		startDash()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	-- Dash tidak bisa di-cancel dengan lepas klik (Genshin-like: dash langsung selesai sendiri)
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
	startDash()
end)

btn.MouseButton1Up:Connect(function()
	pressEffect(false)
	-- Dash tidak bisa di-cancel (selesai sendiri)
end)

-- ============================================
-- RESPAWN
-- ============================================
player.CharacterAdded:Connect(function(newChar)
	character   = newChar
	humanoid    = newChar:WaitForChild("Humanoid")
	animator    = humanoid:WaitForChild("Animator")
	hrp         = newChar:WaitForChild("HumanoidRootPart")

	isDashing   = false
	canDash     = true
	normalHip   = humanoid.HipHeight
	normalSpeed = humanoid.WalkSpeed

	if dashConn then
		dashConn:Disconnect()
		dashConn = nil
	end

	loadAnimation()
end)

print("[SlideController] ✅ Loaded langsung di LocalScript")