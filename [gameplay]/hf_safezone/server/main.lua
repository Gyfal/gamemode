require 'config.shared'

-- Локальные переменные для синхронизации
local playersInZones = {} -- {[source] = zoneId}
local zonesData = {} -- Хранение данных зон

-- Функция для синхронизации игроков в зоне
local function syncPlayersInZone(zoneId)
    local playersInThisZone = {}
    for source, zone in pairs(playersInZones) do
        if zone == zoneId then
            table.insert(playersInThisZone, source)
        end
    end
    
    -- Отправляем всем игрокам в зоне список других игроков
    for _, source in ipairs(playersInThisZone) do
        TriggerClientEvent('hf_safezone:client:syncPlayers', source, playersInThisZone)
    end
end

-- Событие входа игрока в зону
RegisterNetEvent('hf_safezone:server:playerEnteredZone', function(zoneId)
    local source = source
    playersInZones[source] = zoneId
    
    -- Синхронизируем с другими игроками
    syncPlayersInZone(zoneId)
    
    -- QBOX интеграция
    if QBX and QBX.Functions then
        local player = QBX.Functions.GetPlayer(source)
        if player then
            -- Сохраняем метаданные
            exports.qbx_core:SetMetadata(source, 'inSafeZone', true)
            exports.qbx_core:SetMetadata(source, 'safeZoneId', zoneId)
            
            -- Автоматически отключаем PVP для игрока через QBOX
            TriggerClientEvent('QBCore:Client:SetDuty', source, false)
            
            -- Логируем событие
            local playerName = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
            print(string.format('^3[SAFE ZONE] ^0Player %s (%s) entered zone %s^0', playerName, player.PlayerData.citizenid, zoneId))
            
            -- Уведомление через QBOX систему
            exports.qbx_core:Notify(source, {
                text = 'Вы вошли в безопасную зону',
                caption = zonesData[zoneId] and zonesData[zoneId].name or 'Безопасная зона'
            }, 'success', 3000)
        end
    end
    
    -- Триггерим хук для других ресурсов
    TriggerEvent('hf_safezone:server:playerEntered', source, zoneId)
end)

-- Событие выхода игрока из зоны
RegisterNetEvent('hf_safezone:server:playerExitedZone', function()
    local source = source
    local zoneId = playersInZones[source]
    
    if zoneId and source then
        playersInZones[source] = nil
        syncPlayersInZone(zoneId)
        
        -- QBOX интеграция для выхода
        if QBX and QBX.Functions then
            local player = QBX.Functions.GetPlayer(source)
            if player then
                -- Очищаем метаданные
                exports.qbx_core:SetMetadata(source, 'inSafeZone', false)
                exports.qbx_core:SetMetadata(source, 'safeZoneId', nil)
                
                -- Логируем событие
                local playerName = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
                print(string.format('^1[SAFE ZONE] ^0Player %s (%s) exited zone %s^0', playerName, player.PlayerData.citizenid, zoneId))
                
                -- Уведомление через QBOX
                -- exports.qbx_core:Notify(source, 'Вы покинули безопасную зону', 'inform', 2000)
            end
        end
        
        -- Триггерим хук для других ресурсов
        TriggerEvent('hf_safezone:server:playerExited', source, zoneId)
    end
end)


-- Очистка при отключении игрока
AddEventHandler('playerDropped', function()
    local source = source
    if playersInZones[source] then
        local zoneId = playersInZones[source]
        playersInZones[source] = nil
        syncPlayersInZone(zoneId)
    end
end)

-- Экспорт для проверки находится ли игрок в зоне
exports('IsPlayerInSafeZone', function(source)
    return playersInZones[source] ~= nil
end)

exports('GetPlayerSafeZone', function(source)
    return playersInZones[source]
end)

-- Дополнительные экспорты для QBOX интеграции
exports('GetPlayersInZone', function(zoneId)
    local players = {}
    for source, zone in pairs(playersInZones) do
        if zone == zoneId then
            table.insert(players, source)
        end
    end
    return players
end)

exports('GetZoneInfo', function(zoneId)
    return zonesData[zoneId]
end)

exports('CreateZoneFromData', function(zoneData)
    if zoneData and zoneData.id then
        zonesData[zoneData.id] = zoneData
        TriggerClientEvent('hf_safezone:client:createZone', -1, zoneData)
        return true
    end
    return false
end)

-- Ожидаем загрузки QBX перед регистрацией команд
CreateThread(function()
    -- Ждем пока QBX будет доступен
    while not QBX do
        Wait(100)
    end
        
    -- Команда проверки игроков в зоне (для админов)
    QBX.Commands.Add('checkzone', 'Проверить игроков в зоне', {}, false, function(source, args)
        if not IsPlayerAceAllowed(source, 'command.checkzone') then
            exports.qbx_core:Notify(source, 'У вас недостаточно прав', 'error')
            return
        end
        
        local zonesList = {}
        for src, zoneId in pairs(playersInZones) do
            if not zonesList[zoneId] then
                zonesList[zoneId] = {}
            end
            local player = QBX.Functions.GetPlayer(src)
            if player then
                local name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
                table.insert(zonesList[zoneId], name)
            end
        end
        
        for zoneId, players in pairs(zonesList) do
            local message = string.format('Зона %s: %s', zoneId, table.concat(players, ', '))
            exports.qbx_core:Notify(source, message, 'inform', 5000)
        end
        
        if next(zonesList) == nil then
            exports.qbx_core:Notify(source, 'Нет игроков в безопасных зонах', 'inform')
        end
    end)
    
    print('^2[SAFE ZONE] ^0Resource loaded successfully^0')
end)