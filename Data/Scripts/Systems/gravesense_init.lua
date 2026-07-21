System.LogAlways("[GraveSense] loading 2026 runtime")

Script.ReloadScript("Scripts/GraveSense/GS_Log.lua")
Script.ReloadScript("Scripts/GraveSense/GS_State.lua")
Script.ReloadScript("Scripts/GraveSense/GS_Rules.lua")
Script.ReloadScript("Scripts/GraveSense/GS_Mutator.lua")
Script.ReloadScript("Scripts/GraveSense/GraveSense.lua")

if UIAction and UIAction.RegisterEventSystemListener then
    UIAction.RegisterEventSystemListener(GraveSense, "System", "OnGameplayStarted", "OnGameplayStarted")
end

if GraveSense and GraveSense.Start then
    GraveSense.Start()
end
