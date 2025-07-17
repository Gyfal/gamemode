local config = require 'config.server'
local sharedConfig = require 'config.shared'

-- Хранение данных игроков
local playerData = {}

-- Функция проверки расстояния (антифрод)
local function isPlayerNearLocation(src, coords, maxDistance)
    if not config.anticheat.enabled then return true end

    local ped = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(ped)
    local distance = #(playerCoords - coords)

    return distance <= (maxDistance or config.anticheat.maxDistance)
end

-- Функция логирования
local function logToConsole(title, message)
    if not config.logging.enabled then return end

    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    print(string.format('^3[BUS JOB] ^2[%s] ^5%s^0: %s', timestamp, title, message))
end

-- Функция завершения работы (универсальная)
local function finishBusJob(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not playerData[src] or not playerData[src].working then return end

    local data = playerData[src]

    -- Удаляем автобус, если он ещё существует
    if data.busNetId then
        local veh = NetworkGetEntityFromNetworkId(data.busNetId)
        if DoesEntityExist(veh) then
            exports.qbx_vehiclekeys:RemoveKeys(src, veh, true)
            TriggerClientEvent('qbx_busjob_new:client:deleteVehicle', src, data.busNetId)
            DeleteEntity(veh)
        end
    end

    -- Возврат залога
    if data.deposit and data.deposit > 0 then
        player.Functions.AddMoney('cash', data.deposit, 'bus-job-deposit-return')
        exports.qbx_core:Notify(src, ('Залог возвращен: $%d'):format(data.deposit), 'success')
    end

    -- Итоговая статистика
    local workTime = os.time() - (data.startTime or os.time())
    exports.qbx_core:Notify(src, ('Заработано за смену: $%d'):format(data.earnings or 0), 'info')

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
        exports.qbx_core:Notify(src, 'Вы уже работаете водителем автобуса!', 'error')
        return
    end

    -- Проверяем расстояние до NPC
    if not isPlayerNearLocation(src, sharedConfig.jobNPC.coords.xyz, 50.0) then
        exports.qbx_core:Notify(src, 'Вы слишком далеко от NPC!', 'error')
        return
    end

    -- Устанавливаем работу
    player.Functions.SetJob(config.job.name, config.job.minGrade)

    -- Параметры автобуса
    local busConfig = sharedConfig.busModels[1] -- По умолчанию первый автобус
    local deposit = 0
    if sharedConfig.settings.requireDeposit then
        deposit = busConfig.deposit or 0
        if player.PlayerData.money.cash < deposit then
            exports.qbx_core:Notify(src, 'У вас недостаточно наличных для залога!', 'error')
            player.Functions.SetJob('unemployed', 0)
            return
        end
        if deposit > 0 then
            player.Functions.RemoveMoney('cash', deposit, 'bus-job-deposit')
        end
    end

    -- Координаты спавна
    local spawnLocation = sharedConfig.busSpawnLocations[math.random(1, #sharedConfig.busSpawnLocations)]

    -- Спавн автобуса с моментальным варпом при помощи qbx.spawnVehicle
    local netId = qbx.spawnVehicle({
        model = busConfig.model,
        spawnSource = spawnLocation,
        warp = true
    })

    if not netId or netId == 0 then
        exports.qbx_core:Notify(src, 'Не удалось создать автобус!', 'error')
        if deposit > 0 then
            player.Functions.AddMoney('cash', deposit, 'bus-job-deposit-return')
        end
        player.Functions.SetJob('unemployed', 0)
        return
    end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(veh) then
        exports.qbx_core:Notify(src, 'Не удалось создать автобус!', 'error')
        if deposit > 0 then
            player.Functions.AddMoney('cash', deposit, 'bus-job-deposit-return')
        end
        player.Functions.SetJob('unemployed', 0)
        return
    end

    -- Настройка автобуса и ключей
    local plate = 'BUS' .. math.random(1000, 9999)
    SetVehicleNumberPlateText(veh, plate)
    exports.qbx_vehiclekeys:GiveKeys(src, veh)
    SetVehicleDoorsLocked(veh, 1)

    -- Сохраняем данные игрока
    playerData[src] = {
        working = true,
        busNetId = netId,
        deposit = deposit,
        currentStop = 1,
        lastStopTime = os.time(),
        earnings = 0,
        startTime = os.time(),
        spawnLocation = spawnLocation
    }

    -- Уведомляем клиента и начинаем маршрут
    exports.qbx_core:Notify(src, 'Автобус готов! Следуйте к первой остановке', 'success')
    TriggerClientEvent('qbx_busjob_new:client:startWork', src, netId, deposit)

    if config.logging.enabled then
        logToConsole(
            'Начало работы',
            ('Игрок %s (ID: %s) начал смену автобусника. Залог: $%d'):format(GetPlayerName(src), src, deposit)
        )
    end
end)

-- Увольнение с работы
RegisterNetEvent('qbx_busjob_new:server:quitJob', function()
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    if player.PlayerData.job.name ~= config.job.name then
        exports.qbx_core:Notify(src, 'Вы не работаете водителем автобуса!', 'error')
        return
    end

    -- Завершаем работу и очищаем
    finishBusJob(src)

    -- Сброс работы
    player.Functions.SetJob('unemployed', 0)
    exports.qbx_core:Notify(src, 'Вы уволились с работы!', 'info')
end)

-- Запрос автобуса
RegisterNetEvent('qbx_busjob_new:server:requestBus', function(busIndex)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)

    if not player then return end

    -- Проверки
    if player.PlayerData.job.name ~= config.job.name then
        exports.qbx_core:Notify(src, 'Вы не работаете водителем автобуса!', 'error')
        return
    end

    if playerData[src] and playerData[src].working then
        exports.qbx_core:Notify(src, 'Вы уже работаете!', 'error')
        return
    end

    local busConfig = sharedConfig.busModels[busIndex]
    if not busConfig then
        exports.qbx_core:Notify(src, 'Неверный выбор автобуса!', 'error')
        return
    end

    -- Проверка залога
    local deposit = 0
    if sharedConfig.settings.requireDeposit then
        deposit = busConfig.deposit
        if player.PlayerData.money.cash < deposit then
            exports.qbx_core:Notify(src, 'У вас недостаточно наличных для залога!', 'error')
            return
        end

        -- Снятие залога
        player.Functions.RemoveMoney('cash', deposit, 'bus-job-deposit')
    end

    -- Выбор случайной координаты спавна
    local spawnLocation = sharedConfig.busSpawnLocations[math.random(1, #sharedConfig.busSpawnLocations)]

    -- Проверка расстояния от NPC (более логично, чем от места спавна)
    if not isPlayerNearLocation(src, sharedConfig.jobNPC.coords.xyz, 50.0) then
        exports.qbx_core:Notify(src, 'Вы слишком далеко от NPC!', 'error')
        return
    end

    -- Спавн автобуса в случайном месте
    local netId = qbx.spawnVehicle({
        model = busConfig.model,
        spawnSource = spawnLocation,
        warp = false -- Отключаем автоматическую телепортацию для более надежного контроля
    })

    if not netId or netId == 0 then
        exports.qbx_core:Notify(src, 'Не удалось создать автобус!', 'error')
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
    exports.qbx_core:Notify(src, 'Автобус готов! Следуйте к первой остановке', 'success')

    -- Сохранение данных игрока
    playerData[src] = {
        working = true,
        busNetId = netId,
        deposit = deposit,
        currentStop = 1,
        lastStopTime = os.time(),
        earnings = 0,
        startTime = os.time(),
        spawnLocation = spawnLocation -- Сохраняем координаты спавна для дебага
    }

    -- Отправка данных клиенту
    TriggerClientEvent('qbx_busjob_new:client:startWork', src, netId, deposit)

    if config.logging.enabled then
        logToConsole(
            'Начало работы',
            ('Игрок %s начал работу. Автобус: %s, Залог: $%d, Спавн: %.1f, %.1f, %.1f'):format(
                GetPlayerName(src), busConfig.label, deposit, spawnLocation.x, spawnLocation.y, spawnLocation.z)
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

-- Прибытие на остановку
RegisterNetEvent('qbx_busjob_new:server:reachedStop', function(stopIndex)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)

    if not player or not playerData[src] or not playerData[src].working then return end

    local stop = sharedConfig.busRoute[stopIndex]
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

    -- Не выплачиваем за стартовую точку
    if stop.isStartPoint then
        payment = 0
    end

    -- Применяем бонус только если есть базовая оплата
    if payment > 0 and math.random(100) <= config.payment.bonusChance then
        payment = math.floor(payment * config.payment.bonusMultiplier)
        exports.qbx_core:Notify(src, 'Бонус за отличную работу!', 'success')
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
            ('Игрок %s получил $%d за остановку %s'):format(GetPlayerName(src), payment, stop.name)
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

    exports.qbx_core:Notify(src, ('Бонус за полный маршрут: $%d'):format(bonus), 'success')

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
        -- Удаление автобуса
        if playerData[src].busNetId then
            local veh = NetworkGetEntityFromNetworkId(playerData[src].busNetId)
            if DoesEntityExist(veh) then
                -- Удаляем ключи перед удалением автобуса
                exports.qbx_vehiclekeys:RemoveKeys(src, veh, true)
                DeleteEntity(veh)
            end
        end

        playerData[src] = nil
    end
end)

-- Очистка при выходе игрока
AddEventHandler('playerDropped', function()
    local src = source
    if playerData[src] then
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
                    exports.qbx_core:Notify(playerId, ('Работа завершена. Залог возвращен: $%d'):format(data.deposit),
                        'info')
                else
                    exports.qbx_core:Notify(playerId, 'Работа завершена из-за перезапуска ресурса', 'info')
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
        end
    end

    -- Очищаем все данные
    playerData = {}

    print(string.format('^3[BUS JOB] ^1Ресурс остановлен. Удалено %d автобусов. Все активные работы завершены.^0',
        cleanupCount))
end)
