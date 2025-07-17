local config = require 'config.client'
local sharedConfig = require 'config.shared'
local serverConfig = require 'config.server'

-- Локальные переменные
local jobNPC = nil
local jobBlip = nil
local currentTruck = nil
local currentRoute = {}
local currentPoint = 1
local currentTargetBlip = nil
local isWorking = false
local isCollecting = false
local isDumping = false
local garbageCollected = 0
local maxCapacity = 10
local totalEarnings = 0
local npcCreated = false

-- Таймер выхода из мусоровоза
local leaveStartTime = nil
local leaveTimeout = config.leaveTruckTimeout or 45000

-- Основной игровой цикл
local mainLoopActive = false

-- Создание NPC для устройства на работу
local function createJobNPC()
    if npcCreated then return end
    local npcConfig = sharedConfig.jobNPC

    -- Загрузка модели
    lib.requestModel(npcConfig.model, 10000)

    -- Создание педа
    jobNPC = CreatePed(4, npcConfig.model, npcConfig.coords.x, npcConfig.coords.y, npcConfig.coords.z - 1.0,
        npcConfig.coords.w, false, true)

    -- Настройка педа
    SetEntityInvincible(jobNPC, true)
    FreezeEntityPosition(jobNPC, true)
    SetBlockingOfNonTemporaryEvents(jobNPC, true)

    -- Добавление взаимодействия через ox_target
    exports.ox_target:addLocalEntity(jobNPC, {
        {
            name = 'garbagejob_hire',
            icon = 'fas fa-briefcase',
            label = 'Устроиться мусорщиком',
            canInteract = function()
                return not isWorking and QBX.PlayerData and QBX.PlayerData.job.name ~= serverConfig.job.name
            end,
            onSelect = function()
                TriggerServerEvent('qbx_garbagejob:server:startJob')
            end
        },
        {
            name = 'garbagejob_get_truck',
            icon = 'fas fa-truck',
            label = 'Взять мусоровоз',
            canInteract = function()
                return not isWorking and QBX.PlayerData and QBX.PlayerData.job.name == serverConfig.job.name
            end,
            onSelect = function()
                TriggerServerEvent('qbx_garbagejob:server:requestTruck')
            end
        },
        {
            name = 'garbagejob_quit',
            icon = 'fas fa-times',
            label = 'Уволиться',
            canInteract = function()
                return QBX.PlayerData and QBX.PlayerData.job.name == serverConfig.job.name
            end,
            onSelect = function()
                TriggerServerEvent('qbx_garbagejob:server:quitJob')
            end
        }
    })

    -- Создание блипа
    if npcConfig.blip.enabled then
        jobBlip = AddBlipForCoord(npcConfig.coords.x, npcConfig.coords.y, npcConfig.coords.z)
        SetBlipSprite(jobBlip, npcConfig.blip.sprite)
        SetBlipDisplay(jobBlip, 4)
        SetBlipScale(jobBlip, npcConfig.blip.scale)
        SetBlipColour(jobBlip, npcConfig.blip.color)
        SetBlipAsShortRange(jobBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(npcConfig.blip.label)
        EndTextCommandSetBlipName(jobBlip)
    end

    npcCreated = true
end

-- Завершение работы
local function endWork()
    leaveStartTime = nil
    isWorking = false
    isCollecting = false
    isDumping = false
    garbageCollected = 0
    currentRoute = {}
    currentPoint = 1

    -- Удаление мусоровоза
    if currentTruck and DoesEntityExist(currentTruck) then
        SetEntityAsMissionEntity(currentTruck, true, true)
        DeleteVehicle(currentTruck)
    end

    -- Удаление блипов
    if currentTargetBlip then
        RemoveBlip(currentTargetBlip)
        currentTargetBlip = nil
    end

    currentTruck = nil
    totalEarnings = 0

    lib.notify({
        title = 'Работа завершена',
        description = 'Вы закончили работу мусорщиком',
        type = 'info'
    })
end

-- События
RegisterNetEvent('qbx_garbagejob:client:endWork', endWork)

-- Удаление мусоровоза по команде сервера
RegisterNetEvent('qbx_garbagejob:client:deleteVehicle', function(truckNetId)
    local veh = NetworkGetEntityFromNetworkId(truckNetId)
    if DoesEntityExist(veh) then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
        print('^3[GARBAGE JOB CLIENT] ^2Мусоровоз удален клиентом (NetID: ' .. truckNetId .. ')^0')
    end
end)

-- Обработка загрузки игрока
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    createJobNPC()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if jobNPC then
        DeletePed(jobNPC)
    end

        RemoveBlip(jobBlip)
    end
    endWork()
end)

-- Основной поток
CreateThread(function()
    -- Дожидаемся загрузки игрока
    while not QBX or not QBX.PlayerData do
        Wait(500)
    end
    bNPC()
end)

-- Очистка при остановке ресурса
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- Удаление NPC
    if jobNPC and DoesEntityExist(jobNPC) then
        DeletePed(jobNPC)
        jobNPC = nil
    end

    -- Удаление блипа
    if jobBlip then
        RemoveBlip(jobBlip)
        jobBlip = nil
    end

    -- Завершение работы
    if isWorking then
        endWork()
    end
end)