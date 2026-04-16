local character = script.Parent

local humanoid = character:WaitForChild("Humanoid")

local UIS = game:GetService("UserInputService")

local RunService = game:GetService("RunService")

-- STATE SYSTEM

character:SetAttribute("IsBusy", false)

-- DOUBLE JUMP

local NumJumps = 0

local canjump = false

local maxJump = 2

local JumpCooldown = 0.2

-- SPRINT + STAMINA

local normalSpeed = 16

local sprintSpeed = 30

local stamina = 100

local maxStamina = 100

local drain = 20

local regen = 10

local sprinting = false
local stamina   = maxStamina

-- FIX #4: Baca normalSpeed dari Humanoid langsung,
--         bukan hardcode angka 16
local normalSpeed = humanoid.WalkSpeed

-- ============================================
-- DOUBLE JUMP
-- ============================================

-- FIX #1 (bagian 1): Reset jumpCount saat Landed
humanoid.StateChanged:Connect(function(old, new)
	if new == Enum.HumanoidStateType.Landed then
		jumpCount = 0
	end
end)

-- FIX #1 (bagian 2): Fallback reset jumpCount lewat RaycastDown
-- Kalau state Landed tidak terpicu (misal kena tepi platform),
-- script tetap tahu kalau karakter sudah di tanah
local function isOnGround()
	local rayOrigin    = root.Position
	local rayDirection = Vector3.new(0, -3.5, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	return result ~= nil
end

UIS.JumpRequest:Connect(function()
	if jumpCount < maxJump then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		jumpCount += 1
	end
end)

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end

	-- FIX #2: Cek stamina > 0 tetap di sini,
	--         dan juga akan dicek terus di RenderStepped
	if input.KeyCode == Enum.KeyCode.LeftShift and stamina > 0 then
		sprinting = true
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = false
		humanoid.WalkSpeed = normalSpeed
	end
end)

-- =====================
-- STAMINA UI
-- =====================
local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StaminaUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.new(0, 200, 0, 18)
bg.Position = UDim2.new(0.05, 0, 0.9, 0)
bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
bg.BorderSizePixel = 0
bg.Parent = screenGui

local fill = Instance.new("Frame")
fill.Size = UDim2.new(1, 0, 1, 0)
fill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
fill.BorderSizePixel = 0
fill.Parent = bg

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = bg

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 6)
fillCorner.Parent = fill

RunService.RenderStepped:Connect(function(dt)

	-- FIX #1 (bagian 2 lanjutan): Kalau di tanah, reset jumpCount
	if isOnGround() and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
		jumpCount = 0
	end

	-- FIX #4: Update normalSpeed kalau ada script lain yang ubah WalkSpeed
	--         (hanya update saat tidak sprint agar tidak konflik)
	if not sprinting then
		normalSpeed = humanoid.WalkSpeed
	end

if sprinting and stamina > 0 then

	humanoid.WalkSpeed = sprintSpeed

	stamina -= drain * dt

else

	humanoid.WalkSpeed = normalSpeed

	stamina += regen * dt

end



if stamina <= 0 then

	stamina = 0

	sprinting = false

end



	stamina = math.clamp(stamina, 0, maxStamina)
end)

-- ============================================
-- RESPAWN: Reset state saat karakter respawn
-- ============================================
player.CharacterAdded:Connect(function(newChar)
	character    = newChar
	humanoid     = newChar:WaitForChild("Humanoid")
	root         = newChar:WaitForChild("HumanoidRootPart")
	normalSpeed  = humanoid.WalkSpeed

	jumpCount = 0
	sprinting = false
	stamina   = maxStamina

	-- Pasang ulang listener StateChanged untuk karakter baru
	humanoid.StateChanged:Connect(function(old, new)
		if new == Enum.HumanoidStateType.Landed then
			jumpCount = 0
		end
	end)
end)

print("[DoubleJump & Sprint - Naura] ✅ Loaded")