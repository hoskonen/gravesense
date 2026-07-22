-- GraveSense user settings (Lua 5.1).
-- This table is intentionally data-only so an MCM adapter can override it later.

GraveSense_Config = {
    enabled = true,

    runtime = {
        heartbeatMs = 1000,
        combatMs = 250,
        deathWatchMs = 100,
        postCombatRetentionMs = 15000,
        scanRadiusM = 10.0,
        maxAttempts = 3,
    },

    -- Until a reliable hostility binding is found, a nearby living actor becomes
    -- eligible only after taking damage while the player is in combat.
    trigger = {
        hpThreshold = 0.75,
        damageDelta = 0.05,
        processUnknownHealth = false,
    },

    rules = {
        repairKits = { enabled = true },
        potions = { enabled = false },
        bandages = { enabled = true },
    },

    safety = {
        dryRun = false,
        skipEquipped = true,
        protectNames = {
            money = true,
        },
        protectClasses = {},
    },

    logging = {
        debug = false,
        itemDetails = false,
        pollingAliveMs = 30000,
    },
}
