-- ============================================
-- CLIENT INIT — Dash + Double Jump + Sprint + Camera
-- ============================================

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local hrp       = character:WaitForChild("HumanoidRootPart")
local camera    = workspace.CurrentCamera

-- ============================================
-- KAMERA — Follow Cursor (Third Person)
-- ============================================
camera.CameraType = Enum.CameraType.Custom

local camDistance    = 15
local camSensitivity = 0.3
local camPitch       = math.rad(-15)
local camYaw         = 0
local camMinPitch    = math.rad(-70)
local camMaxPitch    = math.rad(80)
local cameraRoll     = 0
local cameraRollTarget = 0

UserInputService.MouseBehavior    = Enum.MouseBehavior.LockCenter
UserInputService.MouseIconEnabled = false

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		camYaw   = camYaw   - math.rad(input.Delta.X * camSensitivity)
		camPitch = camPitch - math.rad(input.Delta.Y * camSensitivity)
		camPitch = math.clamp(camPitch, camMinPitch, camMaxPitch)
	end
end)

RunService:BindToRenderStep("CameraUpdate", Enum.RenderPriority.Camera.Value + 1, function(dt)
	cameraRoll = cameraRoll + (cameraRollTarget - cameraRoll) * math.min(1, dt * 14)

	local camOffset = CFrame.new(hrp.Position)
		* CFrame.Angles(0, camYaw, 0)
		* CFrame.Angles(camPitch, 0, 0)
		* CFrame.new(0, 0, camDistance)

	camera.CFrame = CFrame.lookAt(camOffset.Position, hrp.Position + Vector3.new(0, 1.5, 0))
		* CFrame.Angles(0, 0, cameraRoll)
end)

-- ============================================
-- SPRINT
-- ============================================
local SPRINT_SPEED     = 30
local SPRINT_STAMINA   = 100
local SPRINT_DRAIN     = 20   -- per detik saat sprint
local SPRINT_REGEN     = 10   -- per detik saat tidak sprint

local normalSpeed   = humanoid.WalkSpeed
local sprintStamina = SPRINT_STAMINA
local isSprinting   = false

local function syncSprintState()
	character:SetAttribute("SprintManagedByInit", true)
	character:SetAttribute("SprintActive", isSprinting)
	character:SetAttribute("SprintStamina", sprintStamina)
	character:SetAttribute("SprintMaxStamina", SPRINT_STAMINA)
end

syncSprintState()

-- Sprint: LeftShift, RightShift, atau klik kanan
local function isSprintInput(input)
	return input.KeyCode == Enum.KeyCode.LeftShift
		or input.KeyCode == Enum.KeyCode.RightShift
		or input.UserInputType == Enum.UserInputType.MouseButton2
end

local function anySprintKeyHeld()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if isSprintInput(input) and sprintStamina > 0 then
		isSprinting = true
		syncSprintState()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if isSprintInput(input) then
		-- Hanya berhenti sprint jika SEMUA tombol sprint sudah dilepas
		if not anySprintKeyHeld() then
			isSprinting = false
			syncSprintState()
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	-- Jangan ubah speed kalau sedang dash (dihandle di bawah)
	if isDashing then return end

	if isSprinting and sprintStamina > 0 then
		humanoid.WalkSpeed = SPRINT_SPEED
		sprintStamina -= SPRINT_DRAIN * dt
	else
		humanoid.WalkSpeed = normalSpeed
		local flatVel  = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
		local isMoving = flatVel.Magnitude > 1
		sprintStamina += (isMoving and SPRINT_REGEN * 0.5 or SPRINT_REGEN) * dt
	end

	if sprintStamina <= 0 then
		sprintStamina = 0
		isSprinting   = false
		humanoid.WalkSpeed = normalSpeed
	end

	sprintStamina = math.clamp(sprintStamina, 0, SPRINT_STAMINA)
	syncSprintState()
end)

-- ============================================
-- DASH
-- ============================================
local DASH_SPEED       = 100   -- dinaikkan agar lebih jauh
local DASH_DURATION    = 0.55  -- durasi lebih panjang = jarak lebih jauh
local DASH_COOLDOWN    = 1.2
local MAX_DASH_CHARGES = 2
local DASH_TILT        = 12
local NORMAL_FOV       = 70
local DASH_FOV         = 95

local dashCharges  = MAX_DASH_CHARGES
local isDashing    = false
local dashConn     = nil
local activeDashForce = nil

local function setFOV(fov)
	TweenService:Create(camera, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
		FieldOfView = fov
	}):Play()
end

local function stopDash()
	if not isDashing then return end
	isDashing = false

	if dashConn then
		dashConn:Disconnect()
		dashConn = nil
	end

	if activeDashForce then
		activeDashForce:Destroy()
		activeDashForce = nil
	end

	cameraRollTarget = 0
	setFOV(NORMAL_FOV)
	-- Kembalikan speed ke sprint atau normal
	humanoid.WalkSpeed = isSprinting and SPRINT_SPEED or normalSpeed
end

local function startDash()
	if dashCharges <= 0 then return end

	if isDashing then
		if dashConn then dashConn:Disconnect(); dashConn = nil end
		if activeDashForce then activeDashForce:Destroy(); activeDashForce = nil end
		isDashing = false
	end

	-- Kurangi charge & jadwalkan regen
	dashCharges -= 1
	task.delay(DASH_COOLDOWN, function()
		dashCharges = math.min(dashCharges + 1, MAX_DASH_CHARGES)
	end)

	isDashing = true

	-- Arah dash: ikut velocity player atau arah kamera
	local vel     = hrp.AssemblyLinearVelocity
	local flatVel = Vector3.new(vel.X, 0, vel.Z)
	local dir

	if flatVel.Magnitude > 0.5 then
		dir = flatVel.Unit
	else
		dir = Vector3.new(-math.sin(camYaw), 0, -math.cos(camYaw))
	end

	-- Paksa karakter menghadap arah dash
	hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.atan2(-dir.X, -dir.Z), 0)

	cameraRollTarget = math.rad(DASH_TILT)
	setFOV(DASH_FOV)

	-- Gunakan BodyVelocity agar tidak dilawan humanoid
	local bv = Instance.new("BodyVelocity")
	bv.Velocity = Vector3.new(dir.X * DASH_SPEED, 0, dir.Z * DASH_SPEED)
	bv.MaxForce = Vector3.new(1e5, 0, 1e5)  -- hanya X & Z, Y bebas (gravity tetap)
	bv.Name = "DashForce"
	bv.Parent = hrp
	activeDashForce = bv

	local elapsed = 0
	dashConn = RunService.Heartbeat:Connect(function(dt)
		if not isDashing then
			dashConn:Disconnect()
			if bv.Parent then
				bv:Destroy()
			end
			if activeDashForce == bv then
				activeDashForce = nil
			end
			return
		end

		elapsed += dt
		local t       = math.clamp(elapsed / DASH_DURATION, 0, 1)
		local easeOut = 1 - (1 - t) ^ 3
		local spd     = DASH_SPEED * (1 - easeOut)

		if bv and bv.Parent then
			bv.Velocity = Vector3.new(dir.X * spd, 0, dir.Z * spd)
		end

		if elapsed >= DASH_DURATION then
			stopDash()
		end
	end)

	print("[Dash] ▶ Dash! Charge tersisa: " .. dashCharges)
end

-- Keyboard: E, atau klik kiri untuk dash
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E
		or input.UserInputType == Enum.UserInputType.MouseButton1 then
		startDash()
	end
end)

-- ============================================
-- DASH UI (Mobile)
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
dashIcon.Size     = UDim2.new(1, 0, 0.55, 0)
dashIcon.Position = UDim2.new(0, 0, 0.08, 0)
dashIcon.BackgroundTransparency = 1
dashIcon.Text      = "»»"
dashIcon.TextColor3 = Color3.fromRGB(120, 200, 255)
dashIcon.TextScaled = true
dashIcon.Font = Enum.Font.GothamBold

local dashLbl = Instance.new("TextLabel", dashBtn)
dashLbl.Size     = UDim2.new(1, 0, 0.3, 0)
dashLbl.Position = UDim2.new(0, 0, 0.65, 0)
dashLbl.BackgroundTransparency = 1
dashLbl.Text      = "DASH"
dashLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
dashLbl.TextScaled = true
dashLbl.Font = Enum.Font.GothamBold

-- Charge dots
local chargeBar = Instance.new("Frame", dashBtn)
chargeBar.Size = UDim2.new(0.8, 0, 0.08, 0)
chargeBar.Position = UDim2.new(0.1, 0, 0, -12)
chargeBar.BackgroundTransparency = 1

local chargeDots = {}
for i = 1, MAX_DASH_CHARGES do
	local dot = Instance.new("Frame", chargeBar)
	dot.Size     = UDim2.new(1/MAX_DASH_CHARGES - 0.05, 0, 1, 0)
	dot.Position = UDim2.new((i-1)/MAX_DASH_CHARGES + 0.025, 0, 0, 0)
	dot.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
	dot.BorderSizePixel = 0
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	chargeDots[i] = dot
end

RunService.Heartbeat:Connect(function()
	for i, dot in ipairs(chargeDots) do
		dot.BackgroundColor3    = i <= dashCharges and Color3.fromRGB(100, 200, 255) or Color3.fromRGB(60, 80, 100)
		dot.BackgroundTransparency = i <= dashCharges and 0 or 0.6
	end
end)

dashBtn.MouseButton1Down:Connect(function()
	TweenService:Create(dashBtn, TweenInfo.new(0.08), { Size = UDim2.new(0, 70, 0, 70) }):Play()
	startDash()
end)
dashBtn.MouseButton1Up:Connect(function()
	TweenService:Create(dashBtn, TweenInfo.new(0.08), { Size = UDim2.new(0, 80, 0, 80) }):Play()
end)

-- ============================================
-- DOUBLE JUMP
-- Bebas lompat selama belum menyentuh tanah/platform
-- Reset via Raycast (lebih andal dari StateChanged)
-- ============================================
local MAX_JUMPS  = 2
local jumpCount  = 0
-- Pakai humanoid.JumpPower agar otomatis sesuai setting game
local JUMP_POWER = humanoid.JumpPower > 0 and humanoid.JumpPower or 50

-- Raycast ke bawah untuk cek apakah di tanah
local function isOnGround()
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = { character }
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	-- Jarak 4.5 studs ke bawah (cukup untuk karakter R6 & R15)
	local result = workspace:Raycast(hrp.Position, Vector3.new(0, -4.5, 0), rayParams)
	return result ~= nil
end

-- Reset jumpCount setiap frame jika terdeteksi di tanah
-- Ini lebih andal dari StateChanged karena tidak ada race condition
RunService.Heartbeat:Connect(function()
	-- Hanya reset kalau velocity Y tidak sedang naik (sedang lompat ke atas)
	if isOnGround() and hrp.AssemblyLinearVelocity.Y <= 1 then
		jumpCount = 0
	end
end)

-- Fungsi jump terpusat
local function doJump()
	hrp.AssemblyLinearVelocity = Vector3.new(
		hrp.AssemblyLinearVelocity.X,
		JUMP_POWER,
		hrp.AssemblyLinearVelocity.Z
	)
	jumpCount += 1
end

-- Fungsi yang dipanggil oleh semua trigger jump
local function tryJump()
	if jumpCount < MAX_JUMPS then
		doJump()
	end
end

-- Space / default jump
UserInputService.JumpRequest:Connect(tryJump)

-- Klik tengah mouse — TANPA cek processed agar tidak diblokir oleh LockCenter
UserInputService.InputBegan:Connect(function(input)
	-- Sengaja tidak pakai 'processed' untuk mouse buttons
	-- karena LockCenter sering menandai klik sebagai processed
	if input.UserInputType == Enum.UserInputType.MouseButton3 then
		tryJump()
	end
end)

-- ============================================
-- RESPAWN — Reset semua state
-- ============================================
player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoid  = newChar:WaitForChild("Humanoid")
	hrp       = newChar:WaitForChild("HumanoidRootPart")

	-- Reset Dash
	isDashing    = false
	dashCharges  = MAX_DASH_CHARGES
	normalSpeed  = humanoid.WalkSpeed
	if dashConn then dashConn:Disconnect(); dashConn = nil end
	if activeDashForce then
		activeDashForce:Destroy()
		activeDashForce = nil
	end
	-- Cleanup BodyVelocity yang mungkin tertinggal
	local oldBV = hrp:FindFirstChild("DashForce")
	if oldBV then oldBV:Destroy() end

	-- Reset Double Jump
	jumpCount  = 0
	isAirborne = false

	-- Reset Sprint
	isSprinting   = false
	sprintStamina = SPRINT_STAMINA
	normalSpeed   = humanoid.WalkSpeed
	syncSprintState()

	-- Reset camera
	cameraRoll       = 0
	cameraRollTarget = 0

	-- Pasang ulang StateChanged
	humanoid.StateChanged:Connect(function(old, new)
		if new == Enum.HumanoidStateType.Jumping or new == Enum.HumanoidStateType.FreeFall then
			isAirborne = true
		elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			jumpCount  = 0
			isAirborne = false
		end
	end)
end)

print("[Client Init] ✅ Dash (E / tombol UI) + Double Jump + Sprint (Shift) + Camera loaded")
