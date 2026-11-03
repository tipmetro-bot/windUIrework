--[[
    WindUI Rework — готовый скрипт с Key System
    ------------------------------------------------------------------
    Вставьте в executor (или в StarterPlayerScripts при разработке
    через Rojo). КЛЮЧ ДЛЯ ВХОДА: test

    • пока PR #2 не влит в main, грузимся с ветки реворка;
      после мержа замените URL на .../refs/heads/main/dist/main.lua
    • внизу диалога три кнопки: «Выход», «Get Key», «Check Key»
    • если ключ не ввели или нажали «Выход», CreateWindow вернёт nil
]]

local WindUI = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/tipmetro-bot/windUIrework/refs/heads/arena/6e86f6ad-winduirework/dist/main.lua"
))()

WindUI:SetAnimationProfile("Smooth") -- Smooth | Snappy | Calm | Reduced | None
WindUI:SetTheme("Dark")
WindUI.TransparencyValue = 0.18

----------------------------------------------------------------------
-- Окно + Key System
----------------------------------------------------------------------
local Window = WindUI:CreateWindow({
	Title = "WindUI Rework",
	Author = "by tipmetro-bot",
	Folder = "WindUIRework",             -- папка для конфигов и .key файла
	Icon = "rbxassetid://111665032676235",
	Size = UDim2.fromOffset(620, 470),
	Transparent = true,
	Acrylic = false,
	NewElements = true,
	ToggleKey = "RightShift",            -- строка, Enum.KeyCode или список

	-- Язык / тема / загрузка: и из кода, и кликом в панели профиля
	Theme = "Dark",
	Language = "ru",                     -- "ru" | "en"
	Settings = { Language = "ru" },      -- Settings = false скрывает секцию
	Loading = false,                     -- true или { Enabled = true, Duration = 1.2 }

	-- ▼▼▼ KEY SYSTEM: единственный рабочий ключ — test ▼▼▼
	KeySystem = {
		Title = "WindUI Rework · Key System",
		Note = "Тестовый ключ: <b>test</b>",  -- RichText, видно в диалоге
		Key = { "test" },                     -- список допустимых ключей
		SaveKey = false,                      -- false = спрашивать при каждом запуске
		-- URL = "https://...",               -- ссылка для кнопки «Get Key»
		-- API = { ... },                     -- внешний сервис вместо Key
		-- KeyValidator = function(key) return key == "test" end,
	},

	-- Профиль в нижнем левом углу сайдбара
	User = { Enabled = true, Anonymous = false },

	-- Кнопка открытия/закрытия: ПК, телефон и геймпад
	OpenButton = {
		Enabled = true,
		OnlyMobile = false,
		StayVisible = true,    -- остаётся и при открытом окне => закрывает его
		Draggable = true,
		Title = "Открыть UI",
		CornerRadius = UDim.new(1, 0),
		Color = ColorSequence.new(Color3.fromHex("40c9ff"), Color3.fromHex("e81cff")),
	},

	-- Neverlose-подобная панель поверх профиля
	Profile = {
		Config = "default",
		AutoLoad = true,
		Overlap = 16,
		Sections = {
			{ Title = "Комбат", Items = {
				{ Title = "Сайлент аим", Flag = "SilentAim", Default = false },
				{ Title = "Аимбот", Flag = "Aimbot", Default = false },
				{ Title = "Триггербот", Flag = "TriggerBot", Default = false },
				{ Title = "Kill All", Flag = "KillAll", Type = "Button",
					Callback = function() print("Kill All!") end },
			} },
			{ Title = "Визуалы", Items = {
				{ Title = "ESP", Flag = "ESP", Default = true },
				{ Title = "ESP Box", Flag = "ESPBox", Default = false },
				{ Title = "ESP Skeleton", Flag = "ESPSkeleton", Default = false },
			} },
		},
	},
})

-- Ключ не ввели / нажали «Выход» / вышло время ожидания → выходим.
if not Window then
	return
end

----------------------------------------------------------------------
-- ConfigManager: флаги сохраняются в файл конфига
----------------------------------------------------------------------
local Config = Window.ConfigManager and Window.ConfigManager:Config("default", true)
if Config then
	Config:SetAsCurrent()
end

----------------------------------------------------------------------
-- Вкладки
----------------------------------------------------------------------
local Combat = Window:Tab({ Title = "Комбат", Icon = "crosshair" })
Combat:Section({ Title = "Aim" })
Combat:Toggle({ Title = "Сайлент аим", Flag = "SilentAim", Default = false,
	Callback = function(v) print("Сайлент аим:", v) end })

-- Слайдер с нулями: раньше Min/Default = 0 молча пропускались
local FOV = Combat:Slider({
	Title = "FOV (Min = 0, Default = 0)",
	Flag = "AimFOV",
	Value = { Min = 0, Max = 180, Default = 0 },
	Step = 1,
	Callback = function(v) print("FOV:", v) end,
})
Combat:Button({ Title = "Сбросить FOV в 0", Callback = function() FOV:Set(0) end })
Combat:Slider({ Title = "Max = 0 / Step = 0", Value = { Min = 0, Max = 0, Default = 0 },
	Step = 0, Callback = function() end })

local Visuals = Window:Tab({ Title = "Визуалы", Icon = "eye" })
Visuals:Section({ Title = "ESP" })
Visuals:Toggle({ Title = "ESP", Flag = "ESP", Default = true, Callback = function() end })
Visuals:Toggle({ Title = "ESP Box", Flag = "ESPBox", Default = false, Callback = function() end })
Visuals:Toggle({ Title = "ESP Skeleton", Flag = "ESPSkeleton", Default = false, Callback = function() end })

----------------------------------------------------------------------
-- Панель профиля из кода + уведомление
----------------------------------------------------------------------
local Panel = Window.ProfilePanel
if Panel then
	Panel:SetValue("ESP", true)
	Panel:SaveConfig()
end

WindUI:Notify({
	Title = "WindUI Rework",
	Content = "Ключ принят · ПК + телефон · слайдеры с 0 · панель профиля",
	Icon = "sparkles",
	Duration = 6,
})
