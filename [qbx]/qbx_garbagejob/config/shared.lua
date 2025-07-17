return {
    -- Локация NPC для устройства на работу
    jobNPC = {
        model = "s_m_y_garbage_01", -- Модель NPC мусорщика
        coords = vec4(-322.25, -1545.94, 31.02, 180.0), -- Координаты NPC (рядом с мусорной службой)
        blip = {
            enabled = true,
            sprite = 318, -- Иконка блипа (мусорка)
            color = 6, -- Цвет блипа (фиолетовый)
            scale = 0.8,
            label = 'Мусорная служба' -- Название блипа
        }
    },

    -- Места спавна мусоровозов (выбирается случайно)
    truckSpawnLocations = {
        vec4(-319.12, -1545.23, 31.02, 90.0),
        vec4(-315.45, -1548.67, 31.02, 90.0),
        vec4(-311.78, -1552.11, 31.02, 90.0),
        vec4(-308.11, -1555.55, 31.02, 90.0),
        vec4(-325.89, -1541.79, 31.02, 90.0),
        vec4(-329.56, -1538.35, 31.02, 90.0)
    },

    -- Точки сбора мусора по всему городу
    garbagePoints = {
        -- Grove Street и окрестности
        { coords = vec3(-58.97, -1751.52, 29.42), name = "Жилой район Grove Street", payment = 150 },
        { coords = vec3(-126.45, -1691.23, 29.30), name = "Дома на Grove Street", payment = 140 },
        { coords = vec3(-204.67, -1632.89, 33.03), name = "Магазины Grove Street", payment = 160 },

        -- Промышленная зона
        { coords = vec3(126.75, -1929.58, 21.38), name = "Промышленная зона", payment = 180 },
        { coords = vec3(89.23, -1967.45, 20.75), name = "Склады", payment = 170 },
        { coords = vec3(156.78, -1888.12, 23.45), name = "Заводская территория", payment = 185 },

        -- Центр города
        { coords = vec3(194.2, -830.5, 31.2), name = "Центральная площадь", payment = 200 },
        { coords = vec3(304.36, -764.56, 29.31), name = "Больница", payment = 190 },
        { coords = vec3(-250.14, -886.78, 30.63), name = "Банковский район", payment = 210 },

        -- Торговые районы
        { coords = vec3(-692.63, -670.44, 30.86), name = "Торговый центр", payment = 195 },
        { coords = vec3(-1487.56, -378.45, 40.16), name = "Магазины Morningwood", payment = 175 },
        { coords = vec3(-1222.34, -906.78, 12.33), name = "Пирс Vespucci", payment = 165 },

        -- Жилые районы
        { coords = vec3(-712.83, -824.56, 23.54), name = "Пляжные дома", payment = 155 },
        { coords = vec3(-110.31, -1686.29, 29.31), name = "Мотель", payment = 145 },
        { coords = vec3(372.45, -1789.23, 29.09), name = "Жилой комплекс", payment = 160 },

        -- Северные районы
        { coords = vec3(-1456.78, -234.56, 49.23), name = "Элитный район", payment = 220 },
        { coords = vec3(-789.12, 156.34, 75.88), name = "Винвуд Хиллз", payment = 230 },
        { coords = vec3(-567.89, 289.45, 82.17), name = "Ричман", payment = 240 },

        -- Восточные районы
        { coords = vec3(1234.56, -567.89, 69.12), name = "Зеркало Парк", payment = 170 },
        { coords = vec3(987.65, -432.10, 64.05), name = "Ист Винвуд", payment = 165 },
        { coords = vec3(1456.78, -234.56, 66.23), name = "Эль Бурро Хайтс", payment = 155 }
    },

    -- Точки разгрузки (свалки)
    dumpPoints = {
        {
            coords = vec3(-413.97, -1678.23, 19.03),
            name = "Городская свалка",
            bonusPayment = 400,
            blip = {
                sprite = 365, -- Иконка свалки
                color = 1, -- Красный цвет
                scale = 0.7
            }
        },
        {
            coords = vec3(2358.21, 3133.44, 48.21),
            name = "Промышленная свалка",
            bonusPayment = 450,
            blip = {
                sprite = 365,
                color = 1,
                scale = 0.7
            }
        }
    },

    -- Модели мусоровозов
    garbageTrucks = {
        {
            model = `trash`,
            label = 'Стандартный мусоровоз',
            capacity = 10, -- Максимум точек сбора до разгрузки
            deposit = 0 -- Залог за мусоровоз
        },
        {
            model = `trash2`,
            label = 'Большой мусоровоз',
            capacity = 15,
            deposit = 0
        }
    },

    -- Настройки работы
    settings = {
        collectionRadius = 8.0, -- Радиус точки сбора мусора
        dumpRadius = 10.0, -- Радиус точки разгрузки
        showBlips = true, -- Показывать блипы точек
        showMarkers = true, -- Показывать маркеры точек
        showNotifications = true, -- Показывать уведомления
        requireDeposit = false, -- Требовать залог за мусоровоз
        routeSize = {
            min = 5, -- Минимум точек в маршруте
            max = 8  -- Максимум точек в маршруте
        },
        collectionTime = {
            min = 8000, -- Минимальное время сбора мусора (мс)
            max = 12000 -- Максимальное время сбора мусора (мс)
        },
        dumpTime = {
            min = 5000, -- Минимальное время разгрузки (мс)
            max = 8000  -- Максимальное время разгрузки (мс)
        }
    },

    -- Анимации
    animations = {
        collectGarbage = {
            dict = "anim@mp_snowball",
            anim = "pickup_snowball",
            flag = 0,
            duration = 3000
        },
        dumpGarbage = {
            dict = "anim@heists@box_carry@",
            anim = "idle",
            flag = 49,
            duration = 2000
        }
    }
}