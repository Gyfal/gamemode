local config = require 'config.client'
local sharedConfig = require 'config.shared'

-- ===========================
-- СИСТЕМА AI-АВТОБУСОВ
-- ===========================

-- Переменные для AI-автобусов
local aiBuses = {} -- Таблица AI-автобусов {[vehicleNetId] = driverNetId}
local aiBusinesses = {} -- Локальное отслеживание AI-автобусов
local controlledAIBuses = {} -- AI-автобусы под управлением этого клиента
local aiBusBlips = {} -- Блипы AI-автобусов
local aiBusRouteData = {} -- Хранилище данных маршрутов AI-автобусов

-- Экспортируем функции для использования в main.lua
local exports = {}

-- Вспомогательные функции для отрисовки 3D текста
local function drawBusRouteName(coords, routeName)
    qbx.drawText3d({
        coords = coords + vector3(0.0, 0.0, 3.5),
        text = routeName,
        scale = 0.5,
        font = 4,
        color = vec4(255, 255, 0, 255), -- Желтый цвет
        enableOutline = true,
        disableDrawRect = true
    })
end

local function drawBusStopInfo(coords, stopInfo)
    qbx.drawText3d({
        coords = coords + vector3(0.0, 0.0, 3.0),
        text = stopInfo,
        scale = 0.4,
        font = 4,
        color = vec4(255, 255, 255, 255), -- Белый цвет
        enableOutline = true,
        disableDrawRect = true
    })
end

-- Функция для получения названия следующей остановки для AI-автобуса
local function getAIBusNextStopText(route, currentStopIndex)
    if not route or not currentStopIndex then return "В пути" end
    
    -- Ищем следующую остановку с waitTime
    local nextStopFound = false
    local nextStopText = "В пути"
    print(string.format("[AI Bus] Текущий индекс остановки: %d, всего остановок: %d", currentStopIndex, #route.stops))
    
    -- Сначала ищем от текущей позиции до конца
    for i = currentStopIndex, #route.stops do
        local stop = route.stops[i]
        if stop and stop.waitTime and stop.waitTime > 0 then
            nextStopText = "Следует к: " .. (stop.stopName or "Остановка")
            nextStopFound = true
            break
        end
    end
    
    -- Если не нашли, ищем с начала (кольцевой маршрут)
    if not nextStopFound then
        for i = 1, currentStopIndex do
            local stop = route.stops[i]
            if stop.waitTime and stop.waitTime > 0 then
                nextStopText = "Следует к: " .. (stop.stopName or "Остановка")
                break
            end
        end
    end
    
    return nextStopText
end

-- Функция для управления AI-автобусом
local function driveAIBus(data)
    local vehicle = NetworkGetEntityFromNetworkId(data.vehicleNetId)
    local driver = NetworkGetEntityFromNetworkId(data.driverNetId)
    
    if not DoesEntityExist(vehicle) or not DoesEntityExist(driver) then
        return
    end
    
    local route = sharedConfig.busRoutes[data.routeId]
    if not route then return end
    
    -- Запрашиваем контроль над сущностями
    print(NetworkRequestControlOfNetworkId(data.vehicleNetId), data.vehicleNetId, "RequestControlOfNetworkId vehicleNetId")
    print(NetworkRequestControlOfNetworkId(data.driverNetId), "RequestControlOfNetworkId driverNetId")
    
    -- Ждем получения контроля
    local timeout = 0
    while not NetworkHasControlOfNetworkId(data.vehicleNetId) or not NetworkHasControlOfNetworkId(data.driverNetId) do
        Wait(100)
        timeout = timeout + 1
        if timeout > 50 then -- 5 секунд
            return
        end
    end
    
    -- Загружаем коллизии
    SetEntityLoadCollisionFlag(vehicle, true, 1)
    SetEntityLoadCollisionFlag(driver, true, 1)
    while not HasCollisionLoadedAroundEntity(vehicle) or not HasCollisionLoadedAroundEntity(driver) do
        Wait(0)
    end
    
    -- Настройка неуязвимости автобуса и водителя
    SetEntityInvincible(vehicle, true)
    SetEntityInvincible(driver, true)
    SetEntityCanBeDamaged(vehicle, false)
    SetEntityCanBeDamaged(driver, false)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetPedCanBeTargetted(driver, false)
    SetDriverAbility(driver, 1.0)
    SetDriverAggressiveness(driver, 0.0)
    SetBlockingOfNonTemporaryEvents(driver, true)
    
    -- Добавляем проверку на застревание
    if not DoesVehicleHaveStuckVehicleCheck(vehicle) then
        AddVehicleStuckCheckWithWarp(vehicle, 10.0, 1000, false, false, false, -1)
    end
    
    -- Сохраняем данные для отслеживания
    controlledAIBuses[data.busId] = {
        vehicle = vehicle,
        driver = driver,
        routeId = data.routeId,
        currentStopIndex = data.currentStopIndex,
        busId = data.busId,
        isActive = true
    }
    
    -- Основной цикл вождения
    CreateThread(function()
        local busData = controlledAIBuses[data.busId]
        
        while busData and busData.isActive and DoesEntityExist(vehicle) and DoesEntityExist(driver) do
            -- Обработка специального случая когда автобус едет от спавна к маршруту
            if busData.currentStopIndex == 0 then
                -- Автобус должен ехать к первой остановке маршрута
                local firstStop = route.stops[1]
                if not firstStop then
                    print("[AI Bus] Ошибка: первая остановка не найдена в маршруте")
                    break
                end
                
                local targetCoords = vector3(firstStop.coords.x, firstStop.coords.y, firstStop.coords.z)
                -- print(string.format("[AI Bus] Движение от спавна к первой остановке маршрута: %f, %f, %f", targetCoords.x, targetCoords.y, targetCoords.z))
                
                ClearPedTasks(driver)
                SetVehicleOnGroundProperly(vehicle)
                TaskVehicleDriveToCoordLongrange(
                    driver,
                    vehicle,
                    firstStop.coords.x,
                    firstStop.coords.y,
                    firstStop.coords.z,
                    sharedConfig.aiBusinessSettings.averageSpeed * 3.6,
                    262144 + 2048 + 512 + 256 + 32 + 16 + 8 + 4,
                    10.0
                )
                
                -- Ждем пока автобус доедет
                while busData.isActive and DoesEntityExist(vehicle) and DoesEntityExist(driver) do
                    local vehPos = GetEntityCoords(vehicle)
                    local distance = #(vehPos - targetCoords)
                    
                    if distance < 15.0 then
                        -- Достигли целевой остановки с сервера, используем переданный индекс
                        local targetStopIndex = data.targetStopIndex or 1
                        busData.currentStopIndex = targetStopIndex
                        -- print("[AI Bus] Достигли целевой остановки " .. targetStopIndex .. ", начинаем обычный маршрут")
                        
                        -- Обновляем позицию на сервере
                        TriggerServerEvent('qbx_busjob_new:server:updateAIBusPosition', 
                            busData.routeId, 
                            busData.busId, 
                            targetStopIndex, -- Используем целевой индекс с сервера
                            targetCoords
                        )
                        break
                    end
                    
                    Wait(1000)
                end
            else
                -- Обычная логика движения по маршруту
                local currentStop = route.stops[busData.currentStopIndex]
                if not currentStop then 
                    print(string.format("[AI Bus] Ошибка: остановка %d не найдена в маршруте %d", busData.currentStopIndex, busData.routeId))
                    break 
                end
                
                -- Устанавливаем задачу движения к следующей точке
                local targetCoords = vector3(currentStop.coords.x, currentStop.coords.y, currentStop.coords.z)
                print(string.format("[AI Bus] Движение к остановке %d: %f, %f, %f", busData.currentStopIndex, targetCoords.x, targetCoords.y, targetCoords.z))
                
                ClearPedTasks(driver) -- Очищаем старые задачи
                SetVehicleOnGroundProperly(vehicle) -- Убеждаемся что автобус на земле
                TaskVehicleDriveToCoordLongrange(
                    driver,
                    vehicle,
                    currentStop.coords.x,
                    currentStop.coords.y,
                    currentStop.coords.z,
                    sharedConfig.aiBusinessSettings.averageSpeed * 3.6, -- Конвертируем м/с в км/ч
                    sharedConfig.aiBusinessSettings.driveStyle,
                    10.0
                )
            
                -- Ждем пока автобус движется
                while DoesEntityExist(vehicle) and busData.isActive do
                    local currentPos = GetEntityCoords(vehicle)
                    local distanceToStop = #(currentPos - currentStop.coords)
                    
                    -- Проверяем достигли ли остановки
                    if distanceToStop < 15.0 then
                        -- Если это остановка с ожиданием
                        if currentStop.waitTime and currentStop.waitTime > 0 then
                            -- Останавливаем автобус
                            TaskVehicleTempAction(driver, vehicle, 27, 1000)
                            Wait(currentStop.waitTime)
                        end
                        
                        -- Переходим к следующей точке
                        busData.currentStopIndex = busData.currentStopIndex + 1
                        if busData.currentStopIndex > #route.stops then
                            busData.currentStopIndex = 0
                        end
                        
                        -- Обновляем позицию на сервере
                        TriggerServerEvent('qbx_busjob_new:server:updateAIBusPosition', 
                            busData.routeId, 
                            busData.busId, 
                            busData.currentStopIndex,
                            currentPos
                        )
                        
                        break
                    end
                    
                    -- Проверка на застревание (как в publictransport)
                    if IsVehicleStuckTimerUp(vehicle, 0, 10000) or IsVehicleStuckTimerUp(vehicle, 1, 10000) or 
                       IsVehicleStuckTimerUp(vehicle, 2, 10000) or IsVehicleStuckTimerUp(vehicle, 3, 10000) then
                        SetEntityCollision(vehicle, false, true)
                        local vehPos = GetEntityCoords(vehicle)
                        local ret, outPos = GetPointOnRoadSide(vehPos.x, vehPos.y, vehPos.z, -1)
                        if ret then
                            local ret2, pos, heading = GetClosestVehicleNodeWithHeading(outPos.x, outPos.y, outPos.z, 1, 3.0, 0)
                            if ret2 then
                                SetEntityCoords(vehicle, pos.x, pos.y, pos.z)
                                SetEntityHeading(vehicle, heading)
                                SetEntityCollision(vehicle, true, true)
                                SetVehicleOnGroundProperly(vehicle)
                            end
                        end
                    end
                    
                    Wait(100)
                end
            end -- Закрываем блок else (обычная логика движения)
        end
        
        -- Очищаем данные когда автобус больше не под контролем
        if controlledAIBuses[data.busId] then
            controlledAIBuses[data.busId] = nil
        end
    end)
end

-- Обновление всех блипов AI-автобусов одним пакетом
RegisterNetEvent('qbx_busjob_new:client:updateAllAIBusBlips')
AddEventHandler('qbx_busjob_new:client:updateAllAIBusBlips', function(aiBusUpdates)
    if not aiBusUpdates then return end
    
    -- Обрабатываем все обновления из массива
    for _, busData in ipairs(aiBusUpdates) do
        if busData.position then
            -- Сохраняем данные автобуса
            aiBusRouteData[busData.id] = {
                routeId = busData.routeId,
                currentStopIndex = busData.currentStopIndex,
                status = busData.status or 'Работает',
                vehicleNetId = busData.vehicleNetId -- Сохраняем NetId если есть
            }
            
            local blip = aiBusBlips[busData.id]
            if blip and DoesBlipExist(blip) then
                -- Обновляем позицию существующего блипа
                SetBlipCoords(blip, busData.position.x, busData.position.y, busData.position.z)
            else
                -- Создаем новый блип если его нет
                blip = AddBlipForCoord(busData.position.x, busData.position.y, busData.position.z)
                SetBlipSprite(blip, sharedConfig.aiBusinessSettings.blipSprite)
                SetBlipColour(blip, sharedConfig.aiBusinessSettings.blipColor)
                SetBlipScale(blip, sharedConfig.aiBusinessSettings.blipScale)
                SetBlipAlpha(blip, sharedConfig.aiBusinessSettings.blipAlpha)
                SetBlipAsShortRange(blip, true)
                
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName('AI Автобус')
                EndTextCommandSetBlipName(blip)
                
                aiBusBlips[busData.id] = blip
            end
        end
    end
end)

-- Поток для отображения 3D текста над AI-автобусами
CreateThread(function()
    while true do
        local playerPed = cache.ped
        local playerCoords = GetEntityCoords(playerPed)
        local showText = false
        
        -- Проверяем все AI-автобусы в радиусе видимости
        for busId, blip in pairs(aiBusBlips) do
            if DoesBlipExist(blip) then
                local busCoords = GetBlipCoords(blip)
                local distance = #(playerCoords - busCoords)
                
                if distance <= 100.0 then -- В радиусе 50 метров показываем 3D текст
                    showText = true
                    
                    -- Получаем данные автобуса
                    local busData = aiBusRouteData[busId]
                    
                    -- Получаем автобус через NetId из сохраненных данных
                    local vehicle = nil
                    if busData and busData.vehicleNetId then
                        vehicle = NetworkGetEntityFromNetworkId(busData.vehicleNetId)
                    end
                    
                    if vehicle and DoesEntityExist(vehicle) then
                        local actualCoords = GetEntityCoords(vehicle)
                        if busData and sharedConfig.busRoutes[busData.routeId] then
                            
                            local routeData = sharedConfig.busRoutes[busData.routeId]
                            -- Отображаем название маршрута
                            drawBusRouteName(actualCoords, routeData.name)

                            -- print(string.format("[AI Bus] Отображение информации для автобуса %d на маршруте %s на остановке %d", busId, routeData.name, busData.currentStopIndex))
                            -- Получаем текст следующей остановки
                            local nextStopText = getAIBusNextStopText(routeData, busData.currentStopIndex)
                            
                            drawBusStopInfo(actualCoords, nextStopText)
                        end
                    end
                end
            end
        end
        
        -- Если текст показывается, обновляем чаще, иначе реже
        Wait(showText and 1 or 1000)
    end
end)

-- Событие для начала управления AI-автобусом
RegisterNetEvent('qbx_busjob_new:client:controlAIBus', function(data)
    driveAIBus(data)
end)

-- Функция очистки всех AI-автобусов
function exports.cleanupAllAIBuses()
    -- Очищаем контролируемые автобусы
    for busId, busData in pairs(controlledAIBuses) do
        busData.isActive = false
    end
    controlledAIBuses = {}
    
    -- Очищаем блипы
    for busId, blip in pairs(aiBusBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    aiBusBlips = {}
end

-- Регистрация AI-автобуса для контроля доступа к водительскому месту
RegisterNetEvent('qbx_busjob_new:client:registerAIBus')
AddEventHandler('qbx_busjob_new:client:registerAIBus', function(vehicleNetId, driverNetId)
    print("qbx_busjob_new:client:registerAIBus",vehicleNetId, "registerAIBus vehicleNetId", driverNetId, "registerAIBus driverNetId")
    if not vehicleNetId then return end
    local vehicle = lib.waitFor(function()
        if NetworkDoesEntityExistWithNetworkId(vehicleNetId) then
            return NetToVeh(vehicleNetId)
        end
    end)
    
    if not vehicle then return end
    
    print(vehicleNetId, "CREATE vehicleNetId", driverNetId, "driverNetId")
    aiBuses[vehicleNetId] = driverNetId
end)

-- Отмена регистрации AI-автобуса
RegisterNetEvent('qbx_busjob_new:client:unregisterAIBus')
AddEventHandler('qbx_busjob_new:client:unregisterAIBus', function(vehicleNetId)
    if not vehicleNetId then return end
    aiBuses[vehicleNetId] = nil
end)

local isNotifed = false

-- Простая система контроля AI автобусов
CreateThread(function()
    while true do
        Wait(100)
                
        local currentVehicle = cache.vehicle
        if currentVehicle then
            local vehicleNetId = NetworkGetNetworkIdFromEntity(currentVehicle)
            if aiBuses[vehicleNetId] and cache.seat == -1 then
                TaskLeaveVehicle(cache.ped, currentVehicle, 0)
                if not isNotifed then
                    lib.notify({
                        title = 'Доступ запрещен',
                        description = 'Вы не можете находиться на водительском месте AI автобуса',
                        type = 'error'
                    })

                    return
                end

                isNotifed = true
                return
            end
        end

        isNotifed = false
    end
end)

-- Основной поток инициализации
CreateThread(function()
    -- Дожидаемся, пока у ядра появится PlayerData (игрок загрузился)
    while not QBX or not QBX.PlayerData do
        Wait(500)
    end
    
    -- Загружаем модель водителя AI-автобуса
    if sharedConfig.aiBusinessSettings.enabled then
        RequestModel(sharedConfig.aiBusinessSettings.driverModel)
        while not HasModelLoaded(sharedConfig.aiBusinessSettings.driverModel) do
            Wait(10)
        end
    end
end)

-- Очистка при остановке ресурса
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Очистка AI-автобусов
    exports.cleanupAllAIBuses()
end)

-- Возвращаем экспортируемые функции
return exports