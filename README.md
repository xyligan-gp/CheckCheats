# CheckCheats [Fork]
**CheckCheats [Fork]** - форк известного [Rust Check Cheats](https://hlmod.ru/resources/rust-check-cheats.1437/)

## Админская часть
Администратор отправляет игроку запрос на проверку. После отправки запроса у него появится панель в проверки в которой он сможет:

* Узнать статус проверки
* Напомнить игроку о введении данных Discord или Skype
* Переместить игрока за наблюдателей и заблокировать ему заходить в игру во время проверки
* Принудительно окончить проверку

## Клиентская часть
После того как администратор вызвал игрока на проверку, тот в свою очередь должен выбрать мессенджер для проверки (Discord или Skype) и отправить свои данные в чат. Далее игрок ожидает звонка администратора. Если игрок покинет сервер во время проверки, то он будет наказан вечным баном на сервере.

## Статусы проверки
* Ожидание Discord или Skype (начало проверки)
* Ожидание звонка администратора (после успешного ввода данных)
* Проверка на читы (после подтверждения "Принятия звонка")
* Результат проверки (после проверки на читы, вердикт администратора)

## Логи плагина
В отличии от оригинальной версии все логи пишутся в 1 файл: `addons/sourcemod/logs/CheckCheats.log`

* Начало проверки (вызов игрока на проверку администратором сервера
* Введение данных Discord или Skype
* Уход проверяемого игрока с сервера
* Уход проверяющего администратора с сервера
* Результат проверки (обнаружены читы или нет))

# История изменений:
### Версия 2.0:
* Релиз
### Версия 3.0:
* Частично изменён синтаксис плагина
* Добавлена настройка плагина через конфиг, который находится в `addons/sourcemod/configs/CheckCheats.ini`
* Оптимизация кода
* Добавление логов
### Версия 3.1:
* Исправление работы плагина с конфигом
* Добавлена совместимость с Base Bans
* Переписана система логов плагина
* Исправлен баг с наличием SourceTV, ботов и администраторов в списке игроков на проверку (в конфиг плагина добавлен квар `hideAdmins "1"` для этой функции)
* Фикс багов и оптимизация кода
### Версия 3.1.1:
* Исправление багов

## Полезные ссылки:
* Ссылка на оригинальный плагин: [CheckCheats](https://hlmod.ru/resources/rust-check-cheats.1437/)
* Ссылка на тему hlmod: [CheckCheats [Fork]](https://hlmod.ru/resources/check-cheats-fork.3012/)
* Авторы форка [xyligan](https://hlmod.ru/members/xyligan.117532/) и [Nico Yazawa](https://hlmod.ru/members/nico-yazawa.94481/)

#### Важная информация: данный плагин работает в совместимости с Base Bans, SourceBans, SourceBans++ и Material Admin. Данный форк имеет некоторые отличия от оригинальной версии плагина. Все баги форка будут постепенно исправляться.

**Данный форк не является идеальным и будет улучшаться.**
