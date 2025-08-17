return {
    job = {
        name = 'bus',
        label = 'Водитель автобуса',
        minGrade = 0,
    },

    payment = {
        type = 'cash',
        minPayment = 150,
        maxPayment = 250,
        bonusChance = 25,
        bonusMultiplier = 1.5
    },

    anticheat = {
        enabled = true,
        maxDistance = 50.0,
        minTimePerStop = 30,
        teleportCheck = true
    },

    logging = {
        enabled = true,
        webhook = '',
        logPayments = true,
        logRoutes = true
    },

    debug = {
        enabled = false,
        showSpawnCoords = true,
        logSpawnLocations = true
    },
    
    networking = {
        busInfoUpdateDistance = 300.0,
        busInfoCleanupDistance = 350.0
    }
    
}