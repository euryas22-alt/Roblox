-- ============================================
-- GENSHIN-STYLE DOUBLE DASH SYSTEM
-- 2 charge | per-charge cooldown | no stamina | no animation
-- ============================================

-- SERVICES
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
-- CONFIG
-- ============================================
local Config = {
	DashSpeed       = 65,    -- burst speed awal (studs/s)
	DashDuration    = 0.35,  -- durasi setiap dash (detik)
	DashCooldown    = 1.2,   -- waktu cooldown per charge (detik)
	MaxDashCharges  = 2,     -- max charge (seperti Genshin: 2x dash)
	CameraTiltAngle = 12,    -- kemiringan kamera saat dash
	NormalFOV       = 70,    -- FOV normal
	DashFOV         = 90,    -- FOV saat dash (efek kecepatan)
}

-- ============================================
-- STATE
-- ============================================
local dashCharges  = Config.MaxDashCharges  -- charge saat ini
local isDashing    = false
local dashConn     = nil
local normalSpeed  = humanoid.WalkSpeed

-- Camera roll state
local cameraRoll       = 0
local cameraRollTarget = 0

-- ============================================
-- CAMERA ROLL — berjalan SETELAH camera controller Roblox
-- sehingga kamera tetap mengikuti player
-- ============================================
RunService:BindToRenderStep("DashCameraRoll", Enum.RenderPriority.Camera.Value + 1, function(dt)
	cameraRoll = cameraRoll + (cameraRollTarget - cameraRoll) * math.min(1, dt * 14)
	if math.abs(cameraRoll) > 0.0005 then
		camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, cameraRoll)
	end
end)

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

local function setTargetRoll(angle)
	cameraRollTarget = math.rad(angle)
end

local function setFOV(fov)
	TweenService:Create(camera, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
		FieldOfView = fov
	}):Play()
end

-- I-frames: matikan collision semua limb selama dash
local function setCollision(enabled)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = enabled
		end
	end
end

-- Konsumsi 1 charge dan jadwalkan regen-nya
local function consumeCharge()
	dashCharges = dashCharges - 1
	task.delay(Config.DashCooldown, function()
		dashCharges = math.min(dashCharges + 1, Config.MaxDashCharges)
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

	-- Kembalikan state
	setCollision(true)
	setTargetRoll(0)
	setFOV(Config.NormalFOV)
	humanoid.WalkSpeed = normalSpeed
end

local function startDash()
	if dashCharges <= 0 then return end

	-- Jika sedang dash, cancel dulu (Genshin: dash bisa di-chain)
	if isDashing then
		if dashConn then
			dashConn:Disconnect()
			dashConn = nil
		end
		isDashing = false
	end

	consumeCharge()
	isDashing = true

	-- Arah dash: ikut velocity atau depan kamera jika diam
	local vel     = hrp.AssemblyLinearVelocity
	local flatVel = Vector3.new(vel.X, 0, vel.Z)
	local dir
	if flatVel.Magnitude > 0.1 then
		dir = flatVel.Unit
	else
		local look = camera.CFrame.LookVector
		dir = Vector3.new(look.X, 0, look.Z).Unit
	end

	-- Set state dash
	humanoid.WalkSpeed = 0
	setCollision(false)
	setTargetRoll(Config.CameraTiltAngle)
	setFOV(Config.DashFOV)

	-- Burst velocity awal
	hrp.AssemblyLinearVelocity = Vector3.new(
		dir.X * Config.DashSpeed,
		hrp.AssemblyLinearVelocity.Y,
		dir.Z * Config.DashSpeed
	)

	-- Heartbeat: exponential decay velocity (Genshin feel)
	local elapsed = 0
	dashConn = RunService.Heartbeat:Connect(function(dt)
		if not isDashing then
			dashConn:Disconnect()
			return
		end

		elapsed = elapsed + dt
		local t = math.clamp(elapsed / Config.DashDuration, 0, 1)

		-- Cubic ease-out: cepat di awal, smooth di akhir
		local easeOut = 1 - (1 - t) ^ 3
		local currentSpeed = Config.DashSpeed * (1 - easeOut)
		hrp.AssemblyLinearVelocity = Vector3.new(
			dir.X * currentSpeed,
			hrp.AssemblyLinearVelocity.Y,
			dir.Z * currentSpeed
		)

		if elapsed >= Config.DashDuration then
			stopDash()
		end
	end)
end

-- ============================================
-- INPUT — Klik Kiri
-- ============================================
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		startDash()
	end
end)

-- ============================================
-- MOBILE UI — Tombol DASH
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
btn.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
btn.BackgroundTransparency = 0.2
btn.Parent = gui

Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

local stroke = Instance.new("UIStroke", btn)
stroke.Color = Color3.fromRGB(100, 180, 255)
stroke.Thickness = 2.5

local icon = Instance.new("TextLabel", btn)
icon.Size = UDim2.new(1, 0, 0.55, 0)
icon.Position = UDim2.new(0, 0, 0.08, 0)
icon.BackgroundTransparency = 1
icon.Text = "»»"
icon.TextColor3 = Color3.fromRGB(120, 200, 255)
icon.TextScaled = true
icon.Font = Enum.Font.GothamBold

local lbl = Instance.new("TextLabel", btn)
lbl.Size = UDim2.new(1, 0, 0.3, 0)
lbl.Position = UDim2.new(0, 0, 0.65, 0)
lbl.BackgroundTransparency = 1
lbl.Text = "DASH"
lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
lbl.TextScaled = true
lbl.Font = Enum.Font.GothamBold

-- Charge indicator (2 titik = 2 charge)
local chargeBar = Instance.new("Frame", btn)
chargeBar.Size = UDim2.new(0.8, 0, 0.08, 0)
chargeBar.Position = UDim2.new(0.1, 0, 0, -12)
chargeBar.BackgroundTransparency = 1

local chargeDots = {}
for i = 1, Config.MaxDashCharges do
	local dot = Instance.new("Frame", chargeBar)
	dot.Size = UDim2.new(1 / Config.MaxDashCharges - 0.05, 0, 1, 0)
	dot.Position = UDim2.new((i - 1) / Config.MaxDashCharges + 0.025, 0, 0, 0)
	dot.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
	dot.BorderSizePixel = 0
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	chargeDots[i] = dot
end

-- Update warna dot sesuai charge tersisa
RunService.Heartbeat:Connect(function()
	for i, dot in ipairs(chargeDots) do
		if i <= dashCharges then
			dot.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
			dot.BackgroundTransparency = 0
		else
			dot.BackgroundTransparency = 0.6
			dot.BackgroundColor3 = Color3.fromRGB(60, 80, 100)
		end
	end
end)

local function pressEffect(pressing)
	TweenService:Create(btn, TweenInfo.new(0.08), {
		Size = pressing and UDim2.new(0, 70, 0, 70) or UDim2.new(0, 80, 0, 80),
		BackgroundTransparency = pressing and 0.05 or 0.2
	}):Play()
end

btn.MouseButton1Down:Connect(function()
	pressEffect(true)
	startDash()
end)

btn.MouseButton1Up:Connect(function()
	pressEffect(false)
end)

-- ============================================
-- RESPAWN — reset state
-- ============================================
player.CharacterAdded:Connect(function(newChar)
	character   = newChar
	humanoid    = newChar:WaitForChild("Humanoid")
	hrp         = newChar:WaitForChild("HumanoidRootPart")

	isDashing    = false
	dashCharges  = Config.MaxDashCharges
	normalSpeed  = humanoid.WalkSpeed

	if dashConn then
		dashConn:Disconnect()
		dashConn = nil
	end
end)

print("[DashSystem] ✅ Genshin Double Dash loaded — " .. Config.MaxDashCharges .. " charges")