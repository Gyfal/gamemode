local config = require 'config.server'
local sharedConfig = require 'config.shared'

-- Хранение данных игроков
local playerData = {}

-- Счетчик автобусов на маршрутах
local routeBusCount = {}

-- Система кэширования видимости автобусов
local busVisibility = {} -- [busNetId] = { visibleTo = {[playerId] = lastSentData}, lastUpdate = timestamp }

-- Текущий лимит автобусов на маршруте (можно изменить через админ команду)
local maxBusesPerRoute = sharedConfig.settings.maxBusesPerRoute

-- Централизованные функции управления счетчиками маршрутов
local function incrementRouteBusCount(routeId)
    if not routeId then return false end
    
    if not routeBusCount[routeId] then
        routeBusCount[routeId] = 0
    end
    
    routeBusCount[routeId] = routeBusCount[routeId] + 1
    
    if config.logging.enabled then
        logToConsole(
            'Счетчик маршрута',
            ('Маршрут %d: +1 автобус (всего: %d)'):format(routeId, routeBusCount[routeId])
        )
    end
    
    return true
end

local function decrementRouteBusCount(routeId)
    if not routeId then return false end
    
    if not routeBusCount[routeId] then
        routeBusCount[routeId] = 0
        return false
    end
    
    routeBusCount[routeId] = math.max(0, routeBusCount[routeId] - 1)
    
    if config.logging.enabled then
        logToConsole(
            'Счетчик маршрута',
            ('Маршрут %d: -1 автобус (всего: %d)'):format(routeId, routeBusCount[routeId])
        )
    end
    
    return true
end

local function getRouteBusCount(routeId)
    if not routeId then return 0 end
    return routeBusCount[routeId] or 0
end


local function validateRouteBusCount()
    for routeId, count in pairs(routeBusCount) do
        if count < 0 then
            routeBusCount[routeId] = 0
            if config.logging.enabled then
                logToConsole('Валидация счетчика', ('Исправлен отрицательный счетчик маршрута %d'):format(routeId))
            end
        end
    end
end


-- Функция проверки расстояния (антифрод)
local function isPlayerNearLocation(src, coords, maxDistance)
    if not config.anticheat.enabled then return true end

    local ped = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(ped)
    local distance = #(vector3(playerCoords.x, playerCoords.y, playerCoords.z) - vector3(coords.x, coords.y, coords.z))

    return distance <= (maxDistance or config.anticheat.maxDistance)
end

-- Функция логирования
function logToConsole(title, message)
    if not config.logging.enabled then return end

    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    print(string.format('^3[BUS JOB] ^2[%s] ^5%s^0: %s', timestamp, title, message))
end

-- Функция для получения ID следующей остановки
local function getNextStopId(route, currentStopId)
    if not route or not route.stops then return 0 end
    
    -- Ищем следующую остановку с waitTime
    for i = currentStopId, #route.stops do
        local stop = route.stops[i]
        if stop.waitTime and stop.waitTime > 0 then
            return i
        end
    end
    
    -- Если не нашли впереди, ищем с начала (кольцевой маршрут)
    for i = 1, currentStopId - 1 do
        local stop = route.stops[i]
        if stop.waitTime and stop.waitTime > 0 then
            return i
        end
    end
    
    return 0
end

-- Функция завершения работы (универсальная)
local function finishBusJob(src)
    local player = exports.qbx_core:GetPlayer(src)
    print('finishBusJob', player, playerData[src] and playerData[src].working)
    if not player or not playerData[src] or not playerData[src].working then return end

    local data = playerData[src]
    
    -- Уменьшаем счетчик маршрута
    if data.currentRoute then
        decrementRouteBusCount(data.currentRoute.id)
    end

    -- Удаляем автобус, если он ещё существует
    if data.busNetId then
        local veh = NetworkGetEntityFromNetworkId(data.busNetId)
        print('veh', veh, data.busNetId, DoesEntityExist(veh))
        if DoesEntityExist(veh) then
            exports.qbx_vehiclekeys:RemoveKeys(src, veh, true)
            TriggerClientEvent('qbx_busjob_new:client:deleteVehicle', src, data.busNetId)
            DeleteEntity(veh)
        end
        
        -- Очищаем видимость автобуса
        cleanupBusVisibility(data.busNetId)
        
        -- Очищаем пассажиров автобуса
        clearAllServerPassengers(data.busNetId)
    end

    -- Возврат залога
    if data.deposit and data.deposit > 0 then
        player.Functions.AddMoney('cash', data.deposit, 'bus-job-deposit-return')
        lib.notify(src, {
            title = 'Залог возвращен',
            description = ('$%d'):format(data.deposit),
            type = 'success'
        })
    end

    -- Итоговая статистика
    local workTime = os.time() - (data.startTime or os.time())
    lib.notify(src, {
        title = 'Заработано за смену',
        description = ('$%d'):format(data.earnings or 0),
        type = 'info'
    })

    if config.logging.enabled then
        logToConsole(
            'Завершение работы',
            ('Игрок %s завершил работу. Заработано: $%d, Время: %d мин'):format(
                GetPlayerName(src),
                data.earnings or 0,
                math.floor(workTime / 60)
            )
        )
    end

    -- Очистка данных
    playerData[src] = nil

    -- Уведомление клиента
    TriggerClientEvent('qbx_busjob_new:client:endWork', src)
end

-- Устройство на работу
RegisterNetEvent('qbx_busjob_new:server:startJob', function()
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    -- Проверка, не работает ли уже игрок
    if player.PlayerData.job.name == config.job.name then
        lib.notify(src, {
            title = 'Ошибка',
            description = 'Вы уже работаете водителем автобуса!',
            type = 'error'
        })
        return
    end

    -- Проверяем расстояние до NPC
    if not isPlayerNearLocation(src, sharedConfig.jobNPC.coords.xyz, 50.0) then
        lib.notify(src, {
            title = 'Ошибка',
            description = 'Вы слишком далеко от NPC!',
            type = 'error'
        })
        return
    end

    -- Устанавливаем работу
    player.Functions.SetJob(config.job.name, config.job.minGrade)
    lib.notify(src, {
        title = 'Трудоустройство',
        description = 'Вы устроились водителем автобуса! Теперь вы можете взять автобус.',
        type = 'success'
    })

    if config.logging.enabled then
        logToConsole(
            'Устройство на работу',
            ('Игрок %s (ID: %s) устроился водителем автобуса'):format(GetPlayerName(src), src)
        )
    end
end)

-- Увольнение с работы
RegisterNetEvent('qbx_busjob_new:server:quitJob', function()
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    if player.PlayerData.job.name ~= config.job.name then
        lib.notify(src, {
            title = 'Ошибка',
            description = 'Вы не работаете водителем автобуса!',
            type = 'error'
        })
        return
    end

    -- Завершаем работу и очищаем
    finishBusJob(src)

    -- Сброс работы
    player.Functions.SetJob('unemployed', 0)
    lib.notify(src, {
        title = 'Увольнение',
        description = 'Вы уволились с работы!',
        type = 'info'
    })
end)

-- Запрос автобуса
RegisterNetEvent('qbx_busjob_new:server:requestBus', function(busIndex, routeId)
    local src = source
    if not src then return end
    local player = exports.qbx_core:GetPlayer(src)

    if not player then return end

    -- Проверки
    if player.PlayerData.job.name ~= config.job.name then
        lib.notify(src, {
            title = 'Ошибка',
            description = 'Вы не работаете водителем автобуса!',
            type = 'error'
        })
        return
    end

    if playerData[src] and playerData[src].working then
        lib.notify(src, {
            title = 'Ошибка',
            description = 'Вы уже работаете!',
            type = 'error'
        })
        return
    end

    local busConfig = sharedConfig.busModels[busIndex]
    if not busConfig then
        lib.notify(src, {
            title = 'Ошибка',
            description = 'Неверный выбор автобуса!',
            type = 'error'
        })
        return
    end

    -- Проверка залога
    local deposit = 0
    if sharedConfig.settings.requireDeposit then
        deposit = busConfig.deposit
        if player.PlayerData.money.cash < deposit then
            lib.notify(src, {
                title = 'Ошибка',
                description = 'У вас недостаточно наличных для залога!',
                type = 'error'
            })
            return
        end

        -- Снятие залога
        player.Functions.RemoveMoney('cash', deposit, 'bus-job-deposit')
    end

    -- Выбор случайной координаты спавна
    local spawnLocation = sharedConfig.busSpawnLocations[math.random(1, #sharedConfig.busSpawnLocations)]

    -- Проверка расстояния от NPC (более логично, чем от места спавна)
    if not isPlayerNearLocation(src, sharedConfig.jobNPC.coords.xyz, 50.0) then
        lib.notify(src, {
            title = 'Ошибка',
            description = 'Вы слишком далеко от NPC!',
            type = 'error'
        })
        return
    end

    -- Спавн автобуса в случайном месте
    local netId = qbx.spawnVehicle({
        model = busConfig.model,
        spawnSource = spawnLocation,
        warp = false -- Отключаем автоматическую телепортацию для более надежного контроля
    })

    if not netId or netId == 0 then
        lib.notify(src, {
            title = 'Ошибка',
            description = 'Не удалось создать автобус!',
            type = 'error'
        })
        if deposit > 0 then
            player.Functions.AddMoney('cash', deposit, 'bus-job-deposit-return')
        end
        return
    end

    -- Выдача ключей
    local plate = 'BUS' .. math.random(1000, 9999)
    local veh = NetworkGetEntityFromNetworkId(netId)
    SetVehicleNumberPlateText(veh, plate)
    exports.qbx_vehiclekeys:GiveKeys(src, veh) -- Передаем сущность автомобиля, а не номер

    -- Установка игрока владельцем транспорта для синхронизации
    SetVehicleDoorsLocked(veh, 1) -- Разблокировать двери

    -- Немедленная телепортация игрока к автобусу и посадка
    local ped = GetPlayerPed(src)
    SetEntityCoords(ped, spawnLocation.x, spawnLocation.y, spawnLocation.z + 1.0, false, false, false, true)
    Wait(100)                       -- Небольшая задержка для синхронизации
    SetPedIntoVehicle(ped, veh, -1) -- -1 = водительское место

    -- Уведомление о готовности
    lib.notify(src, {
        title = 'Автобус готов',
        description = 'Следуйте к первой остановке',
        type = 'success'
    })

    -- Валидация и проверка маршрута
    if not routeId or type(routeId) ~= 'number' then
        lib.notify(src, {
            title = 'Ошибка',
            description = 'Неверный ID маршрута!',
            type = 'error'
        })
        if deposit > 0 then
            player.Functions.AddMoney('cash', deposit, 'bus-job-deposit-return')
        end
        return
    end

    local selectedRoute = nil
    for _, route in ipairs(sharedConfig.busRoutes) do
        if route.id == routeId then
            selectedRoute = route
            break
        end
    end

    if not selectedRoute then
        lib.notify(src, {
            title = 'Ошибка',
            description = 'Маршрут не найден!',
            type = 'error'
        })
        if deposit > 0 then
            player.Functions.AddMoney('cash', deposit, 'bus-job-deposit-return')
        end
        return
    end

    -- Дополнительная валидация маршрута
    if not selectedRoute.stops or #selectedRoute.stops == 0 then
        lib.notify(src, {
            title = 'Ошибка',
            description = 'Маршрут не содержит остановок!',
            type = 'error'
        })
        if deposit > 0 then
            player.Functions.AddMoney('cash', deposit, 'bus-job-deposit-return')
        end
        return
    end

    -- Проверка доступности маршрута
    if getRouteBusCount(selectedRoute.id) >= maxBusesPerRoute then
        lib.notify(src, {
            title = 'Маршрут занят',
            description = 'На этом маршруте уже максимальное количество автобусов!',
            type = 'error'
        })
        if deposit > 0 then
            player.Functions.AddMoney('cash', deposit, 'bus-job-deposit-return')
        end
        return
    end
    
    -- Увеличиваем счетчик маршрута
    incrementRouteBusCount(selectedRoute.id)

    -- Вычисляем ID следующей остановки
    local nextStopId = getNextStopId(selectedRoute, 1)
    
    -- Сохранение данных игрока
    playerData[src] = {
        working = true,
        busNetId = netId,
        deposit = deposit,
        currentStop = 1,
        currentRoute = selectedRoute,
        lastStopTime = os.time(),
        earnings = 0,
        startTime = os.time(),
        spawnLocation = spawnLocation, -- Сохраняем координаты спавна для дебага
        nextStopId = nextStopId -- Добавляем ID следующей остановки для синхронизации
    }

    -- Отправка данных клиенту
    TriggerClientEvent('qbx_busjob_new:client:startWork', src, netId, deposit, routeId)
    
    -- Новая система автоматически подхватит автобус в периодическом потоке

    if config.logging.enabled then
        logToConsole(
            'Начало работы',
            ('Игрок %s начал работу. Автобус: %s, Маршрут: %s, Залог: $%d'):format(
                GetPlayerName(src), busConfig.label, selectedRoute.name, deposit)
        )
    end
end)

-- Команда для дебага координат спавна автобусов (только для администраторов)
if config.debug and config.debug.enabled then
    lib.addCommand('busspawns', {
        help = 'Показать все координаты спавна автобусов',
        restricted = 'group.admin'
    }, function(source)
        local src = source
        print(string.format("^2[BUS DEBUG] Координаты спавна автобусов для игрока %s [%d]:^0", GetPlayerName(src), src))

        for i, location in ipairs(sharedConfig.busSpawnLocations) do
            print(string.format("^3Спавн %d: X: %.2f, Y: %.2f, Z: %.2f, H: %.2f^0",
                i, location.x, location.y, location.z, location.w))
        end

        -- Отправка сообщения игроку в чат
        TriggerClientEvent('chat:addMessage', src, {
            color = { 0, 255, 0 },
            multiline = true,
            args = { "[BUS DEBUG]", string.format("Найдено %d координат спавна автобусов (см. консоль сервера)", #sharedConfig.busSpawnLocations) }
        })

        -- Если игрок сейчас работает, показать где был заспавнен его автобус
        if playerData[src] and playerData[src].working and playerData[src].spawnLocation then
            local spawnLoc = playerData[src].spawnLocation
            TriggerClientEvent('chat:addMessage', src, {
                color = { 255, 255, 0 },
                args = { "[BUS DEBUG]", string.format("Ваш текущий автобус заспавнен на: %.1f, %.1f, %.1f",
                    spawnLoc.x, spawnLoc.y, spawnLoc.z) }
            })
        end
    end)
end

-- Административные команды для управления счетчиками маршрутов
lib.addCommand('busroutes', {
    help = 'Показать статистику маршрутов автобусов',
    restricted = 'group.admin'
}, function(source)
    print(string.format("^2[BUS ADMIN] Статистика маршрутов для %s [%d]:^0", GetPlayerName(source), source))
    
    lib.notify(source, {
        title = 'Статистика маршрутов',
        description = 'Смотрите консоль сервера для подробной информации',
        type = 'info'
    })
    
    for _, route in ipairs(sharedConfig.busRoutes) do
        local count = getRouteBusCount(route.id)
        print(string.format("^3Маршрут %d (%s): %d/%d автобусов^0", route.id, route.name, count, maxBusesPerRoute))
    end
    
    local activePlayersCount = 0
    for _, data in pairs(playerData) do
        if data.working then
            activePlayersCount = activePlayersCount + 1
        end
    end
    
    print(string.format("^2Всего активных водителей: %d^0", activePlayersCount))
end)

lib.addCommand('busvalidate', {
    help = 'Валидировать и исправить счетчики маршрутов',
    restricted = 'group.admin'
}, function(source)
    validateRouteBusCount()
    lib.notify(source, {
        title = 'Валидация завершена',
        description = 'Счетчики маршрутов валидированы',
        type = 'success'
    })
end)

lib.addCommand('busplayers', {
    help = 'Показать всех активных водителей автобусов',
    restricted = 'group.admin'
}, function(source)
    print(string.format("^2[BUS ADMIN] Активные водители для %s [%d]:^0", GetPlayerName(source), source))
    
    local activeCount = 0
    for playerId, data in pairs(playerData) do
        if data.working then
            activeCount = activeCount + 1
            local routeName = data.currentRoute and data.currentRoute.name or "Неизвестный"
            local earnings = data.earnings or 0
            local workTime = os.time() - (data.startTime or os.time())
            
            print(string.format("^3ID: %d, Имя: %s, Маршрут: %s, Заработано: $%d, Время: %d мин^0",
                playerId, GetPlayerName(playerId), routeName, earnings, math.floor(workTime / 60)))
        end
    end
    
    lib.notify(source, {
        title = 'Активные водители',
        description = string.format("Найдено %d активных водителей (см. консоль сервера)", activeCount),
        type = 'info'
    })
end)

lib.addCommand('busfire', {
    help = 'Принудительно уволить водителя автобуса',
    restricted = 'group.admin',
    params = {
        { name = 'playerId', type = 'playerId', help = 'ID игрока' }
    }
}, function(source, args)
    local targetId = args.playerId
    
    if not playerData[targetId] or not playerData[targetId].working then
        lib.notify(source, {
            title = 'Ошибка',
            description = 'Игрок не работает водителем автобуса',
            type = 'error'
        })
        return
    end
    
    finishBusJob(targetId)
    lib.notify(source, {
        title = 'Увольнение',
        description = string.format("Игрок %s принудительно уволен", GetPlayerName(targetId)),
        type = 'success'
    })
    lib.notify(targetId, {
        title = 'Увольнение',
        description = 'Вы были уволены администратором',
        type = 'error'
    })
end)

lib.addCommand('buslimit', {
    help = 'Управление лимитом автобусов на маршруте',
    restricted = 'group.admin',
    params = {
        { name = 'limit', type = 'number', help = 'Новый лимит автобусов на маршруте (0 для просмотра)', optional = true }
    }
}, function(source, args)
    local newLimit = args.limit
    
    if not newLimit or newLimit == 0 then
        lib.notify(source, {
            title = 'Текущий лимит',
            description = string.format("Лимит автобусов на маршруте: %d", maxBusesPerRoute),
            type = 'info'
        })
        return
    end
    
    if newLimit < 1 or newLimit > 20 then
        lib.notify(source, {
            title = 'Ошибка',
            description = 'Лимит должен быть от 1 до 20',
            type = 'error'
        })
        return
    end
    
    local oldLimit = maxBusesPerRoute
    maxBusesPerRoute = newLimit
    
    lib.notify(source, {
        title = 'Лимит изменен',
        description = string.format("Лимит автобусов изменен с %d на %d", oldLimit, newLimit),
        type = 'success'
    })
    
    if config.logging.enabled then
        logToConsole(
            'Изменение лимита',
            ('Администратор %s изменил лимит автобусов с %d на %d'):format(GetPlayerName(source), oldLimit, newLimit)
        )
    end
end)

-- Прибытие на остановку
RegisterNetEvent('qbx_busjob_new:server:reachedStop', function(stopIndex)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)

    if not player or not playerData[src] or not playerData[src].working then return end

    local data = playerData[src]
    if not data.currentRoute then return end

    local stop = data.currentRoute.stops[stopIndex]
    if not stop then return end

    -- Антифрод проверки
    if config.anticheat.enabled then
        -- Проверка расстояния
        if not isPlayerNearLocation(src, stop.coords, config.anticheat.maxDistance) then
            DropPlayer(src, 'Читы: Телепорт на остановку')
            return
        end

        -- -- Проверка времени
        -- local timeSinceLastStop = os.time() - playerData[src].lastStopTime
        -- if timeSinceLastStop < config.anticheat.minTimePerStop then
        --     DropPlayer(src, 'Читы: Слишком быстрое прохождение маршрута')
        --     return
        -- end
    end

    -- Расчет оплаты на основе конфигурации остановки
    local payment = stop.payment or 0

    -- Не выплачиваем за первую точку маршрута
    if stopIndex == 1 then
        payment = 0
    end

    -- Применяем бонус только если есть базовая оплата
    if payment > 0 and math.random(100) <= config.payment.bonusChance then
        payment = math.floor(payment * config.payment.bonusMultiplier)
        lib.notify(src, {
            title = 'Бонус',
            description = 'Бонус за отличную работу!',
            type = 'success'
        })
    end

    -- Выдача денег
    player.Functions.AddMoney(config.payment.type, payment, 'bus-job-stop')
    playerData[src].earnings = playerData[src].earnings + payment
    playerData[src].lastStopTime = os.time()

    -- Обновляем данные об остановке (новая система автоматически синхронизирует)
    local data = playerData[src]
    local newCurrentStop = stopIndex + 1
    
    data.currentStop = newCurrentStop
    
    -- Вычисляем новую следующую остановку
    if newCurrentStop > #data.currentRoute.stops then
        -- Кольцевой маршрут - начинаем с первой остановки
        data.currentStop = 1
        data.nextStopId = getNextStopId(data.currentRoute, 1)
    else
        data.nextStopId = getNextStopId(data.currentRoute, newCurrentStop)
    end

    -- Отправка уведомления клиенту
    TriggerClientEvent('qbx_busjob_new:client:receivePayment', src, payment)

    if config.logging.logPayments then
        logToConsole(
            'Оплата за остановку',
            ('Игрок %s получил $%d за точку %d'):format(GetPlayerName(src), payment, stopIndex)
        )
    end
end)

-- Завершение маршрута
RegisterNetEvent('qbx_busjob_new:server:completedRoute', function()
    local src = source
    local player = exports.qbx_core:GetPlayer(src)

    if not player or not playerData[src] or not playerData[src].working then return end

    -- Бонус за полный маршрут
    local bonus = sharedConfig.settings.routeCompleteBonus
    player.Functions.AddMoney(config.payment.type, bonus, 'bus-job-route-complete')

    lib.notify(src, {
        title = 'Маршрут завершен',
        description = ('Бонус за полный маршрут: $%d'):format(bonus),
        type = 'success'
    })

    if config.logging.logRoutes then
        local workTime = os.time() - playerData[src].startTime
        logToConsole(
            'Маршрут завершен',
            ('Игрок %s завершил маршрут. Заработано: $%d, Время: %d мин'):format(
                GetPlayerName(src),
                playerData[src].earnings + bonus,
                math.floor(workTime / 60)
            )
        )
    end
end)

-- Старое событие посадки пассажира удалено - теперь обрабатывается в серверной системе пассажиров

-- Завершение работы
RegisterNetEvent('qbx_busjob_new:server:endWork', function()
    finishBusJob(source)
end)

-- Функции управления видимостью автобусов
local function addPlayerToBusVisibility(busNetId, playerId, busData)
    if not busVisibility[busNetId] then
        busVisibility[busNetId] = {
            visibleTo = {},
            lastUpdate = os.time()
        }
    end
    
    -- Добавляем игрока в список видимости и сохраняем отправленные данные
    busVisibility[busNetId].visibleTo[playerId] = {
        routeId = busData.routeId,
        nextStopId = busData.nextStopId,
        sentAt = os.time()
    }
    
    -- Отправляем данные игроку
    TriggerClientEvent('qbx_busjob_new:client:updateBusInfo', 
        playerId, 
        busNetId, 
        busData.routeId, 
        busData.nextStopId, 
        busData.ownerId
    )
end

local function removePlayerFromBusVisibility(busNetId, playerId)
    if not busVisibility[busNetId] or not busVisibility[busNetId].visibleTo[playerId] then
        return
    end
    
    -- Удаляем игрока из списка видимости
    busVisibility[busNetId].visibleTo[playerId] = nil
    
    -- Отправляем nil для очистки на клиенте
    TriggerClientEvent('qbx_busjob_new:client:updateBusInfo', 
        playerId, 
        busNetId, 
        nil, 
        nil, 
        nil
    )
    
    -- Если больше никто не видит автобус, удаляем запись
    if next(busVisibility[busNetId].visibleTo) == nil then
        busVisibility[busNetId] = nil
    end
end

local function updateBusVisibilityData(busNetId, busData)
    if not busVisibility[busNetId] then return end
    
    busVisibility[busNetId].lastUpdate = os.time()
    
    -- Обновляем данные для всех видящих игроков
    for playerId, lastSentData in pairs(busVisibility[busNetId].visibleTo) do
        -- Проверяем, изменились ли данные
        if lastSentData.routeId ~= busData.routeId or lastSentData.nextStopId ~= busData.nextStopId then
            -- Обновляем кэш
            busVisibility[busNetId].visibleTo[playerId] = {
                routeId = busData.routeId,
                nextStopId = busData.nextStopId,
                sentAt = os.time()
            }
            
            -- Отправляем обновленные данные
            TriggerClientEvent('qbx_busjob_new:client:updateBusInfo', 
                playerId, 
                busNetId, 
                busData.routeId, 
                busData.nextStopId, 
                busData.ownerId
            )
        end
    end
end

local function cleanupBusVisibility(busNetId)
    if busVisibility[busNetId] then
        -- Уведомляем всех видящих игроков об удалении автобуса
        for playerId in pairs(busVisibility[busNetId].visibleTo) do
            TriggerClientEvent('qbx_busjob_new:client:updateBusInfo', 
                playerId, 
                busNetId, 
                nil, 
                nil, 
                nil
            )
        end
        busVisibility[busNetId] = nil
    end
end


-- Callback для получения количества автобусов на маршрутах
lib.callback.register('qbx_busjob_new:server:getRouteBusCount', function(source)
    -- Создаем безопасную копию счетчиков для отправки клиенту
    local safeCounts = {}
    for _, route in ipairs(sharedConfig.busRoutes) do
        safeCounts[route.id] = getRouteBusCount(route.id)
    end
    return safeCounts
end)

-- Обработка загрузки игрока
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    -- Очистка старых данных при подключении (если остались)
    local src = source
    if playerData[src] then
        playerData[src] = nil
    end
end)

-- Обработка выгрузки игрока
RegisterNetEvent('QBCore:Server:OnPlayerUnload', function()
    local src = source
    if playerData[src] then
        -- Уменьшаем счетчик маршрута
        if playerData[src].currentRoute then
            decrementRouteBusCount(playerData[src].currentRoute.id)
        end
        
        -- Удаление автобуса
        if playerData[src].busNetId then
            local veh = NetworkGetEntityFromNetworkId(playerData[src].busNetId)
            if DoesEntityExist(veh) then
                -- Удаляем ключи перед удалением автобуса
                exports.qbx_vehiclekeys:RemoveKeys(src, veh, true)
                DeleteEntity(veh)
            end
            
            -- Очищаем видимость автобуса
            cleanupBusVisibility(playerData[src].busNetId)
            
            -- Очищаем пассажиров автобуса
            clearAllServerPassengers(playerData[src].busNetId)
        end

        if config.logging.enabled then
            logToConsole(
                'Выгрузка игрока',
                ('Игрок %s выгружен, данные очищены'):format(GetPlayerName(src))
            )
        end

        playerData[src] = nil
    end
end)

-- Очистка при выходе игрока
AddEventHandler('playerDropped', function()
    local src = source
    if playerData[src] then
        -- Уменьшаем счетчик маршрута
        if playerData[src].currentRoute then
            decrementRouteBusCount(playerData[src].currentRoute.id)
        end
        
        -- Удаление автобуса
        if playerData[src].busNetId then
            local veh = NetworkGetEntityFromNetworkId(playerData[src].busNetId)
            if DoesEntityExist(veh) then
                -- Удаляем ключи перед удалением автобуса
                exports.qbx_vehiclekeys:RemoveKeys(src, veh, true)
                -- Уведомляем клиента о необходимости удалить автобус (если игрок еще онлайн)
                TriggerClientEvent('qbx_busjob_new:client:deleteVehicle', src, playerData[src].busNetId)
                DeleteEntity(veh)
            end
            
            -- Очищаем видимость автобуса
            cleanupBusVisibility(playerData[src].busNetId)
            
            -- Очищаем пассажиров автобуса
            clearAllServerPassengers(playerData[src].busNetId)
        end

        if config.logging.enabled then
            logToConsole(
                'Выход игрока',
                ('Игрок %s покинул сервер, данные очищены'):format(GetPlayerName(src))
            )
        end

        playerData[src] = nil
    end
end)


-- Периодический поток управления видимостью автобусов
CreateThread(function()
    while true do
        Wait(2000) -- Проверяем каждые 2 секунды
        
        local maxDistance = config.networking and config.networking.busInfoUpdateDistance or 300.0
        local allPlayers = GetPlayers()
        
        -- Проходим по всем работающим водителям
        for src, data in pairs(playerData) do
            if data.working and data.busNetId then
                local busNetId = data.busNetId
                local busEntity = NetworkGetEntityFromNetworkId(busNetId)
                
                if DoesEntityExist(busEntity) then
                    local busCoords = GetEntityCoords(busEntity)
                    local busData = {
                        routeId = data.currentRoute.id,
                        nextStopId = data.nextStopId,
                        ownerId = src
                    }
                    
                    -- Получаем текущий список видимости
                    local currentlyVisible = busVisibility[busNetId] and busVisibility[busNetId].visibleTo or {}
                    local shouldBeVisible = {}
                    
                    -- Определяем кто должен видеть автобус
                    for _, playerId in ipairs(allPlayers) do
                        local targetId = tonumber(playerId)
                        if targetId ~= src then -- Водитель сам себя не видит
                            local targetPed = GetPlayerPed(targetId)
                            if targetPed and DoesEntityExist(targetPed) then
                                local targetCoords = GetEntityCoords(targetPed)
                                local distance = #(vector3(busCoords.x, busCoords.y, busCoords.z) - vector3(targetCoords.x, targetCoords.y, targetCoords.z))
                                
                                if distance <= maxDistance then
                                    shouldBeVisible[targetId] = true
                                end
                            end
                        end
                    end
                    
                    -- Добавляем новых игроков в зону видимости
                    for playerId in pairs(shouldBeVisible) do
                        if not currentlyVisible[playerId] then
                            addPlayerToBusVisibility(busNetId, playerId, busData)
                        end
                    end
                    
                    -- Удаляем игроков вышедших из зоны видимости
                    for playerId in pairs(currentlyVisible) do
                        if not shouldBeVisible[playerId] then
                            removePlayerFromBusVisibility(busNetId, playerId)
                        end
                    end
                    
                    -- Обновляем данные для видящих игроков (если изменились)
                    if busVisibility[busNetId] then
                        updateBusVisibilityData(busNetId, busData)
                    end
                else
                    -- Автобус больше не существует, очищаем видимость
                    cleanupBusVisibility(busNetId)
                end
            end
        end
    end
end)

-- Система серверных пассажиров
local serverPassengers = {} -- [busNetId] = {waitingPassengers = {}, onboardPassengers = {}}

-- Функция для генерации безопасных координат рядом с остановкой
local function getSafePassengerSpawnCoords(stopCoords, stopHeading)
    local attempts = 0
    local maxAttempts = 10
    local spawnDistance = sharedConfig.passengerSettings.spawnDistance
    
    while attempts < maxAttempts do
        -- Генерируем угол перпендикулярно направлению остановки для спавна сбоку
        local sideAngle = math.rad(stopHeading + 90 + math.random(-45, 45)) -- Боковое направление с разбросом
        local distance = math.random(spawnDistance * 0.5, spawnDistance) -- Случайное расстояние
        
        local spawnX = stopCoords.x + math.cos(sideAngle) * distance
        local spawnY = stopCoords.y + math.sin(sideAngle) * distance
        
        -- Получаем высоту земли
        local foundGround, groundZ = GetGroundZFor_3dCoord(spawnX, spawnY, stopCoords.z + 10.0, false)
        local spawnZ = foundGround and groundZ or stopCoords.z
        
        -- Проверяем что координаты не на дороге
        local roadNode = GetClosestVehicleNode(spawnX, spawnY, spawnZ, 1)
        if roadNode then
            local roadCoords = vec3(GetVehicleNodePosition(roadNode))
            local distanceToRoad = #(vector3(spawnX, spawnY, spawnZ) - roadCoords)
            
            -- Если далеко от дороги - хорошие координаты
            if distanceToRoad > 5.0 then
                return vec3(spawnX, spawnY, spawnZ), math.random(0, 360)
            end
        else
            -- Если нет дороги рядом - тоже хорошо
            return vec3(spawnX, spawnY, spawnZ), math.random(0, 360)
        end
        
        attempts = attempts + 1
    end
    
    -- Если не смогли найти безопасные координаты, используем базовые с небольшим смещением
    local fallbackAngle = math.rad(stopHeading + 90)
    local fallbackX = stopCoords.x + math.cos(fallbackAngle) * spawnDistance
    local fallbackY = stopCoords.y + math.sin(fallbackAngle) * spawnDistance
    local foundGround, groundZ = GetGroundZFor_3dCoord(fallbackX, fallbackY, stopCoords.z + 10.0, false)
    local fallbackZ = foundGround and groundZ or stopCoords.z
    
    return vec3(fallbackX, fallbackY, fallbackZ), math.random(0, 360)
end

-- Функция для получения случайной модели пассажира
local function getRandomPassengerModel()
    local gender = math.random(1, 2) == 1 and 'male' or 'female'
    local models = sharedConfig.passengerModels[gender]
    return models[math.random(1, #models)]
end

-- Функция для создания ожидающих пассажиров на сервере
local function createServerWaitingPassengers(busNetId, stopCoords, stopHeading, stopIndex, routeStops)
    if not serverPassengers[busNetId] then
        serverPassengers[busNetId] = {waitingPassengers = {}, onboardPassengers = {}}
    end
    
    -- Очищаем старых ожидающих пассажиров
    for _, passenger in pairs(serverPassengers[busNetId].waitingPassengers) do
        if DoesEntityExist(passenger.ped) then
            DeleteEntity(passenger.ped)
        end
    end
    serverPassengers[busNetId].waitingPassengers = {}
    
    -- Проверяем шанс спавна пассажиров
    if math.random(100) > sharedConfig.passengerSettings.passengerSpawnChance then
        return
    end
    
    local numPassengers = math.random(
        sharedConfig.passengerSettings.minPassengersPerStop,
        sharedConfig.passengerSettings.maxPassengersPerStop
    )
    
    for i = 1, numPassengers do
        local model = getRandomPassengerModel()
        
        -- Генерируем безопасные координаты
        local spawnCoords, spawnHeading = getSafePassengerSpawnCoords(stopCoords, stopHeading)
        
        -- Создаем педа на сервере (видимого всем)
        local passenger = CreatePed(4, model, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnHeading, true, false)
        
        -- Ждем создания педа
        local attempts = 0
        while not DoesEntityExist(passenger) and attempts < 50 do
            Wait(10)
            attempts = attempts + 1
        end
        
        if DoesEntityExist(passenger) then
            -- Настройка педа
            TaskStandStill(passenger, -1)
            
            -- Выбираем случайную целевую остановку (не текущую)
            local targetStop = stopIndex
            if routeStops and #routeStops > 1 then
                local validStops = {}
                for j, stop in ipairs(routeStops) do
                    if j ~= stopIndex and stop.waitTime and stop.waitTime > 0 then
                        validStops[#validStops + 1] = j
                    end
                end
                
                if #validStops > 0 then
                    targetStop = validStops[math.random(1, #validStops)]
                end
            end
            
            -- Сохраняем информацию о пассажире
            serverPassengers[busNetId].waitingPassengers[#serverPassengers[busNetId].waitingPassengers + 1] = {
                ped = passenger,
                targetStop = targetStop,
                netId = NetworkGetNetworkIdFromEntity(passenger)
            }
            
            if config.logging.enabled then
                logToConsole(
                    'Спавн пассажира',
                    ('Создан пассажир на остановке %d для автобуса %d'):format(stopIndex, busNetId)
                )
            end
        else
            if config.logging.enabled then
                logToConsole(
                    'Ошибка спавна пассажира',
                    ('Не удалось создать пассажира для автобуса %d'):format(busNetId)
                )
            end
        end
    end
end

-- Функция для посадки пассажиров
local function boardServerPassengers(src, busNetId)
    if not serverPassengers[busNetId] or #serverPassengers[busNetId].waitingPassengers == 0 then
        return
    end
    
    local busEntity = NetworkGetEntityFromNetworkId(busNetId)
    if not DoesEntityExist(busEntity) then
        return
    end
    
    local maxSeats = GetVehicleModelNumberOfSeats(GetEntityModel(busEntity))
    local boardedCount = 0
    
    -- Получаем список занятых мест
    local occupiedSeats = {}
    for _, passenger in pairs(serverPassengers[busNetId].onboardPassengers) do
        occupiedSeats[passenger.seatIndex] = true
    end
    
    for i, waitingPassenger in pairs(serverPassengers[busNetId].waitingPassengers) do
        -- Ищем свободное место
        local seatIndex = nil
        for seat = 0, maxSeats - 1 do
            if seat ~= -1 and not occupiedSeats[seat] and IsVehicleSeatFree(busEntity, seat) then
                seatIndex = seat
                occupiedSeats[seat] = true
                break
            end
        end
        
        if seatIndex then
            -- Сажаем пассажира в автобус
            TaskEnterVehicle(waitingPassenger.ped, busEntity, -1, seatIndex, 1.0, 0)
            
            -- Переносим в список пассажиров в автобусе
            serverPassengers[busNetId].onboardPassengers[#serverPassengers[busNetId].onboardPassengers + 1] = {
                ped = waitingPassenger.ped,
                seatIndex = seatIndex,
                targetStop = waitingPassenger.targetStop,
                netId = waitingPassenger.netId
            }
            
            boardedCount = boardedCount + 1
            
            -- Оплата за пассажира
            local payment = math.random(
                sharedConfig.passengerSettings.passengerPayment.min,
                sharedConfig.passengerSettings.passengerPayment.max
            )
            
            local player = exports.qbx_core:GetPlayer(src)
            if player then
                player.Functions.AddMoney(config.payment.type, payment, 'bus-job-passenger')
                playerData[src].earnings = playerData[src].earnings + payment
                
                -- Уведомляем клиента
                TriggerClientEvent('qbx_busjob_new:client:receivePassengerPayment', src, payment)
            end
            
            if config.logging.enabled then
                logToConsole(
                    'Посадка пассажира',
                    ('Пассажир сел в автобус %d, место %d, оплата $%d'):format(busNetId, seatIndex, payment)
                )
            end
        else
            -- Удаляем пассажира если нет места
            if DoesEntityExist(waitingPassenger.ped) then
                DeleteEntity(waitingPassenger.ped)
            end
        end
    end
    
    -- Очищаем список ожидающих
    serverPassengers[busNetId].waitingPassengers = {}
    
    if boardedCount > 0 then
        lib.notify(src, {
            title = 'Посадка пассажиров',
            description = ('Сели %d пассажиров'):format(boardedCount),
            type = 'success'
        })
    end
end

-- Функция для высадки пассажиров
local function alightServerPassengers(src, busNetId, currentStopIndex)
    if not serverPassengers[busNetId] or #serverPassengers[busNetId].onboardPassengers == 0 then
        return
    end
    
    local passengersToRemove = {}
    local alightedCount = 0
    
    for i, passenger in pairs(serverPassengers[busNetId].onboardPassengers) do
        local shouldExit = false
        
        -- Пассажир выходит если это его остановка или по случайности
        if passenger.targetStop == currentStopIndex then
            shouldExit = true
        elseif math.random(100) <= sharedConfig.passengerSettings.exitChance then
            shouldExit = true
        end
        
        if shouldExit then
            -- Высаживаем пассажира
            if DoesEntityExist(passenger.ped) then
                local busEntity = NetworkGetEntityFromNetworkId(busNetId)
                if DoesEntityExist(busEntity) then
                    TaskLeaveVehicle(passenger.ped, busEntity, 0)
                end
                
                -- Удаляем пассажира через некоторое время
                SetTimeout(5000, function()
                    if DoesEntityExist(passenger.ped) then
                        DeleteEntity(passenger.ped)
                    end
                end)
            end
            
            passengersToRemove[#passengersToRemove + 1] = i
            alightedCount = alightedCount + 1
            
            if passenger.targetStop == currentStopIndex then
                lib.notify(src, {
                    title = 'Пассажир вышел',
                    description = 'Пассажир добрался до пункта назначения',
                    type = 'info'
                })
            end
            
            if config.logging.enabled then
                logToConsole(
                    'Высадка пассажира',
                    ('Пассажир вышел из автобуса %d на остановке %d'):format(busNetId, currentStopIndex)
                )
            end
        end
    end
    
    -- Удаляем пассажиров из списка (в обратном порядке)
    for i = #passengersToRemove, 1, -1 do
        table.remove(serverPassengers[busNetId].onboardPassengers, passengersToRemove[i])
    end
    
    if alightedCount > 0 then
        lib.notify(src, {
            title = 'Высадка пассажиров',
            description = ('Вышли %d пассажиров'):format(alightedCount),
            type = 'info'
        })
    end
end

-- Функция для очистки всех пассажиров автобуса
local function clearAllServerPassengers(busNetId)
    if not serverPassengers[busNetId] then
        return
    end
    
    -- Удаляем ожидающих пассажиров
    for _, passenger in pairs(serverPassengers[busNetId].waitingPassengers) do
        if DoesEntityExist(passenger.ped) then
            DeleteEntity(passenger.ped)
        end
    end
    
    -- Удаляем пассажиров в автобусе
    for _, passenger in pairs(serverPassengers[busNetId].onboardPassengers) do
        if DoesEntityExist(passenger.ped) then
            DeleteEntity(passenger.ped)
        end
    end
    
    -- Очищаем структуру данных
    serverPassengers[busNetId] = nil
    
    if config.logging.enabled then
        logToConsole(
            'Очистка пассажиров',
            ('Удалены все пассажиры автобуса %d'):format(busNetId)
        )
    end
end

-- События для управления пассажирами
RegisterNetEvent('qbx_busjob_new:server:createPassengers', function(stopIndex)
    local src = source
    local data = playerData[src]
    
    if not data or not data.working or not data.busNetId or not data.currentRoute then
        return
    end
    
    local stop = data.currentRoute.stops[stopIndex]
    if not stop or not stop.waitTime or stop.waitTime <= 0 then
        return
    end
    
    -- Создаем пассажиров на сервере
    createServerWaitingPassengers(
        data.busNetId,
        stop.coords,
        stop.heading or 0,
        stopIndex,
        data.currentRoute.stops
    )
end)

RegisterNetEvent('qbx_busjob_new:server:boardPassengers', function()
    local src = source
    local data = playerData[src]
    
    if not data or not data.working or not data.busNetId then
        return
    end
    
    boardServerPassengers(src, data.busNetId)
end)

RegisterNetEvent('qbx_busjob_new:server:alightPassengers', function(stopIndex)
    local src = source
    local data = playerData[src]
    
    if not data or not data.working or not data.busNetId then
        return
    end
    
    alightServerPassengers(src, data.busNetId, stopIndex)
end)

-- ===========================
-- СИСТЕМА AI-АВТОБУСОВ
-- ===========================

local aiBusinesses = {} -- [routeId] = {buses = {[busId] = busData}}
local aiBusIdCounter = 0

-- Структура данных AI-автобуса
local function createAIBusData(routeId, busId)
    return {
        id = busId,
        routeId = routeId,
        currentStopIndex = 1, -- Индекс текущей точки в маршруте
        targetStopIndex = 1, -- Целевая остановка (для движения от спавна к маршруту)
        virtualPosition = nil, -- Виртуальная позиция когда автобус не заспавнен
        lastPositionUpdate = 0, -- Время последнего обновления позиции
        state = 'virtual', -- 'virtual' или 'spawned'
        status = 'Инициализация', -- Статус автобуса
        vehicleNetId = nil, -- NetId когда автобус заспавнен
        driverNetId = nil, -- NetId водителя
        owner = 'server', -- Владелец автобуса
        passengers = {}, -- Список пассажиров в AI-автобусе
        blipId = nil, -- ID блипа на карте
        nextStopTime = 0, -- Время прибытия на следующую остановку
        waitingUntil = 0 -- Время до которого автобус ждет на остановке
    }
end

-- Функция для расчета времени движения между точками
local function calculateTravelTime(pos1, pos2, speed)
    local distance = #(vector3(pos1.x, pos1.y, pos1.z) - vector3(pos2.x, pos2.y, pos2.z))
    return (distance / speed) * 1000 -- в миллисекундах
end

-- Функция для получения следующего индекса остановки (кольцевой маршрут)
local function getNextStopIndex(route, currentIndex)
    if currentIndex >= #route.stops then
        return 1 -- Возвращаемся к началу
    end
    return currentIndex + 1
end

-- Виртуальная симуляция движения автобуса
local function simulateAIBusMovement(busData)
    local route = sharedConfig.busRoutes[busData.routeId]
    if not route then return end
    
    local currentTime = GetGameTimer()
    
    -- Если автобус ждет на остановке
    if busData.waitingUntil > currentTime then
        busData.status = 'На остановке'
        return
    else
        busData.status = 'В пути'
    end
    
    -- Специальный случай: автобус едет от спавна к первой точке маршрута
    if busData.currentStopIndex == 0 then
        local targetStop = route.stops[busData.targetStopIndex]
        if not targetStop then return end
        
        -- Если впервые или достигли целевой точки
        if not busData.virtualPosition or currentTime >= busData.nextStopTime then
            -- Достигли первой точки маршрута
            busData.virtualPosition = targetStop.coords
            busData.currentStopIndex = busData.targetStopIndex
            busData.status = 'В пути'
            
            -- Устанавливаем время ожидания если это остановка
            if targetStop.waitTime and targetStop.waitTime > 0 then
                busData.waitingUntil = currentTime + targetStop.waitTime
            end
            
            -- Рассчитываем время до следующей точки
            local nextIndex = getNextStopIndex(route, busData.currentStopIndex)
            local nextStop = route.stops[nextIndex]
            if nextStop then
                local travelTime = calculateTravelTime(targetStop.coords, nextStop.coords, sharedConfig.aiBusinessSettings.averageSpeed)
                busData.nextStopTime = currentTime + travelTime
            end
        else
            -- Интерполируем движение от спавна к первой точке маршрута
            local targetStop = route.stops[busData.targetStopIndex]
            local totalTime = busData.nextStopTime - busData.lastPositionUpdate
            local elapsed = currentTime - busData.lastPositionUpdate
            local progress = math.min(elapsed / totalTime, 1.0)
            
            -- Интерполируем между текущей позицией и целевой
            local currentPos = busData.virtualPosition
            busData.virtualPosition = vec3(
                currentPos.x + (targetStop.coords.x - currentPos.x) * progress,
                currentPos.y + (targetStop.coords.y - currentPos.y) * progress,
                currentPos.z + (targetStop.coords.z - currentPos.z) * progress
            )
        end
        
        busData.lastPositionUpdate = currentTime
        return
    end
    
    -- Обычная логика движения по маршруту
    local currentStop = route.stops[busData.currentStopIndex]
    local nextIndex = getNextStopIndex(route, busData.currentStopIndex)
    local nextStop = route.stops[nextIndex]
    
    if not currentStop or not nextStop then return end
    
    -- Если впервые или достигли следующей точки
    if not busData.virtualPosition or currentTime >= busData.nextStopTime then
        -- Обновляем позицию
        busData.virtualPosition = nextStop.coords
        busData.currentStopIndex = nextIndex
        
        -- Если это остановка с ожиданием
        if nextStop.waitTime and nextStop.waitTime > 0 then
            busData.waitingUntil = currentTime + nextStop.waitTime
            busData.nextStopTime = busData.waitingUntil
        else
            -- Рассчитываем время до следующей точки
            local nextNextIndex = getNextStopIndex(route, nextIndex)
            local nextNextStop = route.stops[nextNextIndex]
            if nextNextStop then
                local travelTime = calculateTravelTime(nextStop.coords, nextNextStop.coords, sharedConfig.aiBusinessSettings.averageSpeed)
                busData.nextStopTime = currentTime + travelTime
            end
        end
    else
        -- Интерполируем позицию между точками
        local progress = 1.0 - ((busData.nextStopTime - currentTime) / calculateTravelTime(currentStop.coords, nextStop.coords, sharedConfig.aiBusinessSettings.averageSpeed))
        progress = math.max(0, math.min(1, progress))
        
        local x = currentStop.coords.x + (nextStop.coords.x - currentStop.coords.x) * progress
        local y = currentStop.coords.y + (nextStop.coords.y - currentStop.coords.y) * progress
        local z = currentStop.coords.z + (nextStop.coords.z - currentStop.coords.z) * progress
        
        busData.virtualPosition = vec3(x, y, z)
    end
    
    busData.lastPositionUpdate = currentTime
end

-- Функция для создания AI-автобуса когда игрок рядом
local function spawnAIBus(busData)
    if busData.state == 'spawned' then return end
    
    local route = sharedConfig.busRoutes[busData.routeId]
    if not route then return end
    
    -- Определяем heading для спавна
    local heading = 0.0
    if busData.currentStopIndex == 0 then
        -- Автобус едет от спавна к первой точке маршрута
        -- Используем heading из busSpawnLocations
        local spawnLocationIndex = ((busData.id - 1) % #sharedConfig.busSpawnLocations) + 1
        local spawnLocation = sharedConfig.busSpawnLocations[spawnLocationIndex]
        heading = spawnLocation.w or 0.0
    else
        -- Обычная логика
        local currentStop = route.stops[busData.currentStopIndex]
        if not currentStop then return end
        heading = currentStop.heading or 0.0
    end
    
    -- Выбираем модель автобуса
    local busModel = sharedConfig.busModels[1].model -- Используем первую модель
    
    -- Создаем водителя сначала
    local driver = CreatePed(4, sharedConfig.aiBusinessSettings.driverModel, busData.virtualPosition.x, busData.virtualPosition.y, busData.virtualPosition.z + 2.0, 0.0, true, false)
    
    local attempts = 0
    while not DoesEntityExist(driver) and attempts < 50 do
        Wait(10)
        attempts = attempts + 1
    end
    
    if not DoesEntityExist(driver) then
        if config.logging.enabled then
            logToConsole('AI Автобус', 'Не удалось создать AI-водителя')
        end
        return
    end
    
    -- Спавним автобус используя qbx.spawnVehicle (без автоматической телепортации)
    local netId = qbx.spawnVehicle({
        model = busModel,
        spawnSource = vector4(busData.virtualPosition.x, busData.virtualPosition.y, busData.virtualPosition.z, heading),
        warp = false -- Отключаем автоматическую телепортацию для ручного контроля
    })
    
    if not netId then
        DeleteEntity(driver)
        if config.logging.enabled then
            logToConsole('AI Автобус', 'Не удалось создать AI-автобус через qbx.spawnVehicle')
        end
        return
    end
    
    -- Конвертируем netId в entity
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then
        DeleteEntity(driver)
        if config.logging.enabled then
            logToConsole('AI Автобус', 'Не удалось получить entity автобуса из netId')
        end
        return
    end
    
    -- Ждем небольшую синхронизацию и сажаем водителя в автобус
    Wait(100)
    SetPedIntoVehicle(driver, vehicle, -1) -- -1 = водительское место
    
    -- Настраиваем доступ к автобусу: разблокируем двери для пассажиров
    SetVehicleDoorsLocked(vehicle, 1) -- 1 = unlocked, пассажиры могут входить
    
    -- Отправляем клиентам информацию о том, что это AI-автобус
    -- Клиенты будут контролировать доступ к водительскому месту
    TriggerClientEvent('qbx_busjob_new:client:registerAIBus', -1, busData.vehicleNetId, busData.driverNetId)
    
    -- Сохраняем данные
    busData.vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
    busData.driverNetId = NetworkGetNetworkIdFromEntity(driver)
    busData.state = 'spawned'
    
    -- Без пассажиров
    busData.passengers = {}
    
    if config.logging.enabled then
        logToConsole('AI Автобус', ('Создан AI-автобус %d на маршруте %d'):format(busData.id, busData.routeId))
    end
end

-- Функция для удаления AI-автобуса
local function despawnAIBus(busData)
    if busData.state ~= 'spawned' then return end
    
    -- Удаляем пассажиров
    for _, passengerNetId in ipairs(busData.passengers) do
        local passenger = NetworkGetEntityFromNetworkId(passengerNetId)
        if DoesEntityExist(passenger) then
            DeleteEntity(passenger)
        end
    end
    busData.passengers = {}
    
    -- Удаляем водителя
    if busData.driverNetId then
        local driver = NetworkGetEntityFromNetworkId(busData.driverNetId)
        if DoesEntityExist(driver) then
            DeleteEntity(driver)
        end
    end
    
    -- Удаляем автобус
    if busData.vehicleNetId then
        local vehicle = NetworkGetEntityFromNetworkId(busData.vehicleNetId)
        if DoesEntityExist(vehicle) then
            -- Сохраняем последнюю позицию
            busData.virtualPosition = GetEntityCoords(vehicle)
            -- Уведомляем клиентов об удалении AI-автобуса
            TriggerClientEvent('qbx_busjob_new:client:unregisterAIBus', -1, busData.vehicleNetId)
            DeleteEntity(vehicle)
        end
    end
    
    busData.vehicleNetId = nil
    busData.driverNetId = nil
    busData.state = 'virtual'
    
    if config.logging.enabled then
        logToConsole('AI Автобус', ('Удален AI-автобус %d на маршруте %d'):format(busData.id, busData.routeId))
    end
end

-- Функция для инициализации AI-автобусов на маршруте
local function initializeAIBusesForRoute(routeId)
    if not sharedConfig.aiBusinessSettings.enabled then return end
    if getRouteBusCount(routeId) > 0 then return end -- Не создаем AI если есть игроки
    
    local route = sharedConfig.busRoutes[routeId]
    if not route then return end
    
    aiBusinesses[routeId] = aiBusinesses[routeId] or { buses = {} }
    
    -- Создаем AI-автобусы с интервалом
    for i = 1, sharedConfig.aiBusinessSettings.busesPerRoute do
        SetTimeout((i - 1) * sharedConfig.aiBusinessSettings.timeBetweenBuses * 1000, function()
            -- Проверяем еще раз что нет игроков на маршруте
            if getRouteBusCount(routeId) == 0 then
                aiBusIdCounter = aiBusIdCounter + 1
                local busData = createAIBusData(routeId, aiBusIdCounter)
                
                -- Устанавливаем начальную позицию из busSpawnLocations
                local spawnLocationIndex = ((i - 1) % #sharedConfig.busSpawnLocations) + 1
                local spawnLocation = sharedConfig.busSpawnLocations[spawnLocationIndex]
                busData.virtualPosition = vec3(spawnLocation.x, spawnLocation.y, spawnLocation.z)
                busData.currentStopIndex = 0 -- Специальное значение: едет к первой точке маршрута
                busData.status = 'Едет к началу маршрута'
                
                -- Рассчитываем начальный сдвиг по маршруту для каждого автобуса (после того как доедет до маршрута)
                local totalStops = #route.stops
                local stopsPerBus = math.floor(totalStops / sharedConfig.aiBusinessSettings.busesPerRoute)
                local targetIndex = ((i - 1) * stopsPerBus) + 1
                
                if targetIndex <= totalStops then
                    busData.targetStopIndex = targetIndex -- Цель после спавна
                else
                    busData.targetStopIndex = 1
                end
                
                -- Рассчитываем время движения от спавна к первой точке маршрута
                local targetStop = route.stops[busData.targetStopIndex]
                if targetStop then
                    local currentTime = GetGameTimer()
                    local travelTime = calculateTravelTime(busData.virtualPosition, targetStop.coords, sharedConfig.aiBusinessSettings.averageSpeed)
                    busData.nextStopTime = currentTime + travelTime
                    busData.lastPositionUpdate = currentTime
                end
                
                aiBusinesses[routeId].buses[busData.id] = busData
                
                if config.logging.enabled then
                    logToConsole('AI Автобус', ('Инициализирован AI-автобус %d на маршруте %d'):format(busData.id, routeId))
                end
            end
        end)
    end
end

-- Функция для удаления всех AI-автобусов на маршруте
local function removeAllAIBusesFromRoute(routeId)
    if not aiBusinesses[routeId] then return end
    
    for busId, busData in pairs(aiBusinesses[routeId].buses) do
        despawnAIBus(busData)
    end
    
    aiBusinesses[routeId] = nil
    
    if config.logging.enabled then
        logToConsole('AI Автобус', ('Удалены все AI-автобусы с маршрута %d'):format(routeId))
    end
end

-- Поток управления AI-автобусами
CreateThread(function()
    if not sharedConfig.aiBusinessSettings.enabled then return end
    
    -- Инициализация AI-автобусов при старте
    Wait(5000) -- Ждем загрузки ресурса
    for _, route in ipairs(sharedConfig.busRoutes) do
        if getRouteBusCount(route.id) == 0 then
            initializeAIBusesForRoute(route.id)
        end
    end
    
    -- Основной цикл управления
    while true do
        Wait(sharedConfig.aiBusinessSettings.virtualSimulationInterval)
        
        local allPlayers = GetPlayers()
        
        for routeId, routeData in pairs(aiBusinesses) do
            -- Проверяем не появились ли игроки на маршруте
            if getRouteBusCount(routeId) > 0 then
                removeAllAIBusesFromRoute(routeId)
            else
                -- Обновляем каждый AI-автобус
                for busId, busData in pairs(routeData.buses) do
                    if busData.state == 'virtual' then
                        -- Симулируем движение
                        simulateAIBusMovement(busData)
                        
                        -- Отправляем обновление блипа для виртуального автобуса
                        TriggerClientEvent('qbx_busjob_new:client:updateAIBusBlip', -1, busData.id, busData.virtualPosition, busData.status or 'В пути')
                        
                        -- Проверяем proximity для спавна
                        local shouldSpawn = false
                        for _, playerId in ipairs(allPlayers) do
                            local ped = GetPlayerPed(tonumber(playerId))
                            if ped and DoesEntityExist(ped) then
                                local playerPos = GetEntityCoords(ped)
                                if busData.virtualPosition and #(playerPos - busData.virtualPosition) <= sharedConfig.aiBusinessSettings.proximitySpawnDistance then
                                    shouldSpawn = true
                                    break
                                end
                            end
                        end
                        
                        if shouldSpawn then
                            spawnAIBus(busData)
                            
                            -- Находим ближайшего игрока для управления AI
                            local closestPlayer = nil
                            local closestDistance = math.huge
                            
                            for _, playerId in ipairs(allPlayers) do
                                local ped = GetPlayerPed(tonumber(playerId))
                                if ped and DoesEntityExist(ped) then
                                    local playerPos = GetEntityCoords(ped)
                                    local distance = #(vector3(playerPos.x, playerPos.y, playerPos.z) - vector3(busData.virtualPosition.x, busData.virtualPosition.y, busData.virtualPosition.z))
                                    if distance < closestDistance then
                                        closestDistance = distance
                                        closestPlayer = tonumber(playerId)
                                    end
                                end
                            end
                            
                            -- Передаем управление ближайшему игроку
                            if closestPlayer and busData.vehicleNetId then
                                SetTimeout(1000, function() -- Небольшая задержка для синхронизации
                                    TriggerClientEvent('qbx_busjob_new:client:controlAIBus', closestPlayer, {
                                        vehicleNetId = busData.vehicleNetId,
                                        driverNetId = busData.driverNetId,
                                        routeId = busData.routeId,
                                        currentStopIndex = busData.currentStopIndex,
                                        busId = busData.id
                                    })
                                end)
                            end
                        end
                    elseif busData.state == 'spawned' then
                        -- Проверяем нужно ли деспавнить
                        local shouldDespawn = true
                        local vehicle = NetworkGetEntityFromNetworkId(busData.vehicleNetId)
                        
                        if DoesEntityExist(vehicle) then
                            local busPos = GetEntityCoords(vehicle)
                            
                            for _, playerId in ipairs(allPlayers) do
                                local ped = GetPlayerPed(tonumber(playerId))
                                if ped and DoesEntityExist(ped) then
                                    local playerPos = GetEntityCoords(ped)
                                    if #(vector3(playerPos.x, playerPos.y, playerPos.z) - vector3(busPos.x, busPos.y, busPos.z)) <= sharedConfig.aiBusinessSettings.proximitySpawnDistance * 1.5 then
                                        shouldDespawn = false
                                        break
                                    end
                                end
                            end
                            
                            if shouldDespawn then
                                despawnAIBus(busData)
                            else
                                -- Проверяем, нужно ли передать управление другому игроку
                                local currentOwner = NetworkGetEntityOwner(vehicle)
                                if currentOwner > 0 then
                                    local ownerPed = GetPlayerPed(currentOwner)
                                    if DoesEntityExist(ownerPed) then
                                        local ownerPos = GetEntityCoords(ownerPed)
                                        local ownerDistance = #(vector3(ownerPos.x, ownerPos.y, ownerPos.z) - vector3(busPos.x, busPos.y, busPos.z))
                                        
                                        -- Если владелец далеко, найдем нового
                                        if ownerDistance > sharedConfig.aiBusinessSettings.proximitySpawnDistance then
                                            local newOwner = nil
                                            local closestDistance = math.huge
                                            
                                            for _, playerId in ipairs(allPlayers) do
                                                local pid = tonumber(playerId)
                                                if pid ~= currentOwner then
                                                    local ped = GetPlayerPed(pid)
                                                    if ped and DoesEntityExist(ped) then
                                                        local playerPos = GetEntityCoords(ped)
                                                        local distance = #(vector3(playerPos.x, playerPos.y, playerPos.z) - vector3(busPos.x, busPos.y, busPos.z))
                                                        if distance < closestDistance and distance < sharedConfig.aiBusinessSettings.proximitySpawnDistance then
                                                            closestDistance = distance
                                                            newOwner = pid
                                                        end
                                                    end
                                                end
                                            end
                                            
                                            -- Передаем управление новому игроку
                                            if newOwner then
                                                TriggerClientEvent('qbx_busjob_new:client:controlAIBus', newOwner, {
                                                    vehicleNetId = busData.vehicleNetId,
                                                    driverNetId = busData.driverNetId,
                                                    routeId = busData.routeId,
                                                    currentStopIndex = busData.currentStopIndex,
                                                    busId = busData.id
                                                })
                                            end
                                        end
                                    end
                                end
                                
                                -- Отправляем обновление блипа для всех игроков
                                TriggerClientEvent('qbx_busjob_new:client:updateAIBusBlip', -1, busData.id, busPos, busData.status or 'Работает')
                            end
                        else
                            -- Автобус не существует - деспавним из данных
                            despawnAIBus(busData)
                        end
                    end
                end
            end
        end
    end
end)

-- События для управления AI-автобусами при изменении состояния маршрутов
local function onRoutePlayerCountChanged(routeId, playerCount)
    if not sharedConfig.aiBusinessSettings.enabled then return end
    
    if playerCount > 0 then
        -- Игроки появились на маршруте - удаляем AI
        removeAllAIBusesFromRoute(routeId)
    else
        -- Игроки покинули маршрут - создаем AI
        SetTimeout(5000, function() -- Небольшая задержка
            if getRouteBusCount(routeId) == 0 then
                initializeAIBusesForRoute(routeId)
            end
        end)
    end
end

-- Модифицируем функции incrementRouteBusCount и decrementRouteBusCount для отслеживания изменений
local originalIncrementRouteBusCount = incrementRouteBusCount
incrementRouteBusCount = function(routeId)
    local result = originalIncrementRouteBusCount(routeId)
    if result then
        onRoutePlayerCountChanged(routeId, getRouteBusCount(routeId))
    end
    return result
end

local originalDecrementRouteBusCount = decrementRouteBusCount
decrementRouteBusCount = function(routeId)
    local result = originalDecrementRouteBusCount(routeId)
    if result then
        onRoutePlayerCountChanged(routeId, getRouteBusCount(routeId))
    end
    return result
end


-- Событие для передачи управления AI-автобусом клиенту
RegisterNetEvent('qbx_busjob_new:server:requestAIBusControl', function(routeId, busId)
    local src = source
    
    if not aiBusinesses[routeId] or not aiBusinesses[routeId].buses[busId] then
        return
    end
    
    local busData = aiBusinesses[routeId].buses[busId]
    
    if busData.state == 'spawned' and busData.vehicleNetId then
        -- Передаем данные клиенту для управления AI
        TriggerClientEvent('qbx_busjob_new:client:controlAIBus', src, {
            vehicleNetId = busData.vehicleNetId,
            driverNetId = busData.driverNetId,
            routeId = busData.routeId,
            currentStopIndex = busData.currentStopIndex,
            busId = busData.id
        })
    end
end)

-- Событие для обновления позиции AI-автобуса от клиента
RegisterNetEvent('qbx_busjob_new:server:updateAIBusPosition', function(routeId, busId, stopIndex, position)
    if not aiBusinesses[routeId] or not aiBusinesses[routeId].buses[busId] then
        return
    end
    
    local busData = aiBusinesses[routeId].buses[busId]
    busData.currentStopIndex = stopIndex
    busData.virtualPosition = position
end)

-- Callback для получения информации об AI-автобусах
lib.callback.register('qbx_busjob_new:server:getAIBusesInfo', function(source)
    local aiBusesInfo = {}
    
    for routeId, routeData in pairs(aiBusinesses) do
        for busId, busData in pairs(routeData.buses) do
            if busData.virtualPosition then
                aiBusesInfo[#aiBusesInfo + 1] = {
                    id = busData.id,
                    routeId = busData.routeId,
                    position = busData.virtualPosition,
                    state = busData.state,
                    currentStopIndex = busData.currentStopIndex
                }
            end
        end
    end
    
    return aiBusesInfo
end)

-- Админские команды для отладки AI-автобусов
lib.addCommand('aibuses', {
    help = 'Показать информацию об AI-автобусах',
    restricted = 'group.admin'
}, function(source)
    print(string.format("^2[AI BUS] Информация об AI-автобусах для %s [%d]:^0", GetPlayerName(source), source))
    
    local totalAIBuses = 0
    for routeId, routeData in pairs(aiBusinesses) do
        local routeBusCount = 0
        for busId, busData in pairs(routeData.buses) do
            routeBusCount = routeBusCount + 1
            print(string.format("^3AI Автобус %d - Маршрут %d, Состояние: %s, Точка: %d^0", 
                busData.id, busData.routeId, busData.state, busData.currentStopIndex))
        end
        totalAIBuses = totalAIBuses + routeBusCount
        print(string.format("^2Маршрут %d: %d AI-автобусов^0", routeId, routeBusCount))
    end
    
    lib.notify(source, {
        title = 'AI Автобусы',
        description = string.format("Всего AI-автобусов: %d (см. консоль сервера)", totalAIBuses),
        type = 'info'
    })
end)

lib.addCommand('clearaibuses', {
    help = 'Очистить все AI-автобусы',
    restricted = 'group.admin'
}, function(source)
    local removedCount = 0
    for routeId, routeData in pairs(aiBusinesses) do
        for busId, busData in pairs(routeData.buses) do
            despawnAIBus(busData)
            removedCount = removedCount + 1
        end
    end
    aiBusinesses = {}
    
    lib.notify(source, {
        title = 'AI Автобусы',
        description = string.format("Удалено %d AI-автобусов", removedCount),
        type = 'success'
    })
    
    if config.logging.enabled then
        logToConsole('AI Автобус', ('Администратор %s очистил все AI-автобусы (%d)'):format(GetPlayerName(source), removedCount))
    end
end)

lib.addCommand('reloadaibuses', {
    help = 'Перезагрузить AI-автобусы на всех маршрутах',
    restricted = 'group.admin'
}, function(source)
    -- Очищаем все AI-автобусы
    for routeId, routeData in pairs(aiBusinesses) do
        for busId, busData in pairs(routeData.buses) do
            despawnAIBus(busData)
        end
    end
    aiBusinesses = {}
    
    -- Перезапускаем AI на свободных маршрутах
    SetTimeout(2000, function()
        for _, route in ipairs(sharedConfig.busRoutes) do
            if getRouteBusCount(route.id) == 0 then
                initializeAIBusesForRoute(route.id)
            end
        end
    end)
    
    lib.notify(source, {
        title = 'AI Автобусы',
        description = 'AI-автобусы перезагружены',
        type = 'success'
    })
    
    if config.logging.enabled then
        logToConsole('AI Автобус', ('Администратор %s перезагрузил AI-автобусы'):format(GetPlayerName(source)))
    end
end)

-- Очистка при перезапуске ресурса
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    print('^3[BUS JOB] ^2Начинаем очистку ресурса...^0')

    for routeId, routeData in pairs(aiBusinesses) do
        for busId, busData in pairs(routeData.buses) do
            despawnAIBus(busData)
        end
    end

    -- Завершаем работу всем активным работникам
    local cleanupCount = 0
    for playerId, data in pairs(playerData) do
        if data.working and data.busNetId then
            local player = exports.qbx_core:GetPlayer(playerId)
            local veh = NetworkGetEntityFromNetworkId(data.busNetId)

            if DoesEntityExist(veh) then
                -- Удаляем ключи если игрок онлайн
                if player then
                    exports.qbx_vehiclekeys:RemoveKeys(playerId, veh, true)
                end

                -- Уведомляем клиента о необходимости удалить автобус с его стороны
                TriggerClientEvent('qbx_busjob_new:client:deleteVehicle', playerId, data.busNetId)

                -- Удаляем автобус со стороны сервера
                DeleteEntity(veh)
                cleanupCount = cleanupCount + 1

                print(string.format('^3[BUS JOB] ^2Удален автобус игрока %s (NetID: %d)^0',
                    GetPlayerName(playerId) or 'Unknown', data.busNetId))
            end
            
            -- Очищаем видимость автобуса
            cleanupBusVisibility(data.busNetId)
            
            -- Очищаем пассажиров автобуса
            clearAllServerPassengers(data.busNetId)

            if player then
                -- Возврат залога
                if data.deposit > 0 then
                    player.Functions.AddMoney('cash', data.deposit, 'bus-job-deposit-return-resource-stop')
                    lib.notify(playerId, {
                        title = 'Работа завершена',
                        description = ('Залог возвращен: $%d'):format(data.deposit),
                        type = 'info'
                    })
                else
                    lib.notify(playerId, {
                        title = 'Работа завершена',
                        description = 'Работа завершена из-за перезапуска ресурса',
                        type = 'info'
                    })
                end

                -- Логирование
                if config.logging.enabled then
                    local workTime = os.time() - data.startTime
                    logToConsole(
                        'Завершение работы (остановка ресурса)',
                        ('Игрок %s завершил работу. Заработано: $%d, Время: %d мин'):format(
                            GetPlayerName(playerId),
                            data.earnings,
                            math.floor(workTime / 60)
                        )
                    )
                end

                -- Отправка события клиенту для очистки
                TriggerClientEvent('qbx_busjob_new:client:endWork', playerId)
            end
            
            -- Уменьшаем счетчик маршрута
            if data.currentRoute then
                decrementRouteBusCount(data.currentRoute.id)
            end
        end
    end

    -- Очищаем все данные
    playerData = {}
    routeBusCount = {}
    busVisibility = {}
    serverPassengers = {}
    aiBusinesses = {}

    print(string.format('^3[BUS JOB] ^1Ресурс остановлен. Удалено %d автобусов. Все активные работы завершены.^0',
        cleanupCount))
end)
