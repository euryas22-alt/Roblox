local speedBoost = script.Parent

local function steppedOn(part)
	local character = part.Parent
	local player = game.Players:GetPlayerFromCharacter(character)

	if player then
		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then return end

		character:SetAttribute("SpeedBoost", true)

		task.delay(5, function()
			if character then
				character:SetAttribute("SpeedBoost", false)
			end
		end)
	end
end

speedBoost.Touched:Connect(steppedOn)