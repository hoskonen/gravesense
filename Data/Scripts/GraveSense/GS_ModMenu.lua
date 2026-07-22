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

function MM.BuildSettings()
    MCM.AddMod(MOD_ID, MOD_NAME)
    MCM.AddCategory(
        MOD_ID,
        "General",
        "General Grave Sense settings."
    )
    MCM.AddToggle(
        MOD_ID,
        "enabled",
        "Enable Grave Sense",
        "Enable or disable Grave Sense inventory processing.",
        GS.cfg.enabled and 1 or 0
    )
end

function MM.OnValueChanged(settingId, value)
    if settingId ~= "enabled" then return end

    local numericValue = tonumber(value)
    if numericValue == nil then
        log("ignored invalid enabled value: " .. tostring(value))
        return
    end

    local enabled = numericValue ~= 0
    if GS.Settings and GS.Settings.SetEnabled then
        GS.Settings.SetEnabled(enabled, "mcm", true)
    else
        GS.SetEnabled(enabled, "mcm")
        log("settings module unavailable; value was not persisted")
    end
    log("cfg.enabled=" .. tostring(GS.cfg.enabled))
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
