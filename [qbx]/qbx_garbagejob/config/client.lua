return {
    -- Настройки уведомлений
    notifications = {
        position = 'top-right', -- Позиция уведомлений
        duration = 5000 -- Длительность показа уведомлений (мс)
    },

    -- Настройки маркеров
    marker = {
        garbagePoint = {
            type = 1, -- Цилиндр
            scale = { x = 3.0, y = 3.0, z = 1.0 },
            color = { r = 255, g = 165, b = 0, a = 150 }, -- Оранжевый
            bobUpAndDown = true,
            rotate = false
        },
        dumpPoint = {
            type = 1, -- Цилиндр
            scale = { x = 5.0, y = 5.0, z = 2.0 },
            color = { r = 255, g = 0, b = 0, a = 150 }, -- Красный
            bobUpAndDown = true,
            rotate = false
        }
    },

    -- Настройки блипов
    blip = {
        currentTarget = {
            sprite = 1, -- Точка
            color = 5, -- Желтый
            scale = 1.0,
            flash = true,
            route = true,
            routeColor = 5
        },
        dumpSite = {
            sprite = 365, -- Свалка
            color = 1, -- Красный
            scale = 0.8,
            flash = false
        }
    },

    -- Клавиши управления
    keys = {
        cancelJob = 73, -- X - отмена работы
        collectGarbage = 38, -- E - сбор мусора
        dumpGarbage = 38 -- E - разгрузка мусора
    },

    -- Настройки контроля
    leaveTruckTimeout = 45000, -- Время до увольнения при выходе из мусоровоза (мс)

    -- Настройки прогресс-бара
    progressBar = {
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disable = {
            car = true,
            move = true,
            combat = true
        }
    }
}