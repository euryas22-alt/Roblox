-- ============================================
-- CLIENT INIT — Dash + Double Jump + Sprint + Camera
-- ============================================

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local hrp       = character:WaitForChild("HumanoidRootPart")
local camera    = workspace.CurrentCamera

-- ============================================
-- KAMERA — Follow Cursor (Third Person)
-- ============================================
camera.CameraType = Enum.CameraType.Custom

local camDistance   = 15    -- jarak kamera dari player
local camSensitivity = 0.3  -- sensitivitas mouse
local camPitch      = math.rad(-15) -- sudut atas-bawah awal
local camYaw        = 0             -- sudut kiri-kanan awal
local camMinPitch   = math.rad(-70)
local camMaxPitch   = math.rad(80)

-- Kunci & sembunyikan cursor
UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
UserInputService.MouseIconEnabled = false

-- Rotasi kamera berdasarkan gerakan mouse
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local dx = input.Delta.X
		local dy = input.Delta.Y

		camYaw   = camYaw   - math.rad(dx * camSensitivity)
		camPitch = camPitch - math.rad(dy * camSensitivity)
		camPitch = math.clamp(camPitch, camMinPitch, camMaxPitch)
	end
end)

-- Update posisi kamera setiap frame
local cameraRoll       = 0
local cameraRollTarget = 0

RunService:BindToRenderStep("CameraUpdate", Enum.RenderPriority.Camera.Value + 1, function(dt)
	-- Smooth camera roll (efek saat dash)
	cameraRoll = cameraRoll + (cameraRollTarget - cameraRoll) * math.min(1, dt * 14)

	-- Hitung posisi kamera
	local camOffset = CFrame.new(hrp.Position)
		* CFrame.Angles(0, camYaw, 0)
		* CFrame.Angles(camPitch, 0, 0)
		* CFrame.Angles(0, 0, cameraRoll)
		* CFrame.new(0, 0, camDistance)

	camera.CFrame = CFrame.lookAt(camOffset.Position, hrp.Position + Vector3.new(0, 1.5, 0))
		* CFrame.Angles(0, 0, cameraRoll)
end)

-- ============================================
-- DASH CONFIG & STATE
-- ============================================
local DashConfig = {
	DashSpeed       = 65,
	DashDuration    = 0.35,
	DashCooldown    = 1.2,
	MaxDashCharges  = 2,
	CameraTiltAngle = 12,
	NormalFOV       = 70,
	DashFOV         = 90,
}

local dashCharges  = DashConfig.MaxDashCharges
local isDashing    = false
local dashConn     = nil
local normalSpeed  = humanoid.WalkSpeed

-- ============================================
-- DASH HELPERS
-- ============================================
local function setFOV(fov)
	TweenService:Create(camera, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
		FieldOfView = fov
	}):Play()
end

local function setCollision(enabled)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = enabled
		end
	end
end

local function consumeCharge()
	dashCharges -= 1
	task.delay(DashConfig.DashCooldown, function()
		dashCharges = math.min(dashCharges + 1, DashConfig.MaxDashCharges)
	end)
end

-- ============================================
-- DASH CORE
-- ============================================
local function stopDash()
	if not isDashing then return end
	isDashing = false

	if dashConn then
		dashConn:Disconnect()
		dashConn = nil
	end

	setCollision(true)
	cameraRollTarget = 0
	setFOV(DashConfig.NormalFOV)
	humanoid.WalkSpeed = normalSpeed
end

local function startDash()
	if dashCharges <= 0 then
		print("[Dash] Tidak ada charge tersisa!")
		return
	end

	-- Chain dash: cancel dash sebelumnya dulu
	if isDashing then
		if dashConn then dashConn:Disconnect(); dashConn = nil end
		isDashing = false
	end

	consumeCharge()
	isDashing = true

	-- Arah dash: ikut velocity atau arah pandang kamera
	local vel     = hrp.AssemblyLinearVelocity
	local flatVel = Vector3.new(vel.X, 0, vel.Z)
	local dir

	if flatVel.Magnitude > 0.5 then
		dir = flatVel.Unit
	else
		-- Ikut arah yaw kamera
		local camForward = Vector3.new(
			-math.sin(camYaw), 0, -math.cos(camYaw)
		)
		dir = camForward
	end

	humanoid.WalkSpeed = 0
	setCollision(false)
	cameraRollTarget = math.rad(DashConfig.CameraTiltAngle)
	setFOV(DashConfig.DashFOV)

	-- Burst velocity
	hrp.AssemblyLinearVelocity = Vector3.new(
		dir.X * DashConfig.DashSpeed,
		hrp.AssemblyLinearVelocity.Y,
		dir.Z * DashConfig.DashSpeed
	)

	-- Velocity decay (cubic ease-out, Genshin feel)
	local elapsed = 0
	dashConn = RunService.Heartbeat:Connect(function(dt)
		if not isDashing then
			dashConn:Disconnect()
			return
		end

		elapsed += dt
		local t       = math.clamp(elapsed / DashConfig.DashDuration, 0, 1)
		local easeOut = 1 - (1 - t) ^ 3
		local spd     = DashConfig.DashSpeed * (1 - easeOut)

		hrp.AssemblyLinearVelocity = Vector3.new(
			dir.X * spd,
			hrp.AssemblyLinearVelocity.Y,
			dir.Z * spd
		)

		if elapsed >= DashConfig.DashDuration then
			stopDash()
		end
	end)

	print("[Dash] ▶ Dash digunakan! Charge tersisa: " .. dashCharges)
end

-- ============================================
-- DASH — Mobile UI
-- ============================================
local dashGui = Instance.new("ScreenGui")
dashGui.Name = "DashGui"
dashGui.ResetOnSpawn = false
dashGui.IgnoreGuiInset = true
dashGui.Parent = player.PlayerGui

local dashBtn = Instance.new("ImageButton")
dashBtn.Size = UDim2.new(0, 80, 0, 80)
dashBtn.Position = UDim2.new(1, -100, 1, -130)
dashBtn.AnchorPoint = Vector2.new(0.5, 0.5)
dashBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
dashBtn.BackgroundTransparency = 0.2
dashBtn.Parent = dashGui

Instance.new("UICorner", dashBtn).CornerRadius = UDim.new(1, 0)
local dashStroke = Instance.new("UIStroke", dashBtn)
dashStroke.Color = Color3.fromRGB(100, 180, 255)
dashStroke.Thickness = 2.5

local dashIcon = Instance.new("TextLabel", dashBtn)
dashIcon.Size = UDim2.new(1, 0, 0.55, 0)
dashIcon.Position = UDim2.new(0, 0, 0.08, 0)
dashIcon.BackgroundTransparency = 1
dashIcon.Text = "»»"
dashIcon.TextColor3 = Color3.fromRGB(120, 200, 255)
dashIcon.TextScaled = true
dashIcon.Font = Enum.Font.GothamBold

local dashLbl = Instance.new("TextLabel", dashBtn)
dashLbl.Size = UDim2.new(1, 0, 0.3, 0)
dashLbl.Position = UDim2.new(0, 0, 0.65, 0)
dashLbl.BackgroundTransparency = 1
dashLbl.Text = "DASH"
dashLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
dashLbl.TextScaled = true
dashLbl.Font = Enum.Font.GothamBold

-- Charge dots
local chargeBar = Instance.new("Frame", dashBtn)
chargeBar.Size = UDim2.new(0.8, 0, 0.08, 0)
chargeBar.Position = UDim2.new(0.1, 0, 0, -12)
chargeBar.BackgroundTransparency = 1

local chargeDots = {}
for i = 1, DashConfig.MaxDashCharges do
	local dot = Instance.new("Frame", chargeBar)
	dot.Size = UDim2.new(1/DashConfig.MaxDashCharges - 0.05, 0, 1, 0)
	dot.Position = UDim2.new((i-1)/DashConfig.MaxDashCharges + 0.025, 0, 0, 0)
	dot.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
	dot.BorderSizePixel = 0
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	chargeDots[i] = dot
end

RunService.Heartbeat:Connect(function()
	for i, dot in ipairs(chargeDots) do
		if i <= dashCharges then
			dot.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
			dot.BackgroundTransparency = 0
		else
			dot.BackgroundColor3 = Color3.fromRGB(60, 80, 100)
			dot.BackgroundTransparency = 0.6
		end
	end
end)

local function dashPressEffect(pressing)
	TweenService:Create(dashBtn, TweenInfo.new(0.08), {
		Size = pressing and UDim2.new(0, 70, 0, 70) or UDim2.new(0, 80, 0, 80),
		BackgroundTransparency = pressing and 0.05 or 0.2
	}):Play()
end

dashBtn.MouseButton1Down:Connect(function()
	dashPressEffect(true)
	startDash()
end)
dashBtn.MouseButton1Up:Connect(function()
	dashPressEffect(false)
end)

-- ============================================
-- DOUBLE JUMP (Cooldown-based, tidak perlu menyentuh tanah)
-- ============================================
local DOUBLE_JUMP_COOLDOWN = 2   -- detik cooldown setelah double jump dipakai
local jumpCount     = 0          -- 0 = belum lompat, 1 = sudah lompat 1x, 2 = sudah double jump
local canDoubleJump = true       -- apakah double jump bisa dipakai
local djCooldownThread = nil     -- referensi cooldown agar bisa dibatalkan

-- Indikator cooldown di UI
local djGui = Instance.new("ScreenGui")
djGui.Name = "DoubleJumpGui"
djGui.ResetOnSpawn = false
djGui.IgnoreGuiInset = true
djGui.Parent = player.PlayerGui

local djIndicator = Instance.new("Frame")
djIndicator.Size = UDim2.new(0, 60, 0, 8)
djIndicator.Position = UDim2.new(0.5, -30, 0, 12)
djIndicator.BackgroundColor3 = Color3.fromRGB(255, 230, 80)
djIndicator.BorderSizePixel = 0
djIndicator.Parent = djGui
Instance.new("UICorner", djIndicator).CornerRadius = UDim.new(1, 0)

local djLabel = Instance.new("TextLabel")
djLabel.Size = UDim2.new(1, 0, 0, 18)
djLabel.Position = UDim2.new(0, 0, 1, 2)
djLabel.BackgroundTransparency = 1
djLabel.Text = "DOUBLE JUMP"
djLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
djLabel.TextScaled = true
djLabel.Font = Enum.Font.GothamBold
djLabel.Parent = djIndicator

-- Update bar indikator setiap frame
local djCooldownProgress = 1  -- 0 = cooldown, 1 = siap
RunService.Heartbeat:Connect(function()
	if canDoubleJump then
		djCooldownProgress = 1
		djIndicator.BackgroundColor3 = Color3.fromRGB(255, 230, 80)
		djLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
	else
		djIndicator.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		djLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
	end
	djIndicator.Size = UDim2.new(0, 60 * djCooldownProgress, 0, 8)
end)

local function startDoubleJumpCooldown()
	canDoubleJump = false
	djCooldownProgress = 0

	-- Cancel cooldown sebelumnya jika ada
	if djCooldownThread then
		task.cancel(djCooldownThread)
		djCooldownThread = nil
	end

	-- Animasikan progress bar cooldown
	local elapsed = 0
	djCooldownThread = task.spawn(function()
		while elapsed < DOUBLE_JUMP_COOLDOWN do
			elapsed += task.wait()
			djCooldownProgress = math.clamp(elapsed / DOUBLE_JUMP_COOLDOWN, 0, 1)
		end
		-- Cooldown selesai — aktifkan kembali
		canDoubleJump = true
		djCooldownProgress = 1
		-- Reset jumpCount ke 1 agar double jump bisa dipakai lagi
		-- (jumpCount 0 = bisa lompat biasa juga, 1 = sudah lompat 1x di udara)
		if jumpCount >= 2 then
			jumpCount = 1
		end
		print("[DoubleJump] ✅ Double jump siap digunakan lagi!")
	end)
end

-- Reset saat mendarat
humanoid.StateChanged:Connect(function(old, new)
	if new == Enum.HumanoidStateType.Landed then
		jumpCount = 0
		-- Batalkan cooldown, langsung siap
		canDoubleJump = true
		djCooldownProgress = 1
		if djCooldownThread then
			task.cancel(djCooldownThread)
			djCooldownThread = nil
		end
	end
end)

local function isOnGround()
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude
	return workspace:Raycast(hrp.Position, Vector3.new(0, -3.5, 0), params) ~= nil
end

UserInputService.JumpRequest:Connect(function()
	if jumpCount == 0 then
		-- Lompat pertama: biarkan Roblox tangani, hanya catat
		jumpCount = 1

	elseif jumpCount == 1 and canDoubleJump then
		-- Double jump!
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		jumpCount = 2
		startDoubleJumpCooldown()
		print("[DoubleJump] ⬆⬆ Double jump! Cooldown " .. DOUBLE_JUMP_COOLDOWN .. "s")
	end
end)


-- ============================================
-- SPRINT INPUT
-- ============================================
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	-- Dash via keyboard (E)
	if input.KeyCode == Enum.KeyCode.E then
		startDash()
		return
	end

	-- Sprint
	if input.KeyCode == Enum.KeyCode.LeftShift and sprintStamina > 0 then
		isSprinting = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		isSprinting = false
		if not isDashing then
			humanoid.WalkSpeed = jumpNormalSpeed
		end
	end
end)

-- ============================================
-- STAMINA + SPRINT LOOP
-- ============================================
RunService.RenderStepped:Connect(function(dt)
	-- Reset jumpCount fallback via raycast
	if isOnGround() and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
		jumpCount = 0
	end

	-- Update normalSpeed dinamis
	if not isSprinting and not isDashing then
		jumpNormalSpeed = humanoid.WalkSpeed
	end

	if isSprinting and sprintStamina > 0 then
		if not isDashing then
			humanoid.WalkSpeed = sprintSpeed
		end
		sprintStamina -= sprintDrainRate * dt
	else
		local flatVel  = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
		local isMoving = flatVel.Magnitude > 1
		sprintStamina += (isMoving and sprintRegenRate * 0.5 or sprintRegenRate) * dt

		if not isDashing then
			humanoid.WalkSpeed = jumpNormalSpeed
		end
	end

	if sprintStamina <= 0 then
		sprintStamina = 0
		isSprinting   = false
		if not isDashing then
			humanoid.WalkSpeed = jumpNormalSpeed
		end
	end

	sprintStamina = math.clamp(sprintStamina, 0, sprintMaxStamina)
end)

-- ============================================
-- RESPAWN — Reset semua state
-- ============================================
player.CharacterAdded:Connect(function(newChar)
	character   = newChar
	humanoid    = newChar:WaitForChild("Humanoid")
	hrp         = newChar:WaitForChild("HumanoidRootPart")

	-- Reset Dash
	isDashing    = false
	dashCharges  = DashConfig.MaxDashCharges
	normalSpeed  = humanoid.WalkSpeed
	if dashConn then dashConn:Disconnect(); dashConn = nil end

	-- Reset Double Jump
	jumpCount        = 0
	canDoubleJump    = true
	djCooldownProgress = 1
	if djCooldownThread then
		task.cancel(djCooldownThread)
		djCooldownThread = nil
	end

	-- Reset Sprint
	isSprinting     = false
	sprintStamina   = sprintMaxStamina
	jumpNormalSpeed = humanoid.WalkSpeed

	-- Reset camera roll
	cameraRoll       = 0
	cameraRollTarget = 0

	-- Pasang ulang StateChanged untuk karakter baru
	humanoid.StateChanged:Connect(function(old, new)
		if new == Enum.HumanoidStateType.Landed then
			-- Mendarat: reset semua, batalkan cooldown
			jumpCount = 0
			canDoubleJump = true
			djCooldownProgress = 1
			if djCooldownThread then
				task.cancel(djCooldownThread)
				djCooldownThread = nil
			end
		end
	end)
end)

print("[Client Init] ✅ Dash + Double Jump + Sprint + Camera loaded")