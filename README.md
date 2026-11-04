# WindUI Rework

> Полный реворк открытой Luau‑библиотеки **[Footagesus/WindUI](https://github.com/Footagesus/WindUI)** (v1.6.66) для Roblox script‑хабов.
> Весь исходный код оригинала перенесён в этот репозиторий, баги исправлены, добавлены плавные анимации, панель профиля в стиле Neverlose и человеческая документация.

**Коротко:** кнопка открытия/закрытия работает на ПК **и** на телефонах, слайдеры больше не ломаются на `0`, анимации плавные и настраиваемые, в нижнем левом углу — панель настроек профиля со списками «Комбат» и «Визуалы».

---

## Содержание

1. [Что исправлено и добавлено](#что-исправлено-и-добавлено)
2. [Установка](#установка)
3. [Быстрый старт](#быстрый-старт)
4. [Кнопка открытия / закрытия (ПК + телефон)](#кнопка-открытия--закрытия-пк--телефон)
5. [Слайдеры и баг с нулём](#слайдеры-и-баг-с-нулём)
6. [Анимации](#анимации)
7. [Панель профиля (Neverlose‑style)](#панель-профиля-neverlose-style)
8. [Язык и темы — из кода](#язык-и-темы--из-кода)
9. [ConfigManager / сохранение настроек](#configmanager--сохранение-настроек)
10. [Полный API](#полный-api)
11. [Сборка из исходников и тесты](#сборка-из-исходников-и-тесты)
12. [Структура репозитория](#структура-репозитория)
13. [Откуда взят код (GitHub API)](#откуда-взят-код-github-api)
14. [Благодарности и лицензия](#благодарности-и-лицензия)

---

## Что исправлено и добавлено

| # | Что | Было в оригинале | Стало |
|---|-----|------------------|-------|
| 1 | **OpenButton** | Показывался только когда `not Window.IsPC`, т.е. на ПК его не было; клик висел на `MouseButton1Click`; `Edit()` обнулял `Window.IsPC` и не умел `Draggable = true` | Показывается на ПК, телефонах и консолях; `Activated` + `MouseButton1Click` + `TouchTap` с debounce; кнопка **всегда скрыта, пока меню открыто**; корректный `Edit()` |
| 2 | **Клавиша ToggleKey** | Только `Enum.KeyCode`, без debounce | `Enum.KeyCode`, строка (`"RightShift"`) или список; защита от автоповтора; на телефоне работает кнопка |
| 3 | **Слайдеры с `0`** | `Min/Max = 0` → деление `0/0 = nan`; `Step = 0` → деление на ноль; `:Set(0)` и загрузка конфига с `0` молча пропускались (`if Value ~= LastValue`); тач‑драг «залипал» | Нормализация чисел, диапазон всегда `> 0`, `Step > 0`, снап относительно `Min`, кламп в `[Min, Max]`, `:Set(0)` всегда обновляет UI и вызывает колбэк; тач использует `InputChanged` и сравнение по типу ввода |
| 4 | **Анимации** | Разрозненные твины `0.04` / `0.8` / `0.9`, линейные переходы, мгновенный `Visible = false` | Единый модуль `Animations`: профили `Smooth / Snappy / Calm / Reduced / None`, Quint/Exponential/Back, fade + slide + spring‑scale, stagger‑появление списков, ripple, hover/press, пульсация обводки |
| 5 | **Панель профиля** | Не было | Neverlose‑подобный попап в нижнем левом углу поверх профиля: секции «Комбат» (Сайлент аим, Аимбот, Триггербот, Kill All) и «Визуалы» (ESP, ESP Box, ESP Skeleton), сохранение через ConfigManager |
| 6 | **ConfigManager** | `CreateConfig(nil)` падал до проверки; сохранение `0` у слайдера терялось | Проверка имени до конкатенации, корректные `Save/Load` для нулевых значений, повторное использование уже созданного конфига |
| 7 | **Сборка** | Нужен `darklua` (Rust) + Rojo + сабмодуль иконок | `python3 tools/bundle.py` собирает `dist/main.lua` без внешних бинарников; иконки завендорены в `src/Icons/` |
| 8 | **Документация / тесты** | README на 20 строк | Этот README, пример `examples/rework_example.client.lua`, регрессионные тесты `tests/slider_math_test.luau` (47 проверок), smoke‑тест бандла с моками Roblox, CI‑проверка синтаксиса |
| 9 | **8 багов из чек-листа** | ConfigManager терял Dropdown/Colorpicker и дёргал колбэки при загрузке; Key System создавал окно дважды и тек connections; Dropdown не закрывался по клику вне и не обновлял Options; `Locked`‑слайдер драгался; темы не подхватывали новые ключи; drag игнорировал `GuiInset`; дропдауны уходили под окно; `DisconnectAll` не отключал половину соединений | Всё исправлено: тихий `Load`, `RegisterAll`, `Color3.fromHex("#…")`, `SetValues`, `Input.Position` вместо `Mouse.X/Y`, `Active = false`, `DisplayOrders`, `DisconnectGroup` и `Creator.SuspendCallbacks` |
| 10 | **Язык, темы, Key System, загрузка** | Не было | Язык RU/ENG (**по умолчанию ENG**) и **все 16 тем WindUI** задаются из кода, как в оригинале; в панели аккаунта только списки «Комбат»/«Визуалы», без секции настроек; нижние кнопки Get Key / Check Key; настраиваемый экран загрузки |

---

## Установка

### Вариант 1 — один файл (executor, самый простой)

```lua
local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/tipmetro-bot/windUIrework/refs/heads/main/dist/main.lua"
))()
```

> Бандл берётся из `main`. **Тестовый скрипт** — `examples/rework_example.client.lua`:
> ключ `test`, 2 вкладки с боксовыми категориями и слайдерами, без панели
> аккаунта и без «Комбат»/«Визуалы». Второй пример —
> `examples/nighttime_example.client.lua`: 3 вкладки (Nighttime / Слайдеры /
> Оформление), без ключ-системы.
> Файл `dist/main.lua` — это готовый бандл всех модулей из `src/` (включая иконки), возвращает таблицу `WindUI`.

### Вариант 2 — Rojo / Studio

```
rojo serve default.project.json
```

```lua
local WindUI = require(game.ReplicatedStorage.WindUI.Init)
```

`default.project.json` монтирует `src/` в `ReplicatedStorage.WindUI`, а `examples/` можно подключить как `LocalScript`.

---

## Быстрый старт

```lua
local WindUI = loadstring(game:HttpGet(".../dist/main.lua"))()

WindUI:SetAnimationProfile("Smooth")

local Window = WindUI:CreateWindow({
    Title = "WindUI Rework",
    Folder = "MyHub",                    -- включает сохранение конфигов
    ToggleKey = "RightShift",           -- ПК
    User = { Enabled = false },         -- панели аккаунта нет
    OpenButton = { Enabled = true, Draggable = true },   -- скрыта, пока меню открыто
    KeySystem = { Key = { "test" }, SaveKey = false },
})

local Tab = Window:Tab({ Title = "Главная", Icon = "settings" })

-- Категория (бокс со сворачиванием) внутри вкладки
local Category = Tab:Section({
    Title = "Слайдеры", Icon = "sliders-horizontal",
    Box = true, BoxBorder = true, Opened = true,
})

Category:Slider({
    Title = "Test Slider",
    Value = { Min = 0, Max = 100, Default = 0 },   -- 0 работает
    Step = 1,
    Flag = "TestSlider",
    Callback = function(v) print(v) end,
})
```

**Тестовые скрипты:**
- [`examples/rework_example.client.lua`](examples/rework_example.client.lua) — ключ `test`, 2 вкладки с категориями и слайдерами.
- [`examples/nighttime_example.client.lua`](examples/nighttime_example.client.lua) — 3 вкладки с категориями (`Nighttime`, `Слайдеры`, `Оформление`), nighttime + слайдеры, без ключ-системы.

В обоих: **никаких** «Комбат» / «Визуалы» и никакой панели аккаунта. Категории — это `Tab:Section{ Box = true, Opened = true }`, элементы добавляются через `Category:Slider{...}` / `:Toggle{...}` / `:Dropdown{...}`.

---

## Кнопка открытия / закрытия (ПК + телефон)

### Проблема

В оригинале `Window:Close()` показывал кнопку только под условием `not Window.IsPC`, а `Openbutton.lua` внутри `Edit()` вообще писал `Window.IsPC = false`. На ПК после сворачивания окна не оставалось никакого способа открыть его без клавиши `ToggleKey` (которой могло не быть). На телефонах клик обрабатывался только `MouseButton1Click`, а перетаскивание слайдеров/кнопки могло «залипнуть», потому что `InputEnded` сравнивал объекты `InputObject`, которые для тача разные.

### Решение

* Определение платформы: `UserInputService.TouchEnabled / KeyboardEnabled / MouseEnabled / GamepadEnabled` → `Window.IsMobile`, `Window.IsPC`, `Window.IsConsole`. Тач‑ноутбук с клавиатурой считается ПК.
* Кнопка создаётся **всегда** и показывается после закрытия окна на любой платформе.
* Активация через `Activated` (мышь, тач, геймпад) + `MouseButton1Click` + `TouchTap` с debounce `0.3 c`.
* Кнопка вызывает `Window:Toggle()` (открыть **и** закрыть), а не только `Window:Open()`.
* Состояние синхронизируется **мгновенно**: закрыли/скрыли меню → кнопка сразу есть (`Window.Closed = true` → `OpenButtonMain:Refresh()`), открыли → кнопка сразу скрыта. Раньше это делалось внутри корутины через `task.wait(0.06…0.4)` и «терялось» при быстрых переключениях.
* Подпись кнопки локализована («Открыть» / «Закрыть» / «Open» / «Close») и меняется вместе с языком. Раньше на ней отображался сырой ключ `loc:rework.open`.
* `Window:Toggle()` больше не имеет глобального debounce — двойной тап и программные переключения работают; фильтруется только автоповтор клавиши в `InputBegan`.
* **Пока меню открыто кнопки нет вообще** — ни при каком конфиге. `StayVisible` устарел и игнорируется; даже явный `:Visible(true)` не покажет кнопку поверх открытого меню. Появление при закрытии анимировано, исчезновение мгновенное.
* Хитбокс `48 px` на телефонах, ripple, hover/press/spring, плавное появление/скрытие (`GroupTransparency` + `UIScale` + slide).
* `LastInputTypeChanged` обновляет платформу на лету (подключили клавиатуру к планшету — кнопка не пропадает).

### Настройка

```lua
local Window = WindUI:CreateWindow({
    ToggleKey = { "RightShift", Enum.KeyCode.F5 },  -- несколько клавиш тоже ок
    OpenButton = {
        Enabled      = true,    -- false = полностью выключить
        OnlyMobile   = false,   -- true = только телефоны (старое поведение)
        Draggable    = true,    -- перетаскивание за иконку
        OnlyIcon     = false,
        Title        = "Открыть UI",
        Position     = UDim2.new(0.5, 0, 0, 60),
        Scale        = 1,
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 2,
        Color = ColorSequence.new(Color3.fromHex("40c9ff"), Color3.fromHex("e81cff")),
    },
})

Window:EditOpenButton({ Draggable = false })
Window:SetToggleKey("RightShift")
Window:SetOpenButtonEnabled(true)
Window:Toggle()          -- открыть/закрыть кодом
```

| Параметр | По умолчанию | Описание |
|---|---|---|
| `Enabled` | `true` | Показывать кнопку |
| `OnlyMobile` | `false` | `true` = только тач‑устройства |
| `ShowOnPC` | `true` | Алиас, обратный `OnlyMobile` |
| `StayVisible` | — | **Устарел / игнорируется**: кнопка всегда скрыта при открытом меню |
| `Draggable` | `true` | Перетаскивание |
| `OnlyIcon` | `false` | Скрыть подпись |
| `Position`, `Scale`, `Title`, `Icon`, `CornerRadius`, `StrokeThickness`, `Color` | — | Внешний вид |

---

## Слайдеры и баг с нулём

Вся математика вынесена в чистый модуль [`src/modules/SliderMath.lua`](src/modules/SliderMath.lua) (без Roblox‑глобалов), поэтому она покрыта тестами [`tests/slider_math_test.luau`](tests/slider_math_test.luau).

```lua
-- Все варианты нулей работают:
Tab:Slider({ Title = "A", Value = { Min = 0, Max = 100, Default = 0 }, Step = 1 })
Tab:Slider({ Title = "B", Value = { Min = 0, Max = 0,   Default = 0 }, Step = 0 }) -- Max поднимается до 1, Step -> 1
Tab:Slider({ Title = "C", Min = 0, Max = 10, Default = 0 })                      -- плоский синтаксис
Tab:Slider({ Title = "D", Value = 0, Min = 0, Max = 10 })                        -- Value = число
Tab:Slider({ Title = "E", Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.05 })

local Slider = Tab:Slider({ ... })
Slider:Set(0)          -- колбэк сработает, даже если значение уже 0
Slider:SetMin(0)       -- безопасно
Slider:SetMax(0)       -- безопасно (диапазон не станет нулевым)
Slider:SetStep(0)      -- станет 1
print(Slider:GetValue())
```

Что именно починено:

* `SliderMath.Normalise` явно через `tonumber()` разбирает `Min/Max/Default/Step`, `0` нигде не подменяется через `or`, `false`/`nil`/`NaN`/`inf` не ломают расчёты.
* Если `Max <= Min`, диапазон расширяется (`Max = Min + 1`) — никакого `0/0`.
* `Step = 0` → `1`; `Step > Range` → `Range`.
* `Delta()` всегда делит на `math.max(Max - Min, 1e-9)` и клампится в `0..1`.
* `Calculate()` снапит **относительно `Min`** и всегда клампит результат в `[Min, Max]`.
* Программный `:Set(v)` всегда обновляет заполнение, `TextBox`, тултип, `Slider.Value.Default` и вызывает `Callback` (раньше `Value ~= LastValue` «съедало» нули).
* `ConfigManager.Parser.Slider` сохраняет `0` как число и загружает его с `force = true`.
* Тач‑драг: `InputChanged` обновляет позицию пальца, `InputEnded` сравнивает **тип ввода**, а не идентичность `InputObject`; есть failsafe‑таймаут 6 c, `ScrollingEnabled` всегда возвращается.

---

## Анимации

Модуль [`src/modules/Animations.lua`](src/modules/Animations.lua) — единое место для всех таймингов и easing'ов.

| Профиль | Характер |
|---|---|
| `Smooth` *(по умолчанию)* | Quint / Exponential / Back, 0.12–0.55 c |
| `Snappy` | Быстрее в 1.4 раза, Exponential |
| `Calm` | Медленнее, Sine / InOut |
| `Reduced` | Короткие линейные переходы (слабые устройства) |
| `None` | Мгновенно, без твинов (доступность) |

```lua
WindUI:SetAnimationProfile("Smooth")
WindUI:SetAnimationSpeed(1.0)          -- множитель 0.1 .. 4
WindUI:SetAnimationsEnabled(false)     -- == профиль "None"
print(WindUI:GetAnimationProfile())
-- или с объекта окна:
Window:SetAnimationProfile("Snappy")
```

Где применяются:

* **Окно**: «разворачивание» размера + spring‑scale (`ReworkScale`) при открытии, плавное сжатие/затухание при закрытии.
* **OpenButton**: fade + slide + scale, hover/press, ripple по клику, мягкая пульсация градиентной обводки.
* **Слайдер**: плавное заполнение, «пружинящий» thumb при наведении/захвате, тултип.
* **Панель профиля**: выезд снизу + fade + scale, cascade‑появление секций (`Stagger`), анимация высоты при сворачивании секции, поворот шеврона, переключатели с Back‑easing, hover у строк.

Хелперы модуля доступны и напрямую:

```lua
local A = WindUI.Animations
A:Play(obj, "Hover", { BackgroundTransparency = 0.9 }, "Soft", "Out")
A:Pop(obj, { Scale = 1 }, "Slide")
A:Fade(obj, 0, "Fast")
A:Stagger({ frame1, frame2 }, 0.04, "Fast", { GroupTransparency = 0 })
A:Press(uiScale, 1, 0.94)
local pulse = A:Pulse(stroke, "Transparency", 0.1, 0.45, 2.2)
pulse:Stop()
```

---

## Панель профиля (Neverlose‑style, опционально)

> В тестовом скрипте эта панель **не используется**. Подключается только явным `Window:Profile{...}` / `Profile = {...}` в `CreateWindow`.

Находится **в нижнем левом углу окна**, прямо над карточкой профиля и слегка её перекрывает (`Overlap`, по умолчанию 16 px). Открывается кликом по аватару/имени в сайдбаре, закрывается кнопкой `×`, кликом вне панели или `Escape`. Секции сворачиваются по клику на заголовок. Все элементы рассчитаны на тач (строки 34+ px, `Activated`, `TouchTap`).

Структура по умолчанию — ровно та, что просили:

```
КОМБАТ  [список снизу]
    Сайлент аим        [toggle]
    Аимбот             [toggle]
    Триггербот         [toggle]
    Kill All           [button]
ВИЗУАЛЫ [список снизу]
    ESP                [toggle]
    ESP Box            [toggle]
    ESP Skeleton       [toggle]
```

### Подключение

```lua
-- Вариант А: прямо в CreateWindow
local Window = WindUI:CreateWindow({
    User = { Enabled = true },   -- панель включит карточку сама, если забыли
    Profile = {
        Config = "default",
        AutoLoad = true,
        Sections = {
            { Title = "Комбат", Items = {
                { Title = "Сайлент аим", Flag = "SilentAim", Default = false,
                  Callback = function(v) print(v) end },
                { Title = "Аимбот",     Flag = "Aimbot",     Default = false },
                { Title = "Триггербот", Flag = "TriggerBot", Default = false },
                { Title = "Kill All",   Flag = "KillAll", Type = "Button",
                  Callback = function() print("Kill All!") end },
            }},
            { Title = "Визуалы", Items = {
                { Title = "ESP",          Flag = "ESP",          Default = true },
                { Title = "ESP Box",      Flag = "ESPBox",      Default = false },
                { Title = "ESP Skeleton", Flag = "ESPSkeleton", Default = false },
            }},
        },
    },
})

-- Вариант Б: в любой момент после создания окна
local Panel = Window:Profile({
    Config = "default",
    Title = "Мой профиль",     -- необязательно, имя берётся из LocalPlayer
    Subtitle = "Настройки профиля",
    Width = 290,
    Height = 360,
    Overlap = 16,
    OpenByDefault = false,
})
```

### Элемент секции

| Поле | Тип | Описание |
|---|---|---|
| `Title` | `string` | Подпись строки |
| `Flag` | `string` | Ключ для ConfigManager и `:SetValue()` |
| `Default` | `boolean` | Начальное значение (`false` тоже корректно) |
| `Type` | `"Toggle"` / `"Button"` | По умолчанию Toggle; Button вызывает колбэк без сохранения |
| `Callback` | `function(value)` | Вызывается при изменении/нажатии |
| `Expanded` | `boolean` | Свойство секции: раскрыта ли изначально |

### API панели

```lua
Panel:Open()  Panel:Close()  Panel:Toggle()  Panel:IsOpen()  Panel:Destroy()
Panel:AddSection({ Title = "Мисцелланеоус", Items = {...} })
Panel:AddItem("Комбат", { Title = "Anti Aim", Flag = "AntiAim", Default = false })
Panel:GetSection("Визуалы"):Toggle()          -- свернуть / развернуть

Panel:SetValue("Aimbot", true)
print(Panel:GetValue("Aimbot"))
print(Panel:GetValues())                       -- { Aimbot = true, ESP = true, ... }

Panel:SetConfig("newConfig")
Panel:SaveConfig()  Panel:LoadConfig()  print(Panel:GetConfigs())
Panel:SetTitle("Player")  Panel:SetSubtitle("config: default")
```

Значения сохраняются через штатный **ConfigManager API**: `Window.ConfigManager:Config(name)` → `ConfigModule:Register(flag, item)` → `:Save()` / `:Load()`. Если у экзекутора нет файловой системы (Studio), всё работает в памяти, а методы сохранения просто возвращают `false, "..."`.

Колбэк `User.Callback` из конфигурации окна сохраняется и по-прежнему вызывается при клике на профиль; за открытие панели отвечает отдельный обработчик (с debounce, чтобы `Activated` + `MouseButton1Click` не открывали её дважды).

---

## Язык и темы — из кода

**Панель аккаунта больше не содержит секции «Настройки».** В ней только два списка — «Комбат» (`сайлент аим`, `аимбот`, `триггербот`, `kill all`) и «Визуалы» (`esp`, `esp box`, `esp skeleton`). Язык и тема задаются **из кода**, как в оригинальном WindUI.

### Язык: RU / ENG, по умолчанию ENG

```lua
local WindUI = loadstring(game:HttpGet(".../dist/main.lua"))()
print(WindUI:GetLanguage())         --> "en"

WindUI:SetLanguage("ru")            --> весь интерфейс на русском
WindUI:SetLanguage("eng")           --> обратно на английский

-- или при создании окна:
WindUI:CreateWindow({ Language = "ru", ... })
```

Принимаются алиасы: `ru`, `rus`, `russian`, `ru-ru` → RU; `en`, `eng`, `english`, `en-us`, `en-gb` → ENG. Перевод обновляет уже созданные подписи (включая заголовки секций панели, Key System и экран загрузки). `WindUI:OnLanguageChange(fn)` подписывается на смену языка.

### Темы: как в оригинальном WindUI

Тема выбирается из кода — `Theme = "Rose"` в `CreateWindow` или `WindUI:SetTheme("Rose")`. Доступны **все темы оригинала**:

```
Dark, Light, Rose, Plant, Red, Indigo, Sky, Violet, Amber,
Emerald, Midnight, Crimson, MonokaiPro, CottonCandy, Mellowsi, Rainbow
```

```lua
WindUI:SetTheme("Midnight")
print(WindUI:GetCurrentTheme())     --> "Midnight"
print(WindUI:GetThemes())           --> таблица всех тем

WindUI:SetTheme("Monokai Pro")      -- можно и по красивому имени Theme.Name
WindUI:AddTheme({ Name = "MyTheme", ... })  -- свои темы тоже работают
WindUI:OnThemeChange(function(name) print(name) end)
```

### Загрузка (опционально)

```lua
WindUI:CreateWindow({
    Loading = false,                       -- по умолчанию, GUI не создаётся
    -- Loading = true,                     -- или:
    -- Loading = { Enabled = true, Duration = 1.2, Title = "My Hub",
    --             Steps = { "Конфиг…", "Вкладки…", "Готово" } },
    KeySystem = {
        Title = "My Hub",
        Key   = { "test" },   -- рабочий ключ
        SaveKey = false,      -- спрашивать при каждом запуске
    },
})
```

`WindUI:SetLoadingEnabled(bool)` переключает оверлей на лету. Key System имеет нижние кнопки **Get Key** / **Check Key** (и «Выход»), локализованные вместе с интерфейсом; неверный ключ показывает уведомление, а ожидание ввода ограничено 5 минутами.

`Panel:GetSection("Комбат")` и `Panel:GetSection("Combat")` работают при любом языке.
Панель аккаунта — **опциональная** фича библиотеки (`Window:Profile{...}`); в тестовом скрипте `examples/rework_example.client.lua` она **не используется**, там только вкладка со слайдером.

---

## ConfigManager / сохранение настроек

```lua
local Config = Window.ConfigManager:Config("default", true) -- имя, autoload
Config:SetAsCurrent()

local Toggle = Tab:Toggle({ Title = "ESP", Flag = "ESP", Default = false })
Config:Register("ESP", Toggle)     -- или просто укажите Flag при создании

Config:Save()                      -- WindUI/<Folder>/config/default.json
Config:Load()
Config:Set("customKey", 123)
print(Config:Get("customKey"))
print(Window.ConfigManager:AllConfigs())
```

Панель профиля по умолчанию использует конфиг `"default"` и не создаёт второй модуль с тем же именем — флаги из вкладок и из панели лежат в одном файле.

---

## Полный API

### `WindUI`

| Метод | Описание |
|---|---|
| `WindUI:CreateWindow(config)` | Создать окно (только одно) |
| `WindUI:SetTheme(name)` / `:GetThemes()` / `:GetCurrentTheme()` | Темы: Dark, Light, Rose, … |
| `WindUI:SetFont(id)` / `:Localization(cfg)` / `:SetLanguage(code)` / `:GetLanguage()` / `:OnLanguageChange(fn)` | Шрифт и локализация RU/ENG, **по умолчанию ENG** (`ru`, `eng`, `en`, `english`, `rus`) |
| `WindUI:SetTheme(name)` / `:GetThemes()` / `:GetCurrentTheme()` / `:OnThemeChange(fn)` | Тема: возвращает ключ, `OnThemeChange` поддерживаетหลาย подписчиков |
| `WindUI:SetLoadingEnabled(bool)` / `:SetDisplayOrder(name, value)` | Экран загрузки и порядок ScreenGui |
| `WindUI:Notify(cfg)` / `:Popup(cfg)` / `:Gradient(stops)` | Уведомления, попапы, градиенты |
| `WindUI:SetAnimationProfile(name)` / `:GetAnimationProfile()` | Профиль анимаций |
| `WindUI:SetAnimationsEnabled(bool)` / `:SetAnimationSpeed(x)` | Доступность / скорость |
| `WindUI.Animations`, `WindUI.Creator`, `WindUI.Version` | Прямой доступ к модулям |
| `WindUI.Services`, `WindUI:SetParent(gui)` | Сервисы ключей и родитель GUI |

### `Window`

| Метод | Описание |
|---|---|
| `:Tab(cfg)`, `:Section(cfg)`, `:SelectTab(tab)` | Навигация |
| `:Open()`, `:Close()`, `:Toggle()`, `:Destroy()` | Состояние окна |
| `:OnOpen(fn)`, `:OnClose(fn)`, `:OnDestroy(fn)` | Хуки |
| `:SetToggleKey(key)`, `:SetOpenButtonEnabled(bool)`, `:SetOpenButtonVisible(bool)`, `:EditOpenButton(cfg)` | Управление кнопкой |
| `:Profile(cfg)` | Панель профиля (синглтон на окно) |
| `Window.OpenButtonMain:SetOpenState(closed)` / `:IsWindowOpen()` / `:Refresh()` / `:RefreshTitle()` | Явное состояние и локализованная подпись кнопки |
| `Window.LoadingScreen` | Оверлей загрузки (из кода) |
| `Window.ProfilePanel:GetSection(name)` | Поиск секции по RU или EN имени ("Комбат" / "Combat") |
| `Window.ProfilePanel:SetLanguage("eng")` / `:SetTheme("Rose")` | Прокси к `WindUI:SetLanguage` / `WindUI:SetTheme` |
| `:SetTitle`, `:SetAuthor`, `:SetIconSize`, `:SetSize`, `:SetUIScale`, `:SetToTheCenter`, `:ToggleFullscreen` | Окно |
| `:ToggleTransparency`, `:LockAll`, `:UnlockAll`, `:GetLocked`, `:GetUnlocked` | Прочее |
| `:SetAnimationProfile(name)`, `:SetAnimationsEnabled(bool)` | Прокси к `WindUI` |
| `Window.ProfilePanel`, `Window.ConfigManager`, `Window.IsPC`, `Window.IsMobile` | Поля |

### Элементы вкладки

`Paragraph, Button, Toggle, Slider, ProgressBar, Keybind, Input, Dropdown, Code, Colorpicker, Section, Divider, Space, Image, Group, HStack, VStack, Viewport` — все из оригинала, плюс новый `Slider:Set/GetValue/SetMin/SetMax/SetStep/Refresh`.

---

## Сборка из исходников и тесты

`dist/main.lua` генерируется из `src/Init.lua` рекурсивным обходом `require("...")`. Никаких внешних бинарников:

```bash
python3 tools/bundle.py              # пересобрать dist/main.lua
python3 tools/bundle.py --check      # CI: бандл не устарел?
npm install
npm run check                       # Luau-парсер на все файлы + --check
npm run build                       # сборка через build/build.sh
npm test                            # smoke-тест бандла + тесты слайдеров
```

Полная проверка компилятором Luau (опционально, нужен [luau-lang/luau](https://github.com/luau-lang/luau)):

```bash
luau-compile --null dist/main.lua
luau tests/slider_math_test.luau    # 47 проверок на нули и Step -> "ALL OK"
LUAU_BIN=luau python3 tools/smoke_test.py
```

`tools/smoke_test.py` подставляет `dist/main.lua` в `tests/bundle_smoke.luau` (заглушки `Instance`, `game`, `Enum`, `TweenService` …) и в обычном Luau VM создаёт окно, вкладку, слайдеры с нулями и панель профиля — то есть проверяет не только синтаксис, но и рантайм новых модулей. Без установленного `luau` тест аккуратно пропускается.

CI (`.github/workflows/build.yml`) на каждый push/PR парсит все `.lua/.luau` и проверяет, что `dist/main.lua` соответствует исходникам.

> Оригинал собирался через `darklua`. Здесь `build/build.sh` перенаправлен на `tools/bundle.py`, сабмодуль `src/Icons` завендорен обычными файлами, поэтому `git clone` без `--recursive` тоже работает.

---

## Структура репозитория

```
windUIrework/
├── README.md                       ← этот файл
├── LICENSE                         ← MIT (оригинал Footagesus)
├── changelog.md                    ← changelog оригинала
├── REWORK_CHANGELOG.md             ← что изменил реворк
├── package.json / package-lock.json
├── default.project.json            ← Rojo
├── aftman.toml                     ← конфиг оригинала (справочно)
├── build/
│   ├── build.sh                    ← теперь вызывает tools/bundle.py
│   ├── package.lua                 ← генерируется из package.json
│   ├── header.lua
│   └── darklua*.json               ← конфиги оригинала (справочно)
├── dist/
│   └── main.lua                    ← ГОТОВЫЙ БАНДЛ для loadstring()
├── docs/                           ← баннеры/скриншоты оригинала
├── examples/
│   ├── rework_example.client.lua    ← тест: ключ test, 2 вкладки с категориями
│   └── nighttime_example.client.lua ← 3 вкладки с категориями, Nighttime
├── tools/
│   ├── bundle.py                   ← сборщик одного файла
│   ├── check_syntax.mjs            ← проверка синтаксиса Luau
│   └── smoke_test.py               ← прогон бандла с моками Roblox
├── tests/
│   ├── slider_math_test.luau       ← регрессия «слайдеров с 0»
│   ├── bundle_smoke.luau           ← мок Roblox + создание окна/слайдеров/профиля
│   └── 200Elements.lua, ProgressBar.lua  ← тесты оригинала
├── src/
│   ├── Init.lua                    ← публичный API (+ анимации)
│   ├── components/window/
│   │   ├── Init.lua                ← платформа, open/close, Profile API
│   │   ├── Openbutton.lua          ← ПЕРЕПИСАН
│   │   ├── ProfilePanel.lua        ← НОВЫЙ (только Комбат / Визуалы)
│   │   └── LoadingScreen.lua       ← НОВЫЙ (оверлей загрузки)
│   ├── components/… , elements/… , themes/… , utils/…
│   ├── config/Init.lua             ← ConfigManager (фиксы 0)
│   ├── elements/Slider.lua         ← ПЕРЕПИСАН
│   ├── modules/
│   │   ├── Animations.lua          ← НОВЫЙ
│   │   ├── SliderMath.lua         ← НОВЫЙ (чистая математика)
│   │   ├── ReworkLocalization.lua  ← НОВЫЙ (RU/EN)
│   │   └── Creator.lua, Icons.lua, …
│   └── Icons/                       ← завендоренный сабмодуль иконок
└── main*.lua, example-structure.json, sourcemap.json  ← примеры оригинала
```

---

## Откуда взят код (GitHub API)

Исходники получены напрямую из upstream‑репозитория через **GitHub REST API** (как и просили «юзай апи»):

```bash
gh api repos/Footagesus/WindUI/git/trees/main?recursive=1   # список всех файлов
gh api -X GET search/issues -f q='repo:Footagesus/WindUI is:issue slider'
git clone https://github.com/Footagesus/WindUI.git          # полный исходник v1.6.66
git clone https://github.com/Footagesus/Icons.git          # сабмодуль иконок (pin 46d30c1)
```

Затем код был перенесён в этот репозиторий, а все новые возможности реализованы поверх **штатного API WindUI** (`Creator`, `ConfigManager`, `ElementsModule.Load`, `ThemeTag`, `Window:Tab()`), чтобы не ломать совместимость с существующими скриптами.

Иконки завендорены и встроены в `dist/main.lua`: в оригинале `Main-v2.lua` скачивал их через `game:HttpGet` без `pcall`, поэтому при недоступном `raw.githubusercontent.com` падала вся библиотека. Теперь бандл полностью самодостаточный и работает офлайн (после загрузки самого скрипта).

---

## Благодарности и лицензия

* **Оригинальная библиотека:** [Footagesus/WindUI](https://github.com/Footagesus/WindUI) — MIT, автор Footagesus (`.ftgs`).
* **Иконки:** [Footagesus/Icons](https://github.com/Footagesus/Icons) → Lucide, Craft Icons, Geist, Solar, SF Symbols.
* **Документация оригинала:** [WindUI-Docs](https://github.com/Footagesus/WindUI-Docs).
* Реворк, фиксы, анимации, панель профиля, сборщик и документация — `tipmetro-bot/windUIrework`.

Лицензия **MIT** (см. [`LICENSE`](LICENSE)). Проект предназначен для законной разработки собственных Roblox‑интерфейсов и обучения; используйте в соответствии с правилами платформы.
