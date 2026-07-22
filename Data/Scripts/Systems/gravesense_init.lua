System.LogAlways("[GraveSense] loading 2026 runtime")

Script.ReloadScript("Scripts/GraveSense/GS_Log.lua")
Script.ReloadScript("Scripts/GraveSense/GS_State.lua")
Script.ReloadScript("Scripts/GraveSense/GS_Rules.lua")
Script.ReloadScript("Scripts/GraveSense/GS_Mutator.lua")
Script.ReloadScript("Scripts/GraveSense/GraveSense.lua")
Script.ReloadScript("Scripts/GraveSense/GS_EventBridge.lua")
Script.ReloadScript("Scripts/GraveSense/GS_ModMenu.lua")

if UIAction and UIAction.RegisterEventSystemListener and not GraveSense._gameplayListenerBound then
    UIAction.RegisterEventSystemListener(GraveSense, "System", "OnGameplayStarted", "OnGameplayStarted")
    GraveSense._gameplayListenerBound = true
end

if GraveSense and GraveSense.Start then
    GraveSense.Start()
end
