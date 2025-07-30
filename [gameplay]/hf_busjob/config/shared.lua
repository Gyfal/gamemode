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
            name = 'Кольцевой маршрут штата',
            description = 'Кольцевой маршрут по всему штату с 23 остановками',
            headingTolerance = 45.0, -- Допустимая погрешность heading в градусах
            stops = 
            {
                { coords = vec3(1802.80, 3315.66, 42.97), heading = 210.79, payment = 0 },
                { coords = vec3(1825.40, 3275.24, 44.56), heading = 212.80, payment = 150, waitTime = 10000, stopName = "Sandy Shores Airfield" },
                { coords = vec3(2001.41, 3099.98, 47.92), heading = 238.18, payment = 150, waitTime = 10000, stopName = "Yellow Jack Inn." },
                { coords = vec3(2085.82, 3054.14, 46.76), heading = 245.04, payment = 0 },
                { coords = vec3(2179.09, 3021.03, 46.20), heading = 255.02, payment = 0 },
                { coords = vec3(2345.55, 2970.22, 49.31), heading = 238.43, payment = 0 },
                { coords = vec3(2434.04, 2873.04, 49.97), heading = 217.68, payment = 0 },
                { coords = vec3(2530.96, 2722.23, 44.20), heading = 205.77, payment = 150, waitTime = 10000, stopName = "Davis Quartz" },
                { coords = vec3(2590.74, 2565.89, 34.13), heading = 197.63, payment = 0 },
                { coords = vec3(2591.59, 2351.89, 21.81), heading = 168.12, payment = 0 },
                { coords = vec3(2546.21, 2165.46, 20.20), heading = 170.36, payment = 0 },
                { coords = vec3(2534.98, 1935.81, 21.08), heading = 178.81, payment = 0 },
                { coords = vec3(2539.25, 1659.49, 29.48), heading = 180.36, payment = 0 },
                { coords = vec3(2558.52, 1639.26, 29.90), heading = 270.50, payment = 0 },
                { coords = vec3(2659.63, 1637.89, 25.42), heading = 269.54, payment = 0 },
                { coords = vec3(2686.42, 1600.38, 25.42), heading = 180.35, payment = 150, waitTime = 10000, stopName = "Palmer-Taylor Power Station" },
                { coords = vec3(2687.51, 1419.27, 25.42), heading = 180.23, payment = 0 },
                { coords = vec3(2706.64, 1401.17, 25.40), heading = 270.46, payment = 0 },
                { coords = vec3(2748.97, 1401.18, 25.39), heading = 270.72, payment = 0 },
                { coords = vec3(2767.38, 1419.25, 25.37), heading = 344.66, payment = 0 },
                { coords = vec3(2782.66, 1469.08, 25.38), heading = 345.15, payment = 150, waitTime = 10000, stopName = "Palmer-Taylor Power Management" },
                { coords = vec3(2820.87, 1619.67, 25.39), heading = 347.47, payment = 0 },
                { coords = vec3(2804.37, 1643.47, 25.43), heading = 90.28, payment = 0 },
                { coords = vec3(2661.19, 1646.02, 25.42), heading = 89.98, payment = 0 },
                { coords = vec3(2574.71, 1644.42, 29.42), heading = 89.56, payment = 0 },
                { coords = vec3(2545.10, 1666.74, 29.27), heading = 1.18, payment = 0 },
                { coords = vec3(2540.47, 1924.76, 21.17), heading = 358.35, payment = 0 },
                { coords = vec3(2545.84, 2111.06, 20.39), heading = 355.82, payment = 0 },
                { coords = vec3(2599.05, 2358.13, 22.03), heading = 349.37, payment = 0 },
                { coords = vec3(2565.88, 2661.26, 39.95), heading = 20.81, payment = 150, waitTime = 10000, stopName = "Davis Quartz" },
                { coords = vec3(2460.18, 2848.38, 49.60), heading = 35.69, payment = 0 },
                { coords = vec3(2385.00, 2944.20, 50.03), heading = 39.99, payment = 0 },
                { coords = vec3(2332.15, 2984.05, 48.81), heading = 63.53, payment = 0 },
                { coords = vec3(2226.06, 3013.89, 46.04), heading = 88.79, payment = 0 },
                { coords = vec3(2052.02, 2997.23, 45.91), heading = 99.15, payment = 0 },
                { coords = vec3(1909.76, 2968.52, 46.56), heading = 104.47, payment = 0 },
                { coords = vec3(1755.14, 2914.70, 46.57), heading = 117.02, payment = 0 },
                { coords = vec3(1510.85, 2757.75, 38.78), heading = 124.08, payment = 0 },
                { coords = vec3(1314.36, 2685.57, 38.51), heading = 91.93, payment = 0 },
                { coords = vec3(1102.81, 2690.92, 39.50), heading = 86.56, payment = 150, waitTime = 10000, stopName = "The Motor Hotel" },
                { coords = vec3(943.24, 2697.87, 41.29), heading = 87.24, payment = 0 },
                { coords = vec3(778.83, 2702.73, 40.98), heading = 89.27, payment = 0 },
                { coords = vec3(541.37, 2692.91, 43.16), heading = 97.22, payment = 150, waitTime = 10000, stopName = "Harmony" },
                { coords = vec3(304.50, 2644.73, 45.34), heading = 106.93, payment = 0 },
                { coords = vec3(161.94, 2649.60, 49.61), heading = 56.03, payment = 0 },
                { coords = vec3(30.19, 2769.66, 58.95), heading = 56.14, payment = 0 },
                { coords = vec3(-114.84, 2840.93, 51.74), heading = 67.44, payment = 0 },
                { coords = vec3(-251.99, 2890.58, 47.02), heading = 76.27, payment = 0 },
                { coords = vec3(-369.12, 2884.11, 43.43), heading = 106.53, payment = 150, waitTime = 10000, stopName = "Greate Chaparral" },
                { coords = vec3(-501.38, 2847.27, 34.68), heading = 90.65, payment = 0 },
                { coords = vec3(-621.76, 2857.14, 34.51), heading = 98.65, payment = 0 },
                { coords = vec3(-722.87, 2808.10, 27.71), heading = 121.18, payment = 0 },
                { coords = vec3(-862.01, 2753.36, 24.06), heading = 95.35, payment = 0 },
                { coords = vec3(-966.54, 2758.02, 26.29), heading = 99.17, payment = 0 },
                { coords = vec3(-1062.38, 2712.70, 22.57), heading = 126.45, payment = 0 },
                { coords = vec3(-1127.87, 2664.63, 18.51), heading = 131.34, payment = 150, waitTime = 10000, stopName = "Остановка" },
                { coords = vec3(-1244.26, 2551.23, 18.11), heading = 134.68, payment = 0 },
                { coords = vec3(-1352.99, 2445.02, 28.17), heading = 122.84, payment = 0 },
                { coords = vec3(-1562.08, 2405.52, 26.77), heading = 78.29, payment = 0 },
                { coords = vec3(-1675.02, 2437.02, 29.52), heading = 81.67, payment = 0 },
                { coords = vec3(-1746.80, 2434.34, 32.44), heading = 110.93, payment = 0 },
                { coords = vec3(-1843.03, 2391.51, 32.76), heading = 105.00, payment = 0 },
                { coords = vec3(-1933.88, 2369.00, 34.38), heading = 109.52, payment = 0 },
                { coords = vec3(-2081.41, 2317.62, 38.12), heading = 105.37, payment = 0 },
                { coords = vec3(-2185.17, 2310.50, 34.69), heading = 101.75, payment = 0 },
                { coords = vec3(-2303.56, 2254.47, 33.82), heading = 108.15, payment = 0 },
                { coords = vec3(-2399.17, 2275.08, 33.95), heading = 60.37, payment = 0 },
                { coords = vec3(-2523.25, 2336.27, 33.89), heading = 33.30, payment = 150, waitTime = 10000, stopName = "Lago Zancudo" },
                { coords = vec3(-2553.72, 2346.67, 33.89), heading = 93.49, payment = 0 },
                { coords = vec3(-2586.68, 2323.71, 33.41), heading = 103.16, payment = 0 },
                { coords = vec3(-2680.07, 2287.11, 21.61), heading = 91.49, payment = 0 },
                { coords = vec3(-2701.54, 2316.78, 18.44), heading = 344.77, payment = 0 },
                { coords = vec3(-2657.11, 2596.85, 17.52), heading = 351.15, payment = 0 },
                { coords = vec3(-2600.98, 2976.96, 17.49), heading = 352.55, payment = 0 },
                { coords = vec3(-2580.32, 3226.76, 14.47), heading = 354.30, payment = 0 },
                { coords = vec3(-2518.32, 3500.08, 14.89), heading = 335.02, payment = 0 },
                { coords = vec3(-2460.21, 3710.44, 16.09), heading = 349.54, payment = 150, waitTime = 10000, stopName = "Fort Zancudo" },
                { coords = vec3(-2435.06, 3813.25, 22.93), heading = 333.35, payment = 0 },
                { coords = vec3(-2352.67, 4010.25, 28.61), heading = 342.57, payment = 0 },
                { coords = vec3(-2297.32, 4174.20, 40.18), heading = 330.62, payment = 0 },
                { coords = vec3(-2231.18, 4257.28, 46.76), heading = 328.40, payment = 150, waitTime = 10000, stopName = "Hookies" },
                { coords = vec3(-2187.94, 4378.29, 55.37), heading = 342.92, payment = 0 },
                { coords = vec3(-2030.20, 4482.42, 57.86), heading = 313.48, payment = 0 },
                { coords = vec3(-1770.43, 4741.03, 57.90), heading = 313.29, payment = 0 },
                { coords = vec3(-1629.28, 4859.08, 61.77), heading = 315.62, payment = 0 },
                { coords = vec3(-1464.12, 5032.92, 62.96), heading = 310.06, payment = 0 },
                { coords = vec3(-1340.31, 5120.60, 62.49), heading = 312.98, payment = 0 },
                { coords = vec3(-1303.16, 5208.52, 57.71), heading = 347.41, payment = 0 },
                { coords = vec3(-1206.07, 5251.10, 52.01), heading = 273.58, payment = 0 },
                { coords = vec3(-1128.14, 5294.35, 52.43), heading = 313.23, payment = 0 },
                { coords = vec3(-1047.18, 5335.59, 45.32), heading = 304.22, payment = 0 },
                { coords = vec3(-914.11, 5413.04, 37.92), heading = 283.65, payment = 0 },
                { coords = vec3(-832.64, 5414.91, 35.20), heading = 271.82, payment = 0 },
                { coords = vec3(-701.09, 5428.67, 46.77), heading = 231.81, payment = 0 },
                { coords = vec3(-653.91, 5353.96, 60.25), heading = 180.43, payment = 0 },
                { coords = vec3(-691.10, 5314.09, 70.43), heading = 89.53, payment = 0 },
                { coords = vec3(-711.40, 5296.14, 73.31), heading = 185.28, payment = 0 },
                { coords = vec3(-680.36, 5253.38, 77.60), heading = 233.54, payment = 0 },
                { coords = vec3(-613.15, 5264.86, 73.38), heading = 312.28, payment = 0 },
                { coords = vec3(-577.93, 5320.04, 71.05), heading = 339.42, payment = 150, waitTime = 10000, stopName = "Остановка" },
                { coords = vec3(-548.67, 5409.65, 65.54), heading = 359.09, payment = 0 },
                { coords = vec3(-572.55, 5450.11, 61.78), heading = 58.94, payment = 0 },
                { coords = vec3(-633.12, 5450.23, 54.12), heading = 105.14, payment = 0 },
                { coords = vec3(-703.54, 5441.82, 46.29), heading = 90.09, payment = 0 },
                { coords = vec3(-816.98, 5437.99, 34.36), heading = 50.65, payment = 0 },
                { coords = vec3(-806.27, 5463.80, 34.72), heading = 300.95, payment = 0 },
                { coords = vec3(-746.21, 5494.46, 36.25), heading = 301.29, payment = 150, waitTime = 10000, stopName = "Pala Springs" },
                { coords = vec3(-629.06, 5581.59, 39.84), heading = 313.45, payment = 0 },
                { coords = vec3(-548.59, 5719.30, 37.80), heading = 337.90, payment = 0 },
                { coords = vec3(-429.78, 5926.83, 33.24), heading = 320.82, payment = 0 },
                { coords = vec3(-385.70, 5988.40, 32.84), heading = 318.13, payment = 0 },
                { coords = vec3(-392.81, 6024.92, 32.28), heading = 44.36, payment = 0 },
                { coords = vec3(-430.65, 6081.81, 32.26), heading = 357.80, payment = 0 },
                { coords = vec3(-396.73, 6134.65, 32.65), heading = 308.84, payment = 0 },
                { coords = vec3(-344.35, 6182.20, 32.12), heading = 310.45, payment = 0 },
                { coords = vec3(-313.71, 6210.62, 32.16), heading = 312.52, payment = 0 },
                { coords = vec3(-278.98, 6251.57, 32.24), heading = 314.71, payment = 0 },
                { coords = vec3(-234.61, 6291.75, 32.12), heading = 314.98, payment = 150, waitTime = 10000, stopName = "Paleto Bay Care Center" },
                { coords = vec3(-187.57, 6343.19, 32.28), heading = 315.13, payment = 0 },
                { coords = vec3(-151.32, 6332.34, 32.39), heading = 225.13, payment = 0 },
                { coords = vec3(-112.58, 6293.50, 32.17), heading = 225.77, payment = 0 },
                { coords = vec3(-75.91, 6292.48, 32.17), heading = 315.27, payment = 0 },
                { coords = vec3(-17.58, 6343.26, 32.10), heading = 314.95, payment = 150, waitTime = 10000, stopName = "Clucking Bell Farms" },
                { coords = vec3(57.34, 6425.68, 32.13), heading = 315.19, payment = 0 },
                { coords = vec3(154.54, 6518.82, 32.45), heading = 307.65, payment = 0 },
                { coords = vec3(338.15, 6566.31, 29.52), heading = 270.89, payment = 0 },
                { coords = vec3(447.42, 6554.90, 27.87), heading = 263.34, payment = 150, waitTime = 10000, stopName = "Donkey Punch Family Farm" },
                { coords = vec3(594.01, 6531.63, 28.95), heading = 257.22, payment = 0 },
                { coords = vec3(767.85, 6495.16, 26.15), heading = 261.88, payment = 0 },
                { coords = vec3(981.64, 6482.07, 21.82), heading = 268.96, payment = 0 },
                { coords = vec3(1297.46, 6483.88, 21.01), heading = 267.97, payment = 0 },
                { coords = vec3(1523.73, 6416.43, 24.29), heading = 247.68, payment = 150, waitTime = 10000, stopName = "Dignity Village" },
                { coords = vec3(1677.50, 6361.37, 32.61), heading = 252.66, payment = 0 },
                { coords = vec3(1837.73, 6329.22, 40.53), heading = 260.79, payment = 0 },
                { coords = vec3(1983.07, 6148.92, 47.31), heading = 216.57, payment = 0 },
                { coords = vec3(2122.98, 6018.63, 51.97), heading = 234.17, payment = 0 },
                { coords = vec3(2298.99, 5860.87, 48.67), heading = 221.67, payment = 0 },
                { coords = vec3(2485.32, 5527.33, 45.58), heading = 201.07, payment = 0 },
                { coords = vec3(2572.80, 5227.19, 45.55), heading = 194.74, payment = 0 },
                { coords = vec3(2592.83, 5135.23, 45.58), heading = 195.11, payment = 0 },
                { coords = vec3(2563.72, 5098.42, 45.38), heading = 104.79, payment = 0 },
                { coords = vec3(2417.02, 5146.39, 47.77), heading = 57.73, payment = 0 },
                { coords = vec3(2387.88, 5137.62, 48.25), heading = 145.40, payment = 0 },
                { coords = vec3(2250.10, 4997.33, 43.22), heading = 134.31, payment = 150, waitTime = 10000, stopName = "Grapeseed Farms" },
                { coords = vec3(2180.49, 4925.04, 41.62), heading = 134.22, payment = 0 },
                { coords = vec3(2181.27, 4894.87, 42.25), heading = 221.90, payment = 0 },
                { coords = vec3(2181.17, 4765.22, 42.15), heading = 167.08, payment = 0 },
                { coords = vec3(2194.49, 4742.26, 41.71), heading = 257.52, payment = 0 },
                { coords = vec3(2354.33, 4688.97, 36.70), heading = 224.15, payment = 0 },
                { coords = vec3(2432.06, 4609.06, 37.74), heading = 224.33, payment = 0 },
                { coords = vec3(2459.56, 4610.53, 37.68), heading = 315.28, payment = 0 },
                { coords = vec3(2659.73, 4810.63, 34.51), heading = 315.17, payment = 0 },
                { coords = vec3(2766.58, 4917.36, 34.50), heading = 315.50, payment = 0 },
                { coords = vec3(2799.72, 4908.83, 36.43), heading = 207.83, payment = 0 },
                { coords = vec3(2859.50, 4768.50, 49.83), heading = 203.63, payment = 0 },
                { coords = vec3(2940.11, 4719.11, 51.27), heading = 229.22, payment = 0 },
                { coords = vec3(2978.20, 4586.15, 53.85), heading = 184.02, payment = 0 },
                { coords = vec3(2965.13, 4483.10, 47.27), heading = 140.34, payment = 0 },
                { coords = vec3(2875.38, 4438.60, 49.50), heading = 109.56, payment = 150, waitTime = 10000, stopName = "Union Grain Supply Inc." },
                { coords = vec3(2819.43, 4418.49, 49.71), heading = 105.96, payment = 0 },
                { coords = vec3(2711.32, 4384.65, 48.40), heading = 117.83, payment = 0 },
                { coords = vec3(2563.80, 4228.05, 42.07), heading = 147.87, payment = 0 },
                { coords = vec3(2485.34, 4088.79, 38.83), heading = 155.55, payment = 150, waitTime = 10000, stopName = "South Grapeseed" },
                { coords = vec3(2440.56, 3992.58, 37.76), heading = 147.58, payment = 0 },
                { coords = vec3(2255.39, 3834.85, 35.08), heading = 120.28, payment = 0 },
                { coords = vec3(2079.25, 3733.26, 33.86), heading = 119.96, payment = 0 },
                { coords = vec3(2047.94, 3752.78, 33.29), heading = 30.72, payment = 0 },
                { coords = vec3(2009.29, 3754.23, 33.22), heading = 118.93, payment = 0 },
                { coords = vec3(1826.06, 3651.18, 35.12), heading = 120.55, payment = 150, waitTime = 10000, stopName = "Sandy Shores Medical Center" },
                { coords = vec3(1684.57, 3657.14, 36.41), heading = 121.03, payment = 0 },
                { coords = vec3(1684.92, 3526.13, 36.86), heading = 208.33, payment = 0 },
                { coords = vec3(1744.59, 3419.65, 38.77), heading = 208.49, payment = 0 }
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
            -- `a_m_m_beach_01`,
            -- `a_m_m_bevhills_01`,
            -- `a_m_m_business_01`,
            -- `a_m_m_eastsa_01`,
            -- `a_m_m_farmer_01`,
            -- `a_m_m_genfat_01`,
            -- `a_m_m_golfer_01`,
            -- `a_m_m_hasjew_01`,
            -- `a_m_m_hillbilly_01`
        },
        female = {
            `a_f_m_beach_01`,
            -- `a_f_m_bevhills_01`,
            -- `a_f_m_business_02`,
            -- `a_f_m_downtown_01`,
            -- `a_f_m_eastsa_01`,
            -- `a_f_m_fatbla_01`,
            -- `a_f_m_fatcult_01`,
            -- `a_f_m_fatwhite_01`,
            -- `a_f_m_ktown_01`,
            -- `a_f_m_skidrow_01`
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
    },

    -- Настройки AI-автобусов
    aiBusinessSettings = {
        enabled = true, -- Включить AI-автобусы
        busesPerRoute = 3, -- Количество AI-автобусов на маршруте
        timeBetweenBuses = 180, -- Время между AI-автобусами в секундах
        driveStyle = 786601, -- Стиль вождения AI (786603 = агрессивный, игнорирует трафик и препятствия)
        averageSpeed = 15.0, -- Средняя скорость AI-автобусов в м/с (~54 км/ч)
        proximitySpawnDistance = 300.0, -- Расстояние спавна AI-автобуса от игрока
        virtualSimulationInterval = 1000, -- Интервал обновления виртуальной позиции (мс)
        showOnMap = true, -- Показывать AI-автобусы на карте
        blipSprite = 463, -- Спрайт блипа для AI-автобусов (автобус)
        blipColor = 3, -- Цвет блипа (3 = голубой)
        blipScale = 0.6, -- Размер блипа
        blipAlpha = 150, -- Прозрачность блипа (0-255)
        driverModel = `s_m_m_gentransport`, -- Модель водителя AI-автобуса
        canHavePassengers = true, -- Могут ли AI-автобусы иметь пассажиров
        passengerChance = 70, -- Шанс наличия пассажиров в AI-автобусе (%)
        minPassengers = 5, -- Минимум пассажиров в AI-автобусе
        maxPassengers = 15 -- Максимум пассажиров в AI-автобусе
    }
}