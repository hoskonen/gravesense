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
    return { version = tonumber(value.version) or 1, enabled = enabled }, nil
end

function Settings.LoadInto(config)
    local db = ensureDB()
    if not db then return false, "db unavailable" end

    local record, reason = readRecord(db)
    if not record then
        if reason == "missing" then
            log("no saved value; Config.lua enabled=" .. tostring(config.enabled))
        else
            log("ignored invalid saved settings: " .. tostring(reason))
        end
        return false, reason
    end

    config.enabled = record.enabled
    log("loaded enabled=" .. tostring(config.enabled))
    return true, nil
end

function Settings.SaveEnabled(enabled)
    local db = ensureDB()
    if not db then return false, "db unavailable" end

    enabled = enabled == true
    local record = { version = 1, enabled = enabled and 1 or 0 }
    if type(db.SetG) ~= "function" then
        log("global save API unavailable")
        return false, "global write unavailable"
    end
    local writeOk = pcall(db.SetG, db, SETTINGS_KEY, record)
    if not writeOk then
        log("save failed for enabled=" .. tostring(enabled))
        return false, "write failed"
    end

    local saved, reason = readRecord(db)
    local verified = saved ~= nil and saved.enabled == enabled
    log(("saved enabled=%s verified=%s")
        :format(tostring(enabled), tostring(verified)))
    return verified, verified and nil or reason or "verification failed"
end

function Settings.SetEnabled(enabled, source, persist)
    GS.SetEnabled(enabled == true, source or "settings")
    if persist then return Settings.SaveEnabled(enabled == true) end
    return true, nil
end
