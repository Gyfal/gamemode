local config = require 'config.shared'

-- Локальные переменные
local activeZones = {}
local currentSafeZone = nil
local isInSafeZone = false
local collisionDisabled = false
local weaponsDisabled = false
local collisionMonitorThread = nil
local playersInZone = {} -- Список игроков в зоне
local vehiclesInZone = {} -- Список машин в зоне

-- Функция для отключения коллизий между двумя энтити
local function disableCollisionBetween(entity1, entity2)
    if DoesEntityExist(entity1) and DoesEntityExist(entity2) then
        SetEntityNoCollisionEntity(entity1, entity2, true)
    end
end

-- Функция для включения коллизий между двумя энтити
local function enableCollisionBetween(entity1, entity2)
    if DoesEntityExist(entity1) and DoesEntityExist(entity2) then
        SetEntityNoCollisionEntity(entity1, entity2, false)
    end
end

-- Функция получения всех игроков и транспорта в зоне
local function getEntitiesInZone()
    local entities = {peds = {}, vehicles = {}}

    if not currentSafeZone then return entities end

    -- Получаем всех игроков (ИСПРАВЛЕНО: используем GetActivePlayers вместо FindFirstPed)
    local activePlayers = GetActivePlayers()
    for _, player in ipairs(activePlayers) do
        local playerPed = GetPlayerPed(player)
        if DoesEntityExist(playerPed) and playerPed ~= cache.ped then
            local coords = GetEntityCoords(playerPed)

            if currentSafeZone.type == 'sphere' then
                local dist = #(coords - currentSafeZone.coords)
                if dist <= currentSafeZone.radius then
                    table.insert(entities.peds, playerPed)
                end
            elseif currentSafeZone.type == 'box' then
                -- TODO: Добавить проверку для box зон
                table.insert(entities.peds, playerPed)
            elseif currentSafeZone.type == 'polygon' then
                -- TODO: Добавить проверку для polygon зон
                table.insert(entities.peds, playerPed)
            end
        end
    end

    -- Получаем все машины в радиусе
    local handle, vehicle = FindFirstVehicle()
    local success
    repeat
        local coords = GetEntityCoords(vehicle)
        if currentSafeZone.type == 'sphere' then
            local dist = #(coords - currentSafeZone.coords)
            if dist <= currentSafeZone.radius then
                table.insert(entities.vehicles, vehicle)
            end
        elseif currentSafeZone.type == 'box' then
            -- TODO: Добавить проверку для box зон
            table.insert(entities.vehicles, vehicle)
        elseif currentSafeZone.type == 'polygon' then
            -- TODO: Добавить проверку для polygon зон
            table.insert(entities.vehicles, vehicle)
        end
        success, vehicle = FindNextVehicle(handle)
    until not success
    EndFindVehicle(handle)

    return entities
end

-- Поток мониторинга коллизий в зеленой зоне
local function startCollisionMonitor()
    -- Если уже запущен - не запускаем новый
    if collisionMonitorThread then return end

    collisionMonitorThread = CreateThread(function()
        print('Collision monitor started')

        while isInSafeZone and collisionDisabled do
            Wait(250) -- ОПТИМИЗАЦИЯ: увеличили интервал до 250мс

            local playerPed = cache.ped
            if not DoesEntityExist(playerPed) then
                break -- Игрок исчез, выходим
            end

            -- ИСПРАВЛЕНО: Защита от всех типов урона включая столкновения
            -- Параметры: bullet, fire, explosion, collision, melee, steam, p7, drownProof
            SetEntityProofs(playerPed, false, false, false, true, false, false, false, false)
            SetEntityCanBeDamaged(playerPed, false)

            -- Проверяем машину если игрок в ней
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                -- Защищаем транспорт от урона
                SetEntityProofs(vehicle, false, false, false, true, false, false, false, false)
                SetEntityCanBeDamaged(vehicle, false)
                SetEntityInvincible(vehicle, true)
                vehiclesInZone[vehicle] = true
            end

            -- Получаем все энтити в зоне
            local entities = getEntitiesInZone()

            -- ИСПРАВЛЕНО: Отключаем коллизии только между игроками (не со всем миром)
            for _, ped in ipairs(entities.peds) do
                if ped ~= playerPed then
                    -- Отключаем коллизии между текущим игроком и другими игроками
                    disableCollisionBetween(playerPed, ped)

                    -- Если игрок в машине - отключаем коллизии между машиной и другими игроками
                    if vehicle and vehicle ~= 0 then
                        disableCollisionBetween(vehicle, ped)
                    end
                end
            end

            -- ИСПРАВЛЕНО: Отключаем коллизии и урон от транспорта
            for _, veh in ipairs(entities.vehicles) do
                if veh ~= vehicle then
                    -- Отключаем коллизии между игроком и всеми машинами в зоне
                    disableCollisionBetween(playerPed, veh)

                    -- Если игрок в машине - отключаем коллизии между машинами
                    if vehicle and vehicle ~= 0 then
                        disableCollisionBetween(vehicle, veh)
                    end
                end
            end
        end

        print('Collision monitor stopped')
        collisionMonitorThread = nil
    end)
end

local function stopCollisionMonitor()
    if collisionMonitorThread then
        print('Stopping collision monitor')
        collisionMonitorThread = nil
    end

    -- Очищаем списки
    playersInZone = {}

    -- ИСПРАВЛЕНО: Восстанавливаем машины (убираем прозрачность и коллизии)
    for vehicle, _ in pairs(vehiclesInZone) do
        if DoesEntityExist(vehicle) then
            -- Восстанавливаем уязвимость транспорта
            SetEntityProofs(vehicle, false, false, false, false, false, false, false, false)
            SetEntityCanBeDamaged(vehicle, true)
            SetEntityInvincible(vehicle, false)
        end
    end
    vehiclesInZone = {}
end

-- Система отключения коллизий для игроков и транспорта
local function disablePlayerCollisions()
    print('disablePlayerCollisions')
    if collisionDisabled then return end
    collisionDisabled = true

    local playerPed = cache.ped

    -- ИСПРАВЛЕНО: Защита от урона (включая столкновения)
    SetEntityCanBeDamaged(playerPed, false)
    -- Параметры: bullet, fire, explosion, collision, melee, steam, p7, drownProof
    SetEntityProofs(playerPed, false, false, false, true, false, false, false, false)

    -- Если в машине - защищаем машину
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        SetEntityProofs(vehicle, false, false, false, true, false, false, false, false)
        SetEntityCanBeDamaged(vehicle, false)
        SetEntityInvincible(vehicle, true)
        vehiclesInZone[vehicle] = true
    end

    -- Запускаем поток мониторинга коллизий
    startCollisionMonitor()
end

local function enablePlayerCollisions()
    print('enablePlayerCollisions')
    collisionDisabled = false

    -- Останавливаем мониторинг коллизий
    stopCollisionMonitor()

    local playerPed = cache.ped

    -- ИСПРАВЛЕНО: Возвращаем уязвимость игрока
    SetEntityCanBeDamaged(playerPed, true)
    SetEntityProofs(playerPed, false, false, false, false, false, false, false, false)

    -- Возвращаем настройки машины
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        SetEntityProofs(vehicle, false, false, false, false, false, false, false, false)
        SetEntityCanBeDamaged(vehicle, true)
        SetEntityInvincible(vehicle, false)
    end
end

-- Система отключения оружия
local function disableWeapons()
    if weaponsDisabled then return end
    weaponsDisabled = true
    
    CreateThread(function()
        while isInSafeZone and weaponsDisabled do
            local playerPed = cache.ped
            
            -- Отключаем возможность стрелять
            DisableControlAction(0, 24, true) -- INPUT_ATTACK
            DisableControlAction(0, 25, true) -- INPUT_AIM
            DisableControlAction(0, 47, true) -- INPUT_WEAPON_WHEEL_PREV
            DisableControlAction(0, 58, true) -- INPUT_WEAPON_WHEEL_NEXT
            DisableControlAction(0, 140, true) -- INPUT_MELEE_ATTACK_LIGHT
            DisableControlAction(0, 141, true) -- INPUT_MELEE_ATTACK_HEAVY
            DisableControlAction(0, 142, true) -- INPUT_MELEE_ATTACK_ALTERNATE
            DisableControlAction(0, 143, true) -- INPUT_MELEE_BLOCK
            
            -- Убираем оружие из рук
            if GetSelectedPedWeapon(playerPed) ~= GetHashKey('WEAPON_UNARMED') then
                SetCurrentPedWeapon(playerPed, GetHashKey('WEAPON_UNARMED'), true)
            end
            
            -- Отключаем урон от оружия
            SetEntityCanBeDamaged(playerPed, false)
            SetPlayerCanDoDriveBy(cache.playerId, false)
            
            Wait(0)
        end
    end)
end

local function enableWeapons()
    if not weaponsDisabled then return end
    weaponsDisabled = false
    
    local playerPed = cache.ped
    
    -- Включаем урон
    SetEntityCanBeDamaged(playerPed, true)
    SetPlayerCanDoDriveBy(cache.playerId, true)
end

-- Функция входа в зону
local function enterSafeZone(zone)
    print('enterSafeZone')
    if isInSafeZone then return end
    
    isInSafeZone = true
    currentSafeZone = zone
    
    -- Уведомляем сервер о входе в зону
    TriggerServerEvent('hf_safezone:server:playerEnteredZone', zone.id)
    
    -- Применяем настройки зоны
    local zoneSettings = zone.settings or config.settings
    
    if zoneSettings.disablePlayerCollisions then
        disablePlayerCollisions()
    end
    
    if zoneSettings.disableWeapons then
        disableWeapons()
    end
    
    if zoneSettings.godMode then
        SetEntityInvincible(cache.ped, true)
    end
    
    -- Уведомление
    if config.settings.showZoneMessages then
        lib.notify({
            title = locale('safe_zone_enter'),
            description = locale('safe_zone_enter_desc'),
            type = 'success',
            position = config.notifications.position,
            duration = config.notifications.duration
        })
    end
end

-- Функция выхода из зоны
local function exitSafeZone()
    if not isInSafeZone then return end
    
    -- Уведомляем сервер о выходе из зоны
    TriggerServerEvent('hf_safezone:server:playerExitedZone')
    
    isInSafeZone = false
    currentSafeZone = nil
    
    -- Восстанавливаем настройки
    enablePlayerCollisions()
    enableWeapons()
    SetEntityInvincible(cache.ped, false)
    
    -- Уведомление
    if config.settings.showZoneMessages then
        lib.notify({
            title = locale('safe_zone_exit'),
            description = locale('safe_zone_exit_desc'),
            type = 'info',
            position = config.notifications.position,
            duration = config.notifications.duration
        })
    end
end

-- Функция создания зоны в зависимости от типа
local function createZone(zoneData)
    local zone = nil
    
    if zoneData.type == 'sphere' then
        zone = lib.zones.sphere({
            coords = zoneData.coords,
            radius = zoneData.radius,
            debug = zoneData.debug or config.settings.debug,
            onEnter = function()
                enterSafeZone(zoneData)
            end,
            onExit = function()
                exitSafeZone()
            end,
            inside = function()
                -- Дополнительные проверки внутри зоны
                if isInSafeZone and currentSafeZone and currentSafeZone.id == zoneData.id then
                    local zoneSettings = zoneData.settings or config.settings
                    
                    -- Проверяем попытки использовать оружие
                    if zoneSettings.disableWeapons and IsControlPressed(0, 24) then
                        lib.notify({
                            title = locale('weapons_disabled'),
                            type = 'error',
                            duration = 2000
                        })
                    end
                end
            end
        })
    elseif zoneData.type == 'box' then
        zone = lib.zones.box({
            coords = zoneData.coords,
            size = zoneData.size,
            rotation = zoneData.rotation or 0.0,
            debug = zoneData.debug or config.settings.debug,
            onEnter = function()
                enterSafeZone(zoneData)
            end,
            onExit = function()
                exitSafeZone()
            end,
            inside = function()
                if isInSafeZone and currentSafeZone and currentSafeZone.id == zoneData.id then
                    local zoneSettings = zoneData.settings or config.settings
                    
                    if zoneSettings.disableWeapons and IsControlPressed(0, 24) then
                        lib.notify({
                            title = locale('weapons_disabled'),
                            type = 'error',
                            duration = 2000
                        })
                    end
                end
            end
        })
    elseif zoneData.type == 'polygon' then
        zone = lib.zones.poly({
            points = zoneData.points,
            thickness = zoneData.thickness or 30.0,
            debug = zoneData.debug or config.settings.debug,
            onEnter = function()
                enterSafeZone(zoneData)
            end,
            onExit = function()
                exitSafeZone()
            end,
            inside = function()
                if isInSafeZone and currentSafeZone and currentSafeZone.id == zoneData.id then
                    local zoneSettings = zoneData.settings or config.settings
                    
                    if zoneSettings.disableWeapons and IsControlPressed(0, 24) then
                        lib.notify({
                            title = locale('weapons_disabled'),
                            type = 'error',
                            duration = 2000
                        })
                    end
                end
            end
        })
    end
    
    if zone then
        zone.zoneData = zoneData
        activeZones[zoneData.id] = zone
    end
    
    return zone
end

-- Функция создания всех зон
local function createAllZones()
    for _, zoneData in ipairs(config.safeZones) do
        createZone(zoneData)
    end
end

-- Функция удаления всех зон
local function removeAllZones()
    for _, zone in pairs(activeZones) do
        if zone and zone.remove then
            zone:remove()
        end
    end
    activeZones = {}
end

-- События

-- ДОБАВЛЕНО: Дополнительный поток защиты от урона транспорта
CreateThread(function()
    while true do
        -- ОПТИМИЗАЦИЯ: Используем 100мс вместо каждого кадра (0ms)
        Wait(isInSafeZone and 100 or 1000)

        if isInSafeZone then
            local playerPed = cache.ped

            -- Защищаем игрока от урона любого типа в зоне
            if DoesEntityExist(playerPed) then
                -- Сбрасываем урон если получен
                local currentHealth = GetEntityHealth(playerPed)
                local maxHealth = GetEntityMaxHealth(playerPed)

                if currentHealth < maxHealth and currentHealth > 0 then
                    SetEntityHealth(playerPed, maxHealth)
                    ClearPedBloodDamage(playerPed)
                end

                -- Если в машине - защищаем машину
                local vehicle = GetVehiclePedIsIn(playerPed, false)
                if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                    -- Восстанавливаем здоровье машины только если повреждена
                    local vehHealth = GetVehicleBodyHealth(vehicle)
                    if vehHealth < 1000.0 then
                        SetVehicleBodyHealth(vehicle, 1000.0)
                        SetVehicleEngineHealth(vehicle, 1000.0)
                        SetVehiclePetrolTankHealth(vehicle, 1000.0)
                    end
                end
            end
        end
    end
end)

-- Обработка урона в зеленой зоне
AddEventHandler('gameEventTriggered', function(event, args)
    if event == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local attacker = args[2]
        local isDead = args[4]
        local weaponHash = args[5]

        -- Если жертва - текущий игрок и он в зеленой зоне
        if victim == cache.ped and isInSafeZone and currentSafeZone then
            local zoneSettings = currentSafeZone.settings or config.settings

            if zoneSettings.disablePvP or zoneSettings.disableWeapons or zoneSettings.disableVehicleCollisions then
                -- Полностью отменяем урон
                local maxHealth = GetEntityMaxHealth(cache.ped)
                SetEntityHealth(cache.ped, maxHealth)
                ClearPedBloodDamage(cache.ped)

                -- ДОБАВЛЕНО: Проверяем если урон от транспорта
                if DoesEntityExist(attacker) then
                    local isAttackerVehicle = IsEntityAVehicle(attacker)

                    if isAttackerVehicle and zoneSettings.disableVehicleCollisions then
                        -- Транспорт наносит урон - полностью блокируем
                        SetEntityHealth(cache.ped, maxHealth)
                        ClearPedBloodDamage(cache.ped)

                        lib.notify({
                            title = locale('safe_zone_active'),
                            description = 'Вы защищены от транспорта в зоне',
                            type = 'inform',
                            duration = 2000
                        })
                    elseif not isAttackerVehicle and attacker ~= cache.ped then
                        -- Урон от игрока
                        local attackerCoords = GetEntityCoords(attacker)
                        local isAttackerInZone = false

                        if currentSafeZone.type == 'sphere' then
                            local dist = #(attackerCoords - currentSafeZone.coords)
                            isAttackerInZone = dist <= currentSafeZone.radius
                        end

                        if not isAttackerInZone then
                            lib.notify({
                                title = locale('pvp_disabled'),
                                description = 'Вы защищены в безопасной зоне',
                                type = 'error',
                                duration = 2000
                            })
                        end
                    end
                end
            end
        end

        -- Защита для тех кто в машине в зоне
        if victim == cache.ped and IsPedInAnyVehicle(victim, false) and isInSafeZone then
            local vehVictim = GetVehiclePedIsIn(victim, false)
            if vehiclesInZone[vehVictim] and vehVictim and vehVictim ~= 0 then
                -- Отменяем урон по машине и игроку
                SetEntityHealth(victim, GetEntityMaxHealth(victim))
                SetVehicleBodyHealth(vehVictim, 1000.0)
                SetVehicleEngineHealth(vehVictim, 1000.0)
                SetVehiclePetrolTankHealth(vehVictim, 1000.0)
            end
        end
    end
end)

-- Обработчик входа/выхода из машины в зоне
RegisterNetEvent('baseevents:enteredVehicle', function(vehicle, seat, displayName)
    if isInSafeZone and collisionDisabled and vehicle and vehicle ~= 0 then
        -- ИСПРАВЛЕНО: Защищаем машину от урона
        SetEntityProofs(vehicle, false, false, false, true, false, false, false, false)
        SetEntityCanBeDamaged(vehicle, false)
        SetEntityInvincible(vehicle, true)
        vehiclesInZone[vehicle] = true
    end
end)

RegisterNetEvent('baseevents:leftVehicle', function(vehicle, seat, displayName)
    if isInSafeZone and vehiclesInZone[vehicle] and vehicle and vehicle ~= 0 then
        -- ИСПРАВЛЕНО: Машина остается защищенной пока в зоне
        SetEntityProofs(vehicle, false, false, false, true, false, false, false, false)
        SetEntityCanBeDamaged(vehicle, false)
        SetEntityInvincible(vehicle, true)
    end
end)

-- События для управления зонами
RegisterNetEvent('hf_safezone:client:createZone', function(zoneData)
    createZone(zoneData)
end)

RegisterNetEvent('hf_safezone:client:removeZone', function(zoneId)
    if activeZones[zoneId] then
        activeZones[zoneId]:remove()
        activeZones[zoneId] = nil
    end
end)

RegisterNetEvent('hf_safezone:client:updateZones', function(newConfig)
    removeAllZones()
    config = newConfig
    createAllZones()
end)


-- Инициализация при загрузке игрока
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    createAllZones()
end)

-- Основной поток инициализации
CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(100)
    end
    
    print('Create All zone')
    createAllZones()
end)

-- Очистка при остановке ресурса
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Восстанавливаем все настройки
    if isInSafeZone then
        enablePlayerCollisions()
        enableWeapons()
        SetEntityInvincible(cache.ped, false)
    end
    
    -- Удаляем все зоны
    removeAllZones()
end)

-- Экспорт функций для других ресурсов
exports('createZone', createZone)
exports('removeZone', function(zoneId)
    if activeZones[zoneId] then
        activeZones[zoneId]:remove()
        activeZones[zoneId] = nil
    end
end)
-- Обработчик синхронизации игроков в зоне
RegisterNetEvent('hf_safezone:client:syncPlayers', function(playersInZone)
    playersInZone = playersInZone or {}
    
    -- Обновляем список других игроков в зоне
    for _, playerSource in ipairs(playersInZone) do
        if playerSource ~= GetPlayerServerId(PlayerId()) then
            local playerPed = GetPlayerPed(GetPlayerFromServerId(playerSource))
            if DoesEntityExist(playerPed) then
                -- Отключаем коллизии между игроками в зоне
                disableCollisionBetween(cache.ped, playerPed)
            end
        end
    end
end)

-- Обработчик отмены урона
RegisterNetEvent('hf_safezone:client:cancelDamage', function()
    local playerPed = cache.ped
    local maxHealth = GetEntityMaxHealth(playerPed)
    SetEntityHealth(playerPed, maxHealth)
    ClearPedBloodDamage(playerPed)
end)

-- Экспорты
exports('isPlayerInSafeZone', function()
    return isInSafeZone
end)
exports('getCurrentSafeZone', function()
    return currentSafeZone
end)

-- Экспорт для других ресурсов для проверки иммунитета
exports('hasCollisionImmunity', function(playerSource)
    local playerPed = GetPlayerPed(GetPlayerFromServerId(playerSource))
    return DoesEntityExist(playerPed) and GetEntityCollisionDisabled(playerPed)
end)