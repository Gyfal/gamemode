local config = require 'config.shared'
local currentTime = {hour = 0, minute = 0, second = 0}
local currentDay = 1
local currentWeather = "CLEAR"
local lastAppliedWeather = "CLEAR"
local moscowTime = nil
local timeOffset = 0
-- Переменные для локального расчета времени
local lastServerMoscowTime = nil
local lastServerUpdateTime = nil

-- Обвертчная функция для NetworkOverrideClockTime с валидацией
local function setGameTime(hour, minute, second)
    -- Валидация входных параметров
    -- hour = math.max(0, math.min(23, hour or 0))
    -- minute = math.max(0, math.min(59, minute or 0))
    -- second = math.max(0, math.min(59, second or 0))
    
    if config.debug then
        print(string.format("^6[GameTime] Устанавливаем время: %02d:%02d:%02d^0", hour, minute, second))
    end
    
    NetworkOverrideClockTime(hour, minute, second)
end

-- Синхронизация при старте идёт автоматически через StateBag (GlobalState)

-- Старые события qbx_gametime:syncTime / syncWeather удалены – используется GlobalState

-- Функция для получения текущего московского времени (локально рассчитанного)
local function getCurrentMoscowTime()
    if not lastServerMoscowTime or not lastServerUpdateTime then
        return moscowTime
    end
    
    -- Рассчитываем сколько времени прошло с последнего обновления от сервера
    local currentGameTime = GetGameTimer()
    local timeDifferenceMs = currentGameTime - lastServerUpdateTime
    local timeDifferenceSeconds = math.floor(timeDifferenceMs / 1000)
    
    -- Возвращаем локально рассчитанное время
    return lastServerMoscowTime + timeDifferenceSeconds
end

-- Расчет игрового времени на основе московского времени
local function calculateGameTime()
    -- Используем локально рассчитанное время вместо moscowTime
    local currentMoscowTime = getCurrentMoscowTime()
    if not currentMoscowTime then return 1, 0, 0, 0 end
    
    -- Применяем offset (timeOffset уже в секундах)
    local adjustedTime = currentMoscowTime + timeOffset
    
    -- Извлекаем час, минуту и секунду из timestamp
    local secondsInDay = adjustedTime % 86400 -- 86400 = 24 * 60 * 60
    local currentHour = math.floor(secondsInDay / 3600)
    local currentMinute = math.floor((secondsInDay % 3600) / 60)
    local currentSecond = math.floor(secondsInDay % 60)
    local currentMoscowSeconds = currentHour * 3600 + currentMinute * 60 + currentSecond
    
    -- Рассчитываем день недели (1 = понедельник)
    -- Timestamp начинается с четверга 1 января 1970, поэтому корректируем
    local daysSinceEpoch = math.floor(adjustedTime / 86400)
    local moscowWeekday = ((daysSinceEpoch + 4) % 7) + 1 -- +4 потому что 1 января 1970 был четверг
    
    -- Начало недели в секундах от начала дня
    local weekStartSeconds = config.timeSettings.weekStartHourMSK * 3600 + config.timeSettings.weekStartMinuteMSK * 60
    
    -- Считаем секунды с начала недели
    local secondsSinceWeekStart = (moscowWeekday - 1) * 24 * 3600 + currentMoscowSeconds - weekStartSeconds
    
    -- Если мы до начала недели, переносимся на предыдущую неделю
    if secondsSinceWeekStart < 0 then
        secondsSinceWeekStart = secondsSinceWeekStart + (7 * 24 * 3600)
    end
    
    -- Длительность одного игрового дня в реальных секундах
    local realSecondsPerGameDay = config.timeSettings.dayDurationMinutes * 60
    
    -- Определяем текущий игровой день (1-7)
    local gameDay = math.floor(secondsSinceWeekStart / realSecondsPerGameDay) + 1
    if gameDay > 7 then
        gameDay = ((gameDay - 1) % 7) + 1
    end
    
    -- Сколько реальных секунд прошло с начала текущего игрового дня
    local secondsIntoCurrentDay = secondsSinceWeekStart % realSecondsPerGameDay
    
    -- Конвертируем в игровые секунды (86400 игровых секунд = realSecondsPerGameDay реальных секунд)
    local gameSecondsTotal = (secondsIntoCurrentDay / realSecondsPerGameDay) * 86400
    
    -- Разбиваем на часы, минуты и секунды
    local gameHour = math.floor(gameSecondsTotal / 3600)
    local gameMinute = math.floor((gameSecondsTotal % 3600) / 60)
    local gameSecond = math.floor(gameSecondsTotal % 60)
    
    return gameDay, gameHour, gameMinute, gameSecond
end

-- Обработка изменения дня
RegisterNetEvent(config.events.onDayChange, function(day, dayName)
    currentDay = day
    
    if config.ui.showInHud then
        lib.notify({
            title = 'Новый день',
            description = dayName,
            type = 'info',
            duration = 5000
        })
    end
end)

-- Обработка изменения погоды
RegisterNetEvent(config.events.onWeatherChange, function(current)
    -- Проверяем действительно ли погода изменилась
    if current ~= currentWeather then
        currentWeather = current
        -- Сбрасываем флаг применённой погоды для принудительного обновления
        lastAppliedWeather = ""
        
        if config.debug then
            print(string.format("^4[GameTime] Получено изменение погоды: %s^0", currentWeather))
        end
    end
end)

-- ================================
-- StateBag Handlers (GlobalState)
-- ================================

AddStateBagChangeHandler('moscowTime', 'global', function(_, _, value)
    print("moscowTime changed", _, _, value)
    if value then
        moscowTime = value
        lastServerMoscowTime = value -- Обновляем локальную переменную
        lastServerUpdateTime = GetGameTimer() -- Обновляем время последнего обновления
        
        -- При получении нового времени сразу обновляем игровое время
        if lastServerMoscowTime and timeOffset ~= nil then
            local day, hour, minute, second = calculateGameTime()
            print(string.format("Calculated Game Time: Day %d, Hour %d, Minute %d, Second %d", day, hour, minute, second))
            currentTime.hour = hour
            currentTime.minute = minute
            currentTime.second = second
            currentDay = day
            setGameTime(currentTime.hour, currentTime.minute, currentTime.second)
        end
        
        if config.debug then
            print(string.format("^3[GameTime] Московское время обновлено: %s^0", value))
        end
    end
end)

AddStateBagChangeHandler('timeOffset', 'global', function(_, _, value)
    print("timeOffset changed", _, _, value)
    if value ~= nil then
        timeOffset = value
        
        -- При изменении offset сразу обновляем игровое время
        if lastServerMoscowTime then
            local day, hour, minute, second = calculateGameTime()
            currentTime.hour = hour
            currentTime.minute = minute
            currentTime.second = second
            currentDay = day
            setGameTime(currentTime.hour, currentTime.minute, currentTime.second)
        end
        
        if config.debug then
            print(string.format("^3[GameTime] Offset времени обновлен: %d^0", value))
        end
    end
end)

AddStateBagChangeHandler('freezeTime', 'global', function(_, _, value)
    if value ~= nil then
        -- Используем нативные функции для заморозки/разморозки времени
        if value then
            -- Замораживаем время
            NetworkOverrideClockMillisecondsPerGameMinute(99999999)
        else
            -- Размораживаем время
            local gameMinuteMs = math.floor((config.timeSettings.dayDurationMinutes * 60 * 1000) / 1440)
            NetworkOverrideClockMillisecondsPerGameMinute(gameMinuteMs)
        end
        
        if config.debug then
            print(string.format("^3[GameTime] Состояние заморожения: %s^0", value and "заморожено" or "разморожено"))
        end
    end
end)

AddStateBagChangeHandler('weather', 'global', function(_, _, value)
    if value and value.current then
        if value.current ~= currentWeather then
            currentWeather = value.current
            lastAppliedWeather = "" -- force apply
        end
    end
end)

-- Локальный цикл обновления времени
CreateThread(function()
    -- Ждем инициализации сетевой сессии
    while not NetworkIsSessionStarted() do
        Wait(100)
    end
    
    -- Устанавливаем начальную скорость времени
    local gameMinuteMs = math.floor((config.timeSettings.dayDurationMinutes * 60 * 1000) / 1440) -- миллисекунды на игровую минуту
    
    NetworkOverrideClockMillisecondsPerGameMinute(gameMinuteMs)
    print(string.format("^3[GameTime] Установлена скорость времени: %d мс на игровую минуту^0", gameMinuteMs))


    while true do
        -- Используем локально рассчитанное время
        local currentMoscowTime = getCurrentMoscowTime()
        if currentMoscowTime then
            local day, hour, minute, second = calculateGameTime()
            
            -- Проверяем изменение дня
            if currentDay ~= day then
                currentDay = day
                TriggerEvent(config.events.onDayChange, currentDay, config.weekDays[currentDay])
                
                if config.debug then
                    print(string.format("^2[GameTime] День изменился: %s^0", config.weekDays[currentDay]))
                end
            end
            
            -- Проверяем изменение времени (включая секунды)
            if currentTime.hour ~= hour or currentTime.minute ~= minute or currentTime.second ~= second then
                local oldHour = currentTime.hour
                local oldMinute = currentTime.minute
                
                currentTime.hour = hour
                currentTime.minute = minute
                currentTime.second = second
                
                -- Устанавливаем время в игре
                setGameTime(currentTime.hour, currentTime.minute, currentTime.second)
                
                -- Триггерим событие изменения времени только при смене минут
                if oldHour ~= hour or oldMinute ~= minute then
                    TriggerEvent(config.events.onTimeChange, currentTime.hour, currentTime.minute)
                end
                
                if config.debug then
                    print(string.format("^5[GameTime] Время изменилось: %02d:%02d:%02d^0", currentTime.hour, currentTime.minute, currentTime.second))
                end
            end
        end
        
        Wait(config.timeSettings.clientUpdateInterval) -- Проверяем с интервалом из конфига для плавного обновления времени
    end
end)

-- Поток управления погодой
CreateThread(function()
    while true do
        -- Применяем погоду только если она изменилась
        if lastAppliedWeather ~= currentWeather then
            lastAppliedWeather = currentWeather
            SetWeatherTypeOverTime(currentWeather, 15.0)
            if config.debug then
                print(string.format("^3[GameTime] Плавный переход к погоде: %s^0", currentWeather))
            end
            Wait(15000) -- ждём конца перехода
        end

        -- Поддерживаем установленную погоду
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        SetWeatherTypePersist(lastAppliedWeather)
        SetWeatherTypeNow(lastAppliedWeather)
        SetWeatherTypeNowPersist(lastAppliedWeather)

        if lastAppliedWeather == 'XMAS' then
            SetForceVehicleTrails(true)
            SetForcePedFootstepsTracks(true)
        else
            SetForceVehicleTrails(false)
            SetForcePedFootstepsTracks(false)
        end

        Wait(100)
    end
end)

-- UI для отображения времени
if config.ui.showInHud then
    CreateThread(function()
        while true do
            -- Проверяем что время инициализировано
            local currentMoscowTime = getCurrentMoscowTime()
            if currentMoscowTime and currentTime.hour ~= nil and currentTime.minute ~= nil then
                local timeString
                if config.ui.showSeconds then
                    timeString = string.format("%02d:%02d:%02d", currentTime.hour, currentTime.minute, currentTime.second)
                else
                    timeString = string.format("%02d:%02d", currentTime.hour, currentTime.minute)
                end
                
                if config.ui.showWeekDay then
                    timeString = string.format("%s - %s", config.weekDays[currentDay], timeString)
                end
                
                -- Отрисовка текста на экране
                SetTextFont(0)
                SetTextProportional(1)
                SetTextScale(0.0, 0.4)
                SetTextColour(255, 255, 255, 255)
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(1, 0, 0, 0, 255)
                SetTextDropShadow()
                SetTextOutline()
                SetTextEntry("STRING")
                AddTextComponentString(timeString)
                DrawText(config.ui.position.x, config.ui.position.y)
            end
            
            Wait(0)
        end
    end)
end

-- Команда для просмотра текущего времени
RegisterCommand('time', function()
    local currentMoscowTime = getCurrentMoscowTime()
    if currentMoscowTime and currentTime.hour ~= nil and currentTime.minute ~= nil then
        lib.notify({
            title = 'Время',
            description = string.format('%s %02d:%02d:%02d\nПогода: %s', 
                config.weekDays[currentDay], currentTime.hour, currentTime.minute, currentTime.second, currentWeather),
            type = 'info'
        })
    else
        lib.notify({
            title = 'Время',
            description = 'Время еще не синхронизировано...',
            type = 'warning'
        })
    end
end, false)

-- Открытие меню администратора
RegisterCommand('timemenu', function()
    local playerGroup = QBX.PlayerData.job.grade.name
    
    -- Проверка прав доступа
    local hasPermission = false
    if config.adminPermissions.useAcePerms then
        hasPermission = IsAceAllowed(('player.%s'):format(GetPlayerServerId(PlayerId())), config.adminPermissions.acePermission)
    else
        for _, group in ipairs(config.adminPermissions.allowedGroups) do
            if playerGroup == group then
                hasPermission = true
                break
            end
        end
    end
    
    if not hasPermission then
        lib.notify({
            title = 'Ошибка',
            description = 'У вас нет прав для этой команды',
            type = 'error'
        })
        return
    end
    
    -- Создание контекстного меню
    lib.registerContext({
        id = 'gametime_admin_menu',
        title = 'Управление временем',
        options = {
            {
                title = 'Установить время',
                description = 'Изменить текущее время',
                icon = 'clock',
                onSelect = function()
                    local input = lib.inputDialog('Установить время', {
                        {type = 'number', label = 'Час (0-23)', default = currentTime.hour, min = 0, max = 23},
                        {type = 'number', label = 'Минута (0-59)', default = currentTime.minute, min = 0, max = 59}
                    })
                    
                    if input then
                        ExecuteCommand(string.format('settime %d %d', input[1], input[2]))
                    end
                end
            },
            {
                title = 'Установить день',
                description = 'Изменить день недели',
                icon = 'calendar',
                onSelect = function()
                    local options = {}
                    for i = 1, 7 do
                        table.insert(options, {value = i, label = config.weekDays[i]})
                    end
                    
                    local input = lib.inputDialog('Установить день', {
                        {type = 'select', label = 'День недели', options = options, default = currentDay}
                    })
                    
                    if input then
                        ExecuteCommand(string.format('setday %d', input[1]))
                    end
                end
            },
            {
                title = 'Заморозить время',
                description = 'Остановить/запустить ход времени',
                icon = 'pause',
                onSelect = function()
                    ExecuteCommand('freezetime')
                end
            },
            {
                title = 'Установить погоду',
                description = 'Изменить текущую погоду',
                icon = 'cloud',
                onSelect = function()
                    local weatherTypes = {
                        {value = 'CLEAR', label = 'Ясно'},
                        {value = 'CLOUDS', label = 'Облачно'},
                        {value = 'OVERCAST', label = 'Пасмурно'},
                        {value = 'RAIN', label = 'Дождь'},
                        {value = 'THUNDER', label = 'Гроза'},
                        {value = 'FOGGY', label = 'Туман'},
                        {value = 'SMOG', label = 'Смог'},
                        {value = 'SNOW', label = 'Снег'},
                        {value = 'BLIZZARD', label = 'Метель'},
                        {value = 'SNOWLIGHT', label = 'Легкий снег'},
                        {value = 'XMAS', label = 'Рождество'},
                        {value = 'HALLOWEEN', label = 'Хэллоуин'}
                    }
                    
                    local input = lib.inputDialog('Установить погоду', {
                        {type = 'select', label = 'Тип погоды', options = weatherTypes}
                    })
                    
                    if input then
                        ExecuteCommand(string.format('setweather %s', input[1]))
                    end
                end
            }
        }
    })
    
    lib.showContext('gametime_admin_menu')
end, false)

-- Экспорты для других ресурсов
exports('GetCurrentTime', function()
    return currentTime
end)

exports('GetCurrentDay', function()
    return currentDay, config.weekDays[currentDay]
end)

exports('GetCurrentWeather', function()
    return currentWeather
end)

exports('GetMoscowTime', function()
    return getCurrentMoscowTime()
end)

exports('GetTimeOffset', function()
    return timeOffset
end)