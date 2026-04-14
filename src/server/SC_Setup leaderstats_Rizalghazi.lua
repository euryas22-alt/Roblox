-- ============================================================
-- SC_Setup leaderstats_Rizalghazi
-- Setup leaderstats untuk setiap player yang join
-- ============================================================

local Players = game:GetService("Players")

-- ============================================================
-- TEMPLATE DATA (Stats default tiap player baru)
-- ============================================================
local DEFAULT_STATS = {
	Coins  = 0,
	Wins   = 0,
	Deaths = 0,
}

-- ============================================================
-- FUNGSI SETUP LEADERSTATS
-- ============================================================
local function setupLeaderstats(player)
	-- Buat folder leaderstats (wajib nama ini agar muncul di leaderboard Roblox)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name   = "leaderstats"
	leaderstats.Parent = player

	-- Coins
	local coins = Instance.new("IntValue")
	coins.Name   = "Coins"
	coins.Value  = DEFAULT_STATS.Coins
	coins.Parent = leaderstats

	-- Wins
	local wins = Instance.new("IntValue")
	wins.Name   = "Wins"
	wins.Value  = DEFAULT_STATS.Wins
	wins.Parent = leaderstats

	-- Deaths
	local deaths = Instance.new("IntValue")
	deaths.Name   = "Deaths"
	deaths.Value  = DEFAULT_STATS.Deaths
	deaths.Parent = leaderstats

	print("[SC_Setup leaderstats_Rizalghazi] ✅ Leaderstats setup untuk:", player.Name)
end

-- ============================================================
-- PLAYER ADDED - Jalankan setup saat player join
-- ============================================================
Players.PlayerAdded:Connect(function(player)
	setupLeaderstats(player)

	-- Hitung deaths otomatis saat karakter mati
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local deaths = leaderstats:FindFirstChild("Deaths")
				if deaths then
					deaths.Value = deaths.Value + 1
				end
			end
		end)
	end)
end)

-- Handle player yang sudah ada sebelum script jalan (misal di Studio)
for _, player in ipairs(Players:GetPlayers()) do
	setupLeaderstats(player)
end

print("[SC_Setup leaderstats_Rizalghazi] ✅ Leaderstats system aktif")
