local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = game.Players.LocalPlayer

-- =====================
-- STATE SYSTEM
-- =====================
character:SetAttribute("IsBusy", false)

-- =====================
-- DOUBLE JUMP
-- =====================
local NumJumps = 0
local canjump = false
local maxJump = 2
local JumpCooldown = 0.2

-- =====================
-- SPRINT + STAMINA
-- =====================
local normalSpeed = 16
local sprintSpeed = 30

local stamina = 100
local maxStamina = 100
local drain = 20
local regen = 10

local sprinting = false

-- =====================
-- LEDGE SYSTEM
-- =====================
local Root = character:WaitForChild("HumanoidRootPart")
local Head = character:WaitForChild("Head")

local CA = humanoid:LoadAnimation(script:WaitForChild("ClimbAnim"))
local HA = humanoid:LoadAnimation(script:WaitForChild("HoldAnim"))

local ledgeavailable = true
local holding = false

-- =====================
-- STATE CHANGE (JUMP)
-- =====================
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

-- =====================
-- DOUBLE JUMP INPUT
-- =====================
UIS.JumpRequest:Connect(function()

	if character:GetAttribute("IsBusy") then return end

	if canjump and NumJumps < maxJump then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		NumJumps += 1
		canjump = false
	end
end)

-- =====================
-- SPRINT INPUT
-- =====================
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
-- STAMINA UI (TETAP)
-- =====================
local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("StaminaUI")
if old then old:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StaminaUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.new(0, 200, 0, 18)
bg.Position = UDim2.new(0.05, 0, 0.9, 0)
bg.BackgroundColor3 = Color3.fromRGB(40,40,40)
bg.BorderSizePixel = 0
bg.Parent = screenGui

local fill = Instance.new("Frame")
fill.Size = UDim2.new(1,0,1,0)
fill.Parent = bg

Instance.new("UICorner", bg)
Instance.new("UICorner", fill)

-- =====================
-- LEDGE DETECTION
-- =====================
RunService.Heartbeat:Connect(function()

	if holding then return end

	local r = Ray.new(Head.Position, Head.CFrame.LookVector * 5)
	local part, position = workspace:FindPartOnRay(r, character)

	if part and ledgeavailable then
		if part.Size.Y >= 7 then
			if Head.Position.Y >= (part.Position.Y + part.Size.Y/2) - 1
				and Head.Position.Y <= part.Position.Y + part.Size.Y/2
				and humanoid.FloorMaterial == Enum.Material.Air
				and Root.Velocity.Y <= 0 then

				-- AKTIFKAN LEDGE
				holding = true
				ledgeavailable = false
				Root.Anchored = true

				character:SetAttribute("IsBusy", true) -- 🔥 penting
				HA:Play()
			end
		end
	end
end)

-- =====================
-- CLIMB FUNCTION
-- =====================
local function climb()

	local Vele = Instance.new("BodyVelocity")
	Vele.MaxForce = Vector3.new(1,1,1) * math.huge
	Vele.Velocity = Root.CFrame.LookVector * 10 + Vector3.new(0,30,0)
	Vele.Parent = Root

	Root.Anchored = false

	HA:Stop()
	CA:Play()

	game.Debris:AddItem(Vele, .15)

	holding = false

	task.wait(0.75)
	ledgeavailable = true

	character:SetAttribute("IsBusy", false) -- 🔥 BALIK NORMAL
end

-- =====================
-- INPUT CLIMB
-- =====================
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end

	if holding and input.KeyCode == Enum.KeyCode.Space then
		climb()
	end
end)

-- =====================
-- MAIN LOOP (STAMINA + SPEED)
-- =====================
RunService.RenderStepped:Connect(function(dt)

	if character:GetAttribute("IsBusy") then
		humanoid.WalkSpeed = 0
		return
	end

	local boost = character:GetAttribute("SpeedBoost")

	if sprinting and stamina > 0 then
		stamina -= drain * dt
	else
		stamina += regen * dt
	end

	if boost then
		humanoid.WalkSpeed = 50
	elseif sprinting and stamina > 0 then
		humanoid.WalkSpeed = sprintSpeed
	else
		humanoid.WalkSpeed = normalSpeed
	end

	if stamina <= 0 then
		stamina = 0
		sprinting = false
	end

	stamina = math.clamp(stamina, 0, maxStamina)

	local percent = stamina / maxStamina
	fill.Size = UDim2.new(percent, 0, 1, 0)

	if percent > 0.5 then
		fill.BackgroundColor3 = Color3.fromRGB(0,255,0)
	elseif percent > 0.2 then
		fill.BackgroundColor3 = Color3.fromRGB(255,170,0)
	else
		fill.BackgroundColor3 = Color3.fromRGB(255,0,0)
	end
end)