-- Ambil service penting
local Players = game:GetService("Players") -- akses player
local RunService = game:GetService("RunService") -- loop tiap frame (real-time)

-- Ambil player lokal
local player = Players.LocalPlayer

-- Variable karakter
local character
local rootPart -- pusat posisi player
local humanoid -- sistem hidup/mati

-- Connection heartbeat
local connection

-- Simpan posisi terakhir platform (buat bandingin gerakan)
local lastPlatformCFrame

-- 🔍 Fungsi untuk cek apakah object termasuk platform
-- Dia akan naik ke parent terus sampai ketemu model utama
local function isPlatform(instance)
	while instance do
		-- Kalau ketemu model bernama ini, anggap platform
		if instance.Name == "MovingPlatform" or instance.Name == "SpinningBlock" then
			return true, instance
		end

		-- Naik ke parent (biar support nested model)
		instance = instance.Parent
	end

	return false, nil
end

-- 🔁 Fungsi utama (jalan tiap frame)
local function onHeartbeat(dt)
	if not rootPart then return end -- kalau belum ada player, skip

	-- Setup raycast (sinar ke bawah)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {character} -- biar ga kena diri sendiri
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Tembak ray ke bawah sejauh 6 studs
	local raycastResult = workspace:Raycast(
		rootPart.Position,
		Vector3.new(0, -6, 0),
		raycastParams
	)

	-- Kalau kena sesuatu
	if raycastResult and raycastResult.Instance then

		-- Cek apakah itu platform
		local isPlat, model = isPlatform(raycastResult.Instance)

		if isPlat then
			-- Part yang diinjak player
			local platformPart = raycastResult.Instance

			-- Ambil posisi & rotasi sekarang
			local currentCFrame = platformPart.CFrame

			-- Kalau sudah punya posisi sebelumnya
			if lastPlatformCFrame then
				-- Hitung perubahan posisi platform
				local relative = currentCFrame * lastPlatformCFrame:Inverse()

				-- Terapkan perubahan ke player
				-- Jadi player ikut bergerak / muter
				rootPart.CFrame = relative * rootPart.CFrame
			end

			-- Simpan posisi sekarang untuk frame berikutnya
			lastPlatformCFrame = currentCFrame
		else
			-- Kalau bukan platform, reset
			lastPlatformCFrame = nil
		end
	else
		-- Kalau tidak kena apa-apa (jatuh), reset
		lastPlatformCFrame = nil
	end
end

-- 🔄 Setup karakter saat spawn / respawn
local function setupCharacter(char)
	character = char
	rootPart = char:WaitForChild("HumanoidRootPart")
	humanoid = char:WaitForChild("Humanoid")

	-- Reset data platform
	lastPlatformCFrame = nil

	-- Kalau sudah ada koneksi sebelumnya, matikan dulu
	if connection then
		connection:Disconnect()
	end

	-- Jalankan fungsi tiap frame
	connection = RunService.Heartbeat:Connect(onHeartbeat)

	-- Kalau player mati, hentikan loop
	humanoid.Died:Connect(function()
		if connection then
			connection:Disconnect()
		end
	end)
end

-- Kalau karakter sudah ada saat join
if player.Character then
	setupCharacter(player.Character)
end

-- Kalau respawn, setup ulang
player.CharacterAdded:Connect(setupCharacter)
