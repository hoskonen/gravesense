System.LogAlways("[GraveSense] systems init: loading Scripts/GraveSense/GraveSense.lua")
Script.ReloadScript("Scripts/GraveSense/GraveSense.lua")

-- Phase B helpers (read-only)
Script.ReloadScript("Scripts/GraveSense/GS_Util.lua")
Script.ReloadScript("Scripts/GraveSense/GS_Enum.lua")

Script.ReloadScript("Scripts/GraveSense/GS_Sanitizer.lua")
-- (optional) bridge if you kept it as separate file
Script.ReloadScript("Scripts/GraveSense/SanitizerBridge.lua")

-- Register gameplay start (ensures heartbeat after world loads)
if UIAction and UIAction.RegisterEventSystemListener then
    UIAction.RegisterEventSystemListener(GraveSense, "System", "OnGameplayStarted", "OnGameplayStarted")
end

-- Also start immediately (so you see menu logs too)
if GraveSense and GraveSense.StartHeartbeat then GraveSense.StartHeartbeat() end
