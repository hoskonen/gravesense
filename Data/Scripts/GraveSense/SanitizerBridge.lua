-- Scripts/GraveSense/SanitizerBridge.lua
-- Disabled bridge from GraveSense death events → (future) CorpseSanitizer actions
-- Lua 5.1; no goto

local ENABLE_BRIDGE = false -- keep false for now

local function resolveVictim(meta)
    -- minimal resolver stub (read-only)
    local e = meta and meta.entity
    local w = meta and meta.wuid
    local nm = meta and meta.name
    System.LogAlways(("[GraveSense→Bridge] resolve victim name=%s wuid=%s"):format(tostring(nm), tostring(w)))
    return e, w, nm
end

local function onDeath(meta)
    if not ENABLE_BRIDGE then
        System.LogAlways(("[GraveSense→Bridge] would sanitize: %s (wuid=%s)"):format(
            tostring(meta.name), tostring(meta.wuid)))
        return
    end

    -- when we’re ready:
    -- local e, w, nm = resolveVictim(meta)
    -- if CorpseSanitizer and CS.nukeNpcInventory then
    --   CS.later(200, function() CS.nukeNpcInventory(e) end)
    -- end
end

if GraveSense and GraveSense.onDeathUse then
    GraveSense.onDeathUse(onDeath)
    System.LogAlways("[GraveSense→Bridge] subscribed (ENABLE_BRIDGE=false)")
end
