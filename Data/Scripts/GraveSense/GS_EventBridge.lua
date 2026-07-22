-- UI lifecycle events for polling ownership (Lua 5.1).

GraveSense = GraveSense or {}
local GS = GraveSense

function GS.OnGameOverShown(...)
    GS_Log.Info("event: game over shown")
    GS.Pause("gameover")
end

function GS.OnGameOverHidden(...)
    -- Do not resume into the dying world between GameOver and save loading.
    -- OnGameplayStarted clears this pause and creates the authoritative timer.
    GS_Log.Info("event: game over hidden; waiting for gameplay start")
end

function GS:OnSkipTimeEvent(elementName, instanceId, eventName, argTable)
    local mode = argTable and argTable[1] or nil

    if eventName == "OnSetFaderState" then
        if mode and mode ~= "" and mode ~= GS._skipTimeMode then
            GS._skipTimeMode = mode
            GS_Log.Info("event: skip time mode=" .. tostring(mode))
        end
        GS.Pause("skiptime")
    elseif eventName == "OnHide" then
        GS_Log.Info("event: skip time hidden")
        GS._skipTimeMode = nil
        GS.Resume("skiptime")
    end
end

if UIAction and UIAction.RegisterElementListener and not GS._uiLifecycleListenersBound then
    UIAction.RegisterElementListener(GS, "GameOver", -1, "OnPictureShown", "OnGameOverShown")
    UIAction.RegisterElementListener(GS, "GameOver", -1, "OnPictureHided", "OnGameOverHidden")
    UIAction.RegisterElementListener(GS, "SkipTime", -1, "", "OnSkipTimeEvent")
    GS._uiLifecycleListenersBound = true
    GS_Log.Info("lifecycle event bridge registered")
end
