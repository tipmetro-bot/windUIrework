--[[
    WindUI Rework — ТЕСТОВЫЙ СКРИПТ
    ------------------------------------------------------------------
    Вставьте в executor. КЛЮЧ ДЛЯ ВХОДА: test

    • бандл: .../refs/heads/main/dist/main.lua
    • язык RU/ENG (по умолчанию ENG) и темы задаются ИЗ КОДА
    • панели аккаунта нет: НИКАКИХ «Комбат» / «Визуалы» / «Настроек»
    • 2 вкладки, внутри — боксовые категории со слайдерами
    • кнопка открытия появляется только когда меню закрыто
]]

local WindUI = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/tipmetro-bot/windUIrework/refs/heads/main/dist/main.lua"
))()

WindUI:SetAnimationProfile("Smooth") -- Smooth | Snappy | Calm | Reduced | None
WindUI.TransparencyValue = 0.18

----------------------------------------------------------------------
-- Язык и тема — из кода, как в оригинальном WindUI
----------------------------------------------------------------------
-- Язык по умолчанию ENG. Раскомментируйте для русского:
-- WindUI:SetLanguage("ru")          -- или CreateWindow{ Language = "ru" }
WindUI:SetTheme("Dark")

----------------------------------------------------------------------
-- Окно + Key System (ключ test)
----------------------------------------------------------------------
local Window = WindUI:CreateWindow({
	Title = "Test",
	Author = "by tipmetro-bot",
	Folder = "WindUIReworkTest",
	Size = UDim2.fromOffset(600, 450),
	Transparent = true,
	Acrylic = false,
	NewElements = true,
	ToggleKey = "RightShift",

	Theme = "Dark",
	-- Language = "ru",               -- по умолчанию ENG
	Loading = false,                 -- true / { Enabled = true, Duration = 1.2 }

	KeySystem = {
		Title = "Test · Key System",
		Note = "Ключ: <b>test</b>",
		Key = { "test" },             -- единственный рабочий ключ
		SaveKey = false,              -- спрашивать при каждом запуске
	},

	-- Карточки профиля и панели аккаунта НЕТ.
	User = { Enabled = false },

	-- Кнопка есть только у закрытого меню.
	OpenButton = {
		Enabled = true,
		OnlyMobile = false,
		Draggable = true,
	},
})

-- Ключ не ввели / «Выход» → выходим.
if not Window then
	return
end

----------------------------------------------------------------------
-- ВКЛАДКА 1 · Главная: категории со слайдерами
----------------------------------------------------------------------
local Main = Window:Tab({ Title = "Главная", Icon = "settings" })

local SliderCategory = Main:Section({
	Title = "Слайдеры",
	Desc = "От 0 до 100, ноль работает",
	Icon = "sliders-horizontal",
	Box = true,
	BoxBorder = true,
	Opened = true,
})

local TestSlider = SliderCategory:Slider({
	Title = "Test Slider",
	Value = { Min = 0, Max = 100, Default = 0 },
	Step = 1,
	Flag = "TestSlider",
	Callback = function(value)
		print("[TestSlider]", value)
	end,
})

SliderCategory:Slider({
	Title = "Точность 0.00 → 1.00",
	Desc = "Дробный шаг",
	Value = { Min = 0, Max = 1, Default = 0 },
	Step = 0.05,
	Flag = "Precision",
	Callback = function(value)
		print("[Precision]", value)
	end,
})

local EdgeCategory = Main:Section({
	Title = "Граничные случаи",
	Desc = "Проверка бага с нулём",
	Icon = "circle-alert",
	Box = true,
	Opened = true,
})

EdgeCategory:Slider({
	Title = "Min = Max = 0",
	Value = { Min = 0, Max = 0, Default = 0 },
	Step = 1,
})

EdgeCategory:Slider({
	Title = "Отрицательный диапазон",
	Value = { Min = -50, Max = 50, Default = 0 },
	Step = 1,
})

local ActionsCategory = Main:Section({
	Title = "Действия",
	Icon = "rotate-ccw",
	Box = true,
	Opened = true,
})

ActionsCategory:Button({
	Title = "Сбросить слайдер в 0",
	Callback = function()
		TestSlider:Set(0)
		print("Текущее значение:", TestSlider:GetValue())
	end,
})

----------------------------------------------------------------------
-- ВКЛАДКА 2 · Оформление
----------------------------------------------------------------------
local Style = Window:Tab({ Title = "Оформление", Icon = "palette" })

local ThemeCategory = Style:Section({
	Title = "Тема",
	Desc = "16 тем, как в оригинальном WindUI",
	Icon = "palette",
	Box = true,
	Opened = true,
})

ThemeCategory:Dropdown({
	Title = "Theme",
	Values = {
		"Dark", "Light", "Rose", "Plant", "Red", "Indigo", "Sky", "Violet",
		"Amber", "Emerald", "Midnight", "Crimson", "MonokaiPro",
		"CottonCandy", "Mellowsi", "Rainbow",
	},
	Value = "Dark",
	Callback = function(value)
		WindUI:SetTheme(value)
	end,
})

local LangCategory = Style:Section({
	Title = "Язык",
	Desc = "По умолчанию ENG",
	Icon = "languages",
	Box = true,
	Opened = true,
})

LangCategory:Dropdown({
	Title = "Language",
	Values = { "eng", "ru" },
	Value = "eng",
	Callback = function(value)
		WindUI:SetLanguage(value)
	end,
})

local AnimCategory = Style:Section({
	Title = "Анимации",
	Icon = "sparkles",
	Box = true,
	Opened = true,
})

AnimCategory:Dropdown({
	Title = "Profile",
	Values = { "Smooth", "Snappy", "Calm", "Reduced", "None" },
	Value = "Smooth",
	Callback = function(value)
		WindUI:SetAnimationProfile(value)
	end,
})

WindUI:Notify({
	Title = "Test",
	Content = "Ключ test принят · 2 вкладки с категориями",
	Icon = "settings",
	Duration = 5,
})
