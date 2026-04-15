-- ============================================
-- CHECKPOINT SYSTEM - KAzzamAL
-- Gabungan: CheckpointHandler + RespawnHandler
-- ============================================

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

return function()
	local checkpointsFolder = workspace:FindFirstChild("Checkpoints")
	if not checkpointsFolder then
		warn("[Checkpoint] Folder Workspace/Checkpoints tidak ditemukan, sistem checkpoint dilewati.")
		return
	end

	local playerDataFolder = ServerScriptService:FindFirstChild("PlayerData")
	local dataManagerModule = playerDataFolder and playerDataFolder:FindFirstChild("DataManager")
	if not dataManagerModule then
		warn("[Checkpoint] Module PlayerData/DataManager tidak ditemukan, sistem checkpoint dilewati.")
		return
	end

	local DataManager = require(dataManagerModule)
	local FINISH_PART_NAME = "finish"
	local playerCooldowns = {}
	local checkpointCount = 0
	local hasFinish = false

	local function setupCheckpoint(checkpointPart, checkpointNumber)
		local function onTouch(hit)
			local hitParent = hit.Parent
			if not hitParent then return end

			local humanoid = hitParent:FindFirstChild("Humanoid")
			if not humanoid then return end

			local player = Players:GetPlayerFromCharacter(hitParent)
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
			local hitParent = hit.Parent
			if not hitParent then return end

			local humanoid = hitParent:FindFirstChild("Humanoid")
			if not humanoid then return end

			local player = Players:GetPlayerFromCharacter(hitParent)
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

	for _, checkpointPart in ipairs(checkpointsFolder:GetChildren()) do
		if checkpointPart:IsA("BasePart") then
			if checkpointPart.Name == FINISH_PART_NAME then
				setupFinish(checkpointPart)
				print("[Checkpoint] Summit sudah di-setup")
				hasFinish = true
			else
				local checkpointNumber = tonumber(checkpointPart.Name)
				if checkpointNumber then
					setupCheckpoint(checkpointPart, checkpointNumber)
					print("[Checkpoint] Checkpoint " .. checkpointNumber .. " telah di-setup")
					checkpointCount += 1
				else
					warn("[Checkpoint] Part name bukan angka: " .. checkpointPart.Name)
				end
			end
		end
	end

	if checkpointCount == 0 then
		warn("[Checkpoint] Belum ada checkpoint bernama angka di folder Checkpoints.")
	end

	if not hasFinish then
		print("[Checkpoint] Part finish belum ada. Sistem checkpoint tetap aktif tanpa finish.")
	end

	local function onPlayerAdded(player)
		player.CharacterAdded:Connect(function(char)
			print("[Respawn] CharacterAdded fired for:", player.Name)
			task.defer(function()
				DataManager:RespawnPlayerAtCheckpoint(player, char)
			end)
		end)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		local prefix = tostring(player.UserId) .. "_"
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
end
