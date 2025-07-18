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
local lastStopTime = 0
local totalEarnings = 0
local npcCreated = false -- Флаг, чтобы NPC создавался один раз

-- Система пассажиров
local passengers = {}        -- Хранение активных пассажиров {ped, seatIndex, targetStop}
local waitingPassengers = {} -- Пассажиры на остановке
local isProcessingPassengers = false

-- Таймер выхода из автобуса
local leaveStartTime = nil
local leaveTimeout = config.leaveBusTimeout or 30000

-- Функция основного игрового цикла
local function startMainLoop()
    CreateThread(function()
        while isWorking do
            Wait(0)
            
            -- Проверка прибытия на остановку
            checkBusStop()

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

-- Меню выбора маршрута
local function openRouteMenu()
    -- Запрашиваем текущее количество автобусов на маршрутах
    lib.callback('qbx_busjob_new:server:getRouteBusCount', false, function(routeBusCount)
        local options = {}

        for i, route in ipairs(sharedConfig.busRoutes) do
            local busCount = routeBusCount[route.id] or 0
            local maxBuses = sharedConfig.settings.maxBusesPerRoute
            local isAvailable = busCount < maxBuses
            
            options[#options + 1] = {
                title = route.name .. ' [' .. busCount .. '/' .. maxBuses .. ']',
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
function openBusMenu()
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

-- Проверка прибытия на остановку
function checkBusStop()
    if not isWorking or not currentBus or not currentRoute then return end

    local stop = currentRoute.stops[currentStop]
    if not stop then return end

    local busCoords = GetEntityCoords(currentBus)
    local busHeading = GetEntityHeading(currentBus)
    local distance = #(busCoords - stop.coords)

    -- Проверка прибытия
    if distance < sharedConfig.settings.stopRadius then
        -- Улучшенная проверка heading с допуском
        local function normalizeHeading(heading)
            while heading < 0 do heading = heading + 360 end
            while heading >= 360 do heading = heading - 360 end
            return heading
        end
        
        local normalizedBusHeading = normalizeHeading(busHeading)
        local normalizedStopHeading = normalizeHeading(stop.heading)
        
        local headingDiff = math.abs(normalizedBusHeading - normalizedStopHeading)
        if headingDiff > 180 then
            headingDiff = 360 - headingDiff
        end

        local tolerance = currentRoute.headingTolerance or 45.0
        if headingDiff <= tolerance then
            if GetGameTimer() - lastStopTime > 3000 then -- Защита от спама
                lastStopTime = GetGameTimer()

                local isStop = stop.waitTime and stop.waitTime > 0
                local waitTime = stop.waitTime or 0

                if isStop then
                    -- Остановка автобуса
                    SetVehicleHandbrake(currentBus, true)

                    lib.notify({
                        title = 'Остановка',
                        description = 'Вы прибыли на остановку',
                        type = 'success',
                        position = config.notifications.position
                    })

                    -- Сначала высаживаем пассажиров
                    alightPassengers()

                    -- Ждем немного перед посадкой новых
                    SetTimeout(2000, function()
                        -- Проверяем что игрок все еще работает
                        if not isWorking or not currentBus or not DoesEntityExist(currentBus) then return end
                        -- Затем садим новых пассажиров
                        boardPassengers()
                    end)
                end

                -- Отправка на сервер для оплаты за остановку
                TriggerServerEvent('qbx_busjob_new:server:reachedStop', currentStop)

                -- Переход к следующей остановке
                SetTimeout(waitTime + (isStop and 2000 or 100), function()
                    -- Проверяем что игрок все еще работает
                    if not isWorking or not currentBus or not DoesEntityExist(currentBus) then return end
                    
                    if isStop then
                        SetVehicleHandbrake(currentBus, false)
                    end

                    currentStop = currentStop + 1
                    if currentRoute and currentStop > #currentRoute.stops then
                        -- Завершение маршрута
                        TriggerServerEvent('qbx_busjob_new:server:completedRoute')

                        lib.notify({
                            title = 'Маршрут завершен',
                            description = 'Вы завершили маршрут! Заработано: $' .. totalEarnings,
                            type = 'success',
                            duration = 10000
                        })
                        
                        -- Сброс для нового круга или завершение работы
                        endWork()
                    else
                        updateCurrentStop()
                    end
                end)
            end
        end
    end
end

-- Завершение работы
local function endWork()
    leaveStartTime = nil
    isWorking = false

    -- Очистка всех пассажиров
    clearAllPassengers()

    -- Удаление автобуса
    if currentBus and DoesEntityExist(currentBus) then
        -- Устанавливаем как Mission Entity для правильного удаления
        SetEntityAsMissionEntity(currentBus, true, true)
        DeleteVehicle(currentBus)
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

    lib.notify({
        title = 'Работа завершена',
        description = 'Вы закончили работу',
        type = 'info'
    })
end

-- Функции для работы с пассажирами
local function getRandomPassengerModel()
    local gender = math.random(1, 2) == 1 and 'male' or 'female'
    local models = sharedConfig.passengerModels[gender]
    return models[math.random(1, #models)]
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

local function createWaitingPassengers(stopCoords)
    if not currentRoute then return end
    
    if math.random(100) > sharedConfig.passengerSettings.passengerSpawnChance then
        return
    end

    local numPassengers = math.random(
        sharedConfig.passengerSettings.minPassengersPerStop,
        sharedConfig.passengerSettings.maxPassengersPerStop
    )

    for i = 1, numPassengers do
        local model = getRandomPassengerModel()
        lib.requestModel(model, 10000)

        -- Спавн рядом с остановкой
        local spawnCoords = stopCoords + vector3(
            math.random(-5, 5),
            math.random(-5, 5),
            0
        )

        local passenger = CreatePed(4, model, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0.0, false, true)

        -- Настройка педа
        SetEntityInvincible(passenger, true)
        SetBlockingOfNonTemporaryEvents(passenger, true)
        TaskStandStill(passenger, -1)

        -- Случайная целевая остановка (не текущая)
        local targetStop = currentStop
        if currentRoute and #currentRoute.stops > 1 then
            targetStop = math.random(1, #currentRoute.stops)
            while targetStop == currentStop do
                targetStop = math.random(1, #currentRoute.stops)
            end
        end

        waitingPassengers[#waitingPassengers + 1] = {
            ped = passenger,
            targetStop = targetStop
        }

        SetModelAsNoLongerNeeded(model)
    end
end

local function clearWaitingPassengers()
    for _, passenger in pairs(waitingPassengers) do
        if DoesEntityExist(passenger.ped) then
            DeletePed(passenger.ped)
        end
    end
    waitingPassengers = {}
end

function boardPassengers()
    if isProcessingPassengers or #waitingPassengers == 0 then return end

    isProcessingPassengers = true

    lib.notify({
        title = 'Посадка пассажиров',
        description = 'Пассажиры садятся в автобус...',
        type = 'info'
    })

    for _, waitingPassenger in pairs(waitingPassengers) do
        local seatIndex = getAvailableSeat()
        if seatIndex then
            -- Посадка пассажира
            TaskEnterVehicle(waitingPassenger.ped, currentBus, -1, seatIndex, 1.0, 0)

            -- Добавляем в список активных пассажиров
            passengers[#passengers + 1] = {
                ped = waitingPassenger.ped,
                seatIndex = seatIndex,
                targetStop = waitingPassenger.targetStop
            }

            -- Оплата за посадку пассажира
            local payment = math.random(
                sharedConfig.passengerSettings.passengerPayment.min,
                sharedConfig.passengerSettings.passengerPayment.max
            )
            totalEarnings = totalEarnings + payment

            TriggerServerEvent('qbx_busjob_new:server:passengerBoarded', payment)
        else
            -- Нет свободных мест - удаляем пассажира
            DeletePed(waitingPassenger.ped)
        end
    end

    waitingPassengers = {}

    SetTimeout(sharedConfig.passengerSettings.animationTime, function()
        isProcessingPassengers = false
    end)
end

function alightPassengers()
    if isProcessingPassengers then return end

    local passengersToRemove = {}

    for i, passenger in pairs(passengers) do
        -- Проверяем нужно ли пассажиру выходить
        if passenger.targetStop == currentStop or
            math.random(100) <= sharedConfig.passengerSettings.exitChance then
            -- Высадка пассажира
            TaskLeaveVehicle(passenger.ped, currentBus, 0)

            -- Помечаем для удаления
            passengersToRemove[#passengersToRemove + 1] = i

            -- Удаляем пассажира через некоторое время
            SetTimeout(5000, function()
                -- Проверяем что пед еще существует
                if DoesEntityExist(passenger.ped) then
                    DeletePed(passenger.ped)
                end
            end)

            if passenger.targetStop == currentStop then
                lib.notify({
                    title = 'Пассажир вышел',
                    description = 'Пассажир добрался до пункта назначения',
                    type = 'info'
                })
            end
        end
    end

    -- Удаляем пассажиров из списка (в обратном порядке)
    for i = #passengersToRemove, 1, -1 do
        table.remove(passengers, passengersToRemove[i])
    end
end

function clearAllPassengers()
    -- Удаляем всех пассажиров
    for _, passenger in pairs(passengers) do
        if DoesEntityExist(passenger.ped) then
            DeletePed(passenger.ped)
        end
    end
    passengers = {}

    clearWaitingPassengers()
end

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
    currentCheckpoint = CreateCheckpoint(
        checkpointType,
        stop.coords.x, stop.coords.y, stop.coords.z - 1.0,
        nextX, nextY, nextZ,
        5.0, -- радиус
        255, 255, 0, 200, -- желтый цвет
        0
    )
    
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

    -- Создаем новых пассажиров только на остановках с временем ожидания
    if stop.waitTime and stop.waitTime > 0 then
        createWaitingPassengers(stop.coords)
    end

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
                DrawMarker(
                    1,                                  -- Цилиндр
                    stop.coords.x, stop.coords.y, stop.coords.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    10.0, 10.0, 10.0, -- Большой размер
                    255, 255, 0, 150, -- Желтый цвет
                    true, false, 2, true, false, false, false
                )
                Wait(0)
            end
        end)
    end
end

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

    -- Обновление первой остановки (создаёт единственный блип)
    updateCurrentStop()

    -- Автоматический старт двигателя
    SetVehicleEngineOn(currentBus, true, true, false)
    
    -- Запуск основного игрового цикла ПЕРЕД установкой isWorking
    startMainLoop()
    
    -- Устанавливаем isWorking = true ПОСЛЕ запуска цикла
    isWorking = true

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
        DeleteVehicle(veh)
        print('^3[BUS JOB CLIENT] ^2Автобус удален клиентом (NetID: ' .. busNetId .. ')^0')
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    createJobNPC()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if jobNPC then
        DeletePed(jobNPC)
    end
    if jobBlip then
        RemoveBlip(jobBlip)
    end
    endWork()
end)

-- Основной поток
CreateThread(function()
    -- Дожидаемся, пока у ядра появится PlayerData (игрок загрузился)
    while not QBX or not QBX.PlayerData do
        Wait(500)
    end
    createJobNPC()
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
