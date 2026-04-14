-- ============================================
-- CHECKPOINT SYSTEM — KAzzamAL
-- Gabungan: CheckpointHandler + RespawnHandler
-- ============================================

-- SERVICES
local Players           = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local CheckpointsFolder = game:GetService("Workspace"):WaitForChild("Checkpoints")
local DataManager       = require(ServerScriptService:WaitForChild("PlayerData").DataManager)


-- CONFIGURATION
local LAST_CHECKPOINT_NAME = "finish"


-- Anti-spam cooldown table per player per checkpoint
local playerCooldowns = {}


-- ============================================
-- CHECKPOINT TOUCH HANDLERS
-- ============================================

local function setupCheckpoint(checkpointPart, checkpointNumber)
	local function onTouch(hit)
		local humanoid = hit.Parent:FindFirstChild("Humanoid")
		if not humanoid then return end

		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end

		local cooldownKey = player.UserId .. "_" .. checkpointNumber
		if playerCooldowns[cooldownKey] then return end

		playerCooldowns[cooldownKey] = true
		DataManager:PlayerCheckpoint(player, checkpointNumber)
		task.delay(2, function()
			playerCooldowns[cooldownKey] = nil
		end)
	end

	checkpointPart.Touched:Connect(onTouch)
end


local function setupFinish(finishPart)
	local function onTouch(hit)
		local humanoid = hit.Parent:FindFirstChild("Humanoid")
		if not humanoid then return end

		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end

		local cooldownKey = player.UserId .. "_Summit"
		if playerCooldowns[cooldownKey] then return end

		playerCooldowns[cooldownKey] = true
		DataManager:PlayerSummit(player)
		task.delay(5, function()
			playerCooldowns[cooldownKey] = nil
		end)
	end

	finishPart.Touched:Connect(onTouch)
end


-- Setup semua checkpoint parts di folder
for _, checkpointPart in pairs(CheckpointsFolder:GetChildren()) do
	if checkpointPart:IsA("BasePart") then
		if checkpointPart.Name == LAST_CHECKPOINT_NAME then
			setupFinish(checkpointPart)
			print("[Checkpoint] Summit sudah di-setup")
		else
			local checkpointNumber = tonumber(checkpointPart.Name)
			if checkpointNumber then
				setupCheckpoint(checkpointPart, checkpointNumber)
				print("[Checkpoint] Checkpoint " .. checkpointNumber .. " telah di-setup")
			else
				warn("[Checkpoint] Part name bukan angka: " .. checkpointPart.Name)
			end
		end
	end
end


-- ============================================
-- RESPAWN HANDLER
-- ============================================

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(char)
		print("[Respawn] CharacterAdded fired for:", player.Name)
		task.defer(function()
			DataManager:RespawnPlayerAtCheckpoint(player, char)
		end)
	end)
end

-- Handle player yang sudah join sebelum script ini berjalan
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)


-- ============================================
-- CLEANUP saat player keluar
-- ============================================

Players.PlayerRemoving:Connect(function(player)
	local prefix = tostring(player.UserId) .. "_"

	-- Kumpulkan key dulu, baru hapus (hindari modifikasi table saat iterasi)
	local keysToDelete = {}
	for cooldownKey in pairs(playerCooldowns) do
		if cooldownKey:sub(1, #prefix) == prefix then
			table.insert(keysToDelete, cooldownKey)
		end
	end
	for _, key in ipairs(keysToDelete) do
		playerCooldowns[key] = nil
	end
end)
