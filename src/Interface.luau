-- VHSClient Interface (module)
-- Provides functions to get/toggle/reset VHS effects and stuff
-- Exports: Interface:Get(type?), Interface:Set(type?, value), Interface:Toggle(type?), Interface:Init(Client, Local)

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Predefined image offsets used for noise animation
local OFFSETS = {
	NOISE = {
		Vector2.new(0, 0),
		Vector2.new(255.47, 0),
		Vector2.new(510.93, 0),
		Vector2.new(766.40, 0),
		Vector2.new(0, 187.67),
		Vector2.new(255.47, 187.67),
		Vector2.new(510.93, 187.67),
		Vector2.new(766.40, 187.67),
		Vector2.new(0, 375.33),
		Vector2.new(255.47, 375.33),
	},
}

-- Images to preload
local IMAGES = {
	"rbxassetid://103196207045886",
	"rbxassetid://133243681163212",
	"rbxassetid://80164818592276",
	"rbxassetid://104308955051295",
}

-- Module state (populated during Init)
local VHSLocal = nil
local VHSClient = nil

local Interface = {
	Events = {},
}
Interface.__index = Interface

-- Small helper: linear interpolation
local function lerp(a: number, b: number, t: number): number
	return a + t * (b - a)
end

-- Preload assets safely. Accepts a string or table of asset ids.
local function preload(contents)
	if typeof(contents) == "string" then
		contents = { contents }
	end

	-- Use PreloadAsync with a simple failure logger.
	ContentProvider:PreloadAsync(contents, function(contentId, status)
		if status == Enum.AssetFetchStatus.Failure then
			warn("[VHSClient] Failed to preload", contentId)
			-- NOTE: we don't abort here; just log.
		end
	end)
end

-- Helpers to find/Create UI/environment elements.
-- These functions return early on failure to avoid deep nesting.

local function getOrCreateBlurAndColorCorrection()
	-- If running standalone, the Create module supplies instances.
	if VHSLocal and VHSLocal.Standalone then
		local success, Create = pcall(require, script.Parent:WaitForChild("Create"))
		if success and Create then
			return Create:Blur(), Create:ColorCorrection()
		end
	end

	-- Fallback to objects in Lighting
	local blur = Lighting:FindFirstChild("VHSBlur")
	local colorCorrection = Lighting:FindFirstChild("VHSColorCorrection") -- optional
	return blur, colorCorrection
end

local function getGuiInstances()
	-- Try to get the GUI from PlayerGui, fallback fails early.
	local gui = PlayerGui:FindFirstChild("VHSGUI")
	if not gui then
		return nil
	end

	local noise = gui:FindFirstChild("Noise")
	local pink = gui:FindFirstChild("Pink")
	local presetLines = gui:FindFirstChild("PresetLines")

	return gui, noise, pink, presetLines
end

-- Noise animation loop: rotates & cycles ImageRectOffset while visible and enabled.
local function startNoiseLoop(Noise)
	if not Noise then
		return nil
	end

	-- Spawn a separate task
	task.spawn(function()
		while task.wait(0.05) do
			-- Skip quickly if GUI/noise are disabled
			if not (VHSLocal and VHSLocal.Enabled and VHSLocal.Enabled.Gui and VHSLocal.Enabled.Gui.Self and VHSLocal.Enabled.Gui.Noise) then
				continue
			end
			if not (Noise and Noise.Parent and Noise.Visible) then
				continue
			end

			-- Find current offset index
			local noiseIndex = 1
			for i, offset in ipairs(OFFSETS.NOISE) do
				if Noise.ImageRectOffset == offset then
					noiseIndex = i
					break
				end
			end

			-- Advance index (wrap around)
			noiseIndex = noiseIndex % #OFFSETS.NOISE + 1

			-- Normalize rotation and apply large increment
			Noise.Rotation = (Noise.Rotation % 360) + 180
			Noise.ImageRectOffset = OFFSETS.NOISE[noiseIndex]
		end
	end)
end

-- Lines animation: creates lines at intervals and moves them upward until they leave screen.
local function startLinesLoop(VHSGui)
	if not VHSGui then
		return nil
	end

	task.spawn(function()
		while true do
			-- Random wait between 1 and 2 seconds (lerp with math.random())
			task.wait(lerp(1, 2, math.random()))
			-- Skip when master GUI or lines are disabled
			if not (VHSLocal and VHSLocal.Enabled and VHSLocal.Enabled.Gui and VHSLocal.Enabled.Gui.Self and VHSLocal.Enabled.Gui.Lines) then
				continue
			end

			local linesFolder = VHSGui:FindFirstChild("Lines")
			local template = VHSGui:FindFirstChild("LineTemplate")
			if not linesFolder or not template then
				continue
			end

			-- Create and configure line
			local line = template:Clone()
			local lineType = math.random() ^ 4 -- bias distribution toward smaller numbers
			local verticalSize = lerp(0.01, 0.5, lineType)

			line.Name = "Line"
			line.Size = UDim2.new(line.Size.X.Scale, 0, verticalSize, 0)
			line.ImageTransparency = lerp(0.7, 0.95, lineType)
			line.Visible = true
			line.Parent = linesFolder

			-- Render update using RunService.Heartbeat to animate the line
			local conn
			conn = RunService.Heartbeat:Connect(function(deltaTime)
				local currentY = line.Position.Y.Scale - 0.25 * deltaTime
				if currentY < -verticalSize then
					conn:Disconnect()
					line:Destroy()
					return
				end
				line.Position = UDim2.new(-math.random(), 0, currentY, 0)
			end)
		end
	end)
end

-- Initialize visual elements and start relevant loops
local function setup()
	-- Resolve blur/colorCorrection and GUI elements with a fallback
	local blur, colorCorrection = getOrCreateBlurAndColorCorrection()
	local gui, noise, pink, presetLines = getGuiInstances()

	-- If GUI is missing, try waiting for it
	if not gui then
		gui = PlayerGui:WaitForChild("VHSGUI")
		noise = gui:WaitForChild("Noise")
		pink = gui:WaitForChild("Pink")
		presetLines = gui:WaitForChild("PresetLines")
	end

	-- If blur is missing from earlier, attempt to wait for it in Lighting
	if not blur then
		blur = Lighting:WaitForChild("VHSBlur")
	end

	-- Build the Elements table for external use
	Interface.Elements = {
		Blur = blur,
		ColorCorrection = colorCorrection,
		Gui = {
			Self = gui,
			Noise = noise,
			Pink = pink,
			PresetLines = presetLines,
		},
	}

	-- Preload images used by the GUI
	preload(IMAGES)

	-- Start background animation loops
	startNoiseLoop(noise)
	startLinesLoop(gui)
end

-- SetupRemote hooks: helper functions to map events and register handlers
local function safeHandleEvent(name)
	-- Check to see if VHSClient or Handling Event is enabled
	if not VHSClient or not VHSClient.HandleEvent then
		return
	end

	-- Create small wrappers that call Show/Hide/Toggle on the client
	VHSClient:HandleEvent(name, function()
		VHSClient:Show(name)
	end)
	VHSClient:HandleEvent(name, function()
		VHSClient:Hide(name)
	end)
	VHSClient:HandleEvent(name, function()
		VHSClient:Toggle(name)
	end)
end

-- Connect the RemoteEvent and register handlers for events
local function setupHooks()
	if not VHSClient or not VHSClient.RemoteEvent then
		return
	end

	-- Wire up RemoteEvent to local event dispatcher
	VHSClient.RemoteEvent.OnClientEvent:Connect(function(name, ...)
		local lowerName = tostring(name):lower()
		if VHSClient.Events and VHSClient.Events[lowerName] then
			-- Protect call with pcall in case user handler errors
			local ok, err = pcall(VHSClient.Events[lowerName], ...)
			if not ok then
				warn("[VHSClient] Event handler error for", lowerName, err)
			end
		end
	end)

	-- Register set of event names
	local events = {
		"Blur",
		"ColorCorrection",
		"Gui",
		"Noise",
		"Pink",
		"PinkLine",
		"Lines",
		"PresetLines",
	}

	-- Loop is flat and uses early returns inside safeHandleEvent when needed
	for _, eventName in ipairs(events) do
		safeHandleEvent(eventName)
	end
end

-- Public functions helpers --------------------------------------------------------

-- Internal mapper: normalize the type string for comparisons
local function normalizeType(t)
	if not t then
		return nil
	end
	return tostring(t):lower()
end

-- Get current enabled state. If type is nil, returns entire VHSLocal.Enabled table.
function Interface:Get(type)
	if not VHSLocal then
		return false
	end

	local lowerType = normalizeType(type)
	if not lowerType then
		return VHSLocal.Enabled
	end

	if lowerType == "blur" then
		return VHSLocal.Enabled.Blur
	elseif lowerType == "colorcorrection" or lowerType == "color" then
		return VHSLocal.Enabled.ColorCorrection
	elseif lowerType == "gui" then
		return VHSLocal.Enabled.Gui.Self
	elseif lowerType == "noise" then
		return VHSLocal.Enabled.Gui.Noise
	elseif lowerType == "pinkline" or lowerType == "pink" then
		return VHSLocal.Enabled.Gui.Pink
	elseif lowerType == "lines" then
		return VHSLocal.Enabled.Gui.Lines
	elseif lowerType == "presetlines" then
		return VHSLocal.Enabled.Gui.PresetLines
	end

	return false
end

-- Internal helper to apply Interface.Elements states from VHSLocal.Enabled
local function applyElementStates()
	if not Interface.Elements then
		return
	end

	-- Safely set each element only if it exists
	local elements = Interface.Elements
	if elements.Blur then
		elements.Blur.Enabled = VHSLocal.Enabled.Blur
	end
	if elements.ColorCorrection then
		elements.ColorCorrection.Enabled = VHSLocal.Enabled.ColorCorrection
	end

	local guiElems = elements.Gui
	if guiElems and guiElems.Self then
		guiElems.Self.Enabled = VHSLocal.Enabled.Gui.Self
		if guiElems.Noise then
			guiElems.Noise.Visible = VHSLocal.Enabled.Gui.Noise
		end
		if guiElems.Pink then
			guiElems.Pink.Visible = VHSLocal.Enabled.Gui.Pink
		end
		if guiElems.PresetLines then
			guiElems.PresetLines.Visible = VHSLocal.Enabled.Gui.PresetLines
		end
	end
end

-- Set a specific type or apply to all when type==nil
function Interface:Set(type, value)
	if not VHSLocal then
		return false
	end

	local lowerType = normalizeType(type)
	if lowerType == nil then
		-- apply to all toggles
		VHSLocal.Enabled.Blur = value
		VHSLocal.Enabled.ColorCorrection = value
		VHSLocal.Enabled.Gui.Self = value
		VHSLocal.Enabled.Gui.Noise = value
		VHSLocal.Enabled.Gui.Pink = value
		VHSLocal.Enabled.Gui.Lines = value
		VHSLocal.Enabled.Gui.PresetLines = value
	else
		-- per-type assignment
		-- no case for lua :(
		if lowerType == "blur" then
			VHSLocal.Enabled.Blur = value
		elseif lowerType == "colorcorrection" or lowerType == "color" then
			VHSLocal.Enabled.ColorCorrection = value
		elseif lowerType == "gui" then
			VHSLocal.Enabled.Gui.Self = value
		elseif lowerType == "noise" then
			VHSLocal.Enabled.Gui.Noise = value
		elseif lowerType == "pinkline" or lowerType == "pink" then
			VHSLocal.Enabled.Gui.Pink = value
		elseif lowerType == "lines" then
			VHSLocal.Enabled.Gui.Lines = value
		elseif lowerType == "presetlines" then
			VHSLocal.Enabled.Gui.PresetLines = value
		else
			return false
		end
	end

	-- Apply the new state to actual Gui/Blur elements (safe)
	applyElementStates()
	return true
end

-- Toggle a specific type or all when type==nil
function Interface:Toggle(type)
	if not VHSLocal then
		return false
	end

	local lowerType = normalizeType(type)
	if lowerType == nil then
		-- Toggle everything
		VHSLocal.Enabled.Blur = not VHSLocal.Enabled.Blur
		VHSLocal.Enabled.ColorCorrection = not VHSLocal.Enabled.ColorCorrection
		VHSLocal.Enabled.Gui.Self = not VHSLocal.Enabled.Gui.Self
		VHSLocal.Enabled.Gui.Noise = not VHSLocal.Enabled.Gui.Noise
		VHSLocal.Enabled.Gui.Pink = not VHSLocal.Enabled.Gui.Pink
		VHSLocal.Enabled.Gui.Lines = not VHSLocal.Enabled.Gui.Lines
		VHSLocal.Enabled.Gui.PresetLines = not VHSLocal.Enabled.Gui.PresetLines
	else
		if lowerType == "blur" then
			VHSLocal.Enabled.Blur = not VHSLocal.Enabled.Blur
		elseif lowerType == "colorcorrection" or lowerType == "color" then
			VHSLocal.Enabled.ColorCorrection = not VHSLocal.Enabled.ColorCorrection
		elseif lowerType == "gui" then
			VHSLocal.Enabled.Gui.Self = not VHSLocal.Enabled.Gui.Self
		elseif lowerType == "noise" then
			VHSLocal.Enabled.Gui.Noise = not VHSLocal.Enabled.Gui.Noise
		elseif lowerType == "pinkline" or lowerType == "pink" then
			VHSLocal.Enabled.Gui.Pink = not VHSLocal.Enabled.Gui.Pink
		elseif lowerType == "lines" then
			VHSLocal.Enabled.Gui.Lines = not VHSLocal.Enabled.Gui.Lines
		elseif lowerType == "presetlines" then
			VHSLocal.Enabled.Gui.PresetLines = not VHSLocal.Enabled.Gui.PresetLines
		else
			return false
		end
	end

	-- Apply UI changes after toggling
	applyElementStates()
	return true
end

-- Initialize this Interface module with the client functions and local config/state
-- it sets VHSLocal/VHSClient, calls setup and optionally hooks remote events.
function Interface:Init(Client, Local)
	-- Validate input
	if not Client or not Local then
		return false
	end

	VHSLocal = Local
	VHSClient = Client

	-- Prepare visuals and animations
	setup()

	-- If not standalone, wire up remote folder and hooks
	if not (VHSLocal and VHSLocal.Standalone) then
		local success, VHSFolder = pcall(function()
			return ReplicatedStorage:WaitForChild("VHSFolder", 5)
		end)
		if not success or not VHSFolder then
			-- If remote folder not present, return false early (original returned false)
			return false
		end

		VHSClient.ReplicatedRoot = VHSFolder
		VHSClient.RemoteEvent = VHSFolder:WaitForChild("RemoteEvent")
		setupHooks()
	end

	return true
end

return Interface
