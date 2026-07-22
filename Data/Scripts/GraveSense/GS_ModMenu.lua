-- Optional Mod Configuration Menu integration (Lua 5.1).

GraveSense = GraveSense or {}
GraveSense.ModMenu = GraveSense.ModMenu or {}

local GS = GraveSense
local MM = GS.ModMenu
local MOD_ID = "gravesense"
local MOD_NAME = "Grave Sense"

local function log(message)
    System.LogAlways("[GraveSense][MCM] " .. tostring(message))
end

local function toggleValue(value)
    local numericValue = tonumber(value)
    if numericValue == nil then return nil end
    return numericValue ~= 0
end

function MM.BuildSettings()
    MCM.AddMod(MOD_ID, MOD_NAME)

    MCM.AddCategory(MOD_ID, "General", "General Grave Sense settings.")
    MCM.AddToggle(
        MOD_ID, "enabled", "Enable",
        "Enable or disable Grave Sense inventory processing.",
        GS.cfg.enabled and 1 or 0
    )

    MCM.AddCategory(
        MOD_ID, "Item Categories",
        "Choose which item categories Grave Sense removes from NPC inventories."
    )
    MCM.AddToggle(
        MOD_ID, "bandages", "Bandages",
        "Remove bandages from eligible NPC inventories.",
        GS.cfg.rules.bandages.enabled and 1 or 0
    )
    MCM.AddToggle(
        MOD_ID, "potions", "Potions",
        "Remove potions from eligible NPC inventories.",
        GS.cfg.rules.potions.enabled and 1 or 0
    )
    MCM.AddToggle(
        MOD_ID, "repair_kits", "Repair Kits",
        "Remove repair kits from eligible NPC inventories.",
        GS.cfg.rules.repairKits.enabled and 1 or 0
    )

    MCM.AddCategory(MOD_ID, "Debug", "Additional diagnostic logging.")
    MCM.AddToggle(
        MOD_ID, "debug", "Enable",
        "Enable additional Grave Sense diagnostic messages.",
        GS.cfg.logging.debug and 1 or 0
    )
end

function MM.OnValueChanged(settingId, value)
    local enabled = toggleValue(value)
    if enabled == nil then
        log("ignored invalid value for " .. tostring(settingId) .. ": " .. tostring(value))
        return
    end

    if not (GS.Settings and GS.Settings.SaveAll) then
        log("settings module unavailable; change ignored")
        return
    end

    if settingId == "enabled" then
        GS.Settings.SetEnabled(enabled, "mcm", true)
    elseif settingId == "bandages" then
        GS.Settings.SetRuleEnabled("bandages", enabled, "mcm", true)
    elseif settingId == "potions" then
        GS.Settings.SetRuleEnabled("potions", enabled, "mcm", true)
    elseif settingId == "repair_kits" then
        GS.Settings.SetRuleEnabled("repairKits", enabled, "mcm", true)
    elseif settingId == "debug" then
        GS.Settings.SetDebugEnabled(enabled, "mcm", true)
    else
        return
    end

    log(("%s=%s"):format(tostring(settingId), tostring(enabled)))
end

-- Stable closures prevent duplicate/stale callbacks across Script.ReloadScript.
MM._buildListener = MM._buildListener or function()
    MM.BuildSettings()
end

MM._valueListener = MM._valueListener or function(settingId, value)
    MM.OnValueChanged(settingId, value)
end

if MCM == nil then
    log("MCM unavailable; menu integration disabled")
    return
end

if not MM._registered then
    MCM.RegisterBuildSettingsListener(MM._buildListener)
    MCM.RegisterValueChangeListener(MOD_ID, MM._valueListener)
    MM._registered = true
    log("listeners registered")
end
