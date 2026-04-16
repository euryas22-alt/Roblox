local player = game.Players.LocalPlayer
local TweenService = game:GetService("TweenService")


local masterUI = script.Parent
local deathFrame = masterUI:WaitForChild("DeathFrame")
local tipLabel = deathFrame:WaitForChild("TipLabel")
local staminaBarFill = masterUI:WaitForChild("StaminaFrame"):WaitForChild("IsiBar")

local MAX_STAMINA = 100
local tipsList = {
	"Sabar adalah kunci! Perhatikan pola pergerakan rintangan.",
	"Gunakan 'Shift-Lock' di pengaturan untuk lompatan yang lebih akurat.",
	"Jangan menyerah! Setiap kegagalan membawamu lebih dekat ke garis Finish.",
	"Awasi Stamina-mu, jangan sampai kehabisan di tengah lompatan!"
}


player.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid")
	
	humanoid.Died:Connect(function()
		tipLabel.Text = "TIPS: " .. tipsList[math.random(1, #tipsList)]
		deathFrame.Visible = true
		task.wait(3)
		deathFrame.Visible = false
	end)
	
	local staminaData = character:WaitForChild("StaminaValue", 10)

	if staminaData then
		local persentase = staminaData.Value / MAX_STAMINA
		staminaBarFill.Size = UDim2.new(persentase, 0, 1, 0)
		staminaBarFill.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
		
		staminaData.Changed:Connect(function(newValue)
			local persentase = newValue / MAX_STAMINA
			
			local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween = TweenService:Create(staminaBarFill, tweenInfo, {Size = UDim2.new(persentase, 0, 1, 0)})
			tween:Play()
			
			if newValue <= 30 then
				staminaBarFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
			else
				staminaBarFill.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
			end
		end)
	else
		warn("⚠️ StaminaValue tidak ditemukan pada character " .. character.Name)

		staminaBarFill.Size = UDim2.new(1, 0, 1, 0)
	end
end)