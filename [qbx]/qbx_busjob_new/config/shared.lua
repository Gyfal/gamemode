return {
    -- Локация NPC для устройства на работу
    jobNPC = {
        model = "s_m_m_busdriver_01", -- Модель NPC
        coords = vec4(462.8, -641.2, 28.45, 87.0), -- Координаты NPC (x, y, z, heading)
        blip = {
            enabled = true,
            sprite = 513, -- Иконка блипа (автобус)
            color = 5, -- Цвет блипа (желтый)
            scale = 0.8,
            label = 'Автопарк' -- Название блипа
        }
    },

    -- Места спавна автобуса (выбирается случайно)
    busSpawnLocations = {
        vec4(469.28, -588.04, 28.49, 170.08),
        vec4(463.95, -587.16, 28.49, 170.08), 
        vec4(455.63, -583.77, 28.49, 175.75),
        vec4(474.89, -589.43, 28.49, 170.08),
        vec4(459.65, -585.43, 28.49, 175.75),
        vec4(452.31, -581.89, 28.49, 175.75)
    },
    
    -- Место спавна автобуса (устаревшее, оставлено для совместимости)
    busSpawn = vec4(466.5, -634.5, 28.45, 87.0), -- Координаты спавна (x, y, z, heading)

    -- Маршрут автобуса (остановки) - Городской маршрут №1
    busRoute = {
        {
            name = 'Автопарк (Старт)',
            coords = vec3(462.8, -641.2, 28.45),
            payment = 0, -- Стартовая точка без оплаты
            isStartPoint = true
        },
        {
            name = 'Центральная площадь',
            coords = vec3(194.2, -830.5, 31.2),
            payment = 180,
            description = 'Главная площадь города'
        },
        {
            name = 'Больница',
            coords = vec3(304.36, -764.56, 29.31),
            payment = 160,
            description = 'Центральная больница'
        },
        {
            name = 'Банк',
            coords = vec3(-250.14, -886.78, 30.63),
            payment = 200,
            description = 'Финансовый район'
        },
        {
            name = 'Торговый центр',
            coords = vec3(-692.63, -670.44, 30.86),
            payment = 220,
            description = 'Торговый район'
        },
        {
            name = 'Пляж',
            coords = vec3(-712.83, -824.56, 23.54),
            payment = 250,
            description = 'Пляжная зона отдыха'
        },
        {
            name = 'Мотель',
            coords = vec3(-110.31, -1686.29, 29.31),
            payment = 190,
            description = 'Жилой район'
        },
        {
            name = 'Автопарк (Финиш)',
            coords = vec3(462.8, -641.2, 28.45),
            payment = 300, -- Бонус за завершение круга
            isEndPoint = true,
            description = 'Возвращение в автопарк'
        }
    },

    -- Модели автобусов
    busModels = {
        {
            model = `bus`,
            label = 'Городской автобус',
            deposit = 0 -- Залог за автобус
        },
        {
            model = `airbus`,
            label = 'Аэропортовский автобус',
            deposit = 0
        }
    },

    -- Модели пассажиров NPC
    passengerModels = {
        male = {
            `a_m_m_afriamer_01`,
            `a_m_m_beach_01`,
            `a_m_m_bevhills_01`,
            `a_m_m_business_01`,
            `a_m_m_eastsa_01`,
            `a_m_m_farmer_01`,
            `a_m_m_genfat_01`,
            `a_m_m_golfer_01`,
            `a_m_m_hasjew_01`,
            `a_m_m_hillbilly_01`
        },
        female = {
            `a_f_m_beach_01`,
            `a_f_m_bevhills_01`,
            `a_f_m_business_02`,
            `a_f_m_downtown_01`,
            `a_f_m_eastsa_01`,
            `a_f_m_fatbla_01`,
            `a_f_m_fatcult_01`,
            `a_f_m_fatwhite_01`,
            `a_f_m_ktown_01`,
            `a_f_m_skidrow_01`
        }
    },

    -- Настройки пассажиров
    passengerSettings = {
        maxPassengersPerStop = 3, -- Максимум пассажиров на остановке
        minPassengersPerStop = 1, -- Минимум пассажиров на остановке
        passengerSpawnChance = 80, -- Шанс появления пассажиров на остановке (%)
        passengerPayment = {
            min = 50, -- Минимальная оплата за пассажира
            max = 100 -- Максимальная оплата за пассажира
        },
        waitTime = 3000, -- Время ожидания посадки/высадки (мс)
        exitChance = 30, -- Шанс выхода пассажира на каждой остановке (%)
        spawnDistance = 10.0, -- Расстояние спавна пассажиров от остановки
        animationTime = 2000 -- Время анимации посадки/высадки
    },

    -- Настройки
    settings = {
        stopRadius = 7.0, -- Радиус остановки
        routeCompleteBonus = 500, -- Бонус за полный круг
        showBlips = true, -- Показывать блипы остановок
        showMarkers = true, -- Показывать маркеры остановок
        showNotifications = true, -- Показывать уведомления
        requireDeposit = true -- Требовать залог за автобус
    }
}