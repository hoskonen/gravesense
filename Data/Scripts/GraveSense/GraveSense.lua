-- Scripts/GraveSense/GraveSense.lua
-- Minimal heartbeat + combat-gated death probe (Lua 5.1)

GraveSense     = GraveSense or {}
local GS       = GraveSense

-- State
GS._hbActive   = false      -- heartbeat loop running?
GS._cbActive   = false      -- combat loop running?
GS._inCombat   = false
GS._ticksHB    = 0
GS._ticksCB    = 0
GS._seenDead   = {}      -- [wuid]=true (to avoid re-logging same corpse)

-- Subscribers
GS._pipesDeath = {}      -- list of callbacks (fn(meta))
function GraveSense.onDeathUse(fn) GS._pipesDeath[#GS._pipesDeath + 1] = fn end

-- Latest death metadata (for debugging/manual bridge)
GS._latestDeath = nil

-- Debounce (avoid re-firing for the same corpse too often)
GS._seenDeadAt = {} -- [wuid] = lastFireMs

local function _fireDeath(meta)
    GS._latestDeath = meta
    for i = 1, #GS._pipesDeath do
        local ok, err = pcall(GS._pipesDeath[i], meta)
        if not ok then System.LogAlways("[GraveSense] death pipe error: " .. tostring(err)) end
    end
end

-- Death queue (read-only handoff; no mutations)
GS._dq = {}    -- array of {timeMs, wuid, entity, name, pos}
GS._dqMax = 32 -- cap

-- ===== config: defaults + overrides loader =====
-- Defaults live in code; overrides come from Scripts/GraveSense/Config.lua (if present)
GS.cfg = {
    enabled     = true,
    heartbeatMs = 3000,
    traceTicks  = false,
    debug       = true,

    combatMs    = 1000,
    scanRadiusM = 8.0,
    debounceMs  = 15000,

    bridge      = {
        enabled         = true,
        sanitizeOnDeath = false,
        delayMs         = 200,
        dryRun          = true,
    },
}

local function _applyOverrides(dst, src)
    for k, v in pairs(src or {}) do
        if type(v) == "table" and type(dst[k]) == "table" then
            _applyOverrides(dst[k], v)
        else
            dst[k] = v
        end
    end
end

function GraveSense.ReloadConfig()
    -- reset to defaults
    GS.cfg = {
        enabled     = true,
        heartbeatMs = 3000,
        traceTicks  = false,
        debug       = true,

        combatMs    = 1000,
        scanRadiusM = 8.0,
        debounceMs  = 15000,

        bridge      = {
            enabled         = true,
            sanitizeOnDeath = false,
            delayMs         = 200,
            dryRun          = true,
        },
    }

    -- load overrides
    local ok = pcall(function()
        Script.ReloadScript("Scripts/GraveSense/Config.lua")
    end)

    if ok and _G.GraveSense_Config and type(_G.GraveSense_Config) == "table" then
        _applyOverrides(GS.cfg, _G.GraveSense_Config)
        System.LogAlways(("[GraveSense] config loaded hb=%.1fs combat=%.1fs r=%.1fm debounce=%.1fs bridge=%s sanitizeOnDeath=%s")
            :format(
                (GS.cfg.heartbeatMs or 0) / 1000,
                (GS.cfg.combatMs or 0) / 1000,
                (GS.cfg.scanRadiusM or 0),
                (GS.cfg.debounceMs or 0) / 1000,
                tostring(GS.cfg.bridge and GS.cfg.bridge.enabled),
                tostring(GS.cfg.bridge and GS.cfg.bridge.sanitizeOnDeath)
            ))
    else
        System.LogAlways("[GraveSense] config defaults in effect (no overrides)")
    end
end

-- call once during load
GraveSense.ReloadConfig()

local function _dqPush(rec)
    local q = GS._dq
    q[#q + 1] = rec
    if #q > (GS._dqMax or 32) then table.remove(q, 1) end
end

function GraveSense.GetLatestDeath()
    return GS._dq[#GS._dq]
end

function GraveSense.DrainDeaths()
    local q = GS._dq
    local out = q
    GS._dq = {}
    return out
end

-- Logging
local function Log(s) System.LogAlways("[GraveSense] " .. tostring(s)) end

-- Helpers
local function GetPlayer()
    return (System.GetEntityByName and (System.GetEntityByName("Henry") or System.GetEntityByName("dude"))) or nil
end

local function IsInCombatRaw(player)
    local soul = player and player.soul
    if soul and soul.IsInCombatDanger then
        local ok, v = pcall(soul.IsInCombatDanger, soul); if ok and (v == 1 or v == true) then return true end
    end
    if soul and soul.IsInCombat then
        local ok, v = pcall(soul.IsInCombat, soul); if ok and (v == 1 or v == true) then return true end
    end
    local a = player and player.actor
    if a and a.IsInCombat then
        local ok, v = pcall(a.IsInCombat, a); if ok and (v == 1 or v == true) then return true end
    end
    return false
end

local function IsEntityDead(e)
    if not e then return false end
    if e.soul and e.soul.IsDead then
        local ok, v = pcall(e.soul.IsDead, e.soul); if ok and (v == true or v == 1) then return true end
    end
    if e.actor and e.actor.IsDead then
        local ok, v = pcall(e.actor.IsDead, e.actor); if ok and (v == true or v == 1) then return true end
    end
    -- best-effort HP read (optional, very light)
    local hp
    if e.soul and e.soul.GetHealth then
        local ok, v = pcall(e.soul.GetHealth, e.soul); if ok then hp = v end
    end
    if hp == nil and e.actor and e.actor.GetHealth then
        local ok, v = pcall(e.actor.GetHealth, e.actor); if ok then hp = v end
    end
    if type(hp) == "number" and hp <= 1.0 then return true end
    return false
end

local function GetWUID(e)
    if XGenAIModule and XGenAIModule.GetMyWUID and e then
        local ok, w = pcall(function() return XGenAIModule.GetMyWUID(e) end); if ok and w then return w end
    end
    return tostring(e.id or e)
end

local function Dist2(a, b)
    local dx = a.x - b.x; local dy = a.y - b.y; local dz = a.z - b.z; return dx * dx + dy * dy + dz * dz
end

-- ========== HEARTBEAT TICK (every 3s) ==========
function GraveSense.HeartbeatTick()
    if not GS._hbActive then return end
    GS._ticksHB = GS._ticksHB + 1

    local p = GetPlayer()
    if not p then
        if GS.cfg.debug then
            Log("Polling for combat.. (no player)")
        end
    else
        local ic = IsInCombatRaw(p)
        if GS.cfg.debug then
            Log("Polling for combat.. inCombat=" .. tostring(ic))
        end

        if ic and not GS._inCombat then
            GS._inCombat = true
            GraveSense.StartCombatLoop()
        elseif (not ic) and GS._inCombat then
            GS._inCombat = false
            GraveSense.StopCombatLoop("combat ended")
        end
    end

    if Script and Script.SetTimerForFunction then
        Script.SetTimerForFunction(GS.cfg.heartbeatMs, "GraveSense.HeartbeatTick")
    end
end

_G["GraveSense.HeartbeatTick"] = GraveSense.HeartbeatTick

local function DEBOUNCE_MS()
    return (GS.cfg and GS.cfg.debounceMs) or 15000
end

-- ========== COMBAT TICK (every 1s while in combat) ==========
function GraveSense.CombatTick()
    if (not GS._cbActive) or (not GS._inCombat) then return end
    GS._ticksCB = GS._ticksCB + 1

    -- scan for newly-dead enemies near player
    -- scan for newly-dead enemies near player
    local p = GetPlayer()
    if p and p.GetWorldPos then
        local pos  = p:GetWorldPos()
        local R    = GS.cfg.scanRadiusM or 8.0
        local list = (System.GetEntitiesInSphere and System.GetEntitiesInSphere(pos, R)) or System.GetEntities() or {}
        local r2   = R * R

        for i = 1, #list do
            local e = list[i]
            if e and e ~= p and e.GetWorldPos then
                local ep = e:GetWorldPos()
                local inside = System.GetEntitiesInSphere and true or (Dist2(pos, ep) <= r2)
                if inside and IsEntityDead(e) then
                    local w    = GetWUID(e)
                    local now  = (System.GetCurrTime and math.floor(System.GetCurrTime() * 1000)) or
                        math.floor((os.clock() or 0) * 1000)
                    local last = GS._seenDeadAt[w]
                    if not last or (now - last) >= DEBOUNCE_MS() then
                        GS._seenDeadAt[w] = now
                        local nm = (e.GetName and e:GetName()) or (e.class or "entity")
                        if GS.cfg.debug then Log("☠ death detected: " .. tostring(nm) .. " (wuid=" .. tostring(w) .. ")") end

                        -- build once, then queue + fire once
                        local rec = {
                            entity = e,
                            wuid = w,
                            name = nm,
                            pos = ep,
                            timeMs = now,
                            radius = R,
                            ticks = GS
                                ._ticksCB
                        }
                        _dqPush(rec)
                        _fireDeath(rec)
                    end
                end
            end
        end
    end


    if Script and Script.SetTimerForFunction then
        Script.SetTimerForFunction(GS.cfg.combatMs, "GraveSense.CombatTick")
    end
end

_G["GraveSense.CombatTick"] = GraveSense.CombatTick

-- DEV: prove the event bus fires
if GraveSense and GraveSense.onDeathUse then
    GraveSense.onDeathUse(function(meta)
        System.LogAlways(("[GraveSense] [BUS] death event: name=%s wuid=%s r=%.1fm t=%d ticks=%d")
            :format(tostring(meta.name), tostring(meta.wuid), meta.radius or 0, meta.timeMs or -1, meta.ticks or -1))
    end)
end

-- ========== LIFECYCLE ==========
function GraveSense.StartHeartbeat()
    if GS._hbActive then
        if Script and Script.SetTimerForFunction then Script.SetTimerForFunction(1, "GraveSense.HeartbeatTick") end
        return
    end
    GS._hbActive = true
    GS._ticksHB  = 0
    if GS.cfg.debug then Log(string.format("Heartbeat started (%.1fs)", (GS.cfg.heartbeatMs or 0) / 1000)) end
    GraveSense.HeartbeatTick()
end

function GraveSense.StartCombatLoop()
    if GS._cbActive then return end
    GS._cbActive = true
    GS._ticksCB  = 0
    GS._seenDead = {} -- reset per combat
    Log(string.format("Combat loop started (%.1fs)", (GS.cfg.combatMs or 0) / 1000))
    GraveSense.CombatTick()
end

function GraveSense.StopCombatLoop(reason)
    if not GS._cbActive then return end
    GS._cbActive = false
    Log("Combat loop stopped" .. (reason and (": " .. tostring(reason)) or ""))
end

function GraveSense.StopAll(reason)
    GS._hbActive = false
    GS._cbActive = false
    GS._inCombat = false
    if GS.cfg.debug then
        Log("All loops stopped" .. (reason and (": " .. tostring(reason)) or ""))
    end
end

function GraveSense.OnGameplayStarted()
    if GS.cfg.debug then
        Log("OnGameplayStarted → ensure heartbeat")
    end
    GraveSense.StartHeartbeat()
end

function GraveSense.DebugConfig()
    local c = GS.cfg
    System.LogAlways(("[GraveSense] cfg: enabled=%s hb=%dms cb=%dms r=%.1fm debounce=%dms trace=%s debug=%s")
        :format(tostring(c.enabled), c.heartbeatMs, c.combatMs, c.scanRadiusM, c.debounceMs, tostring(c.traceTicks),
            tostring(c.debug)))
end

function GraveSense.Reboot()
    GraveSense.StopAll("reboot")
    GraveSense.ReloadConfig()
    GraveSense.StartHeartbeat()
end

function GraveSense.DebugDumpLatest()
    local d = GraveSense.GetLatestDeath and GraveSense.GetLatestDeath()
    if not d or not d.entity then
        System.LogAlways("[GraveSense] no deaths to dump")
        return
    end
    local rows, how = GS_Enum.enumSubject(d.entity)
    GS_Enum.logInventoryRows(d.entity, rows, how)
end
