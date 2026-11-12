# DiabolicUI for Diablo-WoW — журнал изменений / changelog

## 2.0.0-diablowow — 2026-11-12

### Русский

**Сборка и загрузка**
- Восстановлены папки `engine`, `config`, `data`, `media` и файлы `handlers/statusbar.lua`, `tooltip.lua`, `unitframe.lua`: при загрузке на GitHub (лимит 100 файлов) они потерялись, аддон из репозитория не запускался.
- `Interface: 70000` → `30300`: клиент 3.3.5 больше не считает аддон устаревшим.
- Объявлены все SavedVariables (`DiabolicBarsDB`, `DiabolicUI_OptionsDB`, `DiabolicUI_ErrorLog`, `DiabolicUI_CharDB`) — настройки теперь сохраняются между сессиями.

**Панели команд = DiabolicUI + Bartender4**
- Встроен Bartender4 4.4.2 (3.3.5) под именем `DiabolicBars` (префикс фреймов `DBT`), конфликтов с отдельно установленным Bartender4 нет. Бинды обычных панелей подхватываются автоматически.
- Старые панели DiabolicUI удалены. Сохранены фирменная подложка (демон, ангел, череп) под 1/2/3 ряда и фреймы-якоря для сфер, трекера и т. п.
- Рамка кнопок DiabolicUI на всех кнопках действий, питомца и стоек; набор текстур (36/44/50 px) выбирается по реальному размеру кнопки.
- Раскладка по умолчанию в стиле Diablo: 1–3 нижних ряда, 2 правые панели, питомец, стойки, тотемы.
- Меню больше не открывается отдельной кнопкой: обычная нижняя панель микрокнопок справа, как в стандартном интерфейсе, включая **магазин** и **трансмог**; над ней сумки.
- Микроменю возвращается на место после смены талантов (`MainMenuBar_ToPlayerArt`).
- Полоска опыта Парагона (`ParagonXPBarFrame`) перенесена из скрытой `MainMenuBar` на место полоски опыта DiabolicUI.
- Модуль тотемов DiabolicUI удалён: тотемами управляет Bartender, двойного перемещения нет.

**Масштаб**
- Ядро больше не выставляет `uiScale` само при каждом изменении экрана и не удаляет ползунок масштаба из настроек видео. Работает стандартный масштаб клиента. «Пиксель в пиксель» — разово командой `/diabolic autoscale`.

**Чат**
- Убран фильтр «залипшей клавиши»: он стирал сообщение и закрывал поле ввода, если последние 6 символов совпадали (`))))))`, `!!!!!!`, `......`).
- Убрано принудительное скрытие поля ввода при потере фокуса (клиент делает это сам в режиме «IM»).

**Цель и враги**
- Реализован элемент аур (раньше был пустой заглушкой): под фреймом цели видны баффы и дебаффы с таймером, стаками, цветом по типу дебаффа, подсказкой; на врагах сначала ваши дебаффы.
- Новые неймплейты в стиле DiabolicUI (раньше модуль был пустым): здоровье, каст-бар с иконкой, имя, уровень, череп босса, рейдовая метка, подсветка цели, подсветка угрозы, ваши дебаффы над целью.
- Режим «полоски врагов над моделью»: верхний фрейм цели скрывается для обычных врагов (боссы, элиты, редкие и игроки остаются сверху). Переключается в `/dui`.

**Настройки**
- Одно меню `/dui` вместо трёх пересекающихся (`options.lua`, `movers.lua`, `moveframes.lua` регистрировали одну и ту же `/diomove`).
- Скрытие каждого элемента: каждая панель, подложка, сферы, цель, цель цели, фокус, питомец, миникарта, опыт/парагон, баффы, список заданий, чат.
- Разблокировка и перетаскивание панелей, режим назначения клавиш, 1/2/3 нижних ряда, сброс раскладки, полные настройки Bartender (`/dbars`).
- Пункт DiabolicUI в «Интерфейс → Модификации».
- Журнал ошибок Lua в `SavedVariables\DiabolicUI.lua` (`/dui errors`, `/dui errors clear`).

### English

**Build / loading**
- Restored `engine`, `config`, `data`, `media` and three handler files lost by the 100-file GitHub web upload limit (the repo version could not load).
- `Interface: 70000` → `30300` (no more "out of date" on the 3.3.5 client).
- All SavedVariables declared, settings now persist.

**Action bars = DiabolicUI + Bartender4**
- Bartender4 4.4.2 embedded as `DiabolicBars` (`DBT` frame prefix), safe next to a standalone Bartender4; default keybinds carry over.
- Old DiabolicUI bars removed; artwork (demon/angel/skull for 1/2/3 rows) and anchor frames kept.
- DiabolicUI button border skin on action/pet/stance buttons, 36/44/50 px texture set picked by on-screen size.
- Diablo-style default layout; standard bottom-right micro menu including **Shop** and **Transmog**, bags above it.
- Micro menu restored after talent swaps; paragon bar moved from the hidden MainMenuBar to the DiabolicUI XP slot; DiabolicUI totem module dropped in favour of Bartender's.

**Scale**: the engine no longer forces `uiScale` on every display/scale event and no longer removes the Blizzard scale slider; `/diabolic autoscale` applies pixel-perfect scale once on demand.

**Chat**: removed the "stuck key" filter that wiped messages ending in 6 equal characters (`))))))`), and the forced edit box hide on focus loss.

**Target / enemies**: real aura element (target buffs/debuffs, timers, stacks, debuff-type colors, tooltips); new DiabolicUI-style nameplates (health, cast bar, name, level, boss skull, raid icon, target and threat highlight, your debuffs); optional "enemy bars above the model" mode hiding the top target frame for ordinary enemies.

**Options**: single `/dui` menu replacing three overlapping ones; hide toggle for every element and bar; lock/unlock, keybind mode, 1/2/3 rows, layout reset, full Bartender options (`/dbars`); Interface → AddOns entry; Lua error log in SavedVariables.

### Не проверено в игре / not yet tested in game
Код проверен на синтаксис и ссылки на файлы, но в клиенте ещё не запускался. Нужен тест на тестовом реалме; ошибки собираются в `/dui errors`.
Syntax and file references are verified, but the build has not been run in the client yet. Errors are collected by `/dui errors`.
