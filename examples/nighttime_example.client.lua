--[[
    WindUI Rework — пример с вкладками и категориями
    ------------------------------------------------------------------
    Вставьте в executor (или загрузите одной строкой loadstring).

    • 3 вкладки, внутри каждой — боксовые категории (Section{ Box = true })
    • ключ-системы нет, панели аккаунта нет, Комбат/Визуалов нет
    • язык ENG по умолчанию, тема и анимации задаются из кода
    • все слайдеры корректно работают с 0
]]

local WindUI = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/tipmetro-bot/windUIrework/refs/heads/main/dist/main.lua"
))()

WindUI:SetAnimationProfile("Smooth")
WindUI.TransparencyValue = 0.18
WindUI:SetTheme("Dark")

local Window = WindUI:CreateWindow({
	Title = "Nighttime",
	Author = "by tipmetro-bot",
	Folder = "WindUIReworkExample",
	Size = UDim2.fromOffset(600, 450),
	ToggleKey = "RightShift",
	Transparent = true,
	NewElements = true,
	Theme = "Dark",
	Loading = false,
	User = { Enabled = false },
	OpenButton = { Enabled = true, Draggable = true },
})
if not Window then
	return
end

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local saved = {
	ClockTime = Lighting.ClockTime,
	Brightness = Lighting.Brightness,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	FogColor = Lighting.FogColor,
	FogEnd = Lighting.FogEnd,
}

local hour, fogEnd, night, fog = 0, 300, false, false
local TestSlider

local function restore()
	Lighting.ClockTime = saved.ClockTime
	Lighting.Brightness = saved.Brightness
	Lighting.Ambient = saved.Ambient
	Lighting.OutdoorAmbient = saved.OutdoorAmbient
	Lighting.FogColor = saved.FogColor
	Lighting.FogEnd = saved.FogEnd
end

local function applyNight()
	Lighting.ClockTime = hour
	Lighting.Brightness = 0.2 + (1 - math.abs(12 - hour) / 12) * 0.35
	Lighting.Ambient = Color3.fromRGB(16, 20, 38)
	Lighting.OutdoorAmbient = Color3.fromRGB(20, 26, 48)
	Lighting.FogColor = Color3.fromRGB(10, 14, 30)
	Lighting.FogEnd = fog and fogEnd or saved.FogEnd
end

----------------------------------------------------------------------
-- ВКЛАДКА 1 · Nighttime
----------------------------------------------------------------------
local Night = Window:Tab({ Title = "Nighttime", Icon = "moon" })

local TimeCategory = Night:Section({
	Title = "Время суток",
	Desc = "Освещение и время",
	Icon = "moon",
	Box = true,
	BoxBorder = true,
	Opened = true,
})

TimeCategory:Toggle({
	Title = "Night Mode",
	Desc = "Ночь вкл / выкл",
	Value = false,
	Callback = function(state)
		night = state
		if state then applyNight() else restore() end
	end,
})

TimeCategory:Slider({
	Title = "Nighttime / ClockTime",
	Desc = "0 = полночь, 12 = день, 24 = утро",
	Value = { Min = 0, Max = 24, Default = 0 },
	Step = 0.5,
	Callback = function(value)
		hour = value
		if night then applyNight() end
	end,
})

TimeCategory:Slider({
	Title = "Brightness",
	Value = { Min = 0, Max = 3, Default = 0 },
	Step = 0.05,
	Callback = function(value)
		if night then Lighting.Brightness = value end
	end,
})

local FogCategory = Night:Section({
	Title = "Туман",
	Desc = "Дальность и цвет",
	Icon = "cloud-fog",
	Box = true,
	Opened = true,
})

FogCategory:Toggle({
	Title = "Fog",
	Value = false,
	Callback = function(state)
		fog = state
		if night then applyNight() end
	end,
})

FogCategory:Slider({
	Title = "Fog End",
	Desc = "Дальность тумана, 0 работает",
	Value = { Min = 0, Max = 1000, Default = 300 },
	Step = 10,
	Callback = function(value)
		fogEnd = value
		if night and fog then Lighting.FogEnd = fogEnd end
	end,
})

local ActionsCategory = Night:Section({
	Title = "Действия",
	Icon = "zap",
	Box = true,
	Opened = true,
})

ActionsCategory:Button({
	Title = "Сбросить освещение",
	Callback = function()
		night, fog = false, false
		restore()
	end,
})

ActionsCategory:Button({
	Title = "Kick Self",
	Callback = function()
		Players.LocalPlayer:Kick("Nighttime · bye")
	end,
})

----------------------------------------------------------------------
-- ВКЛАДКА 2 · Слайдеры
----------------------------------------------------------------------
local Sliders = Window:Tab({ Title = "Слайдеры", Icon = "sliders-horizontal" })

local BasicCategory = Sliders:Section({
	Title = "Основные",
	Desc = "Обычные диапазоны",
	Icon = "sliders-horizontal",
	Box = true,
	Opened = true,
})

TestSlider = BasicCategory:Slider({
	Title = "Test Slider",
	Desc = "От 0 до 100, старт с 0",
	Value = { Min = 0, Max = 100, Default = 0 },
	Step = 1,
	Flag = "TestSlider",
	Callback = function(value)
		print("[TestSlider]", value)
	end,
})

BasicCategory:Slider({
	Title = "Precision",
	Desc = "Дробный шаг 0.05",
	Value = { Min = 0, Max = 1, Default = 0 },
	Step = 0.05,
	Callback = function(value)
		print("[Precision]", value)
	end,
})

local EdgeCategory = Sliders:Section({
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

local ControlCategory = Sliders:Section({
	Title = "Управление",
	Icon = "rotate-ccw",
	Box = true,
	Opened = true,
})

ControlCategory:Button({
	Title = "Сбросить в 0",
	Callback = function()
		TestSlider:Set(0)
		print("Текущее значение:", TestSlider:GetValue())
	end,
})

ControlCategory:Button({
	Title = "Поставить 50",
	Callback = function()
		TestSlider:Set(50)
		print("Текущее значение:", TestSlider:GetValue())
	end,
})

----------------------------------------------------------------------
-- ВКЛАДКА 3 · Оформление
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

local InfoCategory = Style:Section({
	Title = "Информация",
	Icon = "info",
	Box = true,
	Opened = true,
})

InfoCategory:Paragraph({
	Title = "WindUI Rework",
	Desc = "Три вкладки, боксовые категории, zero-safe слайдеры.",
})

WindUI:Notify({
	Title = "Nighttime",
	Content = "3 вкладки · категории · слайдеры с 0",
	Icon = "moon",
	Duration = 5,
})
