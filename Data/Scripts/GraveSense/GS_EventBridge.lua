-- UI lifecycle events for polling ownership (Lua 5.1).

GraveSense = GraveSense or {}
local GS = GraveSense

function GS.OnGameOverShown(...)
    GS_Log.Info("event: game over shown")
    GS.Pause("gameover")
end

function GS.OnGameOverHidden(...)
    GS_Log.Info("event: game over hidden")
    GS.Resume("gameover")
end

function GS:OnSkipTimeEvent(elementName, instanceId, eventName, argTable)
    local mode = argTable and argTable[1] or nil
    GS_Log.Info(("event: skip time %s mode=%s"):format(tostring(eventName), tostring(mode)))

    if eventName == "OnSetFaderState" then
        GS.Pause("skiptime")
    elseif eventName == "OnHide" then
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
