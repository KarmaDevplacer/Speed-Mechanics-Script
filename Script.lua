-- Get necessary Roblox services.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Get the local player, their character, and the humanoid within the character.
local localPlayer = Players.LocalPlayer
-- Wait for the character to be added initially.
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
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

-- Thread reference for the continuous speed increase loop.
local continuousSpeedLoop = nil

---
-- UI Setup
---

local playerGui = localPlayer:WaitForChild("PlayerGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpeedControlUI"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false -- THIS IS KEY: Prevents the UI from resetting on player death!

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 160) -- Increased height for speed display
frame.Position = UDim2.new(0.5, -100, 0.1, 0)
frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
frame.BorderSizePixel = 0
frame.Parent = screenGui

-- Add UI Corner for rounded corners to the main frame
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0.2, 0) -- Adjusted height
title.Text = "Control de Velocidad Normal"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
title.Font = Enum.Font.SourceSansBold
title.Parent = frame

-- Add UI Corner for rounded corners to the title
local titleUiCorner = Instance.new("UICorner")
titleUiCorner.CornerRadius = UDim.new(0, 8)
titleUiCorner.Parent = title

-- NEW: Close Button (the 'X')
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 24, 0, 24) -- Small square button
closeButton.Position = UDim2.new(1, -24, 0, 0) -- Top-right corner of the frame
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0) -- Red background for close
closeButton.Font = Enum.Font.SourceSansBold
closeButton.TextSize = 18 -- Make 'X' visible
closeButton.Parent = frame

-- Add UI Corner for rounded corners to the close button
local closeButtonUiCorner = Instance.new("UICorner")
closeButtonUiCorner.CornerRadius = UDim.new(0, 4) -- Slightly smaller radius for close button
closeButtonUiCorner.Parent = closeButton

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0.9, 0, 0.25, 0) -- Adjusted height
toggleButton.Position = UDim2.new(0.05, 0, 0.25, 0) -- Adjusted position
toggleButton.Text = "Desactivar Script"
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.Parent = frame

-- Add UI Corner for rounded corners to the toggle button
local toggleButtonUiCorner = Instance.new("UICorner")
toggleButtonUiCorner.CornerRadius = UDim.new(0, 6)
toggleButtonUiCorner.Parent = toggleButton

local resetButton = Instance.new("TextButton")
resetButton.Size = UDim2.new(0.9, 0, 0.25, 0) -- Adjusted height
resetButton.Position = UDim2.new(0.05, 0, 0.5, 0) -- Adjusted position
resetButton.Text = "Velocidad Normal"
resetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
resetButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
resetButton.Font = Enum.Font.SourceSansBold
resetButton.Parent = frame

-- Add UI Corner for rounded corners to the reset button
local resetButtonUiCorner = Instance.new("UICorner")
resetButtonUiCorner.CornerRadius = UDim.new(0, 6)
resetButtonUiCorner.Parent = resetButton

-- NEW: TextLabel to display current walk speed in real-time
local currentSpeedDisplayLabel = Instance.new("TextLabel")
currentSpeedDisplayLabel.Size = UDim2.new(0.9, 0, 0.25, 0)
currentSpeedDisplayLabel.Position = UDim2.new(0.05, 0, 0.75, 0) -- Positioned at the bottom
currentSpeedDisplayLabel.Text = "Velocidad Actual: N/A"
currentSpeedDisplayLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
currentSpeedDisplayLabel.TextScaled = true
currentSpeedDisplayLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40) -- Slightly darker background
currentSpeedDisplayLabel.Font = Enum.Font.SourceSansBold
currentSpeedDisplayLabel.Parent = frame

-- Add UI Corner for rounded corners to the current speed display label
local currentSpeedDisplayUiCorner = Instance.new("UICorner")
currentSpeedDisplayUiCorner.CornerRadius = UDim.new(0, 6)
currentSpeedDisplayUiCorner.Parent = currentSpeedDisplayLabel

---
-- Draggable UI Functionality (Remains the same as previous versions)
---
local dragging = false
local dragInput
local dragStart
local startPos

local function updateFramePosition(input, gameProcessedEvent)
	local delta = input.Position - dragStart
	local newX = startPos.X.Offset + delta.X
	local newY = startPos.Y.Offset + delta.Y

	local maxX = screenGui.AbsoluteSize.X - frame.AbsoluteSize.X
	local maxY = screenGui.AbsoluteSize.Y - frame.AbsoluteSize.Y

	newX = math.clamp(newX, 0, maxX)
	newY = math.clamp(newY, 0, maxY)

	frame.Position = UDim2.new(0, newX, 0, newY)

	if not gameProcessedEvent then
		return true
	end
end

local function makeDraggable(guiObject)
	guiObject.InputBegan:Connect(function(input, gameProcessedEvent)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragInput = input
			dragStart = input.Position
			startPos = frame.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					dragInput = nil
				end
			end)

			if not gameProcessedEvent then
				return true
			end
		end
	end)
end

UserInputService.InputChanged:Connect(function(input, gameProcessedEvent)
	if dragging and input == dragInput then
		updateFramePosition(input, gameProcessedEvent)
	end
end)

makeDraggable(title)
makeDraggable(frame)


---
-- Speed Control Logic - Modified for consistent "step" detection
---

-- Function to update the player's walk speed and animation speed.
-- This function will now be called by the continuous loop.
local function applySpeedIncrease()
	if not humanoid or not humanoid.Parent then
		return
	end

	local currentWalkSpeed = humanoid.WalkSpeed
	local newWalkSpeed = math.min(currentWalkSpeed + WALK_SPEED_INCREASE_PER_STEP, MAX_ABSURD_SPEED)
	humanoid.WalkSpeed = newWalkSpeed

	for _, animTrack in ipairs(humanoid:GetPlayingAnimationTracks()) do
		if animTrack.Name == "WalkAnim" or animTrack.Name == "Running" then
			animTrack.Speed = originalAnimationSpeed + (newWalkSpeed * ANIMATION_SPEED_MULTIPLIER)
			break
		end
	end

    -- Update the real-time speed display
    if currentSpeedDisplayLabel then
        currentSpeedDisplayLabel.Text = string.format("Velocidad Actual: %.2f", humanoid.WalkSpeed)
    end
end

-- Function to start the continuous speed increase loop.
local function startContinuousSpeedLoop()
    if continuousSpeedLoop then return end -- Prevent multiple loops from running

    continuousSpeedLoop = RunService.Stepped:Connect(function()
        -- Only increase speed if script is active AND player is actively moving
        if isScriptActive and humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
            applySpeedIncrease()
        end
    end)
end

-- Function to stop the continuous speed increase loop.
local function stopContinuousSpeedLoop()
    if continuousSpeedLoop then
        continuousSpeedLoop:Disconnect()
        continuousSpeedLoop = nil
    end
end

-- Function to reset all script states and UI when it's closed or deactivated
local function resetScriptState()
    isScriptActive = false
    stopContinuousSpeedLoop() -- Stop the continuous speed increase

    -- Ensure humanoid exists before trying to reset its properties
    if humanoid then
        humanoid.WalkSpeed = originalWalkSpeed
        for _, animTrack in ipairs(humanoid:GetPlayingAnimationTracks()) do
            if animTrack.Name == "WalkAnim" or animTrack.Name == "Running" then
                animTrack.Speed = originalAnimationSpeed
                break
            end
        end
    end

    if currentSpeedDisplayLabel then
        currentSpeedDisplayLabel.Text = "Velocidad Actual: N/A"
    end

    -- Update toggle button text to reflect inactive state
    if toggleButton then
        toggleButton.Text = "Activar Script"
        toggleButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    end
end

---
-- Event Handling for Buttons and Character Respawn
---

-- Removed humanoid.Running:Connect for speed increase, now handled by continuousSpeedLoop

-- Connect to Humanoid.Changed to update the display in real-time
-- This catches any changes to WalkSpeed, not just from our script
humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
    -- Only update if script is active, as resetScriptState handles inactive state
    if isScriptActive and currentSpeedDisplayLabel then
        currentSpeedDisplayLabel.Text = string.format("Velocidad Actual: %.2f", humanoid.WalkSpeed)
    end
end)


toggleButton.MouseButton1Click:Connect(function()
	isScriptActive = not isScriptActive
	if isScriptActive then
		toggleButton.Text = "Desactivar Script"
		toggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        startContinuousSpeedLoop() -- Start the continuous loop when activated
        -- Update display immediately when activated
        if currentSpeedDisplayLabel then
            currentSpeedDisplayLabel.Text = string.format("Velocidad Actual: %.2f", humanoid.WalkSpeed)
        end
	else
		resetScriptState() -- Use the new reset function
	end
end)

resetButton.MouseButton1Click:Connect(function()
	resetScriptState() -- Use the new reset function
end)

-- NEW: Close Button Click Event
closeButton.MouseButton1Click:Connect(function()
    resetScriptState() -- Reset all states
    if screenGui then
        screenGui:Destroy() -- Destroy the UI
    end
end)


-- Handle character respawns: Re-acquire references and persist state.
localPlayer.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = newCharacter:WaitForChild("Humanoid")
    originalWalkSpeed = humanoid.WalkSpeed -- Re-acquire original walk speed

    -- Re-connect the Humanoid.Changed event for the new humanoid
    humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if isScriptActive and currentSpeedDisplayLabel then
            currentSpeedDisplayLabel.Text = string.format("Velocidad Actual: %.2f", humanoid.WalkSpeed)
        end
    end)

    -- If the script was active before death, ensure it remains active and restarts the loop
    if isScriptActive then
        toggleButton.Text = "Desactivar Script"
        toggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        startContinuousSpeedLoop() -- Restart the continuous loop
        if currentSpeedDisplayLabel then
            currentSpeedDisplayLabel.Text = string.format("Velocidad Actual: %.2f", humanoid.WalkSpeed)
        end
    else
        -- If it was inactive, ensure everything is reset and UI reflects inactive state.
        resetScriptState()
    end
end)

-- Initial UI state setup
if isScriptActive then
	toggleButton.Text = "Desactivar Script"
	toggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    startContinuousSpeedLoop() -- Start the continuous loop initially if active
    if currentSpeedDisplayLabel then
        currentSpeedDisplayLabel.Text = string.format("Velocidad Actual: %.2f", humanoid.WalkSpeed)
    end
else
	resetScriptState() -- Ensure initial state is correct if not active
end
	- Initialize UI to inactive state
