# Quickshell bar

Перенос верхнего бара из Waybar. Старый конфиг Waybar не изменён и остаётся
в `~/.config/waybar` как запасной вариант.

## Запуск

```sh
qs -d          # запустить в фоне
qs -p ~/.config/quickshell   # запустить из терминала (для отладки)
qs kill        # остановить
```

При сохранении файлов Quickshell сам перезагружает конфиг. Для изменений,
которые требуют перезапуска (например, `//@ pragma` в `shell.qml`), используйте
`qs kill && qs -d`.

## Структура

- `shell.qml` — точка входа, создаёт бар на каждом мониторе.
- `Bar.qml` — геометрия панели, фон, раскладка левой/центральной/правой части.
- `Theme.js` — цвета, шрифт и иконки Nerd Font.
- `components/Workspaces.qml` — рабочие столы Hyprland, клики и прокрутка.
- `components/Clock.qml`, `components/CalendarPopup.qml` — часы и календарь.
- `components/Language.qml` — раскладка клавиатуры (ENG/RUS).
- `components/CpuStats.qml`, `MemoryStats.qml`, `DiskStats.qml` — системные
  показатели и их подсказки.
- `components/Volume.qml` — громкость PipeWire.
- `components/Tray.qml` — системный трей.
- `components/Notifications.qml` — индикатор и переключатель swaync.
- `components/PowerButton.qml` — кнопка wlogout.
- `components/Tooltip.qml` — общая всплывающая подсказка.

## Автозапуск

Уже настроен в `~/.config/hypr/exec.lua`:

```lua
hl.exec_cmd("qs -n -d")
hl.exec_cmd("swaync")
-- hl.exec_cmd("waybar & swaync")
```

Строка с Waybar оставлена закомментированной как запасной вариант. Чтобы
вернуться к Waybar, раскомментируйте её и уберите запуск `qs`.
