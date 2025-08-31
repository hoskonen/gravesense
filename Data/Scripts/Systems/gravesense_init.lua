-- Scripts/Systems/gravesense_init.lua
System.LogAlways("[GraveSense] systems init: loading Scripts/GraveSense/GraveSense.lua")
Script.ReloadScript("Scripts/GraveSense/GraveSense.lua")

-- register world start (same style as your working demo)
if UIAction and UIAction.RegisterEventSystemListener then
    UIAction.RegisterEventSystemListener(GraveSense, "System", "OnGameplayStarted", "OnGameplayStarted")
end

-- also start immediately so you see logs at the menu too
if GraveSense and GraveSense.Start then GraveSense.Start() end
