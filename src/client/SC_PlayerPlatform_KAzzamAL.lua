local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character
local rootPart
local humanoid

local connection
local lastPlatformCFrame

local function onHeartbeat()
	if not rootPart then return end
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local raycastResult = workspace:Raycast(
		rootPart.Position,
		Vector3.new(0, -6, 0),
		raycastParams
	)
	if raycastResult and raycastResult.Instance:GetAttribute("IsMovingPlatform") then
		local platform = raycastResult.Instance
		local platformCFrame = platform.CFrame
		if lastPlatformCFrame then
			local relative = platformCFrame * lastPlatformCFrame:Inverse()
			rootPart.CFrame = relative * rootPart.CFrame
		end
		lastPlatformCFrame = platformCFrame
	else
		lastPlatformCFrame = nil
	end
end

local function setupCharacter(char)
	character = char
	rootPart = character:WaitForChild("HumanoidRootPart")
	humanoid = character:WaitForChild("Humanoid")
	lastPlatformCFrame = nil
	if connection then
		connection:Disconnect()
	end
	connection = RunService.Heartbeat:Connect(onHeartbeat)
	humanoid.Died:Connect(function()
		if connection then
			connection:Disconnect()
		end
	end)
end

if player.Character then
	setupCharacter(player.Character)
end

player.CharacterAdded:Connect(setupCharacter)
