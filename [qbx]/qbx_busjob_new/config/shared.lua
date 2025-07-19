return {
    -- Локация NPC для устройства на работу
    jobNPC = {
        model = "s_m_m_cntrybar_01", -- Модель NPC
        coords = vec4(1716.0, 3325.22, 41.22, 195.0), -- Координаты NPC (x, y, z, heading)
        blip = {
            enabled = true,
            sprite = 513, -- Иконка блипа (автобус)
            color = 38,
            scale = 0.8,
            label = 'Автопарк' -- Название блипа
        }
    },

    -- Места спавна автобуса (выбирается случайно)
    busSpawnLocations = {
        vec4(1724.23, 3314.39, 42.05, 195.0),
        vec4(1728.45, 3312.98, 42.05, 195.0),
        vec4(1732.69, 3311.58, 42.05, 195.0),
        vec4(1736.66, 3310.34, 42.05, 195.0)
    },

    -- Маршруты автобусов
    busRoutes = {
        {
            id = 1,
            name = 'Маршрут №1 - Сельский округ',
            description = 'Маршрут через сельские районы и небольшие поселения',
            headingTolerance = 45.0, -- Допустимая погрешность heading в градусах
            stops = {
                { coords = vec3(1806.39, 3259.97, 43.81), heading = 252.9, payment = 0 },
                { coords = vec3(1809.43, 3318.88, 42.98), heading = 30.09, payment = 150, waitTime = 10000 },
                { coords = vec3(1683.21, 3538.29, 36.51), heading = 28.22, payment = 0 },
                { coords = vec3(1865.32, 3665.37, 34.73), heading = 300.05, payment = 180, waitTime = 10000 },
                { coords = vec3(1943.24, 3711.85, 33.2), heading = 299.67, payment = 0 },
                { coords = vec3(1946.93, 3740.2, 33.18), heading = 28.61, payment = 0 },
                { coords = vec3(1899.05, 3823.91, 33.23), heading = 31.51, payment = 0 },
                { coords = vec3(1871.91, 3835.01, 33.21), heading = 119.19, payment = 0 },
                { coords = vec3(1724.06, 3750.85, 34.7), heading = 118.76, payment = 200, waitTime = 10000 },
                { coords = vec3(1257.86, 3539.66, 36.04), heading = 89.8, payment = 0 },
                { coords = vec3(727.53, 3529.09, 35.05), heading = 95.85, payment = 0 },
                { coords = vec3(432.69, 3486.86, 35.45), heading = 104.29, payment = 0 },
                { coords = vec3(291.15, 3416.98, 38.08), heading = 133.78, payment = 0 },
                { coords = vec3(227.84, 3309.53, 41.24), heading = 162.9, payment = 0 },
                { coords = vec3(221.82, 3012.63, 43.24), heading = 184.35, payment = 0 },
                { coords = vec3(-54.17, 2829.81, 55.45), heading = 91.55, payment = 0 },
                { coords = vec3(-296.39, 2897.24, 46.34), heading = 88.34, payment = 0 },
                { coords = vec3(-514.48, 2847.8, 34.81), heading = 86.37, payment = 0 },
                { coords = vec3(-626.55, 2856.51, 34.2), heading = 100.72, payment = 0 },
                { coords = vec3(-864.45, 2753.11, 24.08), heading = 95.19, payment = 0 },
                { coords = vec3(-988.47, 2749.4, 25.7), heading = 111.21, payment = 0 },
                { coords = vec3(-1128.64, 2664.03, 18.47), heading = 131.92, payment = 220, waitTime = 10000 },
                { coords = vec3(-1252.5, 2542.6, 18.68), heading = 135.39, payment = 0 },
                { coords = vec3(-1427.54, 2414.28, 28.09), heading = 103.9, payment = 0 },
                { coords = vec3(-1748.68, 2433.89, 32.43), heading = 112.8, payment = 0 },
                { coords = vec3(-2002.02, 2349.81, 34.39), heading = 112.14, payment = 0 },
                { coords = vec3(-2187.76, 2310.05, 34.58), heading = 104.29, payment = 0 },
                { coords = vec3(-2346.35, 2249.04, 33.68), heading = 77.36, payment = 0 },
                { coords = vec3(-2523.99, 2337.49, 33.89), heading = 32.27, payment = 250, waitTime = 10000 },
                { coords = vec3(-2553.42, 2346.82, 33.89), heading = 94.12, payment = 0 },
                { coords = vec3(-2665.28, 2287.96, 22.84), heading = 92.98, payment = 0 },
                { coords = vec3(-2695.76, 2340.69, 17.89), heading = 348.89, payment = 0 },
                { coords = vec3(-2601.21, 2976.28, 17.49), heading = 351.64, payment = 0 },
                { coords = vec3(-2557.36, 3379.79, 14.15), heading = 346.85, payment = 0 },
                { coords = vec3(-2464.9, 3715.11, 16.3), heading = 349.49, payment = 500 }
            }
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
        passengerSpawnChance = 30, -- Шанс появления пассажиров на остановке (%)
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
        requireDeposit = true, -- Требовать залог за автобус
        maxBusesPerRoute = 5 -- Максимальное количество автобусов на одном маршруте
    }
}