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

local function probabilityValue(value)
    local numericValue = tonumber(value)
    if numericValue == nil or numericValue < 0 or numericValue > 100 then return nil end
    return math.floor(numericValue + 0.5)
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
        "Set the independent removal chance for each eligible item. Zero disables a category."
    )
    MCM.AddSlider(
        MOD_ID, "bandages_chance", "Bandages",
        "Chance to remove each bandage from an eligible fallen NPC.",
        0, 100, 5, GS.cfg.rules.bandages.chance, "%"
    )
    MCM.AddSlider(
        MOD_ID, "potions_chance", "Potions",
        "Chance to remove each potion from an eligible fallen NPC.",
        0, 100, 5, GS.cfg.rules.potions.chance, "%"
    )
    MCM.AddSlider(
        MOD_ID, "repair_kits_chance", "Repair Kits",
        "Chance to remove each repair kit from an eligible fallen NPC.",
        0, 100, 5, GS.cfg.rules.repairKits.chance, "%"
    )

    MCM.AddCategory(
        MOD_ID, "Item Replacements",
        "Optionally add immersive replacement items for supplies removed from fallen NPCs."
    )
    MCM.AddToggle(
        MOD_ID, "empty_potion_bottles", "Empty Potion Bottles",
        "Add one empty potion bottle for each potion removed from an eligible fallen NPC.",
        GS.cfg.replacements.emptyPotionBottles.enabled and 1 or 0
    )

    MCM.AddCategory(MOD_ID, "Debug", "Additional diagnostic logging.")
    MCM.AddToggle(
        MOD_ID, "debug", "Enable",
        "Enable additional Grave Sense diagnostic messages.",
        GS.cfg.logging.debug and 1 or 0
    )
end

function MM.OnValueChanged(settingId, value)
    if not (GS.Settings and GS.Settings.SaveAll) then
        log("settings module unavailable; change ignored")
        return
    end

    if settingId == "enabled" then
        local enabled = toggleValue(value)
        if enabled == nil then return end
        GS.Settings.SetEnabled(enabled, "mcm", true)
    elseif settingId == "debug" then
        local enabled = toggleValue(value)
        if enabled == nil then return end
        GS.Settings.SetDebugEnabled(enabled, "mcm", true)
    elseif settingId == "bandages_chance" then
        local chance = probabilityValue(value)
        if chance == nil then return end
        GS.Settings.SetRuleChance("bandages", chance, "mcm", true)
    elseif settingId == "potions_chance" then
        local chance = probabilityValue(value)
        if chance == nil then return end
        GS.Settings.SetRuleChance("potions", chance, "mcm", true)
    elseif settingId == "repair_kits_chance" then
        local chance = probabilityValue(value)
        if chance == nil then return end
        GS.Settings.SetRuleChance("repairKits", chance, "mcm", true)
    elseif settingId == "empty_potion_bottles" then
        local enabled = toggleValue(value)
        if enabled == nil then return end
        GS.Settings.SetReplacementEnabled("emptyPotionBottles", enabled, "mcm", true)
    else
        return
    end

    log(("%s=%s"):format(tostring(settingId), tostring(value)))
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
