Config = {}

-- Настройки таргета
Config.Target = 'ox' -- 'ox' или 'qb'

-- Событие загрузки фреймворка (может быть пустым)
Config.FrameworkLoadingEvent = 'QBCore:Client:OnPlayerLoaded'

-- Настройки камеры
Config.Camera = {
    enabled = true,
    fov = 30.0,
    offsetX = 0.5,
    offsetY = 0.5,
    offsetZ = 0.0
}

-- Педы для диалогов
Config.peds = {
    -- Пример диспетчера автобусов
    ['bus_dispatcher'] = {
        label = 'Диспетчер автопарка',
        icon = 'fas fa-bus',
        model = 's_m_m_cntrybar_01',
        coords = vector4(1716.0, 3325.22, 41.22, 195.0),
        data = {
            {
                label = 'Приветствие',
                text = 'Здравствуйте! Я диспетчер автопарка. Хотите устроиться водителем автобуса?',
                responses = {
                    {
                        label = 'Да, хочу работать',
                        event = 'qbx_busjob_new:client:showJobDialog'
                    },
                    {
                        label = 'Расскажите о работе',
                        data = {
                            label = 'Информация о работе',
                            text = 'Работа водителем автобуса - это отличная возможность заработать! Вам нужно будет возить пассажиров по установленным маршрутам, останавливаясь на остановках и соблюдая правила дорожного движения.',
                            responses = {
                                {
                                    label = 'Понятно, хочу попробовать',
                                    event = 'qbx_busjob_new:client:showJobDialog'
                                },
                                {
                                    label = 'Спасибо, я подумаю',
                                    close = true
                                }
                            }
                        }
                    },
                    {
                        label = 'Нет, спасибо',
                        close = true
                    }
                }
            }
        }
    }
}

return Config
