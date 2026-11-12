# DiabolicUI for Diablo-WoW (WoW 3.3.5a)

Diablo-style interface for the Diablo-WoW server: DiabolicUI by Lars Norberg with the
action bars of Bartender4 4.4.2 (Nevcairiel) embedded as `DiabolicBars`.

## Установка
1. Скопировать папку в `Interface\AddOns\DiabolicUI`.
2. **Отключить отдельный Bartender4**, если он установлен (иначе будет два набора панелей).
3. Зайти в игру. При первом входе применяется раскладка панелей по умолчанию.

## Команды
| Команда | Что делает |
|---|---|
| `/dui` | меню настроек (скрытие элементов, панели, полоски врагов) |
| `/dui lock` | разблокировать/закрепить панели (перетаскивание) |
| `/dui kb` | назначение клавиш: навести на кнопку и нажать клавишу |
| `/dui reset` | раскладка панелей по умолчанию |
| `/dui errors`, `/dui errors clear` | журнал ошибок Lua |
| `/dbars` | полные настройки панелей (Bartender) |
| `/diabolic autoscale` | один раз выставить масштаб «пиксель в пиксель» |

## Структура
- `engine`, `handlers`, `config`, `data`, `media`, `locale` — ядро DiabolicUI
- `bartender` — встроенный Bartender4 (переименован Bartender4→DiabolicBars, BT4→DBT)
- `modules/actionbars` — подложка, якоря, раскладка по умолчанию, скин кнопок
- `modules/nameplates` — полоски над врагами
- `modules/unitframes/elements/aura.lua` — ауры цели
- `modules/options` — меню `/dui`
- `errorlog.lua` — журнал ошибок

История изменений — `CHANGELOG.md`.
