return {
    debug = false,

    marker = {
        type = 1,
        color = {r = 0, g = 100, b = 255, a = 200},
        scale = vec3(5.0, 5.0, 2.0),
        bobUpAndDown = false,
        rotate = false
    },

    blip = {
        route = {
            sprite = 1,
            color = 38,
            scale = 0.8,
            route = true
        },
        currentStop = {
            sprite = 1,
            color = 38,
            scale = 1.0,
            flash = true
        }
    },

    keys = {
        interact = 38,
        cancelJob = 73
    },

    notifications = {
        position = 'top',
        duration = 5000
    },

    leaveBusTimeout = 120000,

    aiBusDisplay = {
        enabled = true,
        blipSprite = 463,
        blipColor = 3,
        blipScale = 0.6,
        blipAlpha = 150,
        textColor = {0, 255, 255, 255},
        textScale = 0.4,
        updateDistance = 500.0,
        cleanupInterval = 30000,
        
        blipSettings = {
            showRouteInfo = true,
            showNextStop = true,
            blipPrefix = "AI ",
            maxBlipNameLength = 50,
            updateOnlyVisible = true,
            removeOffscreenBlips = false
        },
        
        textSettings = {
            showRouteText = true,
            showStopText = true,
            routeTextOffset = vector3(0.0, 0.0, 3.5),
            stopTextOffset = vector3(0.0, 0.0, 3.0),
            routeTextColor = {255, 255, 0, 255},
            stopTextColor = {0, 255, 255, 255},
            routeTextScale = 0.5,
            stopTextScale = 0.4,
            enableOutline = true,
            maxTextDistance = 100.0
        },
        
        performanceSettings = {
            updateThrottleMs = 1000,
            maxConcurrentUpdates = 5,
            distanceBasedLOD = true,
            nearDistance = 50.0,
            farDistance = 200.0,
            enableCaching = true,
            cacheLifetime = 10000
        }
    }
}