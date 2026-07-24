-- Persistent GraveSense settings backed by KCDUtils LuaDB (Lua 5.1).

GraveSense = GraveSense or {}
GraveSense.Settings = GraveSense.Settings or {}

local GS = GraveSense
local Settings = GS.Settings
local DB_NAMESPACE = "gravesense"
local SETTINGS_KEY = "settings:v1"

local function log(message)
    System.LogAlways("[GraveSense][Settings] " .. tostring(message))
end

local function normalizeBoolean(value)
    if type(value) == "boolean" then return value end
    if type(value) == "number" then
        if value == 1 then return true end
        if value == 0 then return false end
    end
    if type(value) == "string" then
        local lower = string.lower(value)
        if lower == "true" or lower == "1" then return true end
        if lower == "false" or lower == "0" then return false end
    end
    return nil
end

local function normalizePercent(value)
    local numericValue = tonumber(value)
    if numericValue == nil or numericValue < 0 or numericValue > 100 then return nil end
    return math.floor(numericValue + 0.5)
end

local function readChance(record, chanceKey, legacyToggleKey)
    local chance = normalizePercent(record[chanceKey])
    if chance ~= nil then return chance end

    local legacyEnabled = normalizeBoolean(record[legacyToggleKey])
    if legacyEnabled ~= nil then return legacyEnabled and 100 or 0 end
    return nil
end

local function ensureDB()
    if Settings._db then return Settings._db end
    if not (KCDUtils and KCDUtils.DB and KCDUtils.DB.Factory) then
        if not Settings._dbUnavailableLogged then
            Settings._dbUnavailableLogged = true
            log("KCDUtils LuaDB unavailable; using Config.lua")
        end
        return nil
    end

    local ok, db = pcall(KCDUtils.DB.Factory, DB_NAMESPACE)
    if ok and db then
        Settings._db = db
        Settings._dbUnavailableLogged = nil
        return db
    end

    log("failed to open LuaDB namespace")
    return nil
end

local function readRecord(db)
    if type(db.GetG) ~= "function" then return nil, "global read unavailable" end
    local ok, value = pcall(db.GetG, db, SETTINGS_KEY)
    if not ok then return nil, "read failed" end
    if value == nil then return nil, "missing" end
    if type(value) ~= "table" then return nil, "record is not a table" end

    local enabled = normalizeBoolean(value.enabled)
    if enabled == nil then return nil, "enabled value is invalid" end

    -- Probability fields are optional. Older category toggles migrate to
    -- equivalent 0%/100% values; otherwise Config.lua supplies the default.
    return {
        version = tonumber(value.version) or 1,
        enabled = enabled,
        bandagesChance = readChance(value, "bandagesChance", "bandages"),
        potionsChance = readChance(value, "potionsChance", "potions"),
        repairKitsChance = readChance(value, "repairKitsChance", "repairKits"),
        emptyPotionBottles = normalizeBoolean(value.emptyPotionBottles),
        debug = normalizeBoolean(value.debug),
    }, nil
end

local function buildRecord(config)
    return {
        version = 4,
        enabled = config.enabled and 1 or 0,
        bandagesChance = normalizePercent(config.rules.bandages.chance) or 100,
        potionsChance = normalizePercent(config.rules.potions.chance) or 100,
        repairKitsChance = normalizePercent(config.rules.repairKits.chance) or 100,
        emptyPotionBottles = config.replacements.emptyPotionBottles.enabled and 1 or 0,
        debug = config.logging.debug and 1 or 0,
    }
end

local function recordMatchesConfig(record, config)
    return record ~= nil
        and record.enabled == config.enabled
        and record.bandagesChance == config.rules.bandages.chance
        and record.potionsChance == config.rules.potions.chance
        and record.repairKitsChance == config.rules.repairKits.chance
        and record.emptyPotionBottles == config.replacements.emptyPotionBottles.enabled
        and record.debug == config.logging.debug
end

function Settings.LoadInto(config)
    local db = ensureDB()
    if not db then return false, "db unavailable" end

    local record, reason = readRecord(db)
    if not record then
        if reason == "missing" then
            log("no saved value; using Config.lua")
        else
            log("ignored invalid saved settings: " .. tostring(reason))
        end
        return false, reason
    end

    config.enabled = record.enabled
    if record.bandagesChance ~= nil then config.rules.bandages.chance = record.bandagesChance end
    if record.potionsChance ~= nil then config.rules.potions.chance = record.potionsChance end
    if record.repairKitsChance ~= nil then config.rules.repairKits.chance = record.repairKitsChance end
    if record.emptyPotionBottles ~= nil then
        config.replacements.emptyPotionBottles.enabled = record.emptyPotionBottles
    end
    if record.debug ~= nil then config.logging.debug = record.debug end

    log(("loaded enabled=%s bandages=%s%% potions=%s%% repairKits=%s%% emptyPotionBottles=%s debug=%s")
        :format(tostring(config.enabled), tostring(config.rules.bandages.chance),
            tostring(config.rules.potions.chance), tostring(config.rules.repairKits.chance),
            tostring(config.replacements.emptyPotionBottles.enabled),
            tostring(config.logging.debug)))
    return true, nil
end

function Settings.SaveAll(config)
    local db = ensureDB()
    if not db then return false, "db unavailable" end
    if type(db.SetG) ~= "function" then
        log("global save API unavailable")
        return false, "global write unavailable"
    end

    local writeOk = pcall(db.SetG, db, SETTINGS_KEY, buildRecord(config))
    if not writeOk then
        log("save failed")
        return false, "write failed"
    end

    local saved, reason = readRecord(db)
    local verified = recordMatchesConfig(saved, config)
    log("saved all verified=" .. tostring(verified))
    return verified, verified and nil or reason or "verification failed"
end

function Settings.SetEnabled(enabled, source, persist)
    GS.SetEnabled(enabled == true, source or "settings")
    if persist then return Settings.SaveAll(GS.cfg) end
    return true, nil
end

function Settings.SetRuleChance(ruleId, chance, source, persist)
    local rule = GS.cfg and GS.cfg.rules and GS.cfg.rules[ruleId]
    if not rule then return false, "unknown rule" end

    chance = normalizePercent(chance)
    if chance == nil then return false, "invalid probability" end

    rule.chance = chance
    log(("rule %s=%s%% source=%s")
        :format(tostring(ruleId), tostring(rule.chance), tostring(source or "settings")))
    if persist then return Settings.SaveAll(GS.cfg) end
    return true, nil
end

function Settings.SetReplacementEnabled(replacementId, enabled, source, persist)
    local replacement = GS.cfg and GS.cfg.replacements
        and GS.cfg.replacements[replacementId]
    if not replacement then return false, "unknown replacement" end

    replacement.enabled = enabled == true
    log(("replacement %s=%s source=%s")
        :format(tostring(replacementId), tostring(replacement.enabled),
            tostring(source or "settings")))
    if persist then return Settings.SaveAll(GS.cfg) end
    return true, nil
end

function Settings.SetDebugEnabled(enabled, source, persist)
    GS.cfg.logging.debug = enabled == true
    log(("debug=%s source=%s")
        :format(tostring(GS.cfg.logging.debug), tostring(source or "settings")))
    if persist then return Settings.SaveAll(GS.cfg) end
    return true, nil
end
