-- Scripts/GraveSense/GS_Util.lua  (Lua 5.1, no goto)
GS_Util = GS_Util or {}

local function Log(s) System.LogAlways("[GraveSense] " .. tostring(s)) end

function GS_Util.GetPlayer()
    return (System.GetEntityByName and (System.GetEntityByName("Henry") or System.GetEntityByName("dude"))) or nil
end

function GS_Util.GetWUID(e)
    if XGenAIModule and XGenAIModule.GetMyWUID and e then
        local ok, w = pcall(function() return XGenAIModule.GetMyWUID(e) end)
        if ok and w then return w end
    end
    return tostring(e and (e.id or e) or "<nil>")
end

function GS_Util.IsCorpseEntity(e)
    if not e then return false end
    if e.IsCorpse and type(e.IsCorpse) == "function" then
        local ok, res = pcall(e.IsCorpse, e); if ok then return not not res end
    end
    local nm = ""; if e.GetName then pcall(function() nm = e:GetName() end) end
    local s = string.lower(tostring(nm))
    return (s:find("deadbody", 1, true) or s:find("dead_body", 1, true) or s:find("so_deadbody", 1, true)) and true or
    false
end

function GS_Util.IsHostileToPlayer(e)
    local p = GS_Util.GetPlayer()
    if not (e and p) then return false end
    for _, fn in ipairs({ "IsHostileTo", "IsHostile", "IsEnemyTo", "IsEnemy", "IsAggressiveTo" }) do
        local f = e[fn]; if type(f) == "function" then
            local ok, res = pcall(f, e, p); if ok and res then return true end
        end
    end
    -- faction fallback
    local ef, pf
    if e.GetFaction then
        local ok, v = pcall(e.GetFaction, e); if ok then ef = v end
    end
    if p.GetFaction then
        local ok, v = pcall(p.GetFaction, p); if ok then pf = v end
    end
    if ef and pf and ef ~= pf then return true end
    return false
end

-- safe name
function GS_Util.PrettyName(e)
    if not e then return "<nil>" end
    local nm = (e.GetName and e:GetName()) or e.class or "entity"
    return tostring(nm)
end
