local part = workspace:WaitForChild("DisappearingParts")



local function setupfinding(child)
	local istouched = false
	local Originalcolor = child.Color
	
	child.Touched:Connect(function(hit)
		local character = hit.Parent
		if character:FindFirstChild("Humanoid") and not istouched then	
			istouched = true

			task.wait(0.2)

			for i = 0,1 ,0.1 do
				child.Transparency = i
				task.wait(0.05)
			end

			child.CanCollide = false

			task.wait(3)

			child.CanCollide = true
			child.Transparency = 0
			istouched = false

		end


	end)
	
end


for _, child in ipairs(part:GetChildren()) do
	if child:IsA("BasePart") then
		setupfinding(child)
	end
end