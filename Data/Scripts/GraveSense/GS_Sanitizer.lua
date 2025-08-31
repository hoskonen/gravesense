-- Scripts/GraveSense/GS_Sanitizer.lua  (Lua 5.1, no goto)
GS_Sanitizer = GS_Sanitizer or {}
local Log = function(s) System.LogAlways("[GraveSense][San] " .. tostring(s)) end

-- defaults (overrides come from GraveSense.cfg.sanitize if present)
local function cfg()
    local c = (GraveSense and GraveSense.cfg and GraveSense.cfg.sanitize) or {}
    return {
        enabled             = (c.enabled ~= false),   -- global enable for sanitizer
        dryRun              = (c.dryRun ~= false),    -- stay DRY-RUN by default
        unequipBeforeDelete = (c.unequipBeforeDelete ~= false),
        skipMoney           = (c.skipMoney ~= false), -- true: don't delete 'money'
        protectNames        = c.protectNames or {},   -- e.g., { money=true, bandage=true }
        protectClasses      = c.protectClasses or {}, -- map[classId]=true
    }
end

-- tiny helpers
local function getItem(handle)
    if ItemManager and ItemManager.GetItem and handle then
        local ok, it = pcall(ItemManager.GetItem, handle)
        if ok then return it end
    end
end

local function getNameByClass(classId)
    if ItemManager and ItemManager.GetItemName and classId then
        local ok, nm = pcall(ItemManager.GetItemName, tostring(classId))
        if ok and nm and nm ~= "" then return nm end
    end
    return tostring(classId or "?")
end

-- decision: should delete this row?
local function shouldDelete(row, C)
    local it    = row.item or getItem(row.handle)
    local class = (it and it.class) or row.class
    local name  = (class and getNameByClass(class)) or row.name or "?"

    -- protections
    if C.skipMoney and name == "money" then return false, "protect: money" end
    if C.protectNames and C.protectNames[name] then return false, "protect: name" end
    if C.protectClasses and class and C.protectClasses[class] then return false, "protect: class" end

    -- default: delete everything else
    return true, "delete"
end

-- build a plan: read-only pass over inventory
local function enumInventory(subject)
    local out = {}
    local inv = subject and subject.inventory
    if inv and inv.GetInventoryTable then
        local ok, tbl = pcall(inv.GetInventoryTable, inv)
        if ok and type(tbl) == "table" then
            for _, handle in pairs(tbl) do
                local it      = getItem(handle)
                local class   = it and it.class
                local name    = (class and getNameByClass(class)) or "?"
                out[#out + 1] = { handle = handle, item = it, class = class, name = name }
            end
        end
    end
    return out
end

-- execute the plan (if not dry-run)
local function tryUnequip(subject, handle)
    if not subject then return false end
    local inv = subject.inventory
    if inv and inv.IsEquipped and inv.UnequipItem then
        local ok, eq = pcall(inv.IsEquipped, inv, handle)
        if ok and eq then
            local ok2 = pcall(inv.UnequipItem, inv, handle)
            return ok2 and true or false
        end
    end
    return false
end

local function deleteHandle(subject, handle)
    local inv = subject and subject.inventory
    if inv and inv.DeleteItem then
        local ok = pcall(inv.DeleteItem, inv, handle)
        return ok and true or false
    end
    if Inventory and Inventory.DeleteItem and subject then
        local ok = pcall(Inventory.DeleteItem, subject, handle)
        return ok and true or false
    end
    return false
end

-- public: dry-run sanitization (or real if dryRun=false)
function GS_Sanitizer.nukeInventory(subject, opts)
    local C = cfg()

    local rowsBefore = enumInventory(subject)
    local countBefore = #rowsBefore

    if not C.enabled then
        Log("skipped: sanitize.enabled=false"); return false
    end

    local dry = C.dryRun
    if opts and opts.dryRun ~= nil then dry = opts.dryRun and true or false end

    local owner = (subject and ((subject.GetName and subject:GetName()) or subject.class)) or "entity"
    Log(("begin (%s) owner=%s"):format(dry and "dry-run" or "live", tostring(owner)))

    local rows = enumInventory(subject)
    local delCount, keepCount = 0, 0

    for i = 1, #rows do
        local r = rows[i]
        local yes, why = shouldDelete(r, C)
        if yes then
            delCount = delCount + 1
            if dry then
                Log(("  would delete: %s (class=%s handle=%s)"):format(r.name, tostring(r.class), tostring(r.handle)))
            else
                if C.unequipBeforeDelete then tryUnequip(subject, r.handle) end
                local ok = deleteHandle(subject, r.handle)
                Log(("  delete %s → %s"):format(r.name, ok and "ok" or "fail"))
            end
        else
            keepCount = keepCount + 1
            Log(("  keep (%s): %s"):format(why, r.name))
        end
    end

    local rowsAfter = enumInventory(subject)
    local countAfter = #rowsAfter
    local delta = countBefore - countAfter

    if delta > 0 then
        Log(("verify: writable → removed=%d (before=%d after=%d)"):format(delta, countBefore, countAfter))
    else
        Log(("verify: no delta (likely read-only) → before=%d after=%d"):format(countBefore, countAfter))
    end

    Log(("end: keep=%d delete=%d total=%d"):format(keepCount, delCount, #rows))
    return true
end
