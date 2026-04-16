-- ============================================
-- FIX #5: Ambil karakter lewat LocalPlayer,
--         bukan script.Parent agar aman di mana saja
-- ============================================
local Players  = game:GetService("Players")
local UIS      = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local root      = character:WaitForChild("HumanoidRootPart")

-- ============================================
-- SETTINGS
-- ============================================
local maxJump    = 2
local sprintSpeed = 30
local maxStamina  = 100
local drain       = 20  -- stamina berkurang per detik saat sprint
local regen       = 10  -- stamina pulih per detik saat tidak sprint

-- ============================================
-- STATE
-- ============================================
local jumpCount = 0
local sprinting = false
local stamina   = maxStamina
local lastJumpTime = 0

-- FIX #4: Baca normalSpeed dari Humanoid langsung,
--         bukan hardcode angka 16
local normalSpeed = humanoid.WalkSpeed

local function isSprintHandledByInit()
	return character:GetAttribute("SprintManagedByInit") == true
end

local function syncLocalSprintState()
	character:SetAttribute("SprintActive", sprinting)
	character:SetAttribute("SprintStamina", stamina)
	character:SetAttribute("SprintMaxStamina", maxStamina)
end

syncLocalSprintState()

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
	local now = os.clock()
	
	-- Mencegah spam jump dari tombol yang ditahan
	if now - lastJumpTime < 0.25 then return end
	
	local state = humanoid:GetState()
	
	-- Kasus 1: Melompat pertama kali saat di tanah
	if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed or isOnGround() then
		lastJumpTime = now
		jumpCount = 1
		return
	end
	
	-- Kasus 2: Melompat di udara dalam segala kondisi (Freefall, dll)
	if jumpCount < maxJump then
		lastJumpTime = now
		jumpCount += 1
		
		-- Paksa pemutaran animasi lompat
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		
		-- Berikan velocity manual (gaya angkat ke atas minimal sesuai JumpPower/Height)
		local jumpVel = humanoid.UseJumpPower and humanoid.JumpPower or math.sqrt(2 * workspace.Gravity * humanoid.JumpHeight)
		local currentVel = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(currentVel.X, jumpVel, currentVel.Z)
	end
end)

-- ============================================
-- SPRINT
-- ============================================

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if isSprintHandledByInit() then return end

	-- FIX #2: Cek stamina > 0 tetap di sini,
	--         dan juga akan dicek terus di RenderStepped
	if input.KeyCode == Enum.KeyCode.LeftShift and stamina > 0 then
		sprinting = true
		syncLocalSprintState()
	end
end)

UIS.InputEnded:Connect(function(input)
	if isSprintHandledByInit() then return end

	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = false
		humanoid.WalkSpeed = normalSpeed
		syncLocalSprintState()
	end
end)

-- ============================================
-- STAMINA LOOP (tiap frame)
-- ============================================
RunService.RenderStepped:Connect(function(dt)

	-- FIX #1 (bagian 2 lanjutan): Kalau di tanah, reset jumpCount
	if isOnGround() and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
		-- Jangan reset jatah langsung jika baru saja melompat (menunggu animasi terbang)
		if os.clock() - lastJumpTime > 0.25 then
			jumpCount = 0
		end
	end

	-- FIX #4: Update normalSpeed kalau ada script lain yang ubah WalkSpeed
	--         (hanya update saat tidak sprint agar tidak konflik)
	if isSprintHandledByInit() then
		sprinting = character:GetAttribute("SprintActive") == true
		local sharedStamina = character:GetAttribute("SprintStamina")
		if typeof(sharedStamina) == "number" then
			stamina = sharedStamina
		end

		local sharedMaxStamina = character:GetAttribute("SprintMaxStamina")
		if typeof(sharedMaxStamina) == "number" and sharedMaxStamina > 0 then
			maxStamina = sharedMaxStamina
		end

		normalSpeed = humanoid.WalkSpeed
		return
	end

	if not sprinting then
		normalSpeed = humanoid.WalkSpeed
	end

	if sprinting and stamina > 0 then
		-- FIX #2: Kalau stamina habis di tengah sprint, langsung berhenti
		humanoid.WalkSpeed = sprintSpeed
		stamina -= drain * dt
	else
		-- FIX #3: Stamina hanya regen kalau karakter bergerak ATAU diam
		--         tapi TIDAK saat sprint (sudah dihandle di atas)
		--         Stamina regen lebih lambat saat bergerak, lebih cepat saat diam
		local velocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
		local isMoving = velocity.Magnitude > 1

		if isMoving then
			stamina += (regen * 0.5) * dt  -- regen setengah kalau lagi jalan
		else
			stamina += regen * dt           -- regen penuh kalau diam
		end

		humanoid.WalkSpeed = normalSpeed
	end

	-- Paksa berhenti sprint kalau stamina habis
	if stamina <= 0 then
		stamina = 0
		sprinting = false
		humanoid.WalkSpeed = normalSpeed
	end

	stamina = math.clamp(stamina, 0, maxStamina)
	syncLocalSprintState()
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
	syncLocalSprintState()

	-- Pasang ulang listener StateChanged untuk karakter baru
	humanoid.StateChanged:Connect(function(old, new)
		if new == Enum.HumanoidStateType.Landed then
			jumpCount = 0
		end
	end)
end)

print("[DoubleJump & Sprint - Naura] ✅ Loaded")
