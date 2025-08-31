-- Scripts/GraveSense/SanitizerBridge.lua
-- Disabled bridge from GraveSense death events → (future) CorpseSanitizer actions
-- Lua 5.1; no goto
local San = GS_Sanitizer
local function bool(x) return not not x end

-- optional: toggle dumping without editing code again
local function BRIDGE_DUMP() -- defaults to true if not set in cfg
    return (GraveSense and GraveSense.cfg and GraveSense.cfg.bridge and GraveSense.cfg.bridge.dump) ~= false
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
    local cfg             = GraveSense and GraveSense.cfg or {}
    local bcfg            = cfg.bridge or {}
    local scfg            = cfg.sanitize or {}

    local BRIDGE_SANITIZE = bool(bcfg.sanitizeOnDeath)
    local BRIDGE_DELAY    = tonumber(bcfg.delayMs or 200) or 200
    local DRY             = (scfg.dryRun ~= false) -- default true

    System.LogAlways(("[GraveSense→Bridge] would sanitize: %s (wuid=%s)")
        :format(tostring(meta.name), tostring(meta.wuid)))

    -- read-only dump (optional)
    if BRIDGE_DUMP() then
        dumpInventory(meta.entity)
    end

    if BRIDGE_SANITIZE and San and San.nukeInventory then
        local victim = meta.entity -- capture reference now
        local vname  = (victim and victim.GetName and victim:GetName()) or meta.name or "entity"

        System.LogAlways(("[GraveSense→Bridge] scheduling sanitize (dryRun=%s) for %s in %dms")
            :format(tostring(DRY), tostring(vname), BRIDGE_DELAY))

        if Script and Script.SetTimerForFunction then
            GraveSense.__DoSanitize = function()
                -- guard: victim may be gone
                if not victim then
                    System.LogAlways("[GraveSense→Bridge] victim entity nil at run; skipping")
                else
                    local ok, err = pcall(San.nukeInventory, victim, { dryRun = DRY, corpseCtx = true })
                    if not ok then
                        System.LogAlways("[GraveSense→Bridge] sanitize error: " .. tostring(err))
                    end
                end
                -- clear trampoline to avoid reuse
                GraveSense.__DoSanitize = nil
                _G["GraveSense.__DoSanitize"] = nil
            end
            -- make sure the name is visible globally for SetTimerForFunction
            _G["GraveSense.__DoSanitize"] = GraveSense.__DoSanitize
            Script.SetTimerForFunction(BRIDGE_DELAY, "GraveSense.__DoSanitize")
        else
            -- immediate fallback
            local ok, err = pcall(San.nukeInventory, victim, { dryRun = DRY, corpseCtx = true })
            if not ok then
                System.LogAlways("[GraveSense→Bridge] sanitize error: " .. tostring(err))
            end
        end
    else
        System.LogAlways("[GraveSense→Bridge] sanitizeOnDeath=false (skipping)")
    end
end

if GraveSense and GraveSense.onDeathUse then
    GraveSense.onDeathUse(onDeath)
    System.LogAlways("[GraveSense→Bridge] subscribed (ENABLE_BRIDGE=false)")
end
