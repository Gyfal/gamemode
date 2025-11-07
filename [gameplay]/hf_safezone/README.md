# HF SafeZone - Система безопасных зон для FiveM QBOX

Расширенная система безопасных зон с отключением коллизий, защитой от урона и синхронизацией между игроками.

## Особенности

- ✅ **Отключение коллизий**: Игроки проходят сквозь друг друга и транспорт в зоне
- ✅ **Защита от урона**: Игроки в зоне защищены от урона извне
- ✅ **Транспорт**: Машины становятся призраками в зоне
- ✅ **Синхронизация**: Серверная синхронизация через QBOX
- ✅ **Автоматический спавн**: Машины заспавненные в зоне автоматически становятся прозрачными

## Требования

- FiveM сервер
- QBOX Framework
- ox_lib

## Установка

1. Поместите ресурс в папку `resources/[gameplay]/`
2. Добавьте в `server.cfg`:
```
ensure hf_safezone
```

## Конфигурация ACE Permissions

Добавьте в `server.cfg` для админских команд:

```bash
# SafeZone Admin Permissions
add_ace group.admin command.createzone allow
add_ace group.admin command.removezone allow  
add_ace group.admin command.checkzone allow

# Добавить игрока в группу admin (замените steam:ID на реальный)
add_principal identifier.steam:110000xxxxxxx group.admin
```

## Команды

### Админские команды:
- `/createzone <type> <id> <name>` - Создать зону (sphere/box/polygon)
- `/removezone <id>` - Удалить зону по ID
- `/checkzone` - Показать список игроков в зонах

### Примеры:
```
/createzone sphere safezone1 "Безопасная зона 1"
/createzone box garage1 "Гараж 1" 
/removezone safezone1
```

## Настройка зон

Зоны настраиваются в файле `config/shared.lua`:

```lua
safeZones = {
    {
        id = 'busjob_depot',
        name = 'Автопарк Sandy Shores',
        type = 'sphere',
        coords = vector3(1726.0, 3318.0, 42.0),
        radius = 60.0,
        debug = true,
        settings = {
            disablePvP = true,
            disableVehicleCollisions = true,
            disablePlayerCollisions = true,
            disableWeapons = true,
            godMode = false,
        }
    }
}
```

## Экспорты

### Клиентские:
```lua
-- Проверить находится ли игрок в зоне
local inZone = exports.hf_safezone:isPlayerInSafeZone()

-- Получить текущую зону
local zone = exports.hf_safezone:getCurrentSafeZone()

-- Проверить иммунитет коллизий
local hasImmunity = exports.hf_safezone:hasCollisionImmunity(playerSource)
```

### Серверные:
```lua
-- Проверить находится ли игрок в зоне
local inZone = exports.hf_safezone:IsPlayerInSafeZone(source)

-- Получить ID зоны игрока
local zoneId = exports.hf_safezone:GetPlayerSafeZone(source)
```

## События

### Серверные:
- `hf_safezone:server:playerEnteredZone` - Игрок вошел в зону
- `hf_safezone:server:playerExitedZone` - Игрок вышел из зоны
- `hf_safezone:server:checkDamage` - Проверка урона между игроками

### Клиентские:
- `hf_safezone:client:createZone` - Создать зону
- `hf_safezone:client:removeZone` - Удалить зону
- `hf_safezone:client:syncPlayers` - Синхронизация игроков
- `hf_safezone:client:cancelDamage` - Отмена урона

## Интеграция с QBOX

Ресурс использует QBOX metadata для сохранения состояния:
- `inSafeZone` (boolean) - Находится ли игрок в зоне
- `safeZoneId` (string) - ID текущей зоны

## Поддержка

При возникновении проблем проверьте:
1. Все зависимости установлены
2. ACE permissions настроены правильно 
3. Нет конфликтов с другими ресурсами

## Лицензия

MIT License