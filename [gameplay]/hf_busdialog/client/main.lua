local Config = require('config')

local Open = false
local cam = nil
local Peds = {}
local Actions = {}

-- Открытие диалога
local function OpenDialog(options)
    if Open then return end

    Open = true

    -- Создание камеры если включена
    if Config.Camera.enabled and options.ped then
        local pedCoords = GetEntityCoords(options.ped)
        local pedHeading = GetEntityHeading(options.ped)

        -- Рассчитываем позицию камеры
        local camOffset = vector3(
            Config.Camera.offsetX or 0.5,
            Config.Camera.offsetY or 0.5,
            Config.Camera.offsetZ or 0.0
        )

        local camPos = GetOffsetFromEntityInWorldCoords(options.ped, camOffset.x, camOffset.y, camOffset.z + 0.6)

        cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
        PointCamAtEntity(cam, options.ped, 0.0, 0.0, 0.5, true)
        SetCamFov(cam, Config.Camera.fov or 30.0)
        SetCamActive(cam, true)
        RenderScriptCams(true, true, 500, true, true)
    end

    -- Отправка данных в UI
    SendNUIMessage({
        action = 'open',
        data = options.data
    })

    SetNuiFocus(true, true)
end

-- Установка диалога
local function SetDialog(data)
    SendNUIMessage({
        action = 'setDialog',
        data = data
    })
end

-- Закрытие диалога
local function CloseDialog()
    if not Open then return end

    Open = false

    -- Удаление камеры
    if cam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(cam, false)
        cam = nil
    end

    SendNUIMessage({
        action = 'close'
    })

    SetNuiFocus(false, false)
end

-- Спавн педа по ID
local function SpawnPedByID(id)
    if Peds[id] then return end

    local pedConfig = Config.peds[id]
    if not pedConfig then return end

    -- Загрузка модели
    local modelHash = GetHashKey(pedConfig.model)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(0)
    end

    -- Создание педа
    local ped = CreatePed(4, modelHash, pedConfig.coords.x, pedConfig.coords.y, pedConfig.coords.z - 1.0, pedConfig.coords.w, false, true)

    -- Настройка педа
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    Peds[id] = ped

    -- Добавление таргета
    if Config.Target == 'ox' then
        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'dialog_' .. id,
                icon = pedConfig.icon or 'fas fa-comment',
                label = pedConfig.label or 'Поговорить',
                onSelect = function()
                    OpenDialog({
                        ped = ped,
                        data = pedConfig.data[1]
                    })
                end
            }
        })
    elseif Config.Target == 'qb' then
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    icon = pedConfig.icon or 'fas fa-comment',
                    label = pedConfig.label or 'Поговорить',
                    action = function()
                        OpenDialog({
                            ped = ped,
                            data = pedConfig.data[1]
                        })
                    end
                }
            },
            distance = 2.5
        })
    end

    SetModelAsNoLongerNeeded(modelHash)
end

-- Удаление педа по ID
local function DeletePedByID(id)
    if not Peds[id] then return end

    DeleteEntity(Peds[id])
    Peds[id] = nil
end

-- NUI Callback для обработки кликов
RegisterNUICallback('click', function(data, cb)
    cb('ok')

    if data.close then
        CloseDialog()
        return
    end

    if data.data then
        SetDialog(data.data)
    end

    if data.event then
        if data.type == 'server' then
            TriggerServerEvent(data.event)
        else
            TriggerEvent(data.event)
        end

        CloseDialog()
    end
end)

-- NUI Callback для закрытия
RegisterNUICallback('close', function(data, cb)
    cb('ok')
    CloseDialog()
end)

-- Инициализация
CreateThread(function()
    -- Ждем загрузки фреймворка если указано
    if Config.FrameworkLoadingEvent and Config.FrameworkLoadingEvent ~= '' then
        RegisterNetEvent(Config.FrameworkLoadingEvent, function()
            for id, _ in pairs(Config.peds) do
                SpawnPedByID(id)
            end
        end)
    else
        -- Спавним педов сразу
        for id, _ in pairs(Config.peds) do
            SpawnPedByID(id)
        end
    end
end)

-- Очистка при остановке ресурса
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    for id, _ in pairs(Peds) do
        DeletePedByID(id)
    end

    CloseDialog()
end)

-- Экспорты
exports('OpenDialog', OpenDialog)
exports('SetDialog', SetDialog)
exports('CloseDialog', CloseDialog)
exports('SpawnPed', SpawnPedByID)
