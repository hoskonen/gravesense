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

-- try multiple deletion paths; return ok, usedLabel, traceStr
local function deleteHandle(subject, handle)
    local inv   = subject and subject.inventory
    local trace = {}
    local used  = nil

    local function try(label, fn)
        local ok, res = pcall(fn)
        trace[#trace + 1] = label .. "=" .. tostring(ok and (res == nil and "ok" or res))
        if ok and (res == true or res == nil) then
            used = label
            return true
        end
        return false
    end

    -- 1) inventory:DeleteItem(handle)  (engine destroy on owner)
    if inv and inv.DeleteItem then
        if try("inv.DeleteItem", function() return inv:DeleteItem(handle) end) then
            return true, used, table.concat(trace, " | ")
        end
    end

    -- 2) global Inventory.DeleteItem(subject, handle) (engine destroy, alt entry)
    if Inventory and Inventory.DeleteItem and subject then
        if try("Inventory.DeleteItem", function() return Inventory.DeleteItem(subject, handle) end) then
            return true, used, table.concat(trace, " | ")
        end
    end

    -- 3) ItemManager.DeleteItem(handle) (engine destroy by handle)
    if ItemManager and ItemManager.DeleteItem then
        if try("ItemManager.DeleteItem", function() return ItemManager.DeleteItem(handle) end) then
            return true, used, table.concat(trace, " | ")
        end
    end

    -- 4) inventory:RemoveItem(handle) (UI-level remove; may not persist)
    if inv and inv.RemoveItem then
        if try("inv.RemoveItem", function() return inv:RemoveItem(handle) end) then
            return true, used, table.concat(trace, " | ")
        end
    end

    -- 5) fallback global RemoveItem if it exists in your build
    if Inventory and Inventory.RemoveItem and subject then
        if try("Inventory.RemoveItem", function() return Inventory.RemoveItem(subject, handle) end) then
            return true, used, table.concat(trace, " | ")
        end
    end

    return false, used, table.concat(trace, " | ")
end


-- public: dry-run sanitization (or real if dryRun=false)
function GS_Sanitizer.nukeInventory(subject, opts)
    local isDeadNow = IsEntityDead and IsEntityDead(subject) or false
    Log(("ctx: corpse=%s (opts.corpseCtx=%s)"):format(tostring(isDeadNow), tostring(opts and opts.corpseCtx)))
    Log(("owner ptr: inv=%s subject=%s"):format(tostring(subject and subject.inventory), tostring(subject)))

    local inv = subject and subject.inventory
    local owner = (subject and ((subject.GetName and subject:GetName()) or subject.class)) or "entity"
    local isCorpse = IsEntityDead and IsEntityDead(subject) or false
    Log(("ctx: corpse=%s (opts.corpseCtx=%s)"):format(tostring(isCorpse), tostring(opts and opts.corpseCtx)))
    Log(("owner ptr: inv=%s subject=%s"):format(tostring(inv), tostring(subject)))

    -- hard read-only/virtual guards if exposed in your build
    local function invBool(fn)
        if inv and inv[fn] then
            local ok, v = pcall(inv[fn], inv); if ok and v ~= nil then return v end
        end; return nil
    end
    local ro  = invBool("IsReadOnly")
    local vir = invBool("IsVirtual")
    if ro ~= nil then Log(("inventory readonly? %s"):format(tostring(ro))) end
    if vir ~= nil then Log(("inventory virtual?  %s"):format(tostring(vir))) end


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

    -- Inside GS_Sanitizer.nukeInventory, right after computing owner/dry:
    local ro0, how0 = GS_Inv.isReadOnly and GS_Inv.isReadOnly(subject) or nil, "n/a"
    if ro0 ~= nil then
        Log(string.format("inventory readonly? %s (%s)", tostring(ro0), tostring(how0)))
    end

    -- If corpse context or we detect read-only, attempt a release then re-check
    local needRelease = (opts and opts.corpseCtx) or (ro0 == true)
    if needRelease and GS_Inv.release then
        local okRel, howRel = GS_Inv.release(subject)
        Log(string.format("release attempt → %s (%s)", okRel and "ok" or "fail", tostring(howRel)))
        local ro1, how1 = GS_Inv.isReadOnly and GS_Inv.isReadOnly(subject) or nil, "n/a"
        if ro1 ~= nil then
            Log(string.format("inventory readonly (post-release)? %s (%s)", tostring(ro1), tostring(how1)))
            if ro1 == true then
                Log("still read-only after release; proceeding will likely no-op")
            end
        end
    end


    local rows = enumInventory(subject)
    local delCount, keepCount = 0, 0

    for i = 1, #rows do
        local r = rows[i]
        local yes, why = shouldDelete(r, C)

        if not yes then
            keepCount = keepCount + 1
            Log(("  keep (%s): %s"):format(why, r.name))
        else
            delCount = delCount + 1

            if dry then
                Log(("  would delete: %s (class=%s handle=%s)"):format(r.name, tostring(r.class), tostring(r.handle)))
            else
                -- STRICT: unequip if equipped (on THIS inv)
                if inv and inv.IsEquipped then
                    local okEq, isEq = pcall(inv.IsEquipped, inv, r.handle)
                    if okEq and isEq then
                        Log(("  equip: %s is equipped → UnequipItem"):format(r.name))
                        if inv.UnequipItem then
                            local okU = pcall(inv.UnequipItem, inv, r.handle)
                            Log(("    UnequipItem → %s"):format(okU and "ok" or "fail"))
                        end
                    end
                end

                -- DELETE from the SAME inventory reference we enumerated
                local used, ok = nil, false
                local trace = {}

                local function try(label, fn)
                    local okc, res = pcall(fn)
                    trace[#trace + 1] = label .. "=" .. tostring(okc and (res == nil and "ok" or res))
                    if okc and (res == true or res == nil) then
                        used = label; return true
                    end
                    return false
                end

                if inv and inv.DeleteItem and try("inv.DeleteItem", function() return inv:DeleteItem(r.handle) end) then
                    ok = true
                elseif inv and inv.DeleteItemByClass and r.class and
                    try("inv.DeleteItemByClass", function() return inv:DeleteItemByClass(r.class, 1) end) then
                    ok = true
                elseif ItemManager and ItemManager.DeleteItem and
                    try("ItemManager.DeleteItem", function() return ItemManager.DeleteItem(r.handle) end) then
                    ok = true
                elseif inv and inv.RemoveItem and try("inv.RemoveItem", function() return inv:RemoveItem(r.handle) end) then
                    ok = true
                end

                Log(("  delete %s → %s%s {%s}"):format(
                    r.name, ok and "ok" or "fail", used and (" [" .. used .. "]") or "", table.concat(trace, " | ")))

                -- per-item immediate re-enum from the SAME inv (if available)
                local countAfter = 0
                if inv and inv.GetInventoryTable then
                    local okT, tab = pcall(inv.GetInventoryTable, inv)
                    if okT and type(tab) == "table" then for _ in pairs(tab) do countAfter = countAfter + 1 end end
                else
                    local rowsAfter = enumInventory(subject)
                    countAfter = #rowsAfter
                end

                local delta = countBefore - countAfter
                if not dry then
                    if delta > 0 then
                        Log(("verify: writable → removed=%d (before=%d after=%d)"):format(delta, countBefore, countAfter))
                    else
                        Log(("verify: no delta (likely read-only) → before=%d after=%d"):format(countBefore, countAfter))
                    end
                end
            end
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
