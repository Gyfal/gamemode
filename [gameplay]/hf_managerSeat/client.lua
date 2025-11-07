-- HF Seat Manager
local HFSeat = {}

-- -- ox_lib cache
-- if lib and lib.cache then
--     cache = lib.cache
-- else
--     -- Fallback if ox_lib is not available
--     cache = {
--         ped = cache.ped,
--         vehicle = false
--     }
--     -- Update cache manually
--     CreateThread(function()
--         while true do
--             cache.ped = cache.ped
--             -- cache.vehicle = GetVehiclePedIsIn(cache.ped, false)
--             -- if cache.vehicle == 0 then cache.vehicle = false end
--             Wait(250)
--         end
--     end)
-- end

-- Configuration
HFSeat.Config = {
    maxSearchRadius = 10.0,
    enterVehicleTimeout = 10.0,
    updateInterval = 100,
    nearestVehicleCacheTime = 500,
    walkToCorrectDoor = false -- Very buggy, doesn't work reliably with moving vehicles
}

-- State management
HFSeat.State = {
    isShuffling = false,
    isExiting = false,
    isEntering = false,
    lastNearestVehicle = nil,
    lastNearestVehicleTime = 0
}

-- Relationship groups for NPC management
local _, group1Hash = AddRelationshipGroup("hfseat_player")
local _, group2Hash = AddRelationshipGroup("hfseat_npcs")

-- Get nearest vehicle with caching
function HFSeat:GetNearestVehicle(radius)
    local currentTime = GetGameTimer()
    
    -- Check cache first
    if currentTime - self.State.lastNearestVehicleTime < self.Config.nearestVehicleCacheTime then
        if self.State.lastNearestVehicle and DoesEntityExist(self.State.lastNearestVehicle) then
            local distance = #(GetEntityCoords(cache.ped) - GetEntityCoords(self.State.lastNearestVehicle))
            if distance <= radius then
                return self.State.lastNearestVehicle
            end
        end
    end
    
    -- Find new nearest vehicle using GetGamePool
    local playerCoords = GetEntityCoords(cache.ped)
    local vehicles = GetGamePool('CVehicle')
    local nearestVehicle = nil
    local nearestDistance = radius + 0.0
    
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local distance = #(playerCoords - GetEntityCoords(vehicle))
            if distance < nearestDistance then
                nearestDistance = distance
                nearestVehicle = vehicle
            end
        end
    end
    
    -- Update cache
    self.State.lastNearestVehicle = nearestVehicle
    self.State.lastNearestVehicleTime = currentTime
    
    return nearestVehicle
end

-- Get next available passenger seat
function HFSeat:GetNextAvailablePassengerSeat(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    
    local model = GetEntityModel(vehicle)
    local seatCount = GetVehicleModelNumberOfSeats(model)
    
    if seatCount > 1 then
        -- Start from 0 (first passenger seat)
        for i = 0, seatCount - 2 do
            if IsVehicleSeatFree(vehicle, i) then
                return i
            end
        end
    end
    
    return false
end

-- Get available seat (driver or passenger)
function HFSeat:GetAvailableSeat(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    
    -- Check if driver seat is free first
    if IsVehicleSeatFree(vehicle, -1) then
        return -1
    end
    
    -- Find first available passenger seat
    return self:GetNextAvailablePassengerSeat(vehicle)
end

-- Get seat ped is in
function HFSeat:GetSeatPedIsIn(ped, vehicle)
    if not DoesEntityExist(vehicle) or not DoesEntityExist(ped) then 
        return false 
    end
    
    local model = GetEntityModel(vehicle)
    local seatCount = GetVehicleModelNumberOfSeats(model)
    
    -- Check all seats from driver (-1) to last passenger
    for i = -1, seatCount - 2 do
        if GetPedInVehicleSeat(vehicle, i) == ped then
            return i
        end
    end
    
    return false
end

-- Walk to vehicle seat (optional feature)
function HFSeat:WalkToVehicleSeat(vehicle, seatIndex)
    if not self.Config.walkToCorrectDoor then return end
    
    local doorPosition
    local doorBones = {
        [-1] = "door_dside_f",
        [0] = "door_pside_f",
        [1] = "door_dside_r",
        [2] = "door_pside_r"
    }
    
    local boneName = doorBones[seatIndex]
    if boneName then
        local boneIndex = GetEntityBoneIndexByName(vehicle, boneName)
        if boneIndex ~= -1 then
            doorPosition = GetEntityBonePosition_2(vehicle, boneIndex)
        end
    end
    
    if doorPosition then
        TaskGoToCoordAnyMeans(cache.ped, doorPosition.x, doorPosition.y, doorPosition.z, 2.0, 0, 0, 786603)
        local timer = GetGameTimer()
        repeat 
            Wait(0) 
        until #(GetEntityCoords(cache.ped) - doorPosition) < 1.0 or GetGameTimer() - timer > 5000
        ClearPedTasksImmediately(cache.ped)
    end
end

-- Debug function to print current ped tasks
function HFSeat:PrintCurrentPedTasks(ped)
    for i = 1, 500 do
        if GetIsTaskActive(ped, i) then
            print("Active task: " .. i)
        end
    end
end


local states = {}

-- Main thread
CreateThread(function()
    while true do
        Wait(HFSeat.Config.updateInterval)
        local playerPed = cache.ped
        local vehicle = cache.vehicle
        
        if vehicle then
            -- -- Handle vehicle exit and shuffle logic
            if not HFSeat.State.isShuffling then
            --     -- Track intentional exit
            --     if IsControlJustPressed(0, 75) then -- F key
            --         HFSeat.State.isExiting = true
            --         CreateThread(function()
            --             repeat Wait(0) until not GetIsTaskActive(playerPed, 2)
            --             HFSeat.State.isExiting = false
            --         end)
            --     end
                
            --     -- Prevent unwanted exit from back seats
            --     if GetIsTaskActive(playerPed, 2) and not HFSeat.State.isExiting and not IsControlJustPressed(0, 75) then
            --         local currentSeat = HFSeat:GetSeatPedIsIn(playerPed, vehicle)
            --         if currentSeat then
            --             SetPedIntoVehicle(playerPed, vehicle, currentSeat)
            --         end
            --     end
                
                -- Allow forced exit when stuck
            --     if IsControlJustPressed(0, 75) and IsPedInAnyVehicle(playerPed, false) then
            --         TaskLeaveVehicle(playerPed, vehicle, 64)
            --     end
                
            -- --     -- Prevent auto-shuffle to driver seat
            --     if GetPedInVehicleSeat(vehicle, 0) == playerPed and GetIsTaskActive(playerPed, 165) then
            --         SetPedIntoVehicle(playerPed, vehicle, 0)
            --     end
            end
        else
            -- Сброс состояний когда не в транспорте
            HFSeat.State.isShuffling = false
            HFSeat.State.isExiting = false

            local vehicleTryingToEnter = GetVehiclePedIsTryingToEnter(playerPed)

            -- Сбрасываем флаг входа, если игрок отменил попытку
            if HFSeat.State.isEntering then
                local isMoving = IsControlPressed(0, 32) or IsControlPressed(0, 33) or
                                IsControlPressed(0, 34) or IsControlPressed(0, 35) -- W/S/A/D
                local tasksFinished = not GetIsTaskActive(playerPed, 160) and not GetIsTaskActive(playerPed, 165)

                -- Отменяем если: нет попытки входа И (задачи завершены ИЛИ игрок движется)
                if vehicleTryingToEnter == 0 and (tasksFinished or isMoving) then
                    HFSeat.State.isEntering = false
                    print('[HFSeat] Entry cancelled by player')
                end
            end

            -- Защита от флуда: выполняем вход только один раз
            if vehicleTryingToEnter > 0 and not IsPedInAnyVehicle(playerPed, true) and not HFSeat.State.isEntering then
                HFSeat.State.isEntering = true

                -- Определяем целевое место (приоритет на водительское)
                local targetSeat = HFSeat:GetAvailableSeat(vehicleTryingToEnter)

                if targetSeat ~= false then
                    ClearPedTasksImmediately(playerPed)
                    TaskEnterVehicle(playerPed, vehicleTryingToEnter, -1, targetSeat, 2.0, 1, 0)
                    print('[HFSeat] Entering vehicle:', vehicleTryingToEnter, 'Target seat:', targetSeat)

                    -- Отслеживаем завершение входа в отдельном потоке
                    CreateThread(function()
                        local timeout = GetGameTimer() + (HFSeat.Config.enterVehicleTimeout * 1000)

                        -- Ждем пока игрок входит (task 160) или перемещается между местами (task 165)
                        while (GetIsTaskActive(playerPed, 160) or GetIsTaskActive(playerPed, 165)) and GetGameTimer() < timeout do
                            Wait(50)
                        end

                        -- Сбрасываем флаг после завершения или таймаута
                        HFSeat.State.isEntering = false
                        print('[HFSeat] Entry complete or timed out')
                    end)
                else
                    -- Нет свободных мест
                    HFSeat.State.isEntering = false
                    print('[HFSeat] No available seats in vehicle')
                end
            end

            -- print("[ahtung] Vehicle trying to enter:", vehicleTryingToEnter, "Seat trying to enter:", seatTryingToEnter)

            
        --     -- Cancel enter if player is moving AND not holding F
        --     if vehicleTryingToEnter and not IsControlPressed(0, 75) and
        --        (IsControlPressed(0, 32) or IsControlPressed(0, 33) or IsControlPressed(0, 34) or IsControlPressed(0, 35)) then
        --         ClearPedTasks(playerPed)
        --     end
            
        --     -- Handle seat conflicts for ongoing entry
        --     if vehicleTryingToEnter and seatTryingToEnter then
        --         -- If seat is no longer free, find another one
        --         if not IsVehicleSeatFree(vehicleTryingToEnter, seatTryingToEnter) then
        --             local newSeat = HFSeat:GetAvailableSeat(vehicleTryingToEnter)
        --             if newSeat ~= false and newSeat ~= seatTryingToEnter then
        --                 ClearPedTasksImmediately(playerPed)
        --                 TaskEnterVehicle(playerPed, vehicleTryingToEnter, -1, newSeat, 2.0, 1, 0)
        --             elseif newSeat == false then
        --                 -- No seats available
        --                 ClearPedTasks(playerPed)
        --             end
        --         end
        --     end
            
        --     -- Handle vehicle entry on F key press
        --     if IsControlJustPressed(0, 75) and not IsPedInAnyVehicle(playerPed, true) then
        --         -- Only start new enter task if not already entering
        --         if not vehicleTryingToEnter then
        --             local nearestVehicle = HFSeat:GetNearestVehicle(HFSeat.Config.maxSearchRadius)
                    
        --             if nearestVehicle then
        --                 local availableSeat = HFSeat:GetAvailableSeat(nearestVehicle)
                        
        --                 if availableSeat ~= false then
        --                     -- Walk to door if enabled
        --                     HFSeat:WalkToVehicleSeat(nearestVehicle, availableSeat)
                            
        --                     -- Enter vehicle
        --                     TaskEnterVehicle(playerPed, nearestVehicle, -1, availableSeat, 2.0, 1, 0)
        --                 end
        --             end
        --         end
        --     end
            
        --     -- Keep trying to enter while F is held
        --     if IsControlPressed(0, 75) and vehicleTryingToEnter and seatTryingToEnter then
        --         -- If enter task was somehow cancelled, restart it
        --         if not GetIsTaskActive(playerPed, 195) and not GetIsTaskActive(playerPed, 160) then
        --             TaskEnterVehicle(playerPed, vehicleTryingToEnter, -1, seatTryingToEnter, 2.0, 1, 0)
        --         end
        --     end
            
        --     -- Prevent NPCs from being scared when entering vehicle
        --     if IsPedInAnyVehicle(playerPed, true) then
        --         SetRelationshipBetweenGroups(0, group1Hash, group2Hash)
        --         local enteringVehicle = GetVehiclePedIsTryingToEnter(playerPed)
                
        --         if DoesEntityExist(enteringVehicle) then
        --             local model = GetEntityModel(enteringVehicle)
        --             local seatCount = GetVehicleModelNumberOfSeats(model)
                    
        --             for i = -1, seatCount - 2 do
        --                 if not IsVehicleSeatFree(enteringVehicle, i) then
        --                     local npc = GetPedInVehicleSeat(enteringVehicle, i)
        --                     if DoesEntityExist(npc) and not IsPedAPlayer(npc) then
        --                         ClearPedTasks(npc)
        --                         SetPedRelationshipGroupHash(playerPed, group1Hash)
        --                         SetPedRelationshipGroupHash(npc, group2Hash)
        --                     end
        --                 end
        --             end
        --         end
        --     end
        -- end

        -- if IsControlJustPressed(0, 75) then -- F key
            -- CreateThread(function()
            -- print("IsControlPressed", IsControlPressed(0, 75))
            -- repeat Wait(0) until not IsControlPressed(0, 75)
                -- HFSeat.State.isExiting = false
            -- end)
        end


        -- repeat Wait(0) until not IsControlPressed(0, 75)
    end
end)

-- Shuffle command
RegisterCommand('shuff', function()
    if cache.vehicle and not GetIsTaskActive(cache.ped, 165) then
        HFSeat.State.isShuffling = true
        local vehicle = cache.vehicle
        
        ClearRelationshipBetweenGroups(0, group1Hash, group2Hash)
        TaskShuffleToNextVehicleSeat(cache.ped, vehicle)
        
        CreateThread(function()
            repeat Wait(50) until not GetIsTaskActive(cache.ped, 165)
            HFSeat.State.isShuffling = false
        end)
    end
end, false)

-- Exports
exports('getNearestVehicle', function(radius)
    return HFSeat:GetNearestVehicle(radius or HFSeat.Config.maxSearchRadius)
end)

exports('getAvailableSeat', function(vehicle)
    return HFSeat:GetAvailableSeat(vehicle)
end)

exports('getSeatPedIsIn', function(ped, vehicle)
    return HFSeat:GetSeatPedIsIn(ped, vehicle)
end)