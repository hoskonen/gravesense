GS_Log = GS_Log or {}

local function write(level, message)
    System.LogAlways(("[GraveSense][%s] %s"):format(level, tostring(message)))
end

function GS_Log.Info(message)
    write("INFO", message)
end

function GS_Log.Warn(message)
    write("WARN", message)
end

function GS_Log.Error(message)
    write("ERROR", message)
end

function GS_Log.Debug(message)
    local cfg = GraveSense and GraveSense.cfg
    if cfg and cfg.logging and cfg.logging.debug then
        write("DEBUG", message)
    end
end
