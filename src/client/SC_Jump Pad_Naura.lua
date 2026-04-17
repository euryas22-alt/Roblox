local plrJumpHeight = 14.4
local backToDefault = 7.2
local runsOut = true
local runOutTime = 10

local jumpPad = script.Parent

local debounce = {}

jumpPad.Touched:Connect(function(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if debounce[character] then return end
	debounce[character] = true

	-- IMPORTANT FIX: JumpPower vs JumpHeight
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = plrJumpHeight

	if runsOut then
		task.wait(runOutTime)
		if humanoid then
			humanoid.JumpHeight = backToDefault
		end
	end

	task.wait(0.5)
	debounce[character] = nil
end)