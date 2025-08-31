-- Scripts/GraveSense/Config.lua
-- Overrides for GraveSense (Lua 5.1). Leave out any key you don't want to override.

GraveSense_Config = {
    -- heartbeat (combat polling)
    heartbeatMs = 3000,  -- 3s poll for combat
    traceTicks  = false, -- true = log every heartbeat tick
    debug       = true,  -- show ENTER/EXIT & startup logs

    -- combat loop (death probe)
    combatMs    = 250,   -- 1s while in combat
    scanRadiusM = 8.0,   -- meters for death probe radius
    debounceMs  = 15000, -- ignore same corpse for this long
    enabled     = true,  -- master enable for the whole module

    -- bridge/sanitizer (we'll use later; harmless now)
    bridge      = {
        enabled         = true,  -- subscribe to the death bus
        sanitizeOnDeath = true,  -- keep OFF for now
        delayMs         = 200,
        dryRun          = false, -- true = don't do any mutation
    },
    sanitize    = {
        enabled             = true,  -- allow sanitizer module
        dryRun              = false, -- KEEP TRUE while testing
        unequipBeforeDelete = true,
        skipMoney           = true,
        protectNames        = { bandage = true }, -- example
        protectClasses      = {},                 -- fill later if needed
    },
    preCorpse   = {
        enabled            = true,
        hpThreshold        = 0.50, -- wide for proving; tune down later
        deltaThreshold     = 0.20, -- fire if hp drops >= 20% between ticks
        rangeM             = 10.0,
        debounceMs         = 1500,
        delayMs            = 0,
        forceWhenUnknownHp = true, -- <— important for your build
    },
    logging     = { preCorpseTrace = true }

    -- sanitize { enabled=true, dryRun=true/false, skipMoney=true, unequipBeforeDelete=true, ... }

}
