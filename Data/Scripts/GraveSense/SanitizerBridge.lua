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

-- tiny safe resolver for a single handle → {class,name,health,handle}
local function resolveItem(handle)
    local it
    if ItemManager and ItemManager.GetItem and handle then
        local ok, v = pcall(ItemManager.GetItem, handle)
        if ok then it = v end
    end
    local class = it and it.class or nil
    local name  = class
    if ItemManager and ItemManager.GetItemName and class then
        local ok, nm = pcall(ItemManager.GetItemName, tostring(class))
        if ok and nm and nm ~= "" then name = nm end
    end
    local hp = (it and (it.health or it.hp)) or nil
    return { class = class, name = name or "?", health = hp, handle = handle }
end

local function dumpInventory(subject)
    local inv = subject and subject.inventory
    if not inv then
        System.LogAlways("[GraveSense→Bridge] no inventory on subject")
        return
    end

    -- try subject.inventory:GetInventoryTable() first
    local ok, tbl = pcall(inv.GetInventoryTable, inv)
    if not ok or type(tbl) ~= "table" then
        System.LogAlways("[GraveSense→Bridge] GetInventoryTable failed; nothing to list")
        return
    end

    local owner = (subject.GetName and subject:GetName()) or subject.class or "entity"
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    System.LogAlways(("[GraveSense→Bridge] Inventory of %s: %d rows"):format(tostring(owner), n))

    local i = 0
    for k, handle in pairs(tbl) do
        i = i + 1
        local row = resolveItem(handle)
        System.LogAlways(
            ("[GraveSense→Bridge]   #%d class=%s name=%s hp=%s handle=%s")
            :format(i, tostring(row.class), tostring(row.name),
                row.health and string.format("%.2f", row.health) or "nil",
                tostring(row.handle))
        )
    end
end

local function onDeath(meta)
    -- keep your existing banner (no mutations yet)
    System.LogAlways(("[GraveSense→Bridge] would sanitize: %s (wuid=%s)")
        :format(tostring(meta.name), tostring(meta.wuid)))

    -- read-only dump of victim inventory
    dumpInventory(meta.entity)
end

if GraveSense and GraveSense.onDeathUse then
    GraveSense.onDeathUse(onDeath)
    System.LogAlways("[GraveSense→Bridge] subscribed (ENABLE_BRIDGE=false)")
end
