-- ============================================
--  SLIDE CONTROLLER - CODM Style + Animasi
--  LocalScript → taruh di StarterCharacterScripts
-- ============================================

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local animator  = humanoid:WaitForChild("Animator")
local hrp       = character:WaitForChild("HumanoidRootPart")
local camera    = workspace.CurrentCamera

-- ============================================
--  ⚙️ SETTINGS
-- ============================================
local Config = {
    SlideSpeed      = 45,
    SlideDuration   = 0.85,
    SlideCooldown   = 1.0,
    SlideHipHeight  = -0.9,
    MinSpeedToSlide = 4,
    CameraTiltAngle = 6,
    -- Key trigger sekarang pakai klik kiri mouse
    -- Upload animasi di Roblox > Develop > Animations
    -- lalu paste ID-nya di sini (contoh: "rbxassetid://123456789")
    SlideAnimationId = "rbxassetid://2436646739", -- ID default (slide/crouch)
}

-- ============================================
--  STATE
-- ============================================
local isSliding   = false
local canSlide    = true
local slideConn   = nil
local slideTrack  = nil
local normalHip   = humanoid.HipHeight
local normalSpeed = humanoid.WalkSpeed

-- ============================================
--  INISIASI ANIMASI SLIDE
-- ============================================
local slideAnim = Instance.new("Animation")
slideAnim.AnimationId = Config.SlideAnimationId

-- Load animasi ke Animator karakter
local function loadAnimation()
    if slideTrack then
        slideTrack:Destroy()
    end
    slideTrack = animator:LoadAnimation(slideAnim)
    slideTrack.Priority = Enum.AnimationPriority.Action  -- override animasi lain
    slideTrack.Looped   = false
end

loadAnimation()

-- ============================================
--  FUNGSI UTAMA
-- ============================================

local function tiltCamera(angle)
    TweenService:Create(camera, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
        CFrame = camera.CFrame * CFrame.Angles(0, 0, math.rad(angle))
    }):Play()
end

local function stopSlide()
    if not isSliding then return end
    isSliding = false

    -- Hentikan animasi slide
    if slideTrack and slideTrack.IsPlaying then
        slideTrack:Stop(0.2)
    end

    if slideConn then
        slideConn:Disconnect()
        slideConn = nil
    end

    -- Kembalikan karakter ke posisi normal
    TweenService:Create(humanoid, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        HipHeight = normalHip,
        WalkSpeed = normalSpeed
    }):Play()

    -- Cooldown
    canSlide = false
    task.delay(Config.SlideCooldown, function()
        canSlide = true
    end)
end

local function startSlide()
    if isSliding or not canSlide then return end

    local vel   = hrp.AssemblyLinearVelocity
    local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude

    if speed < Config.MinSpeedToSlide then return end

    isSliding = true

    -- ▶️ Putar animasi slide
    if slideTrack and not slideTrack.IsPlaying then
        slideTrack:Play(0.1)
    end

    -- Arah slide = arah gerak saat ini
    local dir = Vector3.new(vel.X, 0, vel.Z).Unit

    -- Jongkokkan karakter + kecepatan slide
    TweenService:Create(humanoid, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
        HipHeight = Config.SlideHipHeight,
        WalkSpeed = Config.SlideSpeed
    }):Play()

    -- Dorong karakter ke depan
    hrp.AssemblyLinearVelocity = Vector3.new(
        dir.X * Config.SlideSpeed,
        hrp.AssemblyLinearVelocity.Y,
        dir.Z * Config.SlideSpeed
    )

    -- Kemiringan kamera
    tiltCamera(Config.CameraTiltAngle)

    -- Timer slide & perlambatan otomatis
    local elapsed = 0
    slideConn = RunService.Heartbeat:Connect(function(dt)
        if not isSliding then
            slideConn:Disconnect()
            return
        end

        elapsed = elapsed + dt
        local t = math.clamp(elapsed / Config.SlideDuration, 0, 1)

        -- Kurangi kecepatan secara halus saat meluncur
        humanoid.WalkSpeed = Config.SlideSpeed * (1 - t) + normalSpeed * t

        if elapsed >= Config.SlideDuration then
            tiltCamera(-Config.CameraTiltAngle)

            -- Animasi selesai → stop slide
            if slideTrack and slideTrack.IsPlaying then
                slideTrack:Stop(0.15)
            end
            stopSlide()
        end
    end)
end

-- ============================================
--  INPUT MOUSE KLIK KIRI
-- ============================================

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        startSlide()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if isSliding then
            tiltCamera(-Config.CameraTiltAngle)
            stopSlide()
        end
    end
end)

-- ============================================
--  TOMBOL MOBILE
-- ============================================

local gui = Instance.new("ScreenGui")
gui.Name           = "SlideGui"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.Parent         = player.PlayerGui

local btn = Instance.new("ImageButton")
btn.Name                   = "SlideBtn"
btn.Size                   = UDim2.new(0, 80, 0, 80)
btn.Position               = UDim2.new(1, -200, 1, -130)
btn.AnchorPoint            = Vector2.new(0.5, 0.5)
btn.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
btn.BackgroundTransparency = 0.25
btn.AutoButtonColor        = false
btn.Image                  = ""
btn.Parent                 = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent       = btn

local stroke = Instance.new("UIStroke")
stroke.Color        = Color3.fromRGB(255, 200, 50)
stroke.Thickness    = 2.5
stroke.Transparency = 0.1
stroke.Parent       = btn

local icon = Instance.new("TextLabel")
icon.Size                 = UDim2.new(1, 0, 0.55, 0)
icon.Position             = UDim2.new(0, 0, 0.08, 0)
icon.BackgroundTransparency = 1
icon.Text                 = "▼▼"
icon.TextColor3           = Color3.fromRGB(255, 220, 60)
icon.TextScaled           = true
icon.Font                 = Enum.Font.GothamBold
icon.Parent               = btn

local lbl = Instance.new("TextLabel")
lbl.Size                 = UDim2.new(1, 0, 0.3, 0)
lbl.Position             = UDim2.new(0, 0, 0.65, 0)
lbl.BackgroundTransparency = 1
lbl.Text                 = "SLIDE"
lbl.TextColor3           = Color3.fromRGB(255, 255, 255)
lbl.TextScaled           = true
lbl.Font                 = Enum.Font.GothamBold
lbl.Parent               = btn

local function pressEffect(pressing)
    TweenService:Create(btn, TweenInfo.new(0.08), {
        Size = pressing and UDim2.new(0, 70, 0, 70) or UDim2.new(0, 80, 0, 80),
        BackgroundTransparency = pressing and 0.05 or 0.25
    }):Play()
end

btn.MouseButton1Down:Connect(function()
    pressEffect(true)
    startSlide()
end)

btn.MouseButton1Up:Connect(function()
    pressEffect(false)
    if isSliding then
        tiltCamera(-Config.CameraTiltAngle)
        stopSlide()
    end
end)

-- ============================================
--  HANDLE RESPAWN
-- ============================================

player.CharacterAdded:Connect(function(newChar)
    character  = newChar
    humanoid   = newChar:WaitForChild("Humanoid")
    animator   = humanoid:WaitForChild("Animator")
    hrp        = newChar:WaitForChild("HumanoidRootPart")

    isSliding  = false
    canSlide   = true
    normalHip  = humanoid.HipHeight
    normalSpeed = humanoid.WalkSpeed

    if slideConn then
        slideConn:Disconnect()
        slideConn = nil
    end

    -- Reload animasi untuk karakter baru
    loadAnimation()
end)

print("[SlideController] ✅ Slide + Animasi loaded!")
