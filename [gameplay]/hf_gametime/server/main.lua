local config = require 'config.shared'
local timeOffset = 0
local weatherState = {
    current = "CLEAR",
    next = "CLEAR",
    timer = 0
}

-- Получение текущего времени МСК (в формате timestamp)
local function getMoscowTime()
    local utcTime = os.time(os.date("!*t"))
    local moscowTime = utcTime + (config.timeSettings.timezoneOffset * 3600)
    return moscowTime
end


-- Выбор погоды в зависимости от времени суток
local function selectWeatherForTime(hour)
    if not config.weatherSettings.syncWithTime then
        return weatherState.current
    end
    
    local timeOfDay
    if hour >= 6 and hour < 12 then
        timeOfDay = "morning"
    elseif hour >= 12 and hour < 18 then
        timeOfDay = "day"
    elseif hour >= 18 and hour < 22 then
        timeOfDay = "evening"
    else
        timeOfDay = "night"
    end
    
    local availableWeather = config.weatherSettings.weatherTypes[timeOfDay]
    return availableWeather[math.random(#availableWeather)]
end

-- Логическая смена погоды
local function getNextWeatherStage(currentWeather)
    -- Логические переходы между типами погоды
    if currentWeather == "CLEAR" or currentWeather == "CLOUDS" then
        local chance = math.random(1, 2)
        if chance == 1 then
            return "CLEARING"
        else
            return "OVERCAST"
        end
    elseif currentWeather == "CLEARING" or currentWeather == "OVERCAST" then
        local chance = math.random(1, 6)
        if chance == 1 then
            if currentWeather == "CLEARING" then 
                return "FOGGY" 
            else 
                return "RAIN" 
            end
        elseif chance == 2 then
            return "CLOUDS"
        elseif chance == 3 then
            return "CLEAR"
        elseif chance == 4 then
            return "SMOG"
        elseif chance == 5 then
            return "SMOG"
        else
            return "FOGGY"
        end
    elseif currentWeather == "THUNDER" or currentWeather == "RAIN" then
        return "CLEARING"
    elseif currentWeather == "SMOG" or currentWeather == "FOGGY" then
        return "CLEAR"
    else
        -- Если погода не попадает в логические цепочки, выбираем случайную для времени суток
        return selectWeatherForTime(12) -- Используем полдень по умолчанию
    end
end

-- Обновление погоды
local function updateWeather()
    weatherState.timer = weatherState.timer - 1
    if weatherState.timer <= 0 then
        weatherState.current = weatherState.next
        weatherState.next = getNextWeatherStage(weatherState.current)
        weatherState.timer = math.random(config.weatherSettings.minWeatherDuration, config.weatherSettings.maxWeatherDuration)
        
        TriggerClientEvent(config.events.onWeatherChange, -1, weatherState.current, weatherState.next)
        
        if config.debug then
            -- print(string.format("^4[GameTime] Смена погоды: %s -> %s^0", weatherState.current, weatherState.next))
        end
    end
end

-- Основной цикл обновления
CreateThread(function()
    -- Инициализация погоды
    weatherState.current = "CLEAR"
    weatherState.next = "CLEAR"
    weatherState.timer = math.random(config.weatherSettings.minWeatherDuration, config.weatherSettings.maxWeatherDuration)

    -- Устанавливаем начальные значения StateBag для синхронизации с клиентами
    GlobalState.moscowTime = getMoscowTime() - 1
    GlobalState.timeOffset = timeOffset
    GlobalState.freezeTime = config.timeSettings.freezeTime
    GlobalState.weather = weatherState

    print("^2[GameTime] Синхронизация времени и погоды запущена^0")

    while true do
        -- Обновляем московское время для синхронизации
        GlobalState.moscowTime = getMoscowTime()
        GlobalState.timeOffset = timeOffset
        GlobalState.freezeTime = config.timeSettings.freezeTime
        
        -- Обновляем погоду
        updateWeather()
        GlobalState.weather = weatherState
        
        Wait(config.timeSettings.serverUpdateInterval) -- Обновляем с интервалом из конфига для синхронизации
    end
end)

-- Удалены отдельные потоки syncTime/syncWeather – теперь используется GlobalState

-- Синхронизация при подключении игрока больше не требуется (StateBag передаст данные автоматически)

-- Команды администратора
lib.addCommand('settime', {
    help = 'Установить время (часы минуты)',
    params = {
        {
            name = 'hour',
            type = 'number',
            help = 'Час (0-23)'
        },
        {
            name = 'minute',
            type = 'number',
            help = 'Минута (0-59)',
            optional = true
        }
    },
    restricted = config.adminPermissions.useAcePerms and config.adminPermissions.acePermission or config.adminPermissions.allowedGroups
}, function(source, args)
    local hour = args.hour
    local minute = args.minute or 0
    
    if hour < 0 or hour > 23 or minute < 0 or minute > 59 then
        lib.notify(source, {
            title = 'Ошибка',
            description = 'Неверное время',
            type = 'error'
        })
        return
    end
    
    -- Простой подход: устанавливаем абсолютный offset на основе целевого времени
    local targetMinutes = hour * 60 + minute
    timeOffset = targetMinutes * 60 -- переводим в секунды
    
    -- Обновляем GlobalState
    GlobalState.timeOffset = timeOffset
    
    lib.notify(source, {
        title = 'Время установлено',
        description = string.format('Время: %02d:%02d', hour, minute),
        type = 'success'
    })
end)

lib.addCommand('setday', {
    help = 'Установить день недели',
    params = {
        {
            name = 'day',
            type = 'number',
            help = 'День (1-7, где 1 = Понедельник)'
        }
    },
    restricted = config.adminPermissions.useAcePerms and config.adminPermissions.acePermission or config.adminPermissions.allowedGroups
}, function(source, args)
    local day = args.day
    
    if day < 1 or day > 7 then
        lib.notify(source, {
            title = 'Ошибка',
            description = 'День должен быть от 1 до 7',
            type = 'error'
        })
        return
    end
    
    -- Вычисляем offset для установки конкретного дня (сохраняем текущее время)
    local currentHour = math.floor((timeOffset % (24 * 60 * 60)) / 3600)
    local currentMinute = math.floor((timeOffset % 3600) / 60)
    timeOffset = (day - 1) * 24 * 60 * 60 + currentHour * 3600 + currentMinute * 60
    
    -- Обновляем GlobalState
    GlobalState.timeOffset = timeOffset
    
    lib.notify(source, {
        title = 'День установлен',
        description = string.format('День: %s', config.weekDays[day]),
        type = 'success'
    })
end)

lib.addCommand('freezetime', {
    help = 'Заморозить/разморозить время',
    restricted = config.adminPermissions.useAcePerms and config.adminPermissions.acePermission or config.adminPermissions.allowedGroups
}, function(source)
    config.timeSettings.freezeTime = not config.timeSettings.freezeTime
    
    -- Обновляем GlobalState для синхронизации с клиентами
    GlobalState.freezeTime = config.timeSettings.freezeTime
    
    lib.notify(source, {
        title = 'Время',
        description = config.timeSettings.freezeTime and 'Время заморожено' or 'Время разморожено',
        type = 'info'
    })
end)

lib.addCommand('setweather', {
    help = 'Установить погоду',
    params = {
        {
            name = 'weather',
            type = 'string',
            help = 'Тип погоды (CLEAR, CLOUDS, OVERCAST, etc.)'
        }
    },
    restricted = config.adminPermissions.useAcePerms and config.adminPermissions.acePermission or config.adminPermissions.allowedGroups
}, function(source, args)
    local weather = string.upper(args.weather)
    
    weatherState.current = weather
    weatherState.next = weather
    weatherState.timer = config.weatherSettings.maxWeatherDuration
    
    GlobalState.weather = weatherState
    TriggerClientEvent(config.events.onWeatherChange, -1, weatherState.current, weatherState.next)
    
    lib.notify(source, {
        title = 'Погода установлена',
        description = string.format('Погода: %s', weather),
        type = 'success'
    })
end)

-- Экспорты для других ресурсов
exports('GetMoscowTime', function()
    return getMoscowTime()
end)

exports('GetTimeOffset', function()
    return timeOffset
end)

exports('GetCurrentWeather', function()
    return weatherState.current
end)

exports('SetTimeOffset', function(offset)
    timeOffset = offset
    GlobalState.timeOffset = timeOffset
    return true
end)

-- Callback для получения времени
lib.callback.register('qbx_gametime:getTimeData', function()
    return {
        moscowTime = getMoscowTime(),
        timeOffset = timeOffset,
        weather = weatherState
    }
end)