local config = require 'config.server'
local sharedConfig = require 'config.shared'

-- Хранение данных игроков
local playerData = {}

-- Состояния игрока
local PlayerStates = {
    IDLE = 0,           -- Не работает
    WORKING = 1,        -- Работает
    COLLECTING = 2,     -- Собирает мусор
    GOING_TO_DUMP = 3,  -- Едет на свалку
    DUMPING = 4         -- Разгружается
}

-- Функция создания данных игрока
local function createPlayerData(src)
    if not src then return nil end

    playerData[src] = {
        working = false,
        state = PlayerStates.IDLE,
        truckNetId = nil,
        truckModel = nil,
        currentRoute = {},
        currentPoint = 1,
        garbageCollected = 0,
        maxCapacity = 10,
        earnings = 0,
        startTime = nil,
        lastActionTime = 0,
        pointsCompleted = 0,
        dumpsCompleted = 0,
        deposit = 0,
        lastCollectionTime = 0,
        collectionsThisMinute = 0,
        minuteStartTime = os.time()
    }

    if config.debug.enabled then
        logToConsole('Создание данных', string.format('Созданы данные для игрока %s [%d]', GetPlayerName(src), src))
    end

    return playerData[src]
end

-- Функция очистки данных игрока
local function clearPlayerData(src)
    if not src or not playerData[src] then return end

    if config.debug.enabled then
        logToConsole('Очистка данных', string.format('Очищены данные игрока %s [%d]', GetPlayerName(src), src))
    end

    playerData[src] = nil
end

-- Функция получения данных игрока
local function getPlayerData(src)
    if not src then return nil end
    return playerData[src]
end

-- Функция проверки работы игрока
local function isPlayerWorking(src)
    if not src or not playerData[src] then return false end
    return playerData[src].working == true
end

-- Функция обновления состояния игрока
local function updatePlayerState(src, newState)
    if not src or not playerData[src] then return false end

    local oldState = playerData[src].state
    playerData[src].state = newState

    if config.debug.enabled then
        logToConsole('Смена состояния', string.format('Игрок %s: %d -> %d', GetPlayerName(src), oldState, newState))
    end

    return true
end

-- Функция проверки расстояния (антифрод)
local function isPlayerNearLocation(src, coords, maxDistance)
    if not config.anticheat.enabled then return true end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local playerCoords = GetEntityCoords(ped)
    local distance = #(playerCoords - coords)

    return distance <= (maxDistance or config.anticheat.maxDistance)
end

-- Функция логирования
local function logToConsole(title, message)
    if not config.logging.enabled then return end

    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    print(string.format('^3[GARBAGE JOB] ^2[%s] ^5%s^0: %s', timestamp, title, message))
end

-- Функция генерации маршрута
local function generateRoute()
    local route = {}
    local availablePoints = {}

    -- Копируем все доступные точки
    for i, point in ipairs(sharedConfig.garbagePoints) do
        availablePoints[#availablePoints + 1] = {
            index = i,
            coords = point.coords,
            name = point.name,
            payment = point.payment
        }
    end

    -- Выбираем случайное количество точек для маршрута
    local routeSize = math.random(sharedConfig.settings.routeSize.min, sharedConfig.settings.routeSize.max)

    for i = 1, routeSize do
        if #availablePoints == 0 then break end

        local randomIndex = math.random(1, #availablePoints)
        table.insert(route, availablePoints[randomIndex])
        table.remove(availablePoints, randomIndex)
    end

    if config.debug.logRouteGeneration then
        logToConsole('Генерация маршрута', string.format('Создан маршрут из %d точек', #route))
    end

    return route
end

-- Функция завершения работы (универсальная)
local function finishGarbageJob(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not playerData[src] or not playerData[src].working then return end

    local data = playerData[src]

    -- Удаляем мусоровоз, если он ещё существует
    if data.truckNetId then
        local veh = NetworkGetEntityFromNetworkId(data.truckNetId)
        if DoesEntityExist(veh) then
            exports.qbx_vehiclekeys:RemoveKeys(src, veh, true)
            TriggerClientEvent('qbx_garbagejob:client:deleteVehicle', src, data.truckNetId)
            DeleteEntity(veh)
        end
    end

    -- Возврат залога (если есть)
    if data.deposit and data.deposit > 0 then
        player.Functions.AddMoney('cash', data.deposit, 'garbage-job-deposit-return')
        exports.qbx_core:Notify(src, string.format('Залог возвращен: $%d', data.deposit), 'success')
    end

    -- Итоговая статистика
    local workTime = os.time() - (data.startTime or os.time())
    local stats = string.format('Заработано: $%d | Время: %d мин | Точек: %d | Разгрузок: %d',
        data.earnings or 0,
        math.floor(workTime / 60),
        data.pointsCompleted or 0,
        data.dumpsCompleted or 0
    )

    exports.qbx_core:Notify(src, stats, 'info')

    if config.logging.enabled then
        logToConsole(
            'Завершение работы',
            string.format('Игрок %s завершил работу. %s', GetPlayerName(src), stats)
        )
    end

    -- Очистка данных
    clearPlayerData(src)

    -- Уведомление клиента
    TriggerClientEvent('qbx_garbagejob:client:endWork', src)
end

-- Обработка загрузки игрока
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    if not src then return end

    -- Очищаем старые данные если они есть
    if playerData[src] then
        clearPlayerData(src)
    end

    -- Создаем новые данные для игрока
    createPlayerData(src)

    if config.logging.enabled then
        logToConsole('Подключение игрока', string.format('Игрок %s [%d] подключился', GetPlayerName(src), src))
    end
end)

-- Обработка выгрузки игрока
RegisterNetEvent('QBCore:Server:OnPlayerUnload', function()
    local src = source
    if not src then return end

    if isPlayerWorking(src) then
        finishGarbageJob(src)
    else
        clearPlayerData(src)
    end

    if config.logging.enabled then
        logToConsole('Отключение игрока', string.format('Игрок %s [%d] отключился', GetPlayerName(src), src))
    end
end)

-- Очистка при выходе игрока
AddEventHandler('playerDropped', function(reason)
    local src = source
    if not src then return end

    if isPlayerWorking(src) then
        finishGarbageJob(src)
    else
        clearPlayerData(src)
    end

    if config.logging.enabled then
        logToConsole('Выход игрока', string.format('Игрок %s [%d] вышел: %s', GetPlayerName(src), src, reason or 'неизвестная причина'))
    end
end)

-- Очистка при перезапуске ресурса
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    print('^3[GARBAGE JOB] ^2Начинаем очистку ресурса...^0')

    local cleanupCount = 0
    for playerId, data in pairs(playerData) do
        if data.working and data.truckNetId then
            local player = exports.qbx_core:GetPlayer(playerId)
            local veh = NetworkGetEntityFromNetworkId(data.truckNetId)

            if DoesEntityExist(veh) then
                if player then
                    exports.qbx_vehiclekeys:RemoveKeys(playerId, veh, true)
                end

                TriggerClientEvent('qbx_garbagejob:client:deleteVehicle', playerId, data.truckNetId)
                DeleteEntity(veh)
                cleanupCount = cleanupCount + 1
            end

            if player then
                if data.deposit and data.deposit > 0 then
                    player.Functions.AddMoney('cash', data.deposit, 'garbage-job-deposit-return-resource-stop')
                    exports.qbx_core:Notify(playerId, string.format('Работа завершена. Залог возвращен: $%d', data.deposit), 'info')
                else
                    exports.qbx_core:Notify(playerId, 'Работа завершена из-за перезапуска ресурса', 'info')
                end

                TriggerClientEvent('qbx_garbagejob:client:endWork', playerId)
            end
        end
    end

    playerData = {}
    print(string.format('^3[GARBAGE JOB] ^1Ресурс остановлен. Удалено %d мусоровозов.^0', cleanupCount))
end)

-- Функция найма на работу
local function hirePlayer(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then
        exports.qbx_core:Notify(src, 'Ошибка получения данных игрока', 'error')
        return false
    end

    -- Проверяем существующие данные игрока
    if not playerData[src] then
        createPlayerData(src)
    end

    local data = playerData[src]

    -- Проверяем, не работает ли игрок уже мусорщиком
    if data.working then
        exports.qbx_core:Notify(src, 'Вы уже работаете мусорщиком!', 'error')
        return false
    end

    -- Проверяем текущую работу игрока
    local currentJob = player.PlayerData.job
    if currentJob and currentJob.name == config.job.name then
        exports.qbx_core:Notify(src, 'Вы уже числитесь мусорщиком!', 'error')
        return false
    end

    -- Устанавливаем работу через QBX Core
    player.Functions.SetJob(config.job.name, config.job.minGrade)

    -- Обновляем данные игрока
    data.working = true
    data.state = PlayerStates.WORKING
    data.startTime = os.time()
    data.earnings = 0
    data.pointsCompleted = 0
    data.dumpsCompleted = 0

    -- Логирование
    if config.logging.enabled then
        logToConsole('Найм на работу', string.format('Игрок %s [%d] устроился мусорщиком', GetPlayerName(src), src))
    end

    exports.qbx_core:Notify(src, 'Добро пожаловать в команду мусорщиков! Получите мусоровоз для начала работы.', 'success')

    -- Уведомляем клиента о начале работы
    TriggerClientEvent('qbx_garbagejob:client:startWork', src)

    return true
end

-- Функция увольнения с работы
local function firePlayer(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then
        exports.qbx_core:Notify(src, 'Ошибка получения данных игрока', 'error')
        return false
    end

    local data = playerData[src]
    if not data or not data.working then
        exports.qbx_core:Notify(src, 'Вы не работаете мусорщиком!', 'error')
        return false
    end

    -- Завершаем работу (это очистит мусоровоз и данные)
    finishGarbageJob(src)

    -- Сбрасываем работу на безработного
    player.Functions.SetJob('unemployed', 0)

    -- Логирование
    if config.logging.enabled then
        logToConsole('Увольнение', string.format('Игрок %s [%d] уволился с работы мусорщика', GetPlayerName(src), src))
    end

    exports.qbx_core:Notify(src, 'Вы уволились с работы мусорщика', 'info')

    return true
end

-- Обработчик события найма на работу
RegisterNetEvent('qbx_garbagejob:server:hirePlayer', function()
    local src = source
    if not src then return end
    hirePlayer(src)
end)

-- Обработчик события увольнения
RegisterNetEvent('qbx_garbagejob:server:firePlayer', function()
    local src = source
    if not src then return end
    firePlayer(src)
end)

-- Обработчик получения статуса работы
RegisterNetEvent('qbx_garbagejob:server:getJobStatus', function()
    local src = source
    if not src then return end
    local data = playerData[src]
    local working = data and data.working or false

    TriggerClientEvent('qbx_garbagejob:client:receiveJobStatus', src, working, data)
end)

-- Функция спавна мусоровоза
local function spawnGarbageTruck(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then
        exports.qbx_core:Notify(src, 'Ошибка получения данных игрока', 'error')
        return false
    end

    local data = playerData[src]
    if not data or not data.working then
        exports.qbx_core:Notify(src, 'Вы не работаете мусорщиком!', 'error')
        return false
    end

    -- Проверяем, нет ли уже мусоровоза
    if data.truckNetId then
        local existingVeh = NetworkGetEntityFromNetworkId(data.truckNetId)
        if DoesEntityExist(existingVeh) then
            exports.qbx_core:Notify(src, 'У вас уже есть мусоровоз!', 'error')
            return false
        else
            -- Очищаем старые данные если мусоровоз не существует
            data.truckNetId = nil
            data.truckModel = nil
        end
    end

    -- Выбираем случайную модель мусоровоза
    local truckConfig = sharedConfig.garbageTrucks[math.random(1, #sharedConfig.garbageTrucks)]
    local truckModel = truckConfig.model

    -- Выбираем случайную точку спавна
    local spawnLocation = sharedConfig.truckSpawnLocations[math.random(1, #sharedConfig.truckSpawnLocations)]

    -- Проверяем залог
    if sharedConfig.settings.requireDeposit and truckConfig.deposit > 0 then
        if player.Functions.GetMoney('cash') < truckConfig.deposit then
            exports.qbx_core:Notify(src, string.format('Недостаточно денег для залога: $%d', truckConfig.deposit), 'error')
            return false
        end

        player.Functions.RemoveMoney('cash', truckConfig.deposit, 'garbage-job-deposit')
        data.deposit = truckConfig.deposit
        exports.qbx_core:Notify(src, string.format('Внесен залог: $%d', truckConfig.deposit), 'info')
    end

    -- Обновляем данные игрока
    data.maxCapacity = truckConfig.capacity
    data.truckModel = truckModel

    -- Уведомляем клиента о спавне мусоровоза
    TriggerClientEvent('qbx_garbagejob:client:spawnTruck', src, {
        model = truckModel,
        coords = spawnLocation,
        label = truckConfig.label,
        capacity = truckConfig.capacity
    })

    -- Логирование
    if config.logging.enabled then
        logToConsole('Спавн мусоровоза', string.format('Игрок %s [%d] получил мусоровоз %s', GetPlayerName(src), src, truckConfig.label))
    end

    return true
end

-- Функция удаления мусоровоза
local function deleteTruck(src, forced)
    local data = playerData[src]
    if not data or not data.truckNetId then return false end

    local veh = NetworkGetEntityFromNetworkId(data.truckNetId)
    if DoesEntityExist(veh) then
        -- Удаляем ключи
        exports.qbx_vehiclekeys:RemoveKeys(src, veh, true)

        -- Уведомляем клиента об удалении
        TriggerClientEvent('qbx_garbagejob:client:deleteTruck', src, data.truckNetId)

        -- Удаляем мусоровоз
        DeleteEntity(veh)

        -- Логирование
        if config.logging.enabled then
            local reason = forced and 'принудительно' or 'по запросу'
            logToConsole('Удаление мусоровоза', string.format('Мусоровоз игрока %s [%d] удален %s', GetPlayerName(src), src, reason))
        end
    end

    -- Очищаем данные
    data.truckNetId = nil
    data.truckModel = nil

    return true
end

-- Обработчик успешного спавна мусоровоза (от клиента)
RegisterNetEvent('qbx_garbagejob:server:truckSpawned', function(netId)
    local src = source
    if not src then return end
    local data = playerData[src]

    if not data or not data.working then return end

    -- Сохраняем network ID мусоровоза
    data.truckNetId = netId

    -- Выдаем ключи от мусоровоза
    local veh = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(veh) then
        exports.qbx_vehiclekeys:GiveKeys(src, veh, true)

        -- Телепортируем игрока в кабину
        TriggerClientEvent('qbx_garbagejob:client:teleportToTruck', src, netId)

        exports.qbx_core:Notify(src, 'Мусоровоз готов к работе! Начинайте сбор мусора.', 'success')

        -- Генерируем первый маршрут
        data.currentRoute = generateRoute()
        data.currentPoint = 1
        data.garbageCollected = 0

        -- Отправляем маршрут клиенту
        TriggerClientEvent('qbx_garbagejob:client:receiveRoute', src, data.currentRoute, data.currentPoint)
    end
end)

-- Обработчик запроса мусоровоза
RegisterNetEvent('qbx_garbagejob:server:requestTruck', function()
    local src = source
    spawnGarbageTruck(src)
end)

-- Обработчик возврата мусоровоза
RegisterNetEvent('qbx_garbagejob:server:returnTruck', function()
    local src = source
    local data = playerData[src]

    if not data or not data.working or not data.truckNetId then
        exports.qbx_core:Notify(src, 'У вас нет мусоровоза для возврата!', 'error')
        return
    end

    -- Возвращаем залог если он был
    if data.deposit and data.deposit > 0 then
        local player = exports.qbx_core:GetPlayer(src)
        if player then
            player.Functions.AddMoney('cash', data.deposit, 'garbage-job-deposit-return')
            exports.qbx_core:Notify(src, string.format('Залог возвращен: $%d', data.deposit), 'success')
            data.deposit = 0
        end
    end

    -- Удаляем мусоровоз
    deleteTruck(src, false)

    exports.qbx_core:Notify(src, 'Мусоровоз возвращен', 'success')
end)

-- Экспорт функций для других ресурсов
exports('GetPlayerJobData', function(playerId)
    return getPlayerData(playerId)
end)

exports('IsPlayerWorking', function(playerId)
    return isPlayerWorking(playerId)
end)

exports('CreatePlayerData', function(playerId)
    return createPlayerData(playerId)
end)

exports('ClearPlayerData', function(playerId)
    return clearPlayerData(playerId)
end)

exports('UpdatePlayerState', function(playerId, newState)
    return updatePlayerState(playerId, newState)
end)