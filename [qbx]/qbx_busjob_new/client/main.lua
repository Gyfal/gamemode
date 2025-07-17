local config = require 'config.client'
local sharedConfig = require 'config.shared'
local serverConfig = require 'config.server'

-- Локальные переменные
local jobNPC = nil
local jobBlip = nil
local currentBus = nil
local currentStop = 1
local routeBlips = {}
local currentStopBlip = nil
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

-- Функции для работы с пассажирами
local function getRandomPassengerModel()
    local gender = math.random(1, 2) == 1 and 'male' or 'female'
    local models = sharedConfig.passengerModels[gender]
    return models[math.random(1, #models)]
end

local function getAvailableSeat()
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
        local targetStop = math.random(1, #sharedConfig.busRoute)
        while targetStop == currentStop do
            targetStop = math.random(1, #sharedConfig.busRoute)
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

local function boardPassengers()
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

local function alightPassengers()
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

local function clearAllPassengers()
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
                return not isWorking and QBX.PlayerData and QBX.PlayerData.job.name ~= serverConfig.job.name
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
                return not isWorking and QBX.PlayerData and QBX.PlayerData.job.name == serverConfig.job.name
            end,
            onSelect = function()
                openBusMenu()
            end
        },
        {
            name = 'busjob_quit',
            icon = 'fas fa-times',
            label = 'Уволиться',
            canInteract = function()
                return QBX.PlayerData and QBX.PlayerData.job.name == serverConfig.job.name
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
        AddTextComponentSubstringPlayerName(locale('npcConfig.blip.label'))
        EndTextCommandSetBlipName(jobBlip)
    end

    npcCreated = true
end

-- Меню выбора автобуса
function openBusMenu()
    local options = {}

    for i, bus in ipairs(sharedConfig.busModels) do
        options[#options + 1] = {
            title = bus.label,
            description = sharedConfig.settings.requireDeposit and ('Залог: $' .. bus.deposit) or 'Без залога',
            icon = 'bus',
            onSelect = function()
                TriggerServerEvent('qbx_busjob_new:server:requestBus', i)
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

-- Создание блипов маршрута
local function createRouteBlips()
    if not sharedConfig.settings.showBlips then return end

    for i, stop in ipairs(sharedConfig.busRoute) do
        local blip = AddBlipForCoord(stop.coords.x, stop.coords.y, stop.coords.z)
        SetBlipSprite(blip, 1)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.6)
        SetBlipColour(blip, 5)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(stop.name)
        EndTextCommandSetBlipName(blip)

        routeBlips[#routeBlips + 1] = blip
    end
end

-- Удаление блипов маршрута
local function removeRouteBlips()
    for _, blip in ipairs(routeBlips) do
        RemoveBlip(blip)
    end
    routeBlips = {}
end

-- Обновление текущей остановки
local function updateCurrentStop()
    -- Удаление старого блипа
    if currentStopBlip then
        RemoveBlip(currentStopBlip)
    end

    local stop = sharedConfig.busRoute[currentStop]
    if not stop then return end

    -- Очищаем предыдущих ожидающих пассажиров
    clearWaitingPassengers()

    -- Создаем новых пассажиров на остановке
    createWaitingPassengers(stop.coords)

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
    AddTextComponentSubstringPlayerName(stop.name)
    EndTextCommandSetBlipName(currentStopBlip)

    -- Уведомление с улучшенной информацией
    local passengerCount = #waitingPassengers
    local description = stop.name
    
    -- Добавляем описание остановки если есть
    if stop.description then
        description = description .. ' - ' .. stop.description
    end
    
    -- Добавляем информацию о пассажирах
    if passengerCount > 0 then
        description = description .. ' (' .. passengerCount .. ' пассажиров ожидают)'
    end
    
    -- Показываем ожидаемую оплату
    if stop.payment and stop.payment > 0 then
        description = description .. ' | Оплата: $' .. stop.payment
    end

    lib.notify({
        title = stop.isStartPoint and 'Начало маршрута' or (stop.isEndPoint and 'Финальная остановка' or 'Следующая остановка'),
        description = description,
        type = stop.isStartPoint and 'success' or (stop.isEndPoint and 'warning' or 'info'),
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

-- Проверка прибытия на остановку
local function checkBusStop()
    if not isWorking or not currentBus then return end

    local stop = sharedConfig.busRoute[currentStop]
    if not stop then return end

    local busCoords = GetEntityCoords(currentBus)
    local distance = #(busCoords - stop.coords)

    -- Отрисовка маркера
    if sharedConfig.settings.showMarkers and distance < 50.0 then
        DrawMarker(
            config.marker.type,
            stop.coords.x, stop.coords.y, stop.coords.z,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            config.marker.scale.x, config.marker.scale.y, config.marker.scale.z,
            config.marker.color.r, config.marker.color.g, config.marker.color.b, config.marker.color.a,
            config.marker.bobUpAndDown, false, 2, config.marker.rotate, false, false, false
        )
    end

    -- Проверка прибытия
    if distance < sharedConfig.settings.stopRadius then
        if GetGameTimer() - lastStopTime > 3000 then -- Защита от спама
            lastStopTime = GetGameTimer()

            -- Остановка автобуса
            SetVehicleHandbrake(currentBus, true)

            lib.notify({
                title = 'Остановка',
                description = 'Вы прибыли на остановку ' .. stop.name,
                type = 'success',
                position = config.notifications.position
            })

            -- Сначала высаживаем пассажиров
            alightPassengers()

            -- Ждем немного перед посадкой новых
            SetTimeout(2000, function()
                -- Затем садим новых пассажиров
                boardPassengers()
            end)

            -- Отправка на сервер для оплаты за остановку
            TriggerServerEvent('qbx_busjob_new:server:reachedStop', currentStop)

            -- Переход к следующей остановке
            SetTimeout(sharedConfig.passengerSettings.waitTime + 2000, function()
                SetVehicleHandbrake(currentBus, false)

                currentStop = currentStop + 1
                if currentStop > #sharedConfig.busRoute then
                    -- Завершение маршрута
                    currentStop = 1
                    TriggerServerEvent('qbx_busjob_new:server:completedRoute')

                    lib.notify({
                        title = 'Маршрут завершен',
                        description = 'Вы завершили полный круг! Заработано: $' .. totalEarnings,
                        type = 'success',
                        duration = 10000
                    })
                    totalEarnings = 0
                end

                updateCurrentStop()
            end)
        end
    end
end

-- Начало работы
RegisterNetEvent('qbx_busjob_new:client:startWork', function(busNetId, deposit)
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
    isWorking = true
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
    removeRouteBlips()
    if currentStopBlip then
        RemoveBlip(currentStopBlip)
        currentStopBlip = nil
    end

    currentBus = nil
    currentStop = 1
    isProcessingPassengers = false

    lib.notify({
        title = 'Работа завершена',
        description = 'Вы закончили работу',
        type = 'info'
    })
end

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

    -- Запуск игрового цикла один раз
    if not mainLoopActive then
        mainLoopActive = true
        CreateThread(function()
            while isWorking do
                -- Проверка прибытия на остановку
                checkBusStop()

                -- Контроль выхода из автобуса
                if currentBus and DoesEntityExist(currentBus) then
                    if IsPedInVehicle(cache.ped, currentBus, false) then
                        if leaveStartTime then
                            leaveStartTime = nil
                            lib.notify({ title = 'Возврат в автобус', description = 'Маршрут продолжен', type = 'success', duration = 3000, position =
                            config.notifications.position })
                        end
                    else
                        if not leaveStartTime then
                            leaveStartTime = GetGameTimer()
                            lib.notify({ title = 'Вы покинули автобус', description = ('Вернитесь в течение %d секунд или будете уволены')
                            :format(math.floor(leaveTimeout / 1000)), type = 'warning', duration = leaveTimeout, position =
                            config.notifications.position })
                        elseif GetGameTimer() - leaveStartTime >= leaveTimeout then
                            leaveStartTime = nil
                            lib.notify({ title = 'Вы уволены', description = 'Вы слишком долго были вне автобуса', type =
                            'error', duration = 5000, position = config.notifications.position })
                            TriggerServerEvent('qbx_busjob_new:server:endWork')
                        end
                    end
                end

                -- Проверка удержания X для отмены работы
                if IsControlJustPressed(0, config.keys.cancelJob) then
                    lib.notify({ title = 'Отмена работы', description = 'Удерживайте X чтобы отменить работу', type =
                    'warning' })
                    local holdStart = GetGameTimer()
                    while IsControlPressed(0, config.keys.cancelJob) do
                        Wait(0)
                        if GetGameTimer() - holdStart > 3000 then
                            TriggerServerEvent('qbx_busjob_new:server:endWork')
                            break
                        end
                    end
                end

                Wait(0)
            end
            mainLoopActive = false -- выход из цикла после окончания работы
        end)
    end
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

    -- Если работаем - завершаем работу
    if isWorking then
        endWork()
    end
end)
