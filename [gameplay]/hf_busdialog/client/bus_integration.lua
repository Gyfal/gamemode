-- Интеграция с автобусником
-- Этот файл можно использовать для расширения функционала диалогов

-- В текущей версии вся логика реализована через конфиг
-- Если нужны дополнительные события или проверки, добавляйте их здесь

-- Пример: обработка успешного трудоустройства
RegisterNetEvent('qbx_busjob_new:client:jobStarted', function()
    lib.notify({
        title = 'Поздравляем!',
        description = 'Вы успешно устроились водителем автобуса',
        type = 'success'
    })
end)

-- Пример: обработка увольнения
RegisterNetEvent('qbx_busjob_new:client:jobQuit', function()
    lib.notify({
        title = 'До свидания!',
        description = 'Вы уволились с работы водителя автобуса',
        type = 'inform'
    })
end)
