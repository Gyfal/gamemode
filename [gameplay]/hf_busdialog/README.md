# HF Bus Dialog System

Диалоговая система на Svelte для работы с автобусником (hf_busjob).

## Описание

Это ресурс предоставляет современную диалоговую систему с красивым UI на основе Svelte для взаимодействия игроков с NPC диспетчера автопарка.

## Возможности

- 🎨 Современный UI на Svelte с плавными анимациями
- 💬 Система диалогов с множественными вариантами ответов
- 🎥 Автоматическая камера при разговоре с NPC
- 🔌 Поддержка ox_target и qb-target
- 🎮 Полная интеграция с hf_busjob
- 🌐 Легкая настройка через config.lua

## Установка

1. Поместите ресурс в папку `[gameplay]`
2. Убедитесь, что `hf_busjob` установлен
3. Ресурс автоматически загрузится через `ensure [gameplay]` в server.cfg

## Зависимости

- ox_target или qb-target
- qbx_core (для интеграции с автобусником)
- ox_lib

## Конфигурация

Откройте `config.lua` для настройки:

```lua
Config.Target = 'ox' -- 'ox' или 'qb'
Config.Camera.enabled = true -- Включить/выключить камеру
Config.Camera.fov = 30.0 -- Поле зрения камеры
```

## Разработка

Для разработки UI:

```bash
cd web
npm install
npm run dev
```

Для сборки:

```bash
npm run build
```

## Интеграция с автобусником

Ресурс автоматически интегрируется с hf_busjob:
- При взаимодействии с NPC диспетчера открывается диалог
- Игрок может устроиться на работу через диалог
- Игрок может взять автобус или уволиться через диалог

## API

### Экспорты

```lua
-- Открыть диалог
exports.hf_busdialog:OpenDialog({
    ped = pedEntity, -- (опционально) entity педа для камеры
    data = {
        label = 'Заголовок',
        text = 'Текст диалога',
        responses = {
            {
                label = 'Вариант 1',
                event = 'eventName', -- (опционально)
                type = 'client', -- 'client' или 'server'
                close = false, -- закрыть диалог после клика
                data = {...} -- (опционально) следующий диалог
            }
        }
    }
})

-- Изменить диалог
exports.hf_busdialog:SetDialog({
    label = 'Новый заголовок',
    text = 'Новый текст',
    responses = {...}
})

-- Закрыть диалог
exports.hf_busdialog:CloseDialog()

-- Заспавнить педа из конфига
exports.hf_busdialog:SpawnPed('ped_id')
```

## Лицензия

MIT

## Автор

HF Team
