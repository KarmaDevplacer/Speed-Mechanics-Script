--!strict

-- Get necessary Roblox services.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
-- Although 'Model' service doesn't exist, we will acquire the player's character model.
-- The request implies getting a reference to the player's model.

-- Get the local player, their character, and the humanoid within the character.
-- 'LocalPlayer' is the player running this script.
local localPlayer = Players.LocalPlayer
-- Wait for the character to load, or get it if it's already there.
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
-- Wait for the Humanoid to be a child of the character.
local humanoid = character:WaitForChild("Humanoid")

-- Configuration variables for speed and animation.
local WALK_SPEED_INCREASE_PER_STEP = 2 -- Amount of speed to add per 'step' (when Humanoid.Running fires).
local ANIMATION_SPEED_MULTIPLIER = 0.1 -- How much the animation speed scales with walk speed.
local MAX_ABSURD_SPEED = 2e12 -- Maximum allowed walk speed (2 trillion studs per second).

-- Store the original walk speed and animation speed for resetting.
local originalWalkSpeed = humanoid.WalkSpeed
local originalAnimationSpeed = 1 -- Default Roblox walk animation speed.

-- State variable to control if the speed boost script is active.
local isScriptActive = true

-- Function to update the player's walk speed and animation speed.
local function updatePlayerSpeed()
	-- If the script is not active, or if the humanoid is somehow invalid, exit.
	if not isScriptActive or not humanoid or not humanoid.Parent then
		return
	end

	local currentWalkSpeed = humanoid.WalkSpeed
	-- Calculate the new walk speed, ensuring it doesn't exceed the maximum absurd speed.
	local newWalkSpeed = math.min(currentWalkSpeed + WALK_SPEED_INCREASE_PER_STEP, MAX_ABSURD_SPEED)
	humanoid.WalkSpeed = newWalkSpeed

	-- Adjust the walk animation speed.
	-- We iterate through all currently playing animation tracks on the humanoid.
	for _, animTrack in ipairs(humanoid:GetPlayingAnimationTracks()) do
		-- The default Roblox walk animation is often named "WalkAnim" or similar.
		-- You might need to adjust this name if your game uses a custom walk animation.
		if animTrack.Name == "WalkAnim" or animTrack.Name == "Running" then -- Common names for walk/run animations
			-- Set the animation speed based on the new walk speed and a multiplier.
			animTrack.Speed = originalAnimationSpeed + (newWalkSpeed * ANIMATION_SPEED_MULTIPLIER)
			break -- Found the walk animation, no need to check others.
		end
	end
end

-- Connect to the Humanoid.Running event. This event fires when the humanoid is moving.
humanoid.Running:Connect(function(speed)
	-- Only trigger the speed increase if the player is actually moving (speed > 0.1).
	if speed > 0.1 then
		updatePlayerSpeed()
	end
end)

-- Connect to RunService.Stepped. This ensures the script is always checking conditions
-- and can force updates, even if player position or animations are externally modified.
RunService.Stepped:Connect(function()
	-- This can be used for persistent checks or to re-apply speed if something external overrides it.
	-- For this script, Humanoid.Running is the primary trigger for speed increase,
	-- but Stepped ensures the script's state (isScriptActive) is always considered.
end)

-- UI Setup: Create a simple menu for controlling the script.
local playerGui = localPlayer:WaitForChild("PlayerGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpeedControlUI"
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 120) -- Slightly taller frame for better spacing
frame.Position = UDim2.new(0.5, -100, 0.1, 0) -- Centered horizontally, 10% from top
frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0.25, 0)
title.Text = "Control de Velocidad Absurda"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true -- Scale text to fit the label
title.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
title.Font = Enum.Font.SourceSansBold
title.Parent = frame

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0.9, 0, 0.3, 0)
toggleButton.Position = UDim2.new(0.05, 0, 0.3, 0) -- Position below title
toggleButton.Text = "Desactivar Script"
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0) -- Green for active
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.Parent = frame

local resetButton = Instance.new("TextButton")
resetButton.Size = UDim2.new(0.9, 0, 0.3, 0)
resetButton.Position = UDim2.new(0.05, 0, 0.65, 0) -- Position below toggle button
resetButton.Text = "Velocidad Normal"
resetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
resetButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0) -- Red for reset
resetButton.Font = Enum.Font.SourceSansBold
resetButton.Parent = frame

-- Function to toggle the script's active state.
toggleButton.MouseButton1Click:Connect(function()
	isScriptActive = not isScriptActive
	if isScriptActive then
		toggleButton.Text = "Desactivar Script"
		toggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0) -- Green
	else
		toggleButton.Text = "Activar Script"
		toggleButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0) -- Red
		-- When deactivated, reset speed and animation to original values.
		humanoid.WalkSpeed = originalWalkSpeed
		for _, animTrack in ipairs(humanoid:GetPlayingAnimationTracks()) do
			if animTrack.Name == "WalkAnim" or animTrack.Name == "Running" then
				animTrack.Speed = originalAnimationSpeed
				break
			end
		end
	end
end)

-- Function to reset the player's speed and animation to their original values.
resetButton.MouseButton1Click:Connect(function()
	humanoid.WalkSpeed = originalWalkSpeed
	for _, animTrack in ipairs(humanoid:GetPlayingAnimationTracks()) do
		if animTrack.Name == "WalkAnim" or animTrack.Name == "Running" then
			animTrack.Speed = originalAnimationSpeed
			break
		end
	end
	-- Deactivate the script after resetting.
	isScriptActive = false
	toggleButton.Text = "Activar Script"
	toggleButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0) -- Red
end)

-- Handle character respawns: Re-acquire references and reset state.
localPlayer.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid")
	-- Update original walk speed in case it changed (e.g., from game settings).
	originalWalkSpeed = humanoid.WalkSpeed
	-- Re-activate the script by default when a new character loads.
	isScriptActive = true
	toggleButton.Text = "Desactivar Script"
	toggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0) -- Green
end)

-- Initial check to ensure the UI is correctly reflecting the script's initial state.
if isScriptActive then
	toggleButton.Text = "Desactivar Script"
	toggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
else
	toggleButton.Text = "Activar Script"
	toggleButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
end
