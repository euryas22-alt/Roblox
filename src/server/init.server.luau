-- Server entry point
local modules = {
	"SC_Setup leaderstats_Rizalghazi",
	"SC_CheckpointSystem_KAzzamAL",
}

for _, moduleName in ipairs(modules) do
	local ok, result = pcall(function()
		local module = require(script:WaitForChild(moduleName))
		if type(module) == "function" then
			module()
		end
	end)

	if not ok then
		warn(string.format("[Server] Gagal memuat %s: %s", moduleName, tostring(result)))
	end
end
