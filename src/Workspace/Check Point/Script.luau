game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		
		local checkpointPos = player:GetAttribute("Checkpoint")
		
		if checkpointPos then
			local root = character:WaitForChild("HumanoidRootPart")
			root.CFrame = CFrame.new(checkpointPos + Vector3.new(0, 3, 0))
		end
		
	end)
end)