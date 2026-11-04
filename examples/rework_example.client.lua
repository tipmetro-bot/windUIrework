--[[
    WindUI Rework — ТЕСТОВЫЙ СКРИПТ
    ------------------------------------------------------------------
    Вставьте в executor. КЛЮЧ ДЛЯ ВХОДА: test

    • бандл: .../refs/heads/main/dist/main.lua
    • язык RU/ENG (по умолчанию ENG) и темы задаются ИЗ КОДА
    • панели аккаунта нет: НИКАКИХ «Комбат» / «Визуалы» / «Настроек»
    • одна вкладка со СЛАЙДЕРОМ (ноль работает)
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
--
-- Тема: Dark, Light, Rose, Plant, Red, Indigo, Sky, Violet, Amber,
--       Emerald, Midnight, Crimson, MonokaiPro, CottonCandy,
--       Mellowsi, Rainbow
WindUI:SetTheme("Dark")

----------------------------------------------------------------------
-- Окно + Key System (ключ test)
----------------------------------------------------------------------
local Window = WindUI:CreateWindow({
	Title = "Test",
	Author = "by tipmetro-bot",
	Folder = "WindUIReworkTest",
	Size = UDim2.fromOffset(560, 400),
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
-- Вкладка со слайдером (и никаких Комбат / Визуалов)
----------------------------------------------------------------------
local Tab = Window:Tab({ Title = "Главная", Icon = "settings" })
Tab:Section({ Title = "Slider" })

local TestSlider = Tab:Slider({
	Title = "Test Slider",
	Desc = "От 0 до 100. Значение 0 работает.",
	Value = { Min = 0, Max = 100, Default = 0 },
	Step = 1,
	Flag = "TestSlider",
	Callback = function(value)
		print("[TestSlider]", value)
	end,
})

Tab:Slider({
	Title = "Точность 0.00 → 1.00",
	Desc = "Дробный шаг",
	Value = { Min = 0, Max = 1, Default = 0 },
	Step = 0.05,
	Flag = "Precision",
	Callback = function(value)
		print("[Precision]", value)
	end,
})

Tab:Button({
	Title = "Сбросить слайдер в 0",
	Callback = function()
		TestSlider:Set(0)
		print("Текущее значение:", TestSlider:GetValue())
	end,
})

WindUI:Notify({
	Title = "Test",
	Content = "Ключ test принят · слайдер готов",
	Icon = "settings",
	Duration = 5,
})
