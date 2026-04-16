local part = script.Parent

local startPos = part.Position
local endPos = startPos + Vector3.new(0, 0, 10)

while true do
	part.Position = endPos
	task.wait(2)
	part.Position = startPos
	task.wait(2)
end