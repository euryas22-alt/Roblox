local LedgeModule = {}

local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local forwardDistance = 2
local ledgeHeight = 3
local climbUpOffset = 3

local function raycast(character, origin, direction)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}

	return workspace:Raycast(origin, direction, params)
end

function LedgeModule:Init(character)
	local humanoid = character:WaitForChild("Humanoid")
	local root = character:WaitForChild("HumanoidRootPart")

	local isGrabbing = false
	local cooldown = false
	local grabRequest = false

	-- INPUT (TEKAN E)
	UIS.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.E then
			grabRequest = true
		end
	end)

	RunService.Heartbeat:Connect(function()
		if isGrabbing or cooldown then return end
		if character:GetAttribute("IsBusy") then return end
		if humanoid.Health <= 0 then return end
		if not grabRequest then return end

		grabRequest = false

		local origin = root.Position
		local forward = root.CFrame.LookVector * forwardDistance

		local wallHit = raycast(character, origin, forward)
		if not wallHit then return end

		local topOrigin = wallHit.Position + Vector3.new(0, ledgeHeight, 0)
		local topCheck = raycast(character, topOrigin, Vector3.new(0, -ledgeHeight, 0))

		if topCheck then
			isGrabbing = true
			cooldown = true

			-- LOCK
			character:SetAttribute("IsBusy", true)

			humanoid.PlatformStand = true
			root.Velocity = Vector3.zero

			-- POSISI LEBIH AMAN
			local hangPos = wallHit.Position
				+ wallHit.Normal * 0.5
				+ Vector3.new(0, -1.5, 0)

			root.CFrame = CFrame.new(hangPos, hangPos + root.CFrame.LookVector)

			task.wait(0.2)

			-- MANTLE
			local climbPos = topCheck.Position + Vector3.new(0, climbUpOffset, 0)
			root.CFrame = CFrame.new(climbPos)

			task.wait(0.1)

			-- UNLOCK
			humanoid.PlatformStand = false
			character:SetAttribute("IsBusy", false)

			isGrabbing = false

			-- COOLDOWN FIX
			task.wait(0.5)
			cooldown = false
		end
	end)
end

return LedgeModule