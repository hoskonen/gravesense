-- Scripts/GraveSense/GS_Enum.lua  (Lua 5.1, no goto)
GS_Enum = GS_Enum or {}

local function Log(s) System.LogAlways("[GraveSense] " .. tostring(s)) end

local function getPrettyItemName(classId)
    if not classId then return "?" end
    if ItemManager and ItemManager.GetItemName then
        local ok, nm = pcall(ItemManager.GetItemName, tostring(classId))
        if ok and nm and nm ~= "" then return nm end
    end
    return tostring(classId)
end

-- Normalize a row into {handle=?, class=?, name=?}
local function normalizeRow(row)
    local handle, class = nil, nil
    if type(row) == "userdata" then
        handle = row
    elseif type(row) == "table" then
        handle = row.id or row.Id or row.handle or row.Handle
        class  = row.class or row.Class
    end
    if not class and ItemManager and ItemManager.GetItemClass then
        if handle then
            local ok, cls = pcall(ItemManager.GetItemClass, handle)
            if ok then class = cls end
        end
    end
    local name = getPrettyItemName(class)
    return { handle = handle, class = class, name = name }
end

-- Try a few common enumeration APIs; return array of normalized rows
function GS_Enum.enumSubject(subject)
    local out = {}
    local inv = subject and subject.inventory
    if inv and inv.GetInventoryTable then
        local ok, tbl = pcall(inv.GetInventoryTable, inv)
        if ok and type(tbl) == "table" then
            for k, v in pairs(tbl) do out[#out + 1] = normalizeRow(v) end
            return out, "subject.inventory:GetInventoryTable"
        end
    end
    if inv and inv.EnumItems then
        local ok, iter = pcall(inv.EnumItems, inv)
        if ok and type(iter) == "table" then
            for i = 1, #iter do out[#out + 1] = normalizeRow(iter[i]) end
            return out, "subject.inventory:EnumItems"
        end
    end
    -- global fallback
    if Inventory and Inventory.GetInventoryTable and subject then
        local ok, tbl = pcall(Inventory.GetInventoryTable, subject)
        if ok and type(tbl) == "table" then
            for k, v in pairs(tbl) do out[#out + 1] = normalizeRow(v) end
            return out, "Inventory.GetInventoryTable(subject)"
        end
    end
    return out, "none"
end

function GS_Enum.logInventoryRows(subject, rows, how)
    local owner = (subject and ((subject.GetName and subject:GetName()) or subject.class)) or "entity"
    how = how or "?"
    Log(("Inventory of %s via %s: %d rows"):format(tostring(owner), tostring(how), #rows))
    for i = 1, #rows do
        local r = rows[i]
        Log(("  #%d class=%s name=%s handle=%s"):format(
            i, tostring(r.class), tostring(r.name), tostring(r.handle)))
    end
end
