-- Scripts/GraveSense/GraveSense.lua
-- Minimal, reliable polling loop (Lua 5.1)

GraveSense             = GraveSense or {}
local GS               = GraveSense

-- --- config ---
local POLL_INTERVAL_MS = 3000 -- 3s

-- --- state ---
GS._active             = false
GS._ticks              = 0

-- --- log ---
local function Log(msg) System.LogAlways("[GraveSense] " .. tostring(msg)) end

-- --- helpers ---
local function GetPlayer()
    return (System.GetEntityByName and (System.GetEntityByName("Henry") or System.GetEntityByName("dude"))) or nil
end

local function IsInCombatRaw(p)
    local soul = p and p.soul
    if soul and soul.IsInCombatDanger then
        local ok, v = pcall(soul.IsInCombatDanger, soul); if ok and (v == 1 or v == true) then return true end
    end
    if soul and soul.IsInCombat then
        local ok, v = pcall(soul.IsInCombat, soul); if ok and (v == 1 or v == true) then return true end
    end
    local a = p and p.actor
    if a and a.IsInCombat then
        local ok, v = pcall(a.IsInCombat, a); if ok and (v == 1 or v == true) then return true end
    end
    return false
end

-- --- dotted global tick ---
function GraveSense.PollingTick()
    if not GS._active then return end

    GS._ticks = (GS._ticks or 0) + 1

    local p = GetPlayer()
    if not p then
        Log("Polling for combat.. (no player)")
    else
        local ic = IsInCombatRaw(p)
        Log("Polling for combat.. inCombat=" .. tostring(ic))
    end

    if Script and Script.SetTimerForFunction then
        Script.SetTimerForFunction(POLL_INTERVAL_MS, "GraveSense.PollingTick")
    end
end

-- ensure dotted global is present for safety (some engines require it)
_G["GraveSense.PollingTick"] = GraveSense.PollingTick

-- --- lifecycle ---
function GS.Start()
    if GS._active then
        Log("Polling already active")
        if Script and Script.SetTimerForFunction then
            Script.SetTimerForFunction(1, "GraveSense.PollingTick")
        end
        return
    end
    GS._active = true
    GS._ticks  = 0
    Log(string.format("Started polling every %.1fs", POLL_INTERVAL_MS / 1000))
    GraveSense.PollingTick() -- kick immediately by name
end

function GS.Stop(reason)
    if not GS._active then
        Log("Polling already stopped")
        return
    end
    GS._active = false
    Log("Stopped polling" .. (reason and (": " .. tostring(reason)) or ""))
end

-- world signal -> (re)start polling after load
function GraveSense.OnGameplayStarted()
    Log("OnGameplayStarted → ensure polling")
    GS.Start()
end
