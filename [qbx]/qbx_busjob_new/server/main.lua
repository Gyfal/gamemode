local config = require 'config.server'
local sharedConfig = require 'config.shared'

-- Хранение данных игроков
local playerData = {}

-- Счетчик автобусов на маршрутах
local routeBusCount = {}

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
    local distance = #(playerCoords - coords)

    return distance <= (maxDistance or config.anticheat.maxDistance)
end

-- Функция логирования
function logToConsole(title, message)
    if not config.logging.enabled then return end

    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    print(string.format('^3[BUS JOB] ^2[%s] ^5%s^0: %s', timestamp, title, message))
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
        spawnLocation = spawnLocation -- Сохраняем координаты спавна для дебага
    }

    -- Отправка данных клиенту
    TriggerClientEvent('qbx_busjob_new:client:startWork', src, netId, deposit, routeId)

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

-- Посадка пассажира
RegisterNetEvent('qbx_busjob_new:server:passengerBoarded', function(payment)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)

    if not player or not playerData[src] or not playerData[src].working then return end

    -- Проверка на валидность оплаты
    if payment < sharedConfig.passengerSettings.passengerPayment.min or
        payment > sharedConfig.passengerSettings.passengerPayment.max then
        DropPlayer(src, 'Читы: Неверная сумма оплаты за пассажира')
        return
    end

    -- Выдача денег
    player.Functions.AddMoney(config.payment.type, payment, 'bus-job-passenger')
    playerData[src].earnings = playerData[src].earnings + payment

    -- Отправка уведомления клиенту
    TriggerClientEvent('qbx_busjob_new:client:receivePassengerPayment', src, payment)

    if config.logging.logPayments then
        logToConsole(
            'Оплата за пассажира',
            ('Игрок %s получил $%d за посадку пассажира'):format(GetPlayerName(src), payment)
        )
    end
end)

-- Завершение работы
RegisterNetEvent('qbx_busjob_new:server:endWork', function()
    finishBusJob(source)
end)

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

-- Очистка при перезапуске ресурса
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    print('^3[BUS JOB] ^2Начинаем очистку ресурса...^0')

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

    print(string.format('^3[BUS JOB] ^1Ресурс остановлен. Удалено %d автобусов. Все активные работы завершены.^0',
        cleanupCount))
end)

