-- Scripts/GraveSense/GraveSense.lua
-- Minimal heartbeat + combat-gated death probe (Lua 5.1)

GraveSense          = GraveSense or {}
local GS            = GraveSense

-- Tunables
local HEARTBEAT_MS  = 3000  -- "Polling for combat.." cadence
local COMBAT_MS     = 1000  -- death probe cadence while in combat
local SCAN_RADIUS_M = 8.0   -- meters for death probe

-- State
GS._hbActive        = false -- heartbeat loop running?
GS._cbActive        = false -- combat loop running?
GS._inCombat        = false
GS._ticksHB         = 0
GS._ticksCB         = 0
GS._seenDead        = {} -- [wuid]=true (to avoid re-logging same corpse)

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
        Log("Polling for combat.. (no player)")
    else
        local ic = IsInCombatRaw(p)
        Log("Polling for combat.. inCombat=" .. tostring(ic))

        if ic and not GS._inCombat then
            GS._inCombat = true
            GraveSense.StartCombatLoop()
        elseif (not ic) and GS._inCombat then
            GS._inCombat = false
            GraveSense.StopCombatLoop("combat ended")
        end
    end

    if Script and Script.SetTimerForFunction then
        Script.SetTimerForFunction(HEARTBEAT_MS, "GraveSense.HeartbeatTick")
    end
end

_G["GraveSense.HeartbeatTick"] = GraveSense.HeartbeatTick

-- ========== COMBAT TICK (every 1s while in combat) ==========
function GraveSense.CombatTick()
    if (not GS._cbActive) or (not GS._inCombat) then return end
    GS._ticksCB = GS._ticksCB + 1

    -- scan for newly-dead enemies near player
    local p = GetPlayer()
    if p and p.GetWorldPos then
        local pos = p:GetWorldPos()
        local list = (System.GetEntitiesInSphere and System.GetEntitiesInSphere(pos, SCAN_RADIUS_M)) or
        System.GetEntities() or {}
        local r2 = SCAN_RADIUS_M * SCAN_RADIUS_M
        for i = 1, #list do
            local e = list[i]
            if e and e ~= p and e.GetWorldPos then
                local ep = e:GetWorldPos()
                local inside = System.GetEntitiesInSphere and true or (Dist2(pos, ep) <= r2)
                if inside and IsEntityDead(e) then
                    local w = GetWUID(e)
                    if not GS._seenDead[w] then
                        GS._seenDead[w] = true
                        local nm = (e.GetName and e:GetName()) or (e.class or "entity")
                        Log("☠ death detected: " .. tostring(nm) .. " (wuid=" .. tostring(w) .. ")")
                    end
                end
            end
        end
    end

    if Script and Script.SetTimerForFunction then
        Script.SetTimerForFunction(COMBAT_MS, "GraveSense.CombatTick")
    end
end

_G["GraveSense.CombatTick"] = GraveSense.CombatTick

-- ========== LIFECYCLE ==========
function GraveSense.StartHeartbeat()
    if GS._hbActive then
        if Script and Script.SetTimerForFunction then Script.SetTimerForFunction(1, "GraveSense.HeartbeatTick") end
        return
    end
    GS._hbActive = true
    GS._ticksHB  = 0
    Log(string.format("Heartbeat started (%.1fs)", HEARTBEAT_MS / 1000))
    GraveSense.HeartbeatTick()
end

function GraveSense.StartCombatLoop()
    if GS._cbActive then return end
    GS._cbActive = true
    GS._ticksCB  = 0
    GS._seenDead = {} -- reset per combat
    Log(string.format("Combat loop started (%.1fs)", COMBAT_MS / 1000))
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
    Log("All loops stopped" .. (reason and (": " .. tostring(reason)) or ""))
end

function GraveSense.OnGameplayStarted()
    Log("OnGameplayStarted → ensure heartbeat")
    GraveSense.StartHeartbeat()
end
