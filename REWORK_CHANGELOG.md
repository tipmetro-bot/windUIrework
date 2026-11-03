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

## Проверено

```
luau-compile --null --only-parse <все Luau-файлы>    OK
luau-compile --null dist/main.lua                    OK
luau tests/slider_math_test.luau                    38 checks, 0 failures
python3 tools/smoke_test.py                         bundle + window + sliders + profile: ALL OK
node tools/check_syntax.mjs                         89 Luau files parsed OK
python3 tools/bundle.py --check                      up to date
```
