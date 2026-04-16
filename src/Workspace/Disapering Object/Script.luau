-- ============================================
-- DISAPPEARING PLATFORM SCRIPT (SERVER-SIDE)
-- MULTIPLAYER SYNCHRONIZED VERSION
-- ============================================
-- Script untuk platform yang menghilang setelah disentuh player
-- SEMUA PLAYER MELIHAT PLATFORM HILANG DI WAKTU YANG SAMA

local part = script.Parent
local Players = game:GetService("Players")

-- ============ KONFIGURASI ============
local DISAPPEAR_DURATION = 3      -- Waktu platform hilang (detik)
local COOLDOWN_TIME = 2           -- Cooldown sebelum bisa hilang lagi (detik)
local OPACITY_ON = 1              -- Opacity saat visible (0-1)
local OPACITY_OFF = 0.2           -- Opacity saat invisible (0-1)
local PLATFORM_ID = part.Name     -- ID platform (gunakan nama part)

-- ============ STATE VARIABLES ============
local isDisappeared = false       -- Status platform
local canDisappear = true         -- Apakah bisa hilang sekarang
local lastPlayerTouched = nil     -- Pemain terakhir yang menyentuh
local touchCooldown = {}          -- Cooldown per player (cegah spam)

-- ============ FUNGSI UTAMA ============

-- Fungsi untuk membuat platform menghilang (SERVER-SIDE)
local function makeDisappear(playerName)
	if not canDisappear or isDisappeared then 
		return 
	end
	
	isDisappeared = true
	canDisappear = false
	lastPlayerTouched = playerName
	
	print("[" .. PLATFORM_ID .. "] Disentuh oleh: " .. playerName .. " - MENGHILANG!")
	
	-- Set status visual SECARA LANGSUNG (semua player lihat)
	part.Transparency = OPACITY_OFF
	part.CanCollide = false
	
	-- Menunggu durasi disappear
	task.wait(DISAPPEAR_DURATION)
	
	-- Platform kembali muncul
	print("[" .. PLATFORM_ID .. "] Platform MUNCUL KEMBALI setelah " .. DISAPPEAR_DURATION .. "s")
	isDisappeared = false
	part.Transparency = OPACITY_ON
	part.CanCollide = true
	
	-- Menunggu cooldown sebelum bisa hilang lagi
	task.wait(COOLDOWN_TIME)
	canDisappear = true
	
	print("[" .. PLATFORM_ID .. "] Platform SIAP HILANG LAGI")
end

-- Fungsi untuk handle touch event
local function onTouched(otherPart)
	-- Cek apakah yang menyentuh adalah player humanoid
	local humanoid = otherPart.Parent:FindFirstChild("Humanoid")
	local player = Players:FindFirstChild(otherPart.Parent.Name)
	
	if humanoid and player then
		local playerName = player.Name
		
		-- Cegah spam touch dari player yang sama dalam cooldown
		if touchCooldown[playerName] and (tick() - touchCooldown[playerName]) < 0.5 then
			return
		end
		
		touchCooldown[playerName] = tick()
		print("[" .. PLATFORM_ID .. "] Player: " .. playerName .. " MENYENTUH PLATFORM")
		
		-- Trigger disappear (akan di-execute di server)
		makeDisappear(playerName)
	end
end

-- ============ SETUP PLATFORM ============

-- Pastikan part adalah platform yang bisa di-trigger
part.CanCollide = true
part.Transparency = OPACITY_ON

-- ============ EVENT CONNECTIONS ============

-- Connect touch event
part.Touched:Connect(onTouched)

-- ============ CLEANUP PADA RESET ============

Players.PlayerRemoving:Connect(function(player)
	if touchCooldown[player.Name] then
		touchCooldown[player.Name] = nil
	end
end)

-- ============ DEBUG INFO ============

print("========================================")
print("✓ Platform Server Script Loaded")
print("  Platform ID: " .. PLATFORM_ID)
print("  Disappear Duration: " .. DISAPPEAR_DURATION .. "s")
print("  Cooldown Time: " .. COOLDOWN_TIME .. "s")
print("  Opacity (ON/OFF): " .. OPACITY_ON .. " / " .. OPACITY_OFF)
print("  Mode: MULTIPLAYER SYNCHRONIZED")
print("========================================")