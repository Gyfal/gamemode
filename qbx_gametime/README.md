# QBX GameTime

Система игрового времени для FiveM сервера с привязкой к московскому времени (МСК).

## Особенности

- 🕐 Синхронизация с московским временем (UTC+3)
- 📅 7-дневный игровой цикл (каждый день = 205 минут реального времени)
- 🌤️ Динамическая система погоды
- ⚡️ Синхронизация через GlobalState (StateBag) без лишних сетевых событий
- 🛠️ Административные команды
- 🌍 Мультиязычность (RU/EN)
- 🔧 Интеграция с Qbox Framework и ox_lib

## Как работает система времени

Система использует `GlobalState` для передачи текущего времени, дня недели и погоды клиентам. Это уменьшает сетевую нагрузку:

```lua
-- Сервер
GlobalState.currentTime = {hour = 12, minute = 30}
GlobalState.weather     = {current = 'CLEAR', next = 'CLOUDS'}

-- Клиент
AddStateBagChangeHandler('currentTime', 'global', function(_, _, time) ... end)
```

### Расписание дней недели (МСК)

| День недели | Начало (МСК) | Конец (МСК) |
|-------------|--------------|-------------|
| Понедельник | 06:00 | 09:25 |
| Вторник | 09:25 | 12:50 |
| Среда | 12:50 | 16:15 |
| Четверг | 16:15 | 19:40 |
| Пятница | 19:40 | 23:05 |
| Суббота | 23:05 | 02:30 (+1) |
| Воскресенье | 02:30 | 06:00 |

## Установка

1. Скопируйте папку `qbx_gametime` в папку `resources`
2. Добавьте в `server.cfg`:
```
ensure qbx_gametime
```

## Команды

### Для игроков
- `/time` - Показать текущее время и день недели

### Для администраторов
- `/settime [час] [минута]` - Установить время
- `/setday [1-7]` - Установить день недели
- `/freezetime` - Заморозить/разморозить время
- `/setweather [тип]` - Установить погоду
- `/timemenu` - Открыть меню управления временем

## Конфигурация

Основные настройки находятся в `config/shared.lua`:

```lua
-- Длительность игрового дня в минутах
dayDurationMinutes = 205

-- Начало недели в МСК
weekStartHourMSK = 6
weekStartMinuteMSK = 0

-- Часовой пояс (МСК = UTC+3)
timezoneOffset = 3

-- Интервал синхронизации (мс) **устарело** – синхронизация теперь через GlobalState
syncInterval = 30000  -- legacy, не используется

-- Показывать время в HUD
showInHud = true

-- Формат 24 часа
format24h = true
```

## Экспорты

### Серверные
```lua
-- Получить текущее время
exports['qbx_gametime']:GetCurrentTime()
-- Возвращает: {hour = 12, minute = 30, second = 0}

-- Получить текущий день
exports['qbx_gametime']:GetCurrentDay()
-- Возвращает: dayNumber, dayName

-- Получить текущую погоду
exports['qbx_gametime']:GetCurrentWeather()
-- Возвращает: "CLEAR"

-- Установить время
exports['qbx_gametime']:SetTime(hour, minute)
-- Возвращает: true/false
```

### Клиентские
```lua
-- Получить текущее время
exports['qbx_gametime']:GetCurrentTime()

-- Получить текущий день
exports['qbx_gametime']:GetCurrentDay()

-- Получить текущую погоду
exports['qbx_gametime']:GetCurrentWeather()
```

## События

### Серверные/Клиентские
```lua
-- При изменении времени (каждую игровую минуту)
RegisterNetEvent('qbx_gametime:timeChanged', function(hour, minute)
    print(string.format("Время изменилось: %02d:%02d", hour, minute))
end)

-- При смене дня
RegisterNetEvent('qbx_gametime:dayChanged', function(dayNumber, dayName)
    print(string.format("Новый день: %s", dayName))
end)

-- При смене погоды
RegisterNetEvent('qbx_gametime:weatherChanged', function(current, next)
    print(string.format("Погода меняется с %s на %s", current, next))
end)
```

## Callback

```lua
-- Получить полные данные о времени
local timeData = lib.callback.await('qbx_gametime:getTimeData', false)
-- Возвращает:
-- {
--     time = {hour = 12, minute = 30, second = 0},
--     day = 1,
--     dayName = "Понедельник",
--     weather = {current = "CLEAR", next = "CLOUDS", timer = 10}
-- }
```

## Типы погоды

- `CLEAR` - Ясно
- `CLOUDS` - Облачно
- `OVERCAST` - Пасмурно
- `RAIN` - Дождь
- `THUNDER` - Гроза
- `FOGGY` - Туман
- `SMOG` - Смог
- `SNOW` - Снег
- `BLIZZARD` - Метель
- `SNOWLIGHT` - Легкий снег
- `XMAS` - Рождество
- `HALLOWEEN` - Хэллоуин

## Права доступа

По умолчанию используются ACE permissions:
```
add_ace group.admin qbx.admin allow
```

Или можно настроить группы в конфигурации:
```lua
adminPermissions = {
    allowedGroups = {'admin', 'god'},
    useAcePerms = false
}
```

## Интеграция с другими ресурсами

### Пример использования в другом ресурсе
```lua
-- Проверить, день ли сейчас
local time = exports['qbx_gametime']:GetCurrentTime()
if time.hour >= 6 and time.hour < 20 then
    print("Сейчас день")
else
    print("Сейчас ночь")
end

-- Подписаться на смену дня
RegisterNetEvent('qbx_gametime:dayChanged', function(dayNumber, dayName)
    if dayNumber == 6 or dayNumber == 7 then
        -- Выходные (суббота/воскресенье)
        -- Можно добавить бонусы или особые события
    end
end)
```

## Лицензия

Этот ресурс распространяется под лицензией MIT.