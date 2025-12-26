local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Prevent the client library from being required on the server
if RunService:IsServer() then
	error(
		"[VHSClient] Server scripts cannot require the client library. Please require the server library from the server to use."
	)
end

-- Core local state for the client VHS system
local VHSLocal = {
	-- Detect whether the system is running standalone (no shared VHSFolder in ReplicatedStorage)
	Standalone = if ReplicatedStorage:FindFirstChild("VHSFolder") then false else true,

	-- Enabled/disabled flags for each effect
	Enabled = {
		Blur = false,
		ColorCorrection = false,

		-- GUI-related stuff
		Gui = {
			Self = false,
			Noise = false,
			Pink = false,
			Lines = false,
			PresetLines = false,
		},
	},
}

-- Main VHSClient class setup
local VHSClient = {}
VHSClient.__index = VHSClient

-- Require the interface handler that actually applies effects
local Interface = require(script.Interface)

-- Returns the current state/value of a given effect type
function VHSClient:Get(type: string?)
	return Interface:Get(type)
end

-- Turns an effect ON
function VHSClient:Show(type: string?)
	return Interface:Set(type, true)
end

-- Turns an effect OFF
function VHSClient:Hide(type: string?)
	return Interface:Set(type, false)
end

-- Toggles an effect between ON/OFF
function VHSClient:Toggle(type: string?)
	return Interface:Toggle(type)
end

-- Connects an event handler (only allowed in standalone mode)
function VHSClient:HandleEvent(name: string, callback: (...any) -> ())
	-- If not running standalone, refuse to register custom events
	if not VHSLocal.Standalone then
		return false
	end

	-- Store event callback under lowercase name
	Interface.Events[name:lower()] = callback
end

-- Initialize the interface with the client + local settings
Interface:Init(VHSClient, VHSLocal)

return VHSClient
