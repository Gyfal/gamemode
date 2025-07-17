return {
    -- Настройки работы
    job = {
        name = 'garbage', -- Название работы в базе данных
        label = 'Мусорщик', -- Отображаемое название
        minGrade = 0, -- Минимальный ранг для работы
    },

    -- Настройки оплаты
    payment = {
        type = 'cash', -- Тип оплаты (cash/bank)
        garbageCollection = {
            min = 100, -- Минимальная оплата за сбор мусора
            max = 200, -- Максимальная оплата за сбор мусора
        },
        dumpBonus = {
            min = 300, -- Минимальная бонусная оплата за разгрузку
            max = 500, -- Максимальная бонусная оплата за разгрузку
        },
        bonusChance = 20, -- Шанс получить бонус (%)
        bonusMultiplier = 1.3 -- Множитель бонуса
    },

    -- Антифрод система
    anticheat = {
        enabled = true, -- Включить антифрод
        maxDistance = 15.0, -- Максимальное расстояние от точки сбора
        minTimePerCollection = 8, -- Минимальное время на сбор мусора (секунды)
        maxTimePerCollection = 30, -- Максимальное время на сбор мусора (секунды)
        teleportCheck = true, -- Проверка на телепорт
        maxCollectionsPerMinute = 10 -- Максимум сборов в минуту
    },

    -- Настройки логирования
    logging = {
        enabled = true, -- Включить логирование
        webhook = '', -- Discord webhook для логов
        logPayments = true, -- Логировать выплаты
        logCollections = true, -- Логировать сбор мусора
        logSuspiciousActivity = true -- Логировать подозрительную активность
    },

    -- Настройки отладки
    debug = {
        enabled = false, -- Включить команды отладки
        showSpawnCoords = true, -- Показывать координаты спавна в уведомлениях
        logRouteGeneration = true -- Логировать генерацию маршрутов
    }
}