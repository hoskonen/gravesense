GS_Mutator = GS_Mutator or {}

local function itemForHandle(handle)
    if ItemManager and ItemManager.GetItem and handle then
        local ok, item = pcall(ItemManager.GetItem, handle)
        if ok then return item end
    end
    return nil
end

local function nameForClass(classId)
    if ItemManager and ItemManager.GetItemName and classId then
        local ok, name = pcall(ItemManager.GetItemName, tostring(classId))
        if ok and name and name ~= "" then return tostring(name) end
    end
    return tostring(classId or "?")
end

local function enumerate(subject)
    local inventory = subject and subject.inventory
    if not (inventory and inventory.GetInventoryTable) then
        return nil, inventory, "inventory unavailable"
    end

    local ok, raw = pcall(inventory.GetInventoryTable, inventory)
    if not ok or type(raw) ~= "table" then
        return nil, inventory, "enumeration failed"
    end

    local rows = {}
    for _, handle in pairs(raw) do
        local item = itemForHandle(handle)
        local classId = item and item.class or nil
        rows[#rows + 1] = {
            handle = handle,
            class = classId,
            name = nameForClass(classId),
        }
    end
    return rows, inventory, nil
end

local function countClass(inventory, rows, classId)
    if inventory and inventory.GetCountOfClass then
        local ok, value = pcall(inventory.GetCountOfClass, inventory, tostring(classId))
        if ok and type(value) == "number" then return value end
    end

    local count = 0
    for i = 1, #(rows or {}) do
        if tostring(rows[i].class) == tostring(classId) then count = count + 1 end
    end
    return count
end

function GS_Mutator.Process(subject, cfg)
    local rows, inventory, enumError = enumerate(subject)
    if not rows then
        return { complete = false, error = enumError, removed = 0, failed = 0, matched = 0 }
    end

    if not (inventory and type(inventory.DeleteItemOfClass) == "function") then
        return { complete = false, error = "DeleteItemOfClass unavailable", removed = 0, failed = 0, matched = 0 }
    end

    local plan, skippedEquipped = GS_Rules.BuildPlan(rows, inventory, cfg)
    local result = {
        complete = true,
        removed = 0,
        failed = 0,
        matched = #plan,
        skippedEquipped = skippedEquipped,
        details = {},
    }

    for i = 1, #plan do
        local operation = plan[i]
        local before = countClass(inventory, rows, operation.class)
        local after = before
        local callOk = true
        local engineResult = nil

        if before > 0 and not (cfg.safety and cfg.safety.dryRun) then
            callOk, engineResult = pcall(
                inventory.DeleteItemOfClass,
                inventory,
                operation.class,
                before
            )
            local afterRows = enumerate(subject)
            after = countClass(inventory, afterRows or {}, operation.class)
        end

        local removed = before - after
        local verified = (cfg.safety and cfg.safety.dryRun) or (callOk and before > 0 and after == 0)
        result.removed = result.removed + math.max(0, removed)
        if not verified then result.failed = result.failed + 1 end
        result.details[#result.details + 1] = {
            rule = operation.rule,
            name = operation.name,
            class = operation.class,
            before = before,
            after = after,
            removed = removed,
            verified = verified,
            engineResult = engineResult,
        }
    end

    return result
end
