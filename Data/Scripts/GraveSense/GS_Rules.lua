GS_Rules = GS_Rules or {}

local definitions = {
    { id = "repairKits", prefixes = { "repairKit_" } },
    { id = "potions", prefixes = { "potion_" } },
    { id = "bandages", names = { "bandage", "bandage_classic" } },
}

local function startsWith(value, prefix)
    return value:sub(1, #prefix) == prefix
end

local function matchingRule(name, settings)
    for i = 1, #definitions do
        local definition = definitions[i]
        local rule = settings and settings[definition.id]
        local chance = rule and tonumber(rule.chance) or 0
        if rule and chance > 0 then
            for j = 1, #(definition.names or {}) do
                if name == definition.names[j] then
                    return definition.id, math.max(0, math.min(100, chance))
                end
            end
            for j = 1, #(definition.prefixes or {}) do
                if startsWith(name, definition.prefixes[j]) then
                    return definition.id, math.max(0, math.min(100, chance))
                end
            end
        end
    end
    return nil
end

-- Produces one operation per item class. Quantities are resolved by the
-- mutator immediately before deletion, so stacked items are removed correctly.
function GS_Rules.BuildPlan(rows, inventory, cfg)
    local plan = {}
    local byClass = {}
    local skippedEquipped = 0
    local safety = (cfg and cfg.safety) or {}

    for i = 1, #(rows or {}) do
        local row = rows[i]
        local classId = row.class and tostring(row.class) or nil
        local name = tostring(row.name or "")
        local protected = (safety.protectNames and safety.protectNames[name])
            or (classId and safety.protectClasses and safety.protectClasses[classId])

        local ruleId, chance
        if not protected then
            ruleId, chance = matchingRule(name, cfg and cfg.rules)
        end
        if ruleId and classId and not byClass[classId] then
            local equipped = false
            if safety.skipEquipped ~= false and inventory and inventory.IsEquipped and row.handle then
                local ok, value = pcall(inventory.IsEquipped, inventory, row.handle)
                equipped = ok and (value == true or value == 1) or false
            end

            if equipped then
                skippedEquipped = skippedEquipped + 1
            else
                local operation = {
                    class = classId,
                    name = name,
                    rule = ruleId,
                    chance = chance,
                }
                plan[#plan + 1] = operation
                byClass[classId] = operation
            end
        end
    end

    return plan, skippedEquipped
end
