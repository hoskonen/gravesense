-- GraveSense 2026 runtime (Lua 5.1).

GraveSense = GraveSense or {}
local GS = GraveSense

-- Hot-reload safety: cancel timer IDs owned by the previous script body.
if Script and Script.KillTimer then
    if GS._heartbeatTimer then pcall(Script.KillTimer, GS._heartbeatTimer) end
    if GS._combatTimer then pcall(Script.KillTimer, GS._combatTimer) end
    if GS._deathWatchTimer then pcall(Script.KillTimer, GS._deathWatchTimer) end
end

GS._heartbeatActive = false
GS._combatActive = false
GS._deathWatchActive = false
GS._inCombat = false
GS._heartbeatTimer = nil
GS._combatTimer = nil
GS._deathWatchTimer = nil
GS._pauseReasons = {}
GS._lastPollingLogMs = nil

local defaults = {
    enabled = true,
    runtime = {
        heartbeatMs = 1000,
        combatMs = 250,
        deathWatchMs = 100,
        postCombatRetentionMs = 15000,
        scanRadiusM = 10.0,
        maxAttempts = 3,
    },
    trigger = {
        hpThreshold = 0.75,
        damageDelta = 0.05,
        processUnknownHealth = false,
    },
    rules = {
        repairKits = { chance = 100 },
        potions = { chance = 100 },
        bandages = { chance = 100 },
    },
    safety = {
        dryRun = true,
        skipEquipped = true,
        protectNames = { money = true },
        protectClasses = {},
    },
    logging = {
        debug = false,
        pollingAliveMs = 30000,
    },
}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end

local function merge(target, source)
    for key, value in pairs(source or {}) do
        if type(value) == "table" and type(target[key]) == "table" then
            merge(target[key], value)
        else
            target[key] = copy(value)
        end
    end
end

function GraveSense.ReloadConfig()
    GS.cfg = copy(defaults)
    GraveSense_Config = nil

    local ok, err = pcall(function()
        Script.ReloadScript("Scripts/GraveSense/Config.lua")
    end)
    if not ok then
        GS_Log.Error("configuration load failed: " .. tostring(err))
        return false
    end

    if type(GraveSense_Config) == "table" then
        merge(GS.cfg, GraveSense_Config)
    end
    return true
end

local function getPlayer()
    if not System.GetEntityByName then return nil end
    return System.GetEntityByName("Henry") or System.GetEntityByName("dude")
end

local function getWuid(entity)
    if XGenAIModule and XGenAIModule.GetMyWUID and entity then
        local ok, value = pcall(XGenAIModule.GetMyWUID, entity)
        if ok and value then return tostring(value) end
    end
    return tostring(entity and (entity.id or entity) or "<nil>")
end

local function getName(entity)
    if entity and entity.GetName then
        local ok, value = pcall(entity.GetName, entity)
        if ok and value and value ~= "" then return tostring(value) end
    end
    return tostring(entity and entity.class or "entity")
end

local function isInCombat(player)
    local soul = player and player.soul
    if soul and soul.IsInCombatDanger then
        local ok, value = pcall(soul.IsInCombatDanger, soul)
        if ok and (value == true or value == 1) then return true end
    end
    if soul and soul.IsInCombat then
        local ok, value = pcall(soul.IsInCombat, soul)
        if ok and (value == true or value == 1) then return true end
    end
    local actor = player and player.actor
    if actor and actor.IsInCombat then
        local ok, value = pcall(actor.IsInCombat, actor)
        if ok and (value == true or value == 1) then return true end
    end
    return false
end

local function isDead(entity)
    local soul = entity and entity.soul
    if soul and soul.IsDead then
        local ok, value = pcall(soul.IsDead, soul)
        if ok and (value == true or value == 1) then return true end
    end
    local actor = entity and entity.actor
    if actor and actor.IsDead then
        local ok, value = pcall(actor.IsDead, actor)
        if ok and (value == true or value == 1) then return true end
    end
    return false
end

local function health01(entity)
    local soul = entity and entity.soul
    if soul and soul.GetHealth then
        local okHealth, health = pcall(soul.GetHealth, soul)
        if okHealth and type(health) == "number" then
            if soul.GetHealthMax then
                local okMax, maximum = pcall(soul.GetHealthMax, soul)
                if okMax and type(maximum) == "number" and maximum > 0 then
                    return math.max(0, math.min(1, health / maximum))
                end
            end
            if health >= 0 and health <= 1 then return health end
        end
    end

    local actor = entity and entity.actor
    if actor and actor.GetHealth then
        local okHealth, health = pcall(actor.GetHealth, actor)
        if okHealth and type(health) == "number" then
            if actor.GetMaxHealth then
                local okMax, maximum = pcall(actor.GetMaxHealth, actor)
                if okMax and type(maximum) == "number" and maximum > 0 then
                    return math.max(0, math.min(1, health / maximum))
                end
            end
            if health >= 0 and health <= 1 then return health end
        end
    end
    return nil
end

local function shouldProcess(key, currentHealth)
    local trigger = GS.cfg.trigger or {}
    local previousHealth = GS_State.GetHealth(key)
    local eligible = false

    if type(currentHealth) == "number" then
        local low = currentHealth <= (tonumber(trigger.hpThreshold) or 0.75)
        local damaged = previousHealth ~= nil
            and (previousHealth - currentHealth) >= (tonumber(trigger.damageDelta) or 0.05)
        eligible = low or damaged
        GS_State.SetHealth(key, currentHealth)
    else
        eligible = trigger.processUnknownHealth == true
    end
    return eligible
end

local function currentTimeMs()
    if System.GetCurrTime then
        local ok, value = pcall(System.GetCurrTime)
        if ok and type(value) == "number" then return math.floor(value * 1000) end
    end
    return math.floor((os.clock() or 0) * 1000)
end

local function logPollingAlive(inCombat)
    local interval = tonumber(GS.cfg.logging and GS.cfg.logging.pollingAliveMs) or 0
    if interval <= 0 then return end

    local now = currentTimeMs()
    if not GS._lastPollingLogMs or (now - GS._lastPollingLogMs) >= interval then
        GS._lastPollingLogMs = now
        GS_Log.Info("polling alive: inCombat=" .. tostring(inCombat))
    end
end

local function logResult(entity, key, result)
    local counts = { repairKits = 0, potions = 0, bandages = 0 }
    for i = 1, #(result.details or {}) do
        local detail = result.details[i]
        counts[detail.rule] = (counts[detail.rule] or 0) + math.max(0, detail.removed or 0)
        GS_Log.Debug(("item name=%s class=%s chance=%s%% selected=%s before=%s after=%s verified=%s engine=%s")
            :format(tostring(detail.name), tostring(detail.class), tostring(detail.chance),
                tostring(detail.selected), tostring(detail.before), tostring(detail.after),
                tostring(detail.verified), tostring(detail.engineResult)))
    end

    GS_Log.Info(("%s processed: repairKits=%d potions=%d bandages=%d removed=%d failed=%d verified=%s wuid=%s")
        :format(getName(entity), counts.repairKits or 0, counts.potions or 0, counts.bandages or 0,
            result.removed or 0, result.failed or 0, tostring((result.failed or 0) == 0), key))
end

local function processEntity(entity, key)
    local ok, result = pcall(GS_Mutator.Process, entity, GS.cfg, key)
    if not ok then
        GS_Log.Error(("%s processing crashed: %s"):format(getName(entity), tostring(result)))
        return false
    end
    if not result.complete then
        local attempts = GS_State.AddAttempt(key)
        local maximum = tonumber(GS.cfg.runtime.maxAttempts) or 3
        if attempts >= maximum then
            GS_State.MarkProcessed(key)
            GS_Log.Warn(("%s skipped after %d attempts: %s")
                :format(getName(entity), attempts, tostring(result.error)))
        else
            GS_Log.Debug(("%s processing deferred (%d/%d): %s")
                :format(getName(entity), attempts, maximum, tostring(result.error)))
        end
        return attempts >= maximum
    end

    GS_State.MarkProcessed(key)
    if result.matched > 0 or result.failed > 0 then
        logResult(entity, key, result)
    else
        GS_Log.Debug(getName(entity) .. " processed: no matching items")
    end
    return true
end

local function trackUntilDeath(entity, key, currentHealth)
    local _, created = GS_State.Track(key, entity)
    if created then
        GS_Log.Info(("tracking %s until death: hp=%s wuid=%s")
            :format(getName(entity), tostring(currentHealth), key))
    end
    GraveSense.StartDeathWatch()
end

function GraveSense.CombatTick()
    GS._combatTimer = nil
    if not GS._combatActive or not GS._inCombat or GraveSense.IsPaused() then return end

    local player = getPlayer()
    if player and player.GetWorldPos then
        local position = player:GetWorldPos()
        local radius = tonumber(GS.cfg.runtime.scanRadiusM) or 10.0
        local entities = (System.GetEntitiesInSphere and System.GetEntitiesInSphere(position, radius)) or {}

        for i = 1, #entities do
            local entity = entities[i]
            local actorLike = entity and entity ~= player and (entity.soul or entity.actor)
            if actorLike and entity.inventory then
                local key = getWuid(entity)
                if not GS_State.WasProcessed(key) then
                    local target = GS_State.GetTarget(key)
                    local dead = isDead(entity)
                    if target and not dead then
                        GS_State.Track(key, entity)
                    elseif not target and dead then
                        -- A lethal hit can occur between combat ticks. Only accept
                        -- a dead actor if this combat previously observed it alive.
                        local previousHealth = GS_State.GetHealth(key)
                        if previousHealth ~= nil and shouldProcess(key, 0) then
                            trackUntilDeath(entity, key, 0)
                        end
                    else
                        local currentHealth = health01(entity)
                        if shouldProcess(key, currentHealth) then
                            trackUntilDeath(entity, key, currentHealth)
                        end
                    end
                end
            end
        end
    end

    if Script and Script.SetTimerForFunction then
        GS._combatTimer = Script.SetTimerForFunction(
            tonumber(GS.cfg.runtime.combatMs) or 250,
            "GraveSense.CombatTick"
        )
    end
end

_G["GraveSense.CombatTick"] = GraveSense.CombatTick

function GraveSense.DeathWatchTick()
    GS._deathWatchTimer = nil
    if not GS._deathWatchActive or GraveSense.IsPaused() then return end

    local now = currentTimeMs()
    local targets = GS_State.GetTargets()
    for key, target in pairs(targets) do
        local entity = target.entity
        if not entity then
            GS_State.RemoveTarget(key)
        elseif isDead(entity) then
            if not target.deathLogged then
                target.deathLogged = true
                GS_Log.Info(("death detected: %s wuid=%s")
                    :format(getName(entity), key))
            end
            if processEntity(entity, key) then
                GS_State.RemoveTarget(key)
            end
        elseif target.expiresAtMs and now >= target.expiresAtMs then
            GS_Log.Debug(("tracking expired alive: %s wuid=%s")
                :format(getName(entity), key))
            GS_State.RemoveTarget(key)
        end
    end

    if not GS_State.HasTargets() then
        GS._deathWatchActive = false
        return
    end

    if Script and Script.SetTimerForFunction then
        GS._deathWatchTimer = Script.SetTimerForFunction(
            tonumber(GS.cfg.runtime.deathWatchMs) or 100,
            "GraveSense.DeathWatchTick"
        )
    end
end

_G["GraveSense.DeathWatchTick"] = GraveSense.DeathWatchTick

function GraveSense.StartDeathWatch()
    if GS._deathWatchActive or GraveSense.IsPaused() or not GS_State.HasTargets() then return end
    GS._deathWatchActive = true
    GraveSense.DeathWatchTick()
end

function GraveSense.StopDeathWatch(clearTargets)
    GS._deathWatchActive = false
    if GS._deathWatchTimer and Script and Script.KillTimer then
        pcall(Script.KillTimer, GS._deathWatchTimer)
    end
    GS._deathWatchTimer = nil
    if clearTargets then GS_State.ClearTargets() end
end

function GraveSense.StartCombat()
    if GS._combatActive or GraveSense.IsPaused() then return end
    GS._combatActive = true
    GS_State.ResetCombat()
    GS_State.ClearTargetExpiry()
    GS_Log.Info("combat scan started")
    GraveSense.CombatTick()
end

function GraveSense.StopCombat()
    local wasActive = GS._combatActive
    GS._combatActive = false
    if GS._combatTimer and Script and Script.KillTimer then
        pcall(Script.KillTimer, GS._combatTimer)
    end
    GS._combatTimer = nil
    GS_State.ResetCombat()
    if GS_State.HasTargets() then
        local retention = tonumber(GS.cfg.runtime.postCombatRetentionMs) or 15000
        GS_State.SetTargetExpiry(currentTimeMs() + math.max(0, retention))
        GraveSense.StartDeathWatch()
    end
    if wasActive then GS_Log.Info("combat scan stopped") end
end

function GraveSense.HeartbeatTick()
    GS._heartbeatTimer = nil
    if not GS._heartbeatActive or GraveSense.IsPaused() then return end

    local player = getPlayer()
    local combat = isInCombat(player)
    if player then logPollingAlive(combat) end
    if combat and not GS._inCombat then
        GS._inCombat = true
        GraveSense.StartCombat()
    elseif not combat and GS._inCombat then
        GS._inCombat = false
        GraveSense.StopCombat()
    end

    if Script and Script.SetTimerForFunction then
        GS._heartbeatTimer = Script.SetTimerForFunction(
            tonumber(GS.cfg.runtime.heartbeatMs) or 1000,
            "GraveSense.HeartbeatTick"
        )
    end
end

_G["GraveSense.HeartbeatTick"] = GraveSense.HeartbeatTick

function GraveSense.Start()
    if not GS.cfg then GraveSense.ReloadConfig() end
    if not GS.cfg.enabled or GraveSense.IsPaused() or GS._heartbeatActive then return end
    GS._heartbeatActive = true
    GS_Log.Info(("ready: repairKits=%s%% potions=%s%% bandages=%s%% dryRun=%s")
        :format(tostring(GS.cfg.rules.repairKits.chance), tostring(GS.cfg.rules.potions.chance),
            tostring(GS.cfg.rules.bandages.chance),
            tostring(GS.cfg.safety.dryRun)))
    GraveSense.HeartbeatTick()
end

function GraveSense.SetEnabled(enabled, source)
    if not GS.cfg then GraveSense.ReloadConfig() end
    enabled = enabled == true

    if GS.cfg.enabled == enabled then
        GS_Log.Info(("enabled=%s source=%s (unchanged)")
            :format(tostring(enabled), tostring(source or "runtime")))
        return
    end

    GS.cfg.enabled = enabled
    if enabled then
        GraveSense.Start()
    else
        GraveSense.Stop()
    end

    GS_Log.Info(("enabled=%s source=%s")
        :format(tostring(enabled), tostring(source or "runtime")))
end

function GraveSense.Stop()
    GraveSense.StopCombat()
    GraveSense.StopDeathWatch(true)
    GS._heartbeatActive = false
    if GS._heartbeatTimer and Script and Script.KillTimer then
        pcall(Script.KillTimer, GS._heartbeatTimer)
    end
    GS._heartbeatTimer = nil
    GS._inCombat = false
end

function GraveSense.IsPaused()
    return next(GS._pauseReasons or {}) ~= nil
end

local function pauseReasonList()
    local reasons = {}
    for reason in pairs(GS._pauseReasons or {}) do reasons[#reasons + 1] = tostring(reason) end
    table.sort(reasons)
    return table.concat(reasons, ",")
end

function GraveSense.Pause(reason)
    reason = tostring(reason or "unknown")
    if GS._pauseReasons[reason] then return end

    GS._pauseReasons[reason] = true
    GraveSense.Stop()
    GS_Log.Info("polling paused: " .. reason)
end

function GraveSense.Resume(reason)
    reason = tostring(reason or "unknown")
    if not GS._pauseReasons[reason] then return end

    GS._pauseReasons[reason] = nil
    if GraveSense.IsPaused() then
        GS_Log.Info("polling remains paused: " .. pauseReasonList())
        return
    end

    GS._lastPollingLogMs = nil
    GS_Log.Info("polling resumed: " .. reason)
    GraveSense.Start()
end

function GraveSense.ClearPauseReasons()
    GS._pauseReasons = {}
end

function GraveSense.OnGameplayStarted()
    -- Level/save loading discards pending Script timers without clearing our
    -- Lua flags. Force a fresh timer chain for the newly established world.
    GraveSense.Stop()
    GraveSense.ClearPauseReasons()
    GS_State.ResetAll()
    GS._lastPollingLogMs = nil
    if GS.Settings and GS.Settings.LoadInto then
        GS.Settings.LoadInto(GS.cfg)
    end
    GS_Log.Info("gameplay started")
    GraveSense.Start()
end

function GraveSense.Reboot()
    GraveSense.Stop()
    GraveSense.ReloadConfig()
    GS_State.ResetAll()
    GraveSense.Start()
end

GraveSense.ReloadConfig()
