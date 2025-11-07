local Config = require('config')

local Open = false
local cam = nil
local Peds = {}
local PedData = {} -- Хранит данные о педах (имя, позиция и т.д.)
local currentPed = nil -- Текущий пед с которым взаимодействуем
local nameTagThread = nil
local interactionThread = nil

-- Открытие диалога
local function OpenDialog(options)
    if Open then return end

    Open = true
    currentPed = options.ped

    -- Скрыть HUD
    DisplayRadar(false)

    -- Создание камеры в стиле от первого лица
    if Config.Camera.enabled and options.ped then
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local pedCoords = GetEntityCoords(options.ped)
        local pedHeading = GetEntityHeading(options.ped)

        -- Позиция камеры - чуть выше и впереди игрока, смотрит на NPC
        local camPos = vector3(
            playerCoords.x,
            playerCoords.y,
            playerCoords.z + 0.7
        )

        cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamCoord(cam, camPos.x, camPos.y, camPos.z)

        -- Направляем камеру на голову NPC
        PointCamAtCoord(cam, pedCoords.x, pedCoords.y, pedCoords.z + 0.6)

        SetCamFov(cam, Config.Camera.fov or 50.0)
        SetCamActive(cam, true)
        RenderScriptCams(true, true, 500, true, true)
    end

    -- Отправка данных в UI
    SendNUIMessage({
        action = 'open',
        npcName = options.npcName or 'NPC',
        dialogs = options.dialogs or {}
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
    currentPed = nil

    -- Показать HUD
    DisplayRadar(true)

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

-- Отрисовка 3D текста
local function Draw3DText(coords, text, scale)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)

    if onScreen then
        SetTextScale(scale, scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 255)
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(x, y)
    end
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
    PedData[ped] = {
        id = id,
        name = pedConfig.name or 'NPC',
        coords = pedConfig.coords,
        dialogs = pedConfig.dialogs or {}
    }

    SetModelAsNoLongerNeeded(modelHash)
end

-- Удаление педа по ID
local function DeletePedByID(id)
    if not Peds[id] then return end

    local ped = Peds[id]
    PedData[ped] = nil
    DeleteEntity(ped)
    Peds[id] = nil
end

-- NUI Callback для обработки действий
RegisterNUICallback('action', function(data, cb)
    cb('ok')

    if data.event then
        if data.type == 'server' then
            TriggerServerEvent(data.event)
        else
            TriggerEvent(data.event)
        end

        if data.closeAfter then
            CloseDialog()
        end
    end
end)

-- NUI Callback для закрытия
RegisterNUICallback('close', function(data, cb)
    cb('ok')
    CloseDialog()
end)

-- Поток для отображения 3D имен и подсказок взаимодействия
local function StartNameTagAndInteractionThread()
    if nameTagThread then return end

    nameTagThread = CreateThread(function()
        local sleepTime = 0

        while true do
            Wait(sleepTime)
            sleepTime = 500 -- По умолчанию спим долго

            if not Open then
                local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                local nearestPed = nil
                local nearestDist = 999999

                for ped, data in pairs(PedData) do
                    if DoesEntityExist(ped) then
                        local pedCoords = GetEntityCoords(ped)
                        local dist = #(playerCoords - pedCoords)

                        -- Отрисовка имени если близко
                        if dist < 10.0 then
                            sleepTime = 0
                            local nameCoords = vector3(pedCoords.x, pedCoords.y, pedCoords.z + 1.1)
                            Draw3DText(nameCoords, data.name, 0.35)

                            -- Проверяем ближайшего педа для взаимодействия
                            if dist < nearestDist and dist < Config.InteractionDistance then
                                nearestPed = ped
                                nearestDist = dist
                            end
                        end
                    end
                end

                -- Показываем подсказку для ближайшего педа
                if nearestPed then
                    SendNUIMessage({
                        action = 'showPrompt',
                        text = 'Нажмите [E] чтобы поговорить'
                    })

                    -- Проверка нажатия E
                    if IsControlJustPressed(0, 38) then -- E key
                        local data = PedData[nearestPed]
                        OpenDialog({
                            ped = nearestPed,
                            npcName = data.name,
                            dialogs = data.dialogs
                        })
                    end
                else
                    SendNUIMessage({
                        action = 'hidePrompt'
                    })
                end
            else
                sleepTime = 500
            end
        end
    end)
end

-- Инициализация
CreateThread(function()
    -- Ждем загрузки фреймворка если указано
    if Config.FrameworkLoadingEvent and Config.FrameworkLoadingEvent ~= '' then
        RegisterNetEvent(Config.FrameworkLoadingEvent, function()
            for id, _ in pairs(Config.peds) do
                SpawnPedByID(id)
            end
            StartNameTagAndInteractionThread()
        end)
    else
        -- Спавним педов сразу
        for id, _ in pairs(Config.peds) do
            SpawnPedByID(id)
        end
        StartNameTagAndInteractionThread()
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
