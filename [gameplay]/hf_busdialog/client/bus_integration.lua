-- Интеграция с автобусником
-- Этот файл добавляет диалоги для NPC диспетчера автопарка

-- Событие для показа диалога о работе
RegisterNetEvent('qbx_busjob_new:client:showJobDialog', function()
    local hasJob = QBX and QBX.PlayerData and QBX.PlayerData.job.name == 'bus'

    if hasJob then
        -- Игрок уже устроен на работу
        exports.hf_busdialog:OpenDialog({
            data = {
                label = 'Выбор действия',
                text = 'Вы уже работаете водителем автобуса. Что вы хотите сделать?',
                responses = {
                    {
                        label = 'Взять автобус',
                        event = 'qbx_busjob_new:client:requestBusMenu'
                    },
                    {
                        label = 'Уволиться',
                        event = 'qbx_busjob_new:client:confirmQuit'
                    },
                    {
                        label = 'Ничего',
                        close = true
                    }
                }
            }
        })
    else
        -- Игрок не устроен на работу
        exports.hf_busdialog:OpenDialog({
            data = {
                label = 'Устройство на работу',
                text = 'Вы хотите устроиться водителем автобуса? Вы будете возить пассажиров по городу и получать за это оплату.',
                responses = {
                    {
                        label = 'Да, устроить на работу',
                        event = 'qbx_busjob_new:server:startJob',
                        type = 'server'
                    },
                    {
                        label = 'Нет, спасибо',
                        close = true
                    }
                }
            }
        })
    end
end)

-- Событие для запроса меню автобусов
RegisterNetEvent('qbx_busjob_new:client:requestBusMenu', function()
    -- Используем существующее меню выбора маршрута
    TriggerEvent('qbx_busjob_new:client:openRouteMenu')
end)

-- Событие для подтверждения увольнения
RegisterNetEvent('qbx_busjob_new:client:confirmQuit', function()
    exports.hf_busdialog:OpenDialog({
        data = {
            label = 'Увольнение',
            text = 'Вы уверены, что хотите уволиться? Если у вас есть активная работа, она будет завершена.',
            responses = {
                {
                    label = 'Да, уволиться',
                    event = 'qbx_busjob_new:server:quitJob',
                    type = 'server'
                },
                {
                    label = 'Нет, остаться',
                    close = true
                }
            }
        }
    })
end)

-- Экспорт события для открытия меню маршрутов
AddEventHandler('qbx_busjob_new:client:openRouteMenu', function()
    -- Эта функция уже существует в main.lua автобусника
    -- Мы просто вызываем её через глобальную переменную
    if openRouteMenu then
        openRouteMenu()
    end
end)
