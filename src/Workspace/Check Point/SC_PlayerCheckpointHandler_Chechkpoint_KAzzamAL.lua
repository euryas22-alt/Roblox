local CheckpointsFolder = game:GetService("Workspace"):WaitForChild("Checkpoints")
local ServerScriptServcie = game:GetService("ServerScriptService")
local DataManager = require(ServerScriptServcie:WaitForChild("PlayerData").DataManager)


-- configuration
local LAST_CHECKPOINT_NAME = 'finish'


-- Anti-spam table untuk track cooldown per player per checkpoiAnt
local playerCooldowns = {}


-- setup touched checkpoint
local function setupCheckpoint(checkpointPart, checkpointNumber)
	local function onTouch(hit)
		local humanoid = hit.Parent:FindFirstChild("Humanoid")
		if not humanoid then return end

		local player = game.Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end
		local playerId = player.UserId
		local cooldownKey = playerId .. "_" .. checkpointNumber
		if playerCooldowns[cooldownKey] then
			return
		end
		playerCooldowns[cooldownKey] = true
		DataManager:PlayerCheckpoint(player, checkpointNumber)
		task.delay(2, function()
			playerCooldowns[cooldownKey] = nil
		end)
	end

	checkpointPart.Touched:Connect(onTouch)
end

-- setup touched finish
local function setupFinish(finishPart)
	local function onTouch(hit)
		local humanoid = hit.Parent:FindFirstChild("Humanoid")
		if not humanoid then return end

		local player = game.Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end
		local playerId = player.UserId
		local cooldownKey = playerId .. "_Summit"

		if playerCooldowns[cooldownKey] then
			return
		end
		playerCooldowns[cooldownKey] = true
		DataManager:PlayerSummit(player)
		task.delay(5, function() 
			playerCooldowns[cooldownKey] = nil
		end)
	end

	finishPart.Touched:Connect(onTouch)
end

-- get semua data checkpoints
for _, checkpointPart in pairs(CheckpointsFolder:GetChildren()) do
	if checkpointPart:IsA("BasePart") then
		if checkpointPart.Name == LAST_CHECKPOINT_NAME then
			setupFinish(checkpointPart)
			print("Summit sudah di-setup")
		else
			local checkpointNumber = tonumber(checkpointPart.Name)
			if checkpointNumber then
				setupCheckpoint(checkpointPart, checkpointNumber)
				print("Checkpoint " .. checkpointNumber .. " telah di-setup")
			else
				warn("Checkpoint part name bukan angka: " .. checkpointPart.Name)
			end
		end
	end
end

-- Clean up cooldowns 
game.Players.PlayerRemoving:Connect(function(player)
	local playerId = player.UserId
	for cooldownKey, _ in pairs(playerCooldowns) do
		if string.find(cooldownKey, tostring(playerId) .. "_") then
			playerCooldowns[cooldownKey] = nil
		end
	end
end)