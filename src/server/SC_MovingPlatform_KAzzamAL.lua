local TweenService = game:GetService("TweenService")
local folder = workspace:WaitForChild("MovingPlatforms")

local speed = 5
local waitTime = 1

local function setupPlatform(model)
	local platform = model:WaitForChild("Platform")
	local checkpoints = {}

	for _, child in pairs(model:GetChildren()) do
		if child:IsA("Part") then
			local number = tonumber(child.Name)
			if number then
				table.insert(checkpoints, {
					number = number,
					part = child
				})
			end
		end
	end

	table.sort(checkpoints, function(a, b)
		return a.number < b.number
	end)

	if #checkpoints < 2 then
		warn("Not enough checkpoints in", model.Name) return
	end

	platform:SetAttribute("IsMovingPlatform", true)

	local function moveTo(position)
		local distance = (platform.Position - position).Magnitude
		local time = distance / speed

		local tweenInfo = TweenInfo.new(time, Enum.EasingStyle.Linear)
		local goal = {Position = position}

		local tween = TweenService:Create(platform, tweenInfo, goal)
		tween:Play()
		tween.Completed:Wait()
	end

	task.spawn(function()
		while true do

			for i = 1, #checkpoints do
				moveTo(checkpoints[i].part.Position)
				task.wait(waitTime)
			end

			for i = #checkpoints - 1, 2, -1 do
				moveTo(checkpoints[i].part.Position)
				task.wait(waitTime)
			end

		end
	end)
end

for _, model in pairs(folder:GetChildren()) do
	if model:IsA("Model") then
		setupPlatform(model)
	end
end

folder.ChildAdded:Connect(function(model)
	if model:IsA("Model") then
		setupPlatform(model)
	end
end)
