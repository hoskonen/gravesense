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
        repairKits = { chance = 100 },
        potions = { chance = 100 },
        bandages = { chance = 100 },
    },

    replacements = {
        emptyPotionBottles = {
            enabled = true,
            class = "0773e4a5-c8da-4783-85af-f7eb7e6bdd44",
            health = 1.0,
        },
    },

    -- Development-only controlled test. Set enabled=true and provide any item
    -- class to inject it when an actor first becomes tracked.
    testing = {
        injectTrackedItem = {
            enabled = false,
            class = "761f9e84-e07b-4b4b-9425-7681898abccd",
            health = 1.0,
            quantity = 1,
        },
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
        pollingAliveMs = 30000,
    },
}
