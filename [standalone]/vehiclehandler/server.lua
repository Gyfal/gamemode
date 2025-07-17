if not lib then print('^1ox_lib must be started before this resource.^0') return end

lib.versionCheck("QuantumMalice/vehiclehandler")

if GetResourceState('ox_inventory') == 'started' then
    exports('cleaningkit', function(event, item, inventory)
        if event == 'usingItem' then
            local success = lib.callback.await('vehiclehandler:basicwash', inventory.id)
            if success then return else return false end
        end
    end)

    exports('tirekit', function(event, item, inventory)
        if event == 'usingItem' then
            local success = lib.callback.await('vehiclehandler:basicfix', inventory.id, 'tirekit')
            if success then return else return false end
        end
    end)

    exports('repairkit', function(event, item, inventory)
        if event == 'usingItem' then
            local success = lib.callback.await('vehiclehandler:basicfix', inventory.id, 'smallkit')
            if success then return else return false end
        end
    end)

    exports('advancedrepairkit', function(event, item, inventory)
        if event == 'usingItem' then
            local success = lib.callback.await('vehiclehandler:basicfix', inventory.id, 'bigkit')
            if success then return else return false end
        end
    end)
end

lib.callback.register('vehiclehandler:sync', function()
    return true
end)

lib.addCommand('fix', {
    help = 'Repair current vehicle',
    restricted = 'group.admin'
}, function(source)
    lib.callback('vehiclehandler:adminfix', source, function() end)
end)

lib.addCommand('wash', {
    help = 'Clean current vehicle',
    restricted = 'group.admin'
}, function(source)
    lib.callback('vehiclehandler:adminwash', source, function() end)
end)

lib.addCommand('setfuel', {
    help = 'Set vehicle fuel level',
    params = {
        {
            name = 'level',
            type = 'number',
            help = 'Amount of fuel to set',
        },
    },
    restricted = 'group.admin'
}, function(source, args)
    local level = args.level

    if level then
        lib.callback('vehiclehandler:adminfuel', source, function() end, level)
    end
end)

lib.addCommand('coords', {
    help = 'Показать текущие координаты игрока',
    restricted = 'group.admin'
}, function(source)
    local playerPed = GetPlayerPed(source)
    if playerPed and playerPed ~= 0 then
        local coords = GetEntityCoords(playerPed)
        local heading = GetEntityHeading(playerPed)
        
        -- Вывод в консоль сервера
        print(string.format("^2[DEBUG] Координаты игрока %s [%d]:^0", GetPlayerName(source), source))
        print(string.format("^3X: %.2f, Y: %.2f, Z: %.2f, H: %.2f^0", coords.x, coords.y, coords.z, heading))
        print(string.format("^5Вектор: vector3(%.2f, %.2f, %.2f)^0", coords.x, coords.y, coords.z))
        print(string.format("^5Вектор с поворотом: vector4(%.2f, %.2f, %.2f, %.2f)^0", coords.x, coords.y, coords.z, heading))
        
        -- Отправка сообщения игроку
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"[DEBUG]", string.format("Ваши координаты: %.2f, %.2f, %.2f, %.2f", coords.x, coords.y, coords.z, heading)}
        })
    else
        print("^1[ERROR] Не удалось получить координаты игрока^0")
    end
end)