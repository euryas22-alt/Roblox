local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- STATE SYSTEM
character:SetAttribute("IsBusy", false)

-- DOUBLE JUMP
local NumJumps = 0
local canjump = false
local maxJump = 2
local JumpCooldown = 0.2

-- SPRINT + STAMINA
local normalSpeed = 16
local sprintSpeed = 30

local stamina = 100
local maxStamina = 100
local drain = 20
local regen = 10

local sprinting = false

humanoid.StateChanged:Connect(function(_, newstate)

	if character:GetAttribute("IsBusy") then return end

	if newstate == Enum.HumanoidStateType.Landed then
		NumJumps = 0
		canjump = false

	elseif newstate == Enum.HumanoidStateType.Freefall then
		task.wait(JumpCooldown)
		canjump = true

	elseif newstate == Enum.HumanoidStateType.Jumping then
		canjump = false
		NumJumps += 1
	end
end)

UIS.JumpRequest:Connect(function()
	if character:GetAttribute("IsBusy") then return end

	if canjump and NumJumps < maxJump then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.KeyCode == Enum.KeyCode.LeftShift and stamina > 0 then
		sprinting = true
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = false
	end
end)

RunService.RenderStepped:Connect(function(dt)

	if character:GetAttribute("IsBusy") then
		humanoid.WalkSpeed = 0
		return
	end

	if sprinting and stamina > 0 then
		humanoid.WalkSpeed = sprintSpeed
		stamina -= drain * dt
	else
		humanoid.WalkSpeed = normalSpeed
		stamina += regen * dt
	end

	if stamina <= 0 then
		stamina = 0
		sprinting = false
	end

	stamina = math.clamp(stamina, 0, maxStamina)
end)