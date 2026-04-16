-- Ambil service penting
local Players = game:GetService("Players") -- untuk akses player
local RunService = game:GetService("RunService") -- untuk loop tiap frame (real-time)

-- Ambil player lokal (client-side)
local player = Players.LocalPlayer

-- Variable karakter player
local character
local rootPart -- HumanoidRootPart = pusat posisi player
local humanoid -- sistem humanoid (hidup/mati)

-- Connection untuk Heartbeat
local connection

-- Menyimpan posisi terakhir platform (CFrame sebelumnya)
local lastPlatformCFramea

-- Fungsi utama yang jalan tiap frame
local function onHeartbeat()
	if not rootPart then return end -- kalau belum ada rootPart, skip

	-- Setup raycast (sinar ke bawah)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {character} -- biar ga kena diri sendiri
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Nembak ray ke bawah sejauh 6 studs
	local raycastResult = workspace:Raycast(
		rootPart.Position,
		Vector3.new(0, -6, 0),
		raycastParams
	)

	-- Cek apakah player berdiri di platform bernama "MovingPlatform"
if raycastResult and raycastResult.Instance then
	local parent = raycastResult.Instance.Parent

	-- cek apakah termasuk platform yang boleh diinjak
	if parent and (parent.Name == "MovingPlatform" or parent.Name == "SpinningBlock") then
		
		local platform = raycastResult.Instance
		local platformCFrame = platform.CFrame

		if lastPlatformCFrame then
			local relative = platformCFrame * lastPlatformCFrame:Inverse()
			rootPart.CFrame = relative * rootPart.CFrame
		end

		lastPlatformCFrame = platformCFrame
	else
		lastPlatformCFrame = nil
	end
else
	lastPlatformCFrame = nil
end
-- Setup saat karakter spawn / respawn
local function setupCharacter(char)
	character = char
	rootPart = character:WaitForChild("HumanoidRootPart")
	humanoid = character:WaitForChild("Humanoid")

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

-- Kalau karakter sudah ada (saat join)
if player.Character then
	setupCharacter(player.Character)
end

-- Kalau respawn, setup ulang
player.CharacterAdded:Connect(setupCharacter)