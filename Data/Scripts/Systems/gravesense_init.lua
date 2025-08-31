System.LogAlways("[GraveSense] systems init: loading Scripts/GraveSense/GraveSense.lua")
Script.ReloadScript("Scripts/GraveSense/Config.lua")
Script.ReloadScript("Scripts/GraveSense/GraveSense.lua")
Script.ReloadScript("Scripts/GraveSense/SanitizerBridge.lua")

-- Register gameplay start (ensures heartbeat after world loads)
if UIAction and UIAction.RegisterEventSystemListener then
    UIAction.RegisterEventSystemListener(GraveSense, "System", "OnGameplayStarted", "OnGameplayStarted")
end

-- Also start immediately (so you see menu logs too)
if GraveSense and GraveSense.StartHeartbeat then GraveSense.StartHeartbeat() end
