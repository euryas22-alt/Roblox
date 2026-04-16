local CheckpointsFolder = game:GetService("Workspace"):WaitForChild("Checkpoints")
local ServerScriptService = game:GetService("ServerScriptService") 
local DataManager = require(ServerScriptService:WaitForChild("PlayerData").DataManager)
local Players = game:GetService("Players")

local function PlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(char)
		print("CharacterAdded fired for:", player.Name)
		task.defer(function()
			DataManager:RespawnPlayerAtCheckpoint(player, char)
		end)
	end)
end


Players.PlayerAdded:Connect(PlayerAdded)
