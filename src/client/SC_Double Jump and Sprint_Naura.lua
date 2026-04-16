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

	task.delay(JumpCooldown, function()
	canjump = true
end)



elseif newstate == Enum.HumanoidStateType.Jumping then

	canjump = false

end

end)

UIS.JumpRequest:Connect(function()

if character:GetAttribute("IsBusy") then return end



if canjump and NumJumps < maxJump then

	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	NumJumps += 1
	canjump = false

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

-- =====================
-- STAMINA UI
-- =====================
local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("StaminaUI")
if old then
	old:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StaminaUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.new(0, 200, 0, 18)
bg.Position = UDim2.new(0.05, 0, 0.9, 0)
bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
bg.BorderSizePixel = 0
bg.Parent = screenGui

local fill = Instance.new("Frame")
fill.Size = UDim2.new(1, 0, 1, 0)
fill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
fill.BorderSizePixel = 0
fill.Parent = bg

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = bg

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 6)
fillCorner.Parent = fill

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

-- UPDATE UI
local percent = stamina / maxStamina
fill.Size = UDim2.new(percent, 0, 1, 0)

if percent > 0.5 then
	fill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
elseif percent > 0.2 then
	fill.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
else
	fill.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
end

end)