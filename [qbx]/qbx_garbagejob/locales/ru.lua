return {
    -- NPC взаимодействие
    npc_hire = 'Устроиться мусорщиком',
    npc_get_truck = 'Взять мусоровоз',
    npc_quit = 'Уволиться',

    -- Уведомления о работе
    job_started = 'Вы устроились мусорщиком!',
    job_ended = 'Вы уволились с работы мусорщика',
    truck_spawned = 'Мусоровоз готов! Следуйте к первой точке сбора',
    already_working = 'Вы уже работаете мусорщиком!',
    not_working = 'Вы не работаете мусорщиком!',

    -- Сбор мусора
    arrived_at_point = 'Вы прибыли к точке сбора: %s',
    collecting_garbage = 'Сбор мусора...',
    garbage_collected = 'Мусор собран! Получено: $%d',
    truck_full = 'Мусоровоз заполнен! Направляйтесь на свалку',

    -- Разгрузка
    arrived_at_dump = 'Вы прибыли на свалку: %s',
    dumping_garbage = 'Разгрузка мусора...',
    garbage_dumped = 'Мусор разгружен! Бонус: $%d',
    new_route_generated = 'Новый маршрут создан! Следуйте к первой точке',

    -- Контроль работы
    left_truck = 'Вы покинули мусоровоз! Вернитесь в течение %d секунд',
    returned_to_truck = 'Вы вернулись в мусоровоз',
    fired_left_truck = 'Вы уволены за покидание мусоровоза!',
    cancel_job_hold = 'Удерживайте X для отмены работы',
    job_cancelled = 'Работа отменена',

    -- Статистика
    shift_earnings = 'Заработано за смену: $%d',
    work_time = 'Время работы: %d мин',
    garbage_points_completed = 'Точек сбора завершено: %d',
    dumps_completed = 'Разгрузок завершено: %d',

    -- Ошибки
    error_truck_spawn = 'Не удалось создать мусоровоз!',
    error_too_far = 'Вы слишком далеко от NPC!',
    error_no_money = 'У вас недостаточно денег для залога!',
    error_invalid_payment = 'Ошибка при получении оплаты',

    -- Инструкции
    instruction_start = 'Следуйте к точкам сбора мусора по GPS',
    instruction_collect = 'Нажмите E для сбора мусора',
    instruction_dump = 'Нажмите E для разгрузки мусора',
    instruction_cancel = 'Удерживайте X для отмены работы',

    -- Прогресс
    progress_collecting = 'Сбор мусора',
    progress_dumping = 'Разгрузка мусора',

    -- Блипы
    blip_garbage_service = 'Мусорная служба',
    blip_garbage_point = 'Точка сбора мусора',
    blip_dump_site = 'Свалка'
}