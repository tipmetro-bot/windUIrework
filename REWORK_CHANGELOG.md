# WindUI Rework — changelog

База: [Footagesus/WindUI](https://github.com/Footagesus/WindUI) v1.6.66 (`d2c9bac`, 2026‑11‑02).
Версия реворка: `1.6.66-rework.1` (2026‑11‑03).

## Исправления

### Кнопка открытия / закрытия
- `Window:Close()` больше не содержит `not Window.IsPC` — open button появляется на ПК, телефонах и консолях.
- Новое определение платформы в `src/components/window/Init.lua`: `TouchEnabled / KeyboardEnabled / MouseEnabled / GamepadEnabled` → `IsMobile / IsPC / IsConsole / InputDevice`.
- `src/components/window/Openbutton.lua` переписан: `Activated` + `MouseButton1Click` + `TouchTap`, debounce, вызов `Window:Toggle()` (а не только `Open()`), увеличенный хитбокс на тач‑устройствах.
- `Edit()` больше не присваивает `Window.IsPC`, корректно обрабатывает `Draggable = true`, `Enabled = false`, `OnlyIcon`, `Position`, `Scale`, `Color`, `CornerRadius`, `StrokeThickness`.
- Новые опции: `StayVisible` (кнопка видна и при открытом окне = настоящий open/close), `ShowOnPC`.
- `ToggleKey` принимает `Enum.KeyCode`, строку или список; добавлен debounce `Window:Toggle()`.
- `LastInputTypeChanged` обновляет платформу без перезапуска.

### Слайдеры с нулём
- Новый чистый модуль `src/modules/SliderMath.lua`: нормализация `Min/Max/Default/Step`, защита от `0/0`, `Step = 0`, `NaN/inf`, снап относительно `Min`, кламп в `[Min, Max]`.
- `src/elements/Slider.lua` переписан: `:Set(0)` и загрузка конфига с `0` всегда обновляют UI и вызывают колбэк; плоский синтаксис `Min/Max/Default`; `Value = number`.
- Тач‑драг: `InputChanged` + позиция указателя, `InputEnded` сравнивает тип ввода (не `InputObject`), failsafe‑таймаут, гарантированный возврат `ScrollingEnabled`.
- `:SetMin(0)`, `:SetMax(0)`, `:SetStep(0)`, `:GetValue()`, `:SetValue()`, `:Refresh()`.
- `src/config/Init.lua`: `Slider.Save/Load` корректно работают с `0`; `CreateConfig(nil)` больше не падает.

## Новое

- `src/modules/Animations.lua`: профили `Smooth / Snappy / Calm / Reduced / None`, `Play / Pop / Fade / Stagger / Press / Pulse`, глобальные `WindUI:SetAnimationProfile`, `:SetAnimationsEnabled`, `:SetAnimationSpeed`.
- Плавные анимации окна (size + spring scale), open button (fade/slide/scale/ripple/glow), слайдера (fill/thumb), панели профиля (slide/fade/stagger/секции/переключатели).
- `src/components/window/ProfilePanel.lua`: Neverlose‑подобная панель в нижнем левом углу поверх профиля; секции «Комбат» (Сайлент аим, Аимбот, Триггербот, Kill All) и «Визуалы» (ESP, ESP Box, ESP Skeleton); открытие кликом по профилю, `×`, кликом вне, `Escape`; сохранение через ConfigManager API; `Window:Profile(cfg)` или `CreateWindow{ Profile = ... }`.
- `examples/rework_example.client.lua` — полный пример.
- `tools/bundle.py` — сборка `dist/main.lua` без darklua/Rojo; `tools/check_syntax.mjs` — проверка Luau.
- `tests/slider_math_test.luau` — 38 регрессионных проверок на нули (чистый Luau).
- `tests/bundle_smoke.luau` + `tools/smoke_test.py` — загрузка бандла с моками Roblox и создание окна / вкладки / слайдеров / панели профиля в Luau VM.
- Кнопки топбара (в т.ч. «свернуть») переведены на `Activated` + `TouchTap` с debounce и увеличенным тач‑таргетом.
- `src/Icons/Main-v2.lua`: иконки больше не скачиваются `HttpGet` без `pcall` (при заблокированном GitHub падала вся библиотека) — используются завендоренные таблицы; `AddIcons` понимает плоские паки, неизвестная иконка больше не крашит окно.
- `.github/workflows/build.yml` — CI: парсинг всех Luau‑файлов + проверка свежести бандла.
- `README.md` (этот репозиторий) и данный changelog.
- `src/Icons/` — сабмодуль иконок завендорен обычными файлами.

## Инфраструктура

- `package.json`: `build`, `bundle`, `check`, `test`, `dev`; `luau-parser` в devDependencies.
- `build/build.sh` теперь вызывает `tools/bundle.py`.
- `.gitignore` больше не игнорирует `src/server/`, `sourcemap.json`, `.env.example`.
- Удалены upstream‑воркфлоу, завязанные на darklua/aftman/сабмодули (`pull_request.yml`, `release.yml`, `comment-pr.yml`).

## Второй проход: чек-лист багов + настройки в UI

### Исправления по списку (8 пунктов)
1. **ConfigManager / флаги** — `Dropdown.Save` читает живое `Value`, `Colorpicker.Load` добавляет `#` к hex (раньше `Color3.fromHex` всегда падал), `RegisterAll()` подхватывает флаги, заданные после создания элемента, `ConfigModule:Load()` применяет значения синхронно внутри `Creator.SuspendCallbacks` — колбэки больше не срабатывают повторно. Добавлен парсер `Choice`.
2. **Key System** — guard `WindUI.CreateWindowBusy` не даёт создать окно дважды, ожидание ограничено по кадрам и завершается при нажатии «Выход», все соединения диалога отключаются в `Finish()`, запись ключа защищена `pcall`.
3. **Dropdown / MultiDropdown** — новый `:SetValues()` обновляет список на лету, `Refresh(Values, silent)` не дёргает колбэк, клик вне списка считается по `Input.Position` (вместо `Mouse.X/Y`, который не учитывал `GuiInset` на телефонах), `ZIndex` меню = 9999.
4. **Slider** — при `Locked` выставляется `Active = false` на всех хит-поверхностях и `TextEditable = false`; `SliderMath.Format` округляет до точности `Min/Max/Step`, а не всегда до `%.2f`.
5. **Темы** — `CreateWindow` теперь идёт через `WindUI:SetTheme` (синхронизирует `WindUI.CurrentTheme`), `AddTheme` сразу применяет тему, в `themes/Fallbacks.lua` добавлены недостающие ключи (`Layer`, `Acrylic*`, `PlaceholderText`, `WindowShadowTransparency`).
6. **Resize / Drag** — `Creator.Drag` учитывает `GuiService:GetGuiInset()`, клампит позицию к вьюпорту и умеет `:Destroy()`.
7. **ZIndex / ScreenGui** — явная таблица `WindUI.DisplayOrders` (Window 10 → Loading 100), `ZIndexBehavior = "Sibling"` на всех ScreenGui, API `WindUI:SetDisplayOrder(name, value)`.
8. **Connections** — `Creator.DisconnectAll` переписан (старый цикл с `table.remove` пропускал половину), добавлены `AddScopedSignal` / `DisconnectGroup`; слайдер, дропдаун и диалог ключа освобождают свои соединения при Destroy.

### Новые возможности
- `src/modules/ReworkLocalization.lua` — встроенный словарь RU/EN, интегрирован в штатный `WindUI:Localization` / `:SetLanguage`; `WindUI:GetLanguage()`, `:OnLanguageChange(fn)`.
- Секция **«Настройки»** в панели профиля: `Язык RU/EN`, `Тема Dark/Light`, `Экран загрузки`, `Загружать настройки` — новый тип строк `Choice`. Всё кликается в UI, `Settings = false` скрывает секцию.
- `src/components/window/LoadingScreen.lua` — настраиваемый оверлей (`Loading = false | true | { Enabled, Duration, Title, Steps, AutoHide }`), `WindUI:SetLoadingEnabled(bool)`, переключатель в настройках.
- Key System: нижние кнопки **Get Key** / **Check Key** (локализованные), «Выход» корректно отменяет создание окна.
- Open/close кнопка: `Window.Closed` меняется мгновенно (быстро двойной тап больше не открывает окно дважды), `SetOpenState()` показывает «Открыть/Закрыть», повторный `Visible(true)` не переигрывает анимацию.

## Скрипт с Key System (ключ `test`)

`examples/rework_example.client.lua` переписан с нуля: компактный готовый скрипт для executor с единственным рабочим ключом **`test`** (`KeySystem.Key = { "test" }`, `SaveKey = false`), подсказкой в диалоге (`Note`), guard'ом `if not Window then return end`, свежим raw-URL бандла и всеми фичами реворка.

Заодно починено в библиотеке:
- неверный статический ключ больше не игнорируется молча — показывает «Неверный ключ / Invalid key»;
- сообщение «No key link configured» локализовано (`keysystem.nolink` RU/EN);
- ожидание ввода ключа считается по `os.time()` (5 минут), а не по 900 кадрам (~15 с на 60 FPS), иначе пользователь физически не успевал ввести ключ.

## Третий проход: кнопка меню, панель аккаунта, «баганый интерфейс»

### Кнопка открытия меню
- На кнопке вместо «Открыть» отображался сырой ключ `loc:rework.open` — `SetOpenState()` писал `Title.Text` напрямую, минуя реестр локализации. Теперь ключ регистрируется через `Creator:ChangeTranslationKey`, подпись резолвится и обновляется при смене языка («Открыть» / «Закрыть» / «Open» / «Close»).
- Состояние `Window.Closed` и видимость кнопки синхронизируются **немедленно** в `Window:Open()` / `Window:Close()`: закрыли/скрыли меню → кнопка есть, открыли → скрыта (при `StayVisible = false`). Раньше это делалось в корутинах через `task.wait(0.06)` / `task.wait(0.4)`.
- Убран глобальный debounce `0.18` из `Window:Toggle()` — он «съедал» быстрые повторные переключения и программные вызовы. Автоповтор клавиши фильтруется только в `InputBegan`.
- Добавлен `OpenButtonMain:Destroy()` (отписка от смены языка, очистка drag и контейнера), вызывается при `Window:Destroy()`.

### Панель аккаунта (секция «Настройки»)
- **Язык RU/ENG**: строка теперь всегда отражает реальный язык библиотеки. `WindUI:SetLanguage("ru")` больше не оставляет в панели «English». Добавлены алиасы `eng`, `english`, `rus`, `russian`, `en-us`, … (`ReworkLocalization.Normalise`).
- **Темы как в WindUI**: вместо двух захардкоженных Dark/Light список строится из `WindUI:GetThemes()` — все 16 тем (Rose, Plant, Red, Indigo, Sky, Violet, Amber, Emerald, Midnight, Crimson, Monokai Pro, Cotton Candy, Mellowsi, Rainbow) плюс темы из `AddTheme()`. Клик открывает всплывающий список с прокруткой, а не циклит 16 раз.
- Строка темы синхронизируется при смене темы из кода (`WindUI:OnThemeChange` теперь держит **несколько** подписчиков и возвращает unsubscribe, `Creator:OnThemeChange` тоже подключён). `GetCurrentTheme()` возвращает ключ, пригодный для `SetTheme`, а не красивое имя («Monokai Pro»).
- `SetTheme` понимает и ключ, и `Theme.Name`; `AddTheme` уведомляет подписчиков.

### Прочий «баганый интерфейс»
- `CopySections()` терял `TitleKey` → стандартные секции «Комбат»/«Визуалы» и их пункты не переводились на EN. Теперь все ключи копируются, а для пользовательских секций с теми же названиями ключи наследуются автоматически.
- `Creator.UpdateLang()` оставлял дырки в `LocalizationObjects`; `#` становился неопределённым, новые `loc:`-метки перезаписывали старые и часть UI переставала переводиться. Реестр теперь компактуется, `ChangeTranslationKey` ходит по `pairs` и умеет снимать регистрацию для обычного текста.
- `RefreshLanguage()` обновляет заголовки секций и подписи строк явно, закрывает всплывающий список и подтягивает актуальные язык/тему в строки выбора.
- `GetSection()` работает с русским и английским именем независимо от текущего языка.
- `EditOpenButton({ StayVisible = false })` в примере: кнопка появляется только у скрытого меню.
- Файловые API экзекутора (`isfile`, `readfile`, `isfolder`, `makefolder`) обёрнуты в безопасные проверки: в Studio и в экзекуторах без файловой системы KeySystem / ConfigManager больше не падают на вызове `nil`.
- Ссылки в README и примере переведены на `refs/heads/main/dist/main.lua`.

## Проверено

```
luau-compile --null --only-parse <все Luau-файлы>    OK
luau-compile --null dist/main.lua                    OK
luau tests/slider_math_test.luau                    47 checks, 0 failures
python3 tools/smoke_test.py                         bundle + settings RU/EN + themes + loading + guards: ALL OK
node tools/check_syntax.mjs                         90 Luau files parsed OK
python3 tools/bundle.py --check                      up to date
```
