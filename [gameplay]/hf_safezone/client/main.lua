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
    
    -- Получаем всех педов в радиусе
    local handle, ped = FindFirstPed()
    local success
    repeat
        local coords = GetEntityCoords(ped)
        if currentSafeZone and currentSafeZone.type == 'sphere' then
            local dist = #(coords - currentSafeZone.coords)
            if dist <= currentSafeZone.radius then
                table.insert(entities.peds, ped)
            end
        end
        success, ped = FindNextPed(handle)
    until not success
    EndFindPed(handle)
    
    -- Получаем все машины в радиусе  
    local handle, vehicle = FindFirstVehicle()
    local success
    repeat
        local coords = GetEntityCoords(vehicle)
        if currentSafeZone and currentSafeZone.type == 'sphere' then
            local dist = #(coords - currentSafeZone.coords)
            if dist <= currentSafeZone.radius then
                table.insert(entities.vehicles, vehicle)
            end
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
            Wait(100) -- Проверяем каждые 100мс для более быстрой реакции
            
            local playerPed = cache.ped
            if not DoesEntityExist(playerPed) then
                break -- Игрок исчез, выходим
            end
            
            -- Отключаем коллизии для игрока
            SetEntityCompletelyDisableCollision(playerPed, true, false)
            SetEntityAlpha(playerPed, 200, false)
            SetEntityCanBeDamaged(playerPed, false)
            
            -- Проверяем машину если игрок в ней
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            if vehicle and DoesEntityExist(vehicle) then
                SetEntityCompletelyDisableCollision(vehicle, true, false) 
                SetEntityAlpha(vehicle, 200, false)
                vehiclesInZone[vehicle] = true
            end
            
            -- Получаем все энтити в зоне
            local entities = getEntitiesInZone()
            
            -- Отключаем коллизии для всех педов в зоне
            for _, ped in ipairs(entities.peds) do
                if ped ~= playerPed then
                    -- Отключаем коллизии между игроком и другими педами в зоне
                    disableCollisionBetween(playerPed, ped)
                    if vehicle then
                        disableCollisionBetween(vehicle, ped)
                    end
                end
            end
            
            -- Отключаем коллизии для всех машин в зоне
            for _, veh in ipairs(entities.vehicles) do
                if veh ~= vehicle then
                    -- Отключаем коллизии с другими машинами в зоне
                    disableCollisionBetween(playerPed, veh)
                    if vehicle then
                        disableCollisionBetween(vehicle, veh)
                    end
                    
                    -- Делаем другие машины прозрачными
                    if not vehiclesInZone[veh] then
                        SetEntityCompletelyDisableCollision(veh, true, false)
                        SetEntityAlpha(veh, 200, false)
                        vehiclesInZone[veh] = true
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
    
    -- Восстанавливаем машины
    for vehicle, _ in pairs(vehiclesInZone) do
        if DoesEntityExist(vehicle) then
            SetEntityCompletelyDisableCollision(vehicle, false, false)
            SetEntityAlpha(vehicle, 255, false)
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
    
    -- Делаем игрока призраком
    SetEntityCompletelyDisableCollision(playerPed, true, false)
    SetEntityAlpha(playerPed, 200, false)
    
    -- Защита от урона
    SetEntityCanBeDamaged(playerPed, false)
    SetEntityProofs(playerPed, true, true, true, true, true, true, true, true)
    
    -- Если в машине - делаем машину призраком
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if vehicle and DoesEntityExist(vehicle) then
        SetEntityCompletelyDisableCollision(vehicle, true, false)
        SetEntityAlpha(vehicle, 200, false)
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
    
    -- Возвращаем коллизии и видимость
    SetEntityCompletelyDisableCollision(playerPed, false, false)
    SetEntityAlpha(playerPed, 255, false)
    
    -- Возвращаем уязвимость
    SetEntityCanBeDamaged(playerPed, true)
    SetEntityProofs(playerPed, false, false, false, false, false, false, false, false)
    
    -- Возвращаем коллизии машины
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if vehicle and DoesEntityExist(vehicle) then
        SetEntityCompletelyDisableCollision(vehicle, false, false)
        SetEntityAlpha(vehicle, 255, false)
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
            
            if zoneSettings.disablePvP or zoneSettings.disableWeapons then
                -- Полностью отменяем урон
                local maxHealth = GetEntityMaxHealth(cache.ped)
                SetEntityHealth(cache.ped, maxHealth)
                ClearPedBloodDamage(cache.ped)
                
                -- Если атакующий вне зоны - показываем уведомление
                if DoesEntityExist(attacker) and attacker ~= cache.ped then
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
        
        -- Защита для тех кто в машине в зоне
        if IsPedInAnyVehicle(victim, false) then
            local vehVictim = GetVehiclePedIsIn(victim, false)
            if vehiclesInZone[vehVictim] then
                -- Отменяем урон по машине
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
    if isInSafeZone and collisionDisabled then
        -- Отключаем коллизии для новой машины
        SetEntityCompletelyDisableCollision(vehicle, true, false)
        SetEntityAlpha(vehicle, 200, false)
        vehiclesInZone[vehicle] = true
    end
end)

RegisterNetEvent('baseevents:leftVehicle', function(vehicle, seat, displayName)
    if isInSafeZone and vehiclesInZone[vehicle] then
        -- Машина остается призраком пока в зоне
        SetEntityCompletelyDisableCollision(vehicle, true, false)
        SetEntityAlpha(vehicle, 200, false)
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