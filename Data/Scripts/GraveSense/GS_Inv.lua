-- Scripts/GraveSense/GS_Inv.lua (or paste near top of GS_Sanitizer.lua)
GS_Inv = GS_Inv or {}

local function _wuidOfInv(subject)
    -- Try a few places where an inventory WUID/id might live
    local inv = subject and subject.inventory
    if inv then
        if inv.GetWUID then
            local ok, w = pcall(inv.GetWUID, inv); if ok and w then return w end
        end
        if inv.wuid then return inv.wuid end
        if inv.id then return inv.id end
    end
    -- Fallback: entity WUID sometimes accepted
    if subject and GetWUID then
        local w = GetWUID(subject); if w then return w end
    end
    return nil
end

local function _entityModule(subject)
    -- Some builds expose module functions directly on the entity
    -- e.g., subject.IsInventoryReadOnly(subject, invWuid)
    return subject
end

function GS_Inv.isReadOnly(subject)
    local inv = subject and subject.inventory
    local mod = _entityModule(subject)
    local invWuid = _wuidOfInv(subject)

    -- 1) Direct method on entity module: IsInventoryReadOnly(inventoryId)
    if mod and mod.IsInventoryReadOnly and invWuid then
        local ok, res = pcall(mod.IsInventoryReadOnly, mod, invWuid)
        if ok and res ~= nil then return res and true or false, "entity.IsInventoryReadOnly(wuid)" end
    end

    -- 2) inventory table might know its own state
    if inv and inv.IsReadOnly then
        local ok, ro = pcall(inv.IsReadOnly, inv)
        if ok and ro ~= nil then return ro and true or false, "inv.IsReadOnly()" end
    end

    -- 3) Actor.CheckVirtualInventoryRestrictions(inventory, className) exists:
    -- if it errors or disallows additions, treat as read-only (heuristic, off by default)
    -- (Commented; enable if you want a heuristic)
    -- if subject and subject.CheckVirtualInventoryRestrictions and inv then
    --   local ok, res = pcall(subject.CheckVirtualInventoryRestrictions, subject, inv, "money")
    --   if ok then return false, "heur: CheckVirtualInventoryRestrictions" end
    -- end

    return nil, "unknown"
end

function GS_Inv.release(subject)
    local mod = _entityModule(subject)
    local invWuid = _wuidOfInv(subject)

    -- 1) ReleaseInventory(ownerEntityId / inventoryId) – exposed on entity module in some builds
    if mod and mod.ReleaseInventory then
        -- Try with entity id/wuid first (the signature in docs mentions ownerEntityId)
        local arg = (GetWUID and GetWUID(subject)) or invWuid
        if arg then
            local ok = pcall(mod.ReleaseInventory, mod, arg)
            if ok then return true, "entity.ReleaseInventory(arg=" .. tostring(arg) .. ")" end
        end
        -- Try without args (some bindings ignore params)
        local ok2 = pcall(mod.ReleaseInventory, mod)
        if ok2 then return true, "entity.ReleaseInventory()" end
    end

    -- 2) Inventory object might expose Release()
    if subject and subject.inventory and subject.inventory.Release then
        local ok = pcall(subject.inventory.Release, subject.inventory)
        if ok then return true, "inv.Release()" end
    end

    return false, "noRelease"
end
