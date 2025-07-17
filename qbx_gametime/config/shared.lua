return {
    -- Базовые настройки
    debug = true,
    
    -- Настройки времени
    timeSettings = {
        -- Длительность одного игрового дня в минутах (205 минут = 3 часа 25 минут)
        dayDurationMinutes = 205,
        
        -- Начало недели в МСК (понедельник 00:00 = 06:00 МСК)
        weekStartHourMSK = 6,
        weekStartMinuteMSK = 0,
        
        -- Часовой пояс (МСК = UTC+3)
        timezoneOffset = 3,
        
        -- Скорость времени (сколько игровых минут проходит за 1 реальную секунду)
        -- 1440 минут (24 часа) / (205 минут * 60 секунд) = ~0.117
        timeSpeed = 0.117,
        
        -- Автоматическая синхронизация времени (как часто синхронизировать между клиентами)
        syncInterval = 30000, -- 30 секунд в миллисекундах
        
        -- Интервал локального обновления времени на клиенте в миллисекундах
        clientUpdateInterval = 1000, -- 1 секунда
        
        -- Интервал обновления времени на сервере в миллисекундах
        serverUpdateInterval = 1 * 60 * 1000, -- 1 секунда
        
        -- Принудительная остановка времени
        freezeTime = false,
        freezeHour = 12,
        freezeMinute = 0
    },
    
    -- Дни недели на русском
    weekDays = {
        [1] = "Понедельник",
        [2] = "Вторник", 
        [3] = "Среда",
        [4] = "Четверг",
        [5] = "Пятница",
        [6] = "Суббота",
        [7] = "Воскресенье"
    },
    
    -- Настройки погоды (опционально, можно связать с временем)
    weatherSettings = {
        -- Синхронизировать погоду с временем суток
        syncWithTime = true,
        
        -- Минимальная продолжительность погоды в игровых часах
        minWeatherDuration = 6,
        maxWeatherDuration = 24,
        
        -- Доступные типы погоды по времени суток
        weatherTypes = {
            morning = {"CLEAR", "CLOUDS", "OVERCAST", "FOGGY"},
            day = {"CLEAR", "CLOUDS", "OVERCAST", "SMOG"},
            evening = {"CLEAR", "CLOUDS", "OVERCAST", "FOGGY"},
            night = {"CLEAR", "CLOUDS", "OVERCAST", "FOGGY", "CLEARING"}
        }
    },
    
    -- Настройки интерфейса
    ui = {
        -- Показывать время в HUD
        showInHud = true,
        
        -- Формат времени
        format24h = true,
        
        -- Показывать день недели
        showWeekDay = true,
        
        -- Показывать секунды
        showSeconds = true,
        
        -- Позиция на экране (если используется встроенный UI)
        position = {
            x = 0.015,
            y = 0.75
        }
    },
    
    -- Права администратора
    adminPermissions = {
        -- Группы, которые могут управлять временем
        allowedGroups = {'admin', 'god'},
        
        -- Или использовать ace permissions
        useAcePerms = true,
        acePermission = 'qbx.admin'
    },
    
    -- События для интеграции с другими ресурсами
    events = {
        -- Событие при смене дня
        onDayChange = 'qbx_gametime:dayChanged',
        
        -- Событие при смене времени (каждую игровую минуту)
        onTimeChange = 'qbx_gametime:timeChanged',
        
        -- Событие при смене погоды
        onWeatherChange = 'qbx_gametime:weatherChanged'
    }
}