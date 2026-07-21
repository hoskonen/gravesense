GS_State = GS_State or {}

GS_State.processed = GS_State.processed or {}
GS_State.health = GS_State.health or {}
GS_State.attempts = GS_State.attempts or {}

function GS_State.ResetAll()
    GS_State.processed = {}
    GS_State.health = {}
    GS_State.attempts = {}
end

function GS_State.ResetCombat()
    GS_State.health = {}
end

function GS_State.WasProcessed(key)
    return key ~= nil and GS_State.processed[tostring(key)] == true
end

function GS_State.MarkProcessed(key)
    if key ~= nil then
        GS_State.processed[tostring(key)] = true
    end
end

function GS_State.AddAttempt(key)
    if key == nil then return 0 end
    key = tostring(key)
    local value = (GS_State.attempts[key] or 0) + 1
    GS_State.attempts[key] = value
    return value
end

function GS_State.GetHealth(key)
    if key == nil then return nil end
    return GS_State.health[tostring(key)]
end

function GS_State.SetHealth(key, value)
    if key ~= nil and type(value) == "number" then
        GS_State.health[tostring(key)] = value
    end
end
