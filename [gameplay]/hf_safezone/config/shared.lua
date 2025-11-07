return {
    -- Общие настройки
    settings = {
        debug = true, -- Включить отладочный режим для зон
        disablePvP = true, -- Отключить PvP в зонах
        disableVehicleCollisions = true, -- Отключить коллизии с транспортом
        disablePlayerCollisions = true, -- Отключить коллизии между игроками
        showZoneMessages = true, -- Показывать сообщения при входе/выходе из зон
        disableWeapons = true, -- Отключить оружие в зонах
        godMode = false, -- Включить режим бога (полная неуязвимость)
    },

    -- Уведомления
    notifications = {
        position = 'top',
        duration = 3000
    },

    -- Зоны безопасности
    safeZones = {
        -- Автопарк автобусной работы Sandy Shores
        {
            id = 'busjob_depot',
            name = 'Автопарк Sandy Shores',
            type = 'sphere',
            coords = vector3(1726.0, 3318.0, 42.0),
            radius = 60.0,
            debug = true,
            settings = {
                disablePvP = true,
                disableVehicleCollisions = true,
                disablePlayerCollisions = true,
                disableWeapons = true,
                godMode = false,
            }
        },
    }
}