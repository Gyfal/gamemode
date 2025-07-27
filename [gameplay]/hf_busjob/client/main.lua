--[[
    ТЕСТОВЫЕ ВАРИАНТЫ 3D СТЕН АВТОБУСНЫХ ОСТАНОВОК:
    
    Вариант 1 (Центр) - DrawPoly с поворотом (оригинальный цвет)
    Вариант 2 (Вправо +10) - Стены из тонких DrawBox с поворотом (ФИОЛЕТОВЫЙ)
    
    ДЕБАГ: Желтый квадрат в позиции игрока поворачивается с игроком
    Чтобы проверить поворот - двигайтесь мышью влево/вправо и смотрите как квадрат поворачивается
--]]

local config = require 'config.client'
local sharedConfig = require 'config.shared'

-- Локальные переменные
local jobNPC = nil
local jobBlip = nil
local currentBus = nil
local currentStop = 1
local currentRoute = nil -- Текущий выбранный маршрут
local currentStopBlip = nil
local nextStopBlip = nil -- Блип следующей точки
local currentCheckpoint = nil -- Текущий чекпоинт
local isWorking = false
local totalEarnings = 0
local npcCreated = false -- Флаг, чтобы NPC создавался один раз
local lastStopTime = 0
local lastCompletedStop = 0 -- Номер последней завершенной остановки

-- Система пассажиров
local passengers = {}        -- Хранение активных пассажиров {ped, seatIndex, targetStop}
local waitingPassengers = {} -- Пассажиры на остановке
local isProcessingPassengers = false

-- Таймер выхода из автобуса
local leaveStartTime = nil
local leaveTimeout = config.leaveBusTimeout or 30000

-- Переменные для 3D маркеров остановок
local isInsideStopZone = false -- Находится ли автобус в зоне остановки
local markerThread = nil -- Поток отрисовки маркера

-- Переменные для 3D текста на автобусах
local busTextThread = nil -- Поток отрисовки текста на автобусах
local activeBuses = {} -- Таблица активных автобусов других игроков {[vehicleEntity] = {routeId = 1, nextStopId = 1}}

-- Функция для получения следующей остановки с ID
local function getNextStopInfo(route, currentStopId)
    if not route or not route.stops then return nil end
    
    currentStopId = currentStopId or currentStop
    
    -- Ищем следующую остановку с названием
    for i = currentStopId, #route.stops do
        local stop = route.stops[i]
        if stop.waitTime and stop.waitTime > 0 then
            return {
                name = stop.stopName or "Остановка",
                id = i
            }
        end
    end
    
    -- Если не нашли впереди, ищем с начала (кольцевой маршрут)
    for i = 1, currentStopId - 1 do
        local stop = route.stops[i]
        if stop.waitTime and stop.waitTime > 0 then
            return {
                name = stop.stopName or "Остановка", 
                id = i
            }
        end
    end
    
    return nil
end

-- Функция для получения названия следующей остановки (для совместимости)
local function getNextStopName()
    local info = getNextStopInfo(currentRoute, currentStop)
    return info and info.name, info and info.id
end

-- Функции для маркеров
local startStopMarkerThread, stopStopMarkerThread

-- Функция для запуска отрисовки 3D маркера остановки
startStopMarkerThread = function()
    if markerThread then return end -- Уже запущен
    
    markerThread = CreateThread(function()
        while isWorking and currentRoute and currentRoute.stops[currentStop] do
            Wait(0)
            local stop = currentRoute.stops[currentStop]
            
            if stop and stop.waitTime and stop.waitTime > 0 then -- Только для остановок с ожиданием
                local coords = stop.coords
                local distance = #(GetEntityCoords(cache.ped) - coords)
                
                -- Рисуем маркер только если близко и автобус существует
                if distance < 150.0 and currentBus and DoesEntityExist(currentBus) then
                    local r, g, b = 255, 0, 0 -- Красный по умолчанию
                    local pulse = math.abs(math.sin(GetGameTimer() * 0.001)) * 100 + 155  -- Пульсирующий альфа
                    
                    -- Проверяем состояние
                    if isInsideStopZone then
                        local speed = GetEntitySpeed(currentBus)
                        if speed < 0.1 then
                            r, g, b = 0, 255, 0 -- Зеленый
                        else
                            r, g, b = 255, 255, 0 -- Желтый
                        end
                    end
                    
                    -- Получаем размеры автобуса
                    local min, max = GetModelDimensions(GetEntityModel(currentBus))
                    local length = math.abs(max.y - min.y) + 2.0  -- Длина + запас
                    local width = math.abs(max.x - min.x) + 1.0   -- Ширина + запас
                    local height = 1.5  -- Высота стен
                    
                    -- Heading остановки
                    local heading = math.rad(stop.heading or 0)
                    local cosH = math.cos(heading)
                    local sinH = math.sin(heading)
                    
                    -- Функция поворота точки
                    local function rotatePoint(px, py, cx, cy)
                        local dx = px * cosH - py * sinH
                        local dy = px * sinH + py * cosH
                        return cx + dx, cy + dy
                    end
                    
                    -- Базовые offsets (половина размеров)
                    local halfL = length / 2
                    local halfW = width / 2
                    
                    -- Углы прямоугольника в локальной системе координат
                    -- Передняя часть автобуса смотрит в положительном Y направлении
                    local corners = {
                        {x = -halfW, y = -halfL}, -- Задняя левая
                        {x = halfW, y = -halfL},  -- Задняя правая
                        {x = halfW, y = halfL},   -- Передняя правая
                        {x = -halfW, y = halfL}   -- Передняя левая
                    }
                    
                    -- Поворачиваем углы и переводим в мировые координаты
                    local worldCorners = {}
                    for i, corner in ipairs(corners) do
                        local x, y = rotatePoint(corner.x, corner.y, coords.x, coords.y)
                        worldCorners[i] = {x = x, y = y}
                    end
                    
                    -- Z уровни с определением высоты земли
                    local foundGround, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 100.0, false)
                    local zLow = foundGround and groundZ - 0.4 or coords.z + 0.02
                    local zHigh = zLow + height
                    
                    -- Функция рисования стены с градиентом (от прозрачного вверху к непрозрачному внизу)
                    local function drawGradientWall(corner1, corner2)
                        local gradientLayers = 18  -- Увеличиваем количество слоев для более плавного градиента
                        local maxAlpha = pulse
                        local minAlpha = math.max(15, pulse * 0.15)  -- Делаем верх еще более прозрачным
                        local layerHeight = (zHigh - zLow) / gradientLayers
                        
                        for layer = 1, gradientLayers do
                            local z1 = zLow + (layer - 1) * layerHeight
                            local z2 = zLow + layer * layerHeight
                            
                            -- Вычисляем прозрачность: внизу максимальная, вверху минимальная
                            local progress = (layer - 1) / (gradientLayers - 1)
                            local alpha = maxAlpha * (1 - progress) + minAlpha * progress
                            
                            -- Лицевая сторона слоя
                            DrawPoly(
                                corner1.x, corner1.y, z1,
                                corner2.x, corner2.y, z1,
                                corner2.x, corner2.y, z2,
                                r, g, b, alpha
                            )
                            DrawPoly(
                                corner1.x, corner1.y, z1,
                                corner2.x, corner2.y, z2,
                                corner1.x, corner1.y, z2,
                                r, g, b, alpha
                            )
                            
                            -- Обратная сторона слоя
                            DrawPoly(
                                corner2.x, corner2.y, z1,
                                corner1.x, corner1.y, z1,
                                corner1.x, corner1.y, z2,
                                r, g, b, alpha
                            )
                            DrawPoly(
                                corner2.x, corner2.y, z1,
                                corner1.x, corner1.y, z2,
                                corner2.x, corner2.y, z2,
                                r, g, b, alpha
                            )
                        end
                    end
                    
                    -- Рисуем 4 стены по периметру с градиентом
                    for i = 1, 4 do
                        local corner1 = worldCorners[i]
                        local corner2 = worldCorners[i % 4 + 1] -- Следующий угол (с wraparound)
                        drawGradientWall(corner1, corner2)
                    end
                    
                
                end
            else
                Wait(500) -- Если текущая остановка не требует ожидания, проверяем реже
            end
        end
        markerThread = nil
    end)
end

-- Функция для остановки отрисовки маркера
stopStopMarkerThread = function()
    if markerThread then
        markerThread = nil
    end
end

-- Функция для старта отрисовки 3D текста на автобусах
local function startBusTextThread()
    if busTextThread then return end
    
    busTextThread = CreateThread(function()
        while true do
            Wait(0)
            local playerPed = cache.ped
            local playerCoords = GetEntityCoords(playerPed)
            
            -- Отображаем 3D текст для собственного автобуса водителя
            if isWorking and currentBus and DoesEntityExist(currentBus) and currentRoute then
                local busCoords = GetEntityCoords(currentBus)
                local distance = #(playerCoords - busCoords)
                
                -- Показываем текст водителю только если он вне автобуса
                if distance < 100.0 then
                    local textCoords = busCoords + vector3(0.0, 0.0, 3.5)
                    
                    -- Отображаем информацию о маршруте
                    qbx.drawText3d({
                        coords = textCoords,
                        text = currentRoute.name,
                        scale = 0.5,
                        font = 4,
                        color = vec4(255, 255, 0, 255), -- Желтый цвет
                        enableOutline = true,
                        disableDrawRect = true
                    })
                    
                    -- Отображаем информацию об остановке
                    local nextStopName = getNextStopName()
                    local stopInfo = nextStopName and ('Следует к: ' .. nextStopName) or ('Точка ' .. currentStop .. '/' .. #currentRoute.stops)
                    local stopTextCoords = busCoords + vector3(0.0, 0.0, 3.0)
                    qbx.drawText3d({
                        coords = stopTextCoords,
                        text = stopInfo,
                        scale = 0.4,
                        font = 4,
                        color = vec4(255, 255, 255, 255), -- Белый цвет
                        enableOutline = true,
                        disableDrawRect = true
                    })
                end
            end
            
            -- Проходим по всем активным автобусам других игроков
            for bus, info in pairs(activeBuses) do
                if DoesEntityExist(bus) then
                    local busCoords = GetEntityCoords(bus)
                    local distance = #(playerCoords - busCoords)
                    
                    -- Отображаем текст только если автобус близко
                    if distance < 100 then 
                        -- Получаем маршрут по ID
                        local route = nil
                        for _, r in ipairs(sharedConfig.busRoutes) do
                            if r.id == info.routeId then
                                route = r
                                break
                            end
                        end
                        
                        if route then
                            -- Получаем позицию над автобусом
                            local textCoords = busCoords + vector3(0.0, 0.0, 3.5)
                            
                            -- Отображаем информацию о маршруте
                            qbx.drawText3d({
                                coords = textCoords,
                                text = route.name,
                                scale = 0.5,
                                font = 4,
                                color = vec4(255, 255, 0, 255), -- Желтый цвет
                                enableOutline = true,
                                disableDrawRect = true
                            })
                            
                            -- Получаем информацию о следующей остановке
                            local nextStopInfo = nil
                            if info.nextStopId and info.nextStopId > 0 then
                                local stop = route.stops[info.nextStopId]
                                if stop and stop.stopName then
                                    nextStopInfo = 'Следует к: ' .. stop.stopName
                                else
                                    nextStopInfo = 'Следует к: Остановка'
                                end
                            end
                            
                            -- Отображаем информацию об остановке ниже
                            if nextStopInfo then
                                local stopTextCoords = busCoords + vector3(0.0, 0.0, 3.0)
                                qbx.drawText3d({
                                    coords = stopTextCoords,
                                    text = nextStopInfo,
                                    scale = 0.4,
                                    font = 4,
                                    color = vec4(255, 255, 255, 255), -- Белый цвет
                                    enableOutline = true,
                                    disableDrawRect = true
                                })
                            end
                        end
                    end
                else
                    -- Удаляем автобус из таблицы если он больше не существует
                    activeBuses[bus] = nil
                end
            end
        end
        busTextThread = nil
    end)
end

-- Функция для остановки отрисовки 3D текста
local function stopBusTextThread()
    if busTextThread then
        busTextThread = nil
    end
end


-- Функция основного игрового цикла
local function startMainLoop()
    CreateThread(function()
        while isWorking do
            Wait(0)
            
            -- Zone-based stop detection is now handled by ox_lib zones

            -- Контроль выхода из автобуса
            if currentBus and DoesEntityExist(currentBus) then
                if IsPedInVehicle(cache.ped, currentBus, false) then
                    if leaveStartTime then
                        leaveStartTime = nil
                        lib.notify({ 
                            title = 'Возврат в автобус', 
                            description = 'Маршрут продолжен', 
                            type = 'success', 
                            duration = 3000, 
                            position = config.notifications.position 
                        })
                    end
                else
                    if not leaveStartTime then
                        leaveStartTime = GetGameTimer()
                        lib.notify({ 
                            title = 'Вы покинули автобус', 
                            description = ('Вернитесь в течение %d секунд или будете уволены'):format(math.floor(leaveTimeout / 1000)), 
                            type = 'warning', 
                            duration = leaveTimeout, 
                            position = config.notifications.position 
                        })
                    elseif GetGameTimer() - leaveStartTime >= leaveTimeout then
                        leaveStartTime = nil
                        lib.notify({ 
                            title = 'Вы уволены', 
                            description = 'Вы слишком долго были вне автобуса', 
                            type = 'error', 
                            duration = 5000, 
                            position = config.notifications.position 
                        })
                        TriggerServerEvent('qbx_busjob_new:server:endWork')
                    end
                end
            end

            -- Проверка удержания X для отмены работы
            if IsControlJustPressed(0, config.keys.cancelJob) then
                lib.notify({ 
                    title = 'Отмена работы', 
                    description = 'Удерживайте X чтобы отменить работу', 
                    type = 'warning' 
                })
                local holdStart = GetGameTimer()
                while IsControlPressed(0, config.keys.cancelJob) do
                    Wait(0)
                    if GetGameTimer() - holdStart > 3000 then
                        TriggerServerEvent('qbx_busjob_new:server:endWork')
                        break
                    end
                end
            end
        end
    end)
end

-- Объявляем функции вперед
local openBusMenu, openRouteMenu

-- Меню выбора маршрута
openRouteMenu = function()
    -- Запрашиваем текущее количество автобусов на маршрутах
    lib.callback('qbx_busjob_new:server:getRouteBusCount', false, function(routeBusCount)
        local options = {}

        for i, route in ipairs(sharedConfig.busRoutes) do
            local busCount = routeBusCount[route.id] or 0
            local maxBuses = sharedConfig.settings.maxBusesPerRoute
            local isAvailable = busCount < maxBuses
            
            options[#options + 1] = {
                title = i .. ') '.. route.name .. ' [' .. busCount .. '/' .. maxBuses .. ']',
                description = route.description .. ' (' .. #route.stops .. ' точек)',
                icon = 'route',
                disabled = not isAvailable,
                onSelect = function()
                    if isAvailable then
                        currentRoute = route
                        openBusMenu()
                    else
                        lib.notify({
                            title = 'Маршрут недоступен',
                            description = 'На этом маршруте уже максимальное количество автобусов',
                            type = 'error'
                        })
                    end
                end
            }
        end

        lib.registerContext({
            id = 'route_selection_menu',
            title = 'Выбор маршрута',
            options = options
        })

        lib.showContext('route_selection_menu')
    end)
end

-- Меню выбора автобуса
openBusMenu = function()
    if not currentRoute then
        lib.notify({
            title = 'Ошибка',
            description = 'Сначала выберите маршрут',
            type = 'error'
        })
        return
    end

    local options = {}

    for i, bus in ipairs(sharedConfig.busModels) do
        options[#options + 1] = {
            title = bus.label,
            description = sharedConfig.settings.requireDeposit and ('Залог: $' .. bus.deposit) or 'Без залога',
            icon = 'bus',
            onSelect = function()
                TriggerServerEvent('qbx_busjob_new:server:requestBus', i, currentRoute.id)
            end
        }
    end

    lib.registerContext({
        id = 'bus_selection_menu',
        title = 'Выбор автобуса',
        options = options
    })

    lib.showContext('bus_selection_menu')
end

-- Функции для работы с пассажирами (теперь на сервере)
local function clearWaitingPassengers()
    -- Очищаем только локальные данные, пассажиры теперь управляются сервером
    waitingPassengers = {}
end

-- Создание чекпоинта
local function createCheckpoint()
    if not currentRoute then return end
    
    -- Удаляем старый чекпоинт
    if currentCheckpoint then
        DeleteCheckpoint(currentCheckpoint)
        currentCheckpoint = nil
    end
    
    local stop = currentRoute.stops[currentStop]
    if not stop then return end
    
    -- Определяем тип чекпоинта
    local checkpointType
    local nextStop = currentRoute.stops[currentStop + 1]
    
    if stop.waitTime and stop.waitTime > 0 then
        -- Для остановок используем специальный тип (тип 10)
        checkpointType = 10
    elseif nextStop then
        -- Для промежуточных точек используем стрелку (тип 1)
        checkpointType = 1
    else
        -- Для последней точки используем специальный тип (тип 10)
        checkpointType = 10
    end
    
    -- Координаты следующей точки для направления
    local nextX, nextY, nextZ = stop.coords.x, stop.coords.y, stop.coords.z
    if nextStop then
        nextX, nextY, nextZ = nextStop.coords.x, nextStop.coords.y, nextStop.coords.z
    end
    
    -- Создаем чекпоинт
    if stop.waitTime and stop.waitTime > 0 then
        -- Для остановок создаем прозрачный чекпоинт (только маркер)
        currentCheckpoint = CreateCheckpoint(
            checkpointType,
            stop.coords.x, stop.coords.y, stop.coords.z - 1.0,
            nextX, nextY, stop.coords.z,
            5.0, -- радиус
            255, 255, 0, 0, -- желтый цвет с полной прозрачностью (альфа = 0)
            0
        )
    else
        -- Для промежуточных точек используем белый цвет
        currentCheckpoint = CreateCheckpoint(
            checkpointType,
            stop.coords.x, stop.coords.y, stop.coords.z - 1.0,
            nextX, nextY, stop.coords.z,
            5.0, -- радиус
            255, 255, 255, 200, -- белый цвет
            0
        )
    end
    
    SetCheckpointCylinderHeight(currentCheckpoint, 2.0, 5.0, 2.0)
end

-- Обновление текущей остановки
local function updateCurrentStop()
    if not currentRoute then return end

    -- Удаление старых блипов
    if currentStopBlip then
        RemoveBlip(currentStopBlip)
        currentStopBlip = nil
    end
    
    if nextStopBlip then
        RemoveBlip(nextStopBlip)
        nextStopBlip = nil
    end

    local stop = currentRoute.stops[currentStop]
    if not stop then return end

    -- Очищаем предыдущих ожидающих пассажиров
    clearWaitingPassengers()

    -- Создаем новых пассажиров только на остановках с временем ожидания (на сервере)
    if stop.waitTime and stop.waitTime > 0 then
        TriggerServerEvent('qbx_busjob_new:server:createPassengers', currentStop)
    end
    
    -- Запускаем отрисовку 3D маркера для остановки
    startStopMarkerThread()

    -- Создание блипа текущей остановки
    currentStopBlip = AddBlipForCoord(stop.coords.x, stop.coords.y, stop.coords.z)
    SetBlipSprite(currentStopBlip, config.blip.currentStop.sprite)
    SetBlipDisplay(currentStopBlip, 4)
    SetBlipScale(currentStopBlip, config.blip.currentStop.scale)
    SetBlipColour(currentStopBlip, config.blip.currentStop.color)
    SetBlipRoute(currentStopBlip, config.blip.route.route)
    SetBlipRouteColour(currentStopBlip, config.blip.route.color)

    if config.blip.currentStop.flash then
        SetBlipFlashes(currentStopBlip, true)
    end

    BeginTextCommandSetBlipName("STRING")
    local stopName = stop.waitTime and stop.waitTime > 0 and "Остановка " .. currentStop or "Точка " .. currentStop
    AddTextComponentSubstringPlayerName(stopName)
    EndTextCommandSetBlipName(currentStopBlip)
    
    -- Создание блипа следующей точки
    local nextStop = currentRoute.stops[currentStop + 1]
    if nextStop then
        nextStopBlip = AddBlipForCoord(nextStop.coords.x, nextStop.coords.y, nextStop.coords.z)
        SetBlipSprite(nextStopBlip, 1)
        SetBlipDisplay(nextStopBlip, 4)
        SetBlipScale(nextStopBlip, 0.7)
        SetBlipColour(nextStopBlip, 2) -- Зеленый цвет для следующей точки
        SetBlipAsShortRange(nextStopBlip, false)
        
        BeginTextCommandSetBlipName("STRING")
        local nextStopName = nextStop.waitTime and nextStop.waitTime > 0 and "Следующая остановка" or "Следующая точка"
        AddTextComponentSubstringPlayerName(nextStopName)
        EndTextCommandSetBlipName(nextStopBlip)
    end
    
    -- Создаем чекпоинт
    createCheckpoint()
    
    -- Сервер сам синхронизирует данные об автобусах

    -- Уведомление с улучшенной информацией
    local passengerCount = #waitingPassengers
    local description = ""
    
    -- Определяем тип точки
    local isFirstStop = currentStop == 1
    local isLastStop = currentStop == #currentRoute.stops
    local isStop = stop.waitTime and stop.waitTime > 0
    
    -- Добавляем информацию о пассажирах
    if passengerCount > 0 then
        description = passengerCount .. ' пассажиров ожидают'
    end
    
    -- Показываем ожидаемую оплату
    if stop.payment and stop.payment > 0 then
        if description ~= "" then description = description .. ' | ' end
        description = description .. 'Оплата: $' .. stop.payment
    end

    -- Добавляем информацию о времени ожидания
    if stop.waitTime and stop.waitTime > 0 then
        if description ~= "" then description = description .. ' | ' end
        description = description .. 'Ожидание: ' .. math.floor(stop.waitTime / 1000) .. ' сек'
    end

    lib.notify({
        title = isFirstStop and 'Начало маршрута' or (isLastStop and 'Финальная остановка' or (isStop and 'Остановка' or 'Следующая точка')),
        description = description ~= "" and description or currentRoute.name,
        type = isFirstStop and 'success' or (isLastStop and 'warning' or 'info'),
        position = config.notifications.position,
        duration = config.notifications.duration
    })

    -- Создание временного большого маркера для первой остановки
    if currentStop == 1 and isWorking then
        CreateThread(function()
            local startTime = GetGameTimer()
            while GetGameTimer() - startTime < 10000 do -- Показывать 10 секунд
                local coords = stop.coords
                local r, g, b = 255, 255, 0 -- Желтый для первой остановки
                local pulse = math.abs(math.sin(GetGameTimer() * 0.002)) * 100 + 155  -- Быстрее пульсация
                
                -- Рисуем большой заполненный 3D квадрат с помощью DrawPoly
                local halfSize = sharedConfig.settings.stopRadius * 1.5 / 2.0  -- Больший размер
                local z = coords.z + 0.02  -- Чуть выше земли
                
                -- Точки внутреннего квадрата
                local p1 = vector3(coords.x - halfSize, coords.y - halfSize, z)
                local p2 = vector3(coords.x + halfSize, coords.y - halfSize, z)
                local p3 = vector3(coords.x + halfSize, coords.y + halfSize, z)
                local p4 = vector3(coords.x - halfSize, coords.y + halfSize, z)
                
                -- Заполненный квадрат (два треугольника)
                DrawPoly(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, p3.x, p3.y, p3.z, r, g, b, pulse)
                DrawPoly(p1.x, p1.y, p1.z, p3.x, p3.y, p3.z, p4.x, p4.y, p4.z, r, g, b, pulse)
                
                -- Внешняя граница (белая, чуть больше)
                local borderOffset = 0.4  -- Больший offset для большого маркера
                local outerHalfSize = halfSize + borderOffset
                
                local op1 = vector3(coords.x - outerHalfSize, coords.y - outerHalfSize, z)
                local op2 = vector3(coords.x + outerHalfSize, coords.y - outerHalfSize, z)
                local op3 = vector3(coords.x + outerHalfSize, coords.y + outerHalfSize, z)
                local op4 = vector3(coords.x - outerHalfSize, coords.y + outerHalfSize, z)
                
                -- Рисуем внешнюю границу линиями
                DrawLine(op1.x, op1.y, op1.z, op2.x, op2.y, op2.z, 255, 255, 255, 255)
                DrawLine(op2.x, op2.y, op2.z, op3.x, op3.y, op3.z, 255, 255, 255, 255)
                DrawLine(op3.x, op3.y, op3.z, op4.x, op4.y, op4.z, 255, 255, 255, 255)
                DrawLine(op4.x, op4.y, op4.z, op1.x, op1.y, op1.z, 255, 255, 255, 255)
                
                Wait(0)
            end
        end)
    end
end

-- Zone management system for bus stops
local busStopZones = {}
local currentZone = nil

-- Helper function to normalize heading
local function normalizeHeading(heading)
    while heading < 0 do heading = heading + 360 end
    while heading >= 360 do heading = heading - 360 end
    return heading
end

-- Check if player is in correct vehicle and heading
local function isValidBusStop(stop)
    if not isWorking or not currentBus or not DoesEntityExist(currentBus) then return false end
    if not IsPedInVehicle(cache.ped, currentBus, false) then return false end
    
    local busHeading = GetEntityHeading(currentBus)
    local normalizedBusHeading = normalizeHeading(busHeading)
    local normalizedStopHeading = normalizeHeading(stop.heading)
    
    local headingDiff = math.abs(normalizedBusHeading - normalizedStopHeading)
    if headingDiff > 180 then
        headingDiff = 360 - headingDiff
    end

    local tolerance = currentRoute.headingTolerance or 45.0
    return headingDiff <= tolerance
end

-- Create zones for all stops in current route
function createBusStopZones()
    if not currentRoute or not currentRoute.stops then return end
    
    for i, stop in ipairs(currentRoute.stops) do
        local zone = lib.zones.sphere({
            coords = stop.coords,
            radius = sharedConfig.settings.stopRadius,
            debug = false,
            name = 'bus_stop_' .. currentRoute.id .. '_' .. i
        })
        
        zone.stopIndex = i
        zone.stopData = stop
        zone.routeId = currentRoute.id
        
        -- Zone enter event
        function zone:onEnter()
            if not isValidBusStop(self.stopData) then return end
            if self.stopIndex ~= currentStop then return end -- Только текущая остановка
            if self.stopIndex <= (lastCompletedStop or 0) then return end -- Не может быть меньше или равна последней завершенной
            if currentZone then return end -- Already processing another zone
            
            -- Устанавливаем флаг входа в зону
            isInsideStopZone = true
            
            currentZone = self
            lastStopTime = GetGameTimer()
            local isStop = self.stopData.waitTime and self.stopData.waitTime > 0
            local waitTime = self.stopData.waitTime or 0

            if isStop then
                -- Ждем полной остановки автобуса
                CreateThread(function()
                    local stopWaitTime = 0
                    while isWorking and currentBus and DoesEntityExist(currentBus) and stopWaitTime < 5000 do
                        local speed = GetEntitySpeed(currentBus)
                        if speed < 0.1 then
                            -- Автобус остановлен
                            SetVehicleHandbrake(currentBus, true)

                            lib.notify({
                                title = 'Остановка',
                                description = 'Вы прибыли на остановку',
                                type = 'success',
                                position = config.notifications.position
                            })

                            -- Сначала высаживаем пассажиров (на сервере)
                            TriggerServerEvent('qbx_busjob_new:server:alightPassengers', currentStop)

                            -- Ждем немного перед посадкой новых
                            SetTimeout(2000, function()
                                -- Проверяем что игрок все еще работает
                                if not isWorking or not currentBus or not DoesEntityExist(currentBus) then return end
                                -- Затем садим новых пассажиров (на сервере)
                                TriggerServerEvent('qbx_busjob_new:server:boardPassengers')
                            end)
                            
                            -- Отправка на сервер для оплаты за остановку
                            TriggerServerEvent('qbx_busjob_new:server:reachedStop', currentStop)
                            break
                        end
                        Wait(100)
                        stopWaitTime = stopWaitTime + 100
                    end
                    
                    if stopWaitTime >= 5000 then
                        lib.notify({
                            title = 'Ошибка',
                            description = 'Вы должны полностью остановить автобус!',
                            type = 'error',
                            position = config.notifications.position
                        })
                    end
                end)
            else
                -- Для обычных точек сразу отправляем событие
                TriggerServerEvent('qbx_busjob_new:server:reachedStop', currentStop)
            end

            -- Переход к следующей остановке
            SetTimeout(waitTime + (isStop and 2000 or 100), function()
                -- Проверяем что игрок все еще работает
                if not isWorking or not currentBus or not DoesEntityExist(currentBus) then return end
                
                if isStop then
                    SetVehicleHandbrake(currentBus, false)
                end

                lastCompletedStop = currentStop -- Записываем завершенную остановку
                currentStop = currentStop + 1
                currentZone = nil -- Reset zone processing
                isInsideStopZone = false -- Сбрасываем флаг зоны
                
                if currentRoute and currentStop > #currentRoute.stops then
                    -- Кольцевой маршрут - начинаем новый круг
                    TriggerServerEvent('qbx_busjob_new:server:completedRoute')

                    lib.notify({
                        title = 'Круг завершен',
                        description = 'Вы завершили круг! Заработано: $' .. totalEarnings .. '\nНачинается новый круг...',
                        type = 'success',
                        duration = 10000
                    })
                    
                    -- Сброс на первую остановку для нового круга
                    currentStop = 1
                    lastCompletedStop = 0 -- Сбрасываем для нового круга
                    updateCurrentStop()
                else
                    updateCurrentStop()
                end
            end)
        end
        
        -- Zone exit event
        function zone:onExit()
            if self.stopIndex == currentStop then
                isInsideStopZone = false -- Сбрасываем флаг при выходе из зоны
            end
        end
        
        busStopZones[i] = zone
    end
end

-- Remove all bus stop zones
function removeBusStopZones()
    for _, zone in pairs(busStopZones) do
        zone:remove()
    end
    busStopZones = {}
    currentZone = nil
end

-- Завершение работы
local function endWork()
    leaveStartTime = nil
    isWorking = false

    -- Остановка отрисовки маркера
    stopStopMarkerThread()
    isInsideStopZone = false
    
    -- Сервер сам удалит наш автобус из синхронизации при завершении работы

    -- Удаление всех зон остановок
    removeBusStopZones()

    -- Очистка локальных данных пассажиров (сервер сам очистит серверных пассажиров)
    passengers = {}
    clearWaitingPassengers()

    -- Удаление автобуса
    if currentBus and DoesEntityExist(currentBus) then
        -- Устанавливаем как Mission Entity для правильного удаления
        SetEntityAsMissionEntity(currentBus, true, true)
        -- DeleteVehicle(currentBus)
    end

    -- Удаление блипов
    if currentStopBlip then
        RemoveBlip(currentStopBlip)
        currentStopBlip = nil
    end
    
    if nextStopBlip then
        RemoveBlip(nextStopBlip)
        nextStopBlip = nil
    end
    
    -- Удаление чекпоинта
    if currentCheckpoint then
        DeleteCheckpoint(currentCheckpoint)
        currentCheckpoint = nil
    end

    currentBus = nil
    currentStop = 1
    currentRoute = nil
    isProcessingPassengers = false
    lastCompletedStop = 0 -- Сбрасываем при завершении

    lib.notify({
        title = 'Работа завершена',
        description = 'Вы закончили работу',
        type = 'info'
    })
end


function getAvailableSeat()
    if not currentBus then return nil end

    local maxSeats = GetVehicleModelNumberOfSeats(GetEntityModel(currentBus))

    -- Начинаем с seat 0 (пассажирские места)
    for i = 0, maxSeats - 1 do
        if i ~= -1 and IsVehicleSeatFree(currentBus, i) then -- -1 это водительское место
            -- Проверяем что место не занято нашими пассажирами
            local seatTaken = false
            for _, passenger in pairs(passengers) do
                if passenger.seatIndex == i then
                    seatTaken = true
                    break
                end
            end
            if not seatTaken then
                return i
            end
        end
    end
    return nil
end


-- Старые функции пассажиров удалены - теперь используется серверная система

-- Создание NPC для устройства на работу
local function createJobNPC()
    if npcCreated then return end
    local npcConfig = sharedConfig.jobNPC

    -- Загрузка модели
    lib.requestModel('a_m_m_indian_01', 10000)

    -- Создание педа
    jobNPC = CreatePed(4, 'a_m_m_indian_01', npcConfig.coords.x, npcConfig.coords.y, npcConfig.coords.z - 1.0,
        npcConfig.coords.w, false, true)

    -- Настройка педа
    SetEntityInvincible(jobNPC, true)
    FreezeEntityPosition(jobNPC, true)
    SetBlockingOfNonTemporaryEvents(jobNPC, true)

    -- Добавление взаимодействия через ox_target
    exports.ox_target:addLocalEntity(jobNPC, {
        {
            name = 'busjob_start',
            icon = 'fas fa-briefcase',
            label = 'Устроиться на работу',
            canInteract = function()
                return not isWorking and QBX.PlayerData and QBX.PlayerData.job.name ~= 'bus'
            end,
            onSelect = function()
                TriggerServerEvent('qbx_busjob_new:server:startJob')
            end
        },
        {
            name = 'busjob_menu',
            icon = 'fas fa-bus',
            label = 'Взять автобус',
            canInteract = function()
                return not isWorking and QBX.PlayerData and QBX.PlayerData.job.name == 'bus'
            end,
            onSelect = function()
                openRouteMenu()
            end
        },
        {
            name = 'busjob_quit',
            icon = 'fas fa-times',
            label = 'Уволиться',
            canInteract = function()
                return QBX.PlayerData and QBX.PlayerData.job.name == 'bus'
            end,
            onSelect = function()
                TriggerServerEvent('qbx_busjob_new:server:quitJob')
            end
        }
    })

    -- Создание блипа
    if npcConfig.blip.enabled then
        jobBlip = AddBlipForCoord(npcConfig.coords.x, npcConfig.coords.y, npcConfig.coords.z)
        SetBlipSprite(jobBlip, npcConfig.blip.sprite)
        SetBlipDisplay(jobBlip, 4)
        SetBlipScale(jobBlip, npcConfig.blip.scale)
        SetBlipColour(jobBlip, npcConfig.blip.color)
        SetBlipAsShortRange(jobBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(sharedConfig.jobNPC.blip.label)
        EndTextCommandSetBlipName(jobBlip)
    end

    npcCreated = true
end



-- Обработка обновления информации об автобусах других игроков
RegisterNetEvent('qbx_busjob_new:client:updateBusInfo', function(busNetId, routeId, nextStopId, senderId)
    -- Не обрабатываем собственные обновления
    if senderId == GetPlayerServerId(PlayerId()) then return end
    
    local bus = NetworkGetEntityFromNetworkId(busNetId)
    if DoesEntityExist(bus) then
        if routeId and nextStopId then
            -- Добавляем или обновляем информацию
            activeBuses[bus] = {
                routeId = routeId,
                nextStopId = nextStopId
            }
        else
            -- Удаляем автобус если нет информации (водитель закончил работу)
            activeBuses[bus] = nil
        end
    end
end)

-- Начало работы
RegisterNetEvent('qbx_busjob_new:client:startWork', function(busNetId, deposit, routeId)
    -- Устанавливаем текущий маршрут если передан ID
    if routeId then
        for _, route in ipairs(sharedConfig.busRoutes) do
            if route.id == routeId then
                currentRoute = route
                break
            end
        end
    end

    if not currentRoute then
        lib.notify({
            title = 'Ошибка',
            description = 'Маршрут не выбран',
            type = 'error'
        })
        return
    end

    local bus = NetworkGetEntityFromNetworkId(busNetId)

    if not bus or bus == 0 then
        lib.notify({
            title = 'Ошибка',
            description = 'Не удалось создать автобус',
            type = 'error'
        })
        return
    end

    -- Ожидание полной загрузки автобуса
    local attempts = 0
    while not DoesEntityExist(bus) and attempts < 30 do
        Wait(100)
        bus = NetworkGetEntityFromNetworkId(busNetId)
        attempts = attempts + 1
    end

    if not DoesEntityExist(bus) then
        lib.notify({
            title = 'Ошибка',
            description = 'Автобус не загрузился',
            type = 'error'
        })
        return
    end

    currentBus = bus
    currentStop = 1
    totalEarnings = 0
    lastCompletedStop = 0 -- Сбрасываем для новой работы

    -- Дополнительная телепортация для надежности
    if not IsPedInVehicle(cache.ped, currentBus, false) then
        local busCoords = GetEntityCoords(currentBus)
        SetEntityCoords(cache.ped, busCoords.x, busCoords.y, busCoords.z + 1.0, false, false, false, true)
        Wait(100)
        TaskWarpPedIntoVehicle(cache.ped, currentBus, -1)
    end

    -- Установка автобуса как личного транспорта
    SetVehicleHasBeenOwnedByPlayer(currentBus, true)
    SetEntityAsMissionEntity(currentBus, true, true)
    SetVehicleNeedsToBeHotwired(currentBus, false)
    SetVehicleDoorsLocked(currentBus, 1) -- Разблокировать двери

    -- Создание зон остановок для текущего маршрута
    createBusStopZones()

    -- Обновление первой остановки (создаёт единственный блип)
    updateCurrentStop()

    -- Автоматический старт двигателя
    SetVehicleEngineOn(currentBus, true, true, false)
    
    -- Запуск основного игрового цикла ПЕРЕД установкой isWorking
    startMainLoop()
    
    -- Устанавливаем isWorking = true ПОСЛЕ запуска цикла
    isWorking = true
    
    -- Сервер сам синхронизирует данные об автобусах

    lib.notify({
        title = 'Работа начата',
        description = deposit and ('Работа начата! Залог: $' .. deposit) or 'Работа начата!',
        type = 'success'
    })

    -- Показать инструкцию
    lib.notify({
        title = 'Инструкция',
        description = 'Следуйте к первой остановке по GPS. Удерживайте X для отмены работы',
        type = 'info',
        duration = 8000
    })
end)

-- Обработка оплаты
RegisterNetEvent('qbx_busjob_new:client:receivePayment', function(amount)
    totalEarnings = totalEarnings + amount

    lib.notify({
        title = 'Оплата получена',
        description = '+$' .. amount,
        type = 'success',
        position = config.notifications.position
    })
end)

-- Обработка оплаты за пассажира
RegisterNetEvent('qbx_busjob_new:client:receivePassengerPayment', function(amount)
    lib.notify({
        title = 'Пассажир сел',
        description = '+$' .. amount,
        type = 'success',
        position = config.notifications.position
    })
end)

-- События
RegisterNetEvent('qbx_busjob_new:client:endWork', endWork)

-- Удаление автобуса по команде сервера
RegisterNetEvent('qbx_busjob_new:client:deleteVehicle', function(busNetId)
    local veh = NetworkGetEntityFromNetworkId(busNetId)
    if DoesEntityExist(veh) then
        -- Устанавливаем как Mission Entity для правильного удаления
        SetEntityAsMissionEntity(veh, true, true)
        -- DeleteVehicle(veh)
        print('^3[BUS JOB CLIENT] ^2Автобус удален клиентом (NetID: ' .. busNetId .. ')^0')
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    createJobNPC()
    startBusTextThread() -- Запускаем отрисовку 3D текста
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if jobNPC then
        DeletePed(jobNPC)
    end
    if jobBlip then
        RemoveBlip(jobBlip)
    end
    stopBusTextThread() -- Останавливаем отрисовку 3D текста
    activeBuses = {} -- Очищаем таблицу автобусов
    endWork()
end)

-- Функция периодической очистки далеких автобусов
local function startBusCleanupThread()
    CreateThread(function()
        while true do
            Wait(5000) -- Проверяем каждые 5 секунд
            local playerCoords = GetEntityCoords(cache.ped)
            local maxCleanupDistance = 350.0 -- Можно настроить в будущем через конфигурацию
            
            for bus, info in pairs(activeBuses) do
                if not DoesEntityExist(bus) then
                    -- Автобус больше не существует
                    activeBuses[bus] = nil
                else
                    local busCoords = GetEntityCoords(bus)
                    local distance = #(playerCoords - busCoords)
                    
                    -- Удаляем из таблицы если автобус слишком далеко
                    if distance > maxCleanupDistance then
                        activeBuses[bus] = nil
                    end
                end
            end
        end
    end)
end

-- Основной поток
CreateThread(function()
    -- Дожидаемся, пока у ядра появится PlayerData (игрок загрузился)
    while not QBX or not QBX.PlayerData do
        Wait(500)
    end
    createJobNPC()
    startBusTextThread() -- Запускаем отрисовку 3D текста при старте ресурса
    startBusCleanupThread() -- Запускаем очистку далеких автобусов
end)

-- Очистка при остановке ресурса
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- Удаление NPC
    if jobNPC and DoesEntityExist(jobNPC) then
        DeletePed(jobNPC)
        jobNPC = nil
    end

    -- Удаление блипа автопарка
    if jobBlip then
        RemoveBlip(jobBlip)
        jobBlip = nil
    end
    
    -- Удаление чекпоинта
    if currentCheckpoint then
        DeleteCheckpoint(currentCheckpoint)
        currentCheckpoint = nil
    end

    -- Если работаем - завершаем работу
    if isWorking then
        endWork()
    end
end)
