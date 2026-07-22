GS_State = GS_State or {}

GS_State.processed = GS_State.processed or {}
GS_State.health = GS_State.health or {}
GS_State.attempts = GS_State.attempts or {}
GS_State.targets = GS_State.targets or {}

function GS_State.ResetAll()
    GS_State.processed = {}
    GS_State.health = {}
    GS_State.attempts = {}
    GS_State.targets = {}
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

function GS_State.Track(key, entity)
    if key == nil or entity == nil then return nil, false end
    key = tostring(key)
    local target = GS_State.targets[key]
    local created = target == nil
    if not target then
        target = { key = key }
        GS_State.targets[key] = target
    end
    target.entity = entity
    target.expiresAtMs = nil
    return target, created
end

function GS_State.GetTarget(key)
    if key == nil then return nil end
    return GS_State.targets[tostring(key)]
end

function GS_State.GetTargets()
    return GS_State.targets
end

function GS_State.RemoveTarget(key)
    if key ~= nil then GS_State.targets[tostring(key)] = nil end
end

function GS_State.HasTargets()
    return next(GS_State.targets) ~= nil
end

function GS_State.SetTargetExpiry(expiresAtMs)
    for _, target in pairs(GS_State.targets) do
        target.expiresAtMs = expiresAtMs
    end
end

function GS_State.ClearTargetExpiry()
    for _, target in pairs(GS_State.targets) do
        target.expiresAtMs = nil
    end
end

function GS_State.ClearTargets()
    GS_State.targets = {}
end
