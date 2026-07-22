System.LogAlways("[GraveSense] loading 2026 runtime")

Script.ReloadScript("Scripts/GraveSense/GS_Log.lua")
Script.ReloadScript("Scripts/GraveSense/GS_State.lua")
Script.ReloadScript("Scripts/GraveSense/GS_Rules.lua")
Script.ReloadScript("Scripts/GraveSense/GS_Mutator.lua")
Script.ReloadScript("Scripts/GraveSense/GS_Settings.lua")
Script.ReloadScript("Scripts/GraveSense/GraveSense.lua")
Script.ReloadScript("Scripts/GraveSense/GS_EventBridge.lua")
Script.ReloadScript("Scripts/GraveSense/GS_ModMenu.lua")

if UIAction and UIAction.RegisterEventSystemListener and not GraveSense._gameplayListenerBound then
    UIAction.RegisterEventSystemListener(GraveSense, "System", "OnGameplayStarted", "OnGameplayStarted")
    GraveSense._gameplayListenerBound = true
end

-- Polling starts only from OnGameplayStarted, after KCDUtils/LuaDB is ready
-- and the persisted master setting has been resolved.
