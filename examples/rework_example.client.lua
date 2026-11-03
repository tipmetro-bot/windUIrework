--[[
    WindUI Rework — полный пример
    ------------------------------------------------------------------
    Вставьте это в executor (или положите в StarterPlayerScripts при
    разработке через Rojo). Показывает все новые возможности:

      1. кнопка открытия/закрытия на ПК, телефоне и геймпаде
      2. слайдеры с нулями (Min/Default/Max/Step = 0)
      3. плавные анимации и профили анимаций
      4. панель профиля в нижнем левом углу (как в Neverlose)
      5. сохранение настроек через ConfigManager API
]]

local WindUI = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/tipmetro-bot/windUIrework/refs/heads/arena/1e7c32a5-winduirework/dist/main.lua"
))()

-- ------------------------------------------------------------------
-- Анимации: "Smooth" (по умолчанию), "Snappy", "Calm", "Reduced", "None"
-- ------------------------------------------------------------------
WindUI:SetAnimationProfile("Smooth")
WindUI.TransparencyValue = 0.18
WindUI:SetTheme("Dark")

-- ------------------------------------------------------------------
-- Окно
-- ------------------------------------------------------------------
local Window = WindUI:CreateWindow({
	Title = "WindUI Rework",
	Author = "by tipmetro-bot",
	Folder = "WindUIRework",            -- нужен для ConfigManager (сохранение)
	Icon = "rbxassetid://111665032676235",
	Size = UDim2.fromOffset(620, 470),
	Transparent = true,
	Acrylic = false,
	NewElements = true,

	-- Клавиша открытия/закрытия на ПК (строка, Enum.KeyCode или список)
	ToggleKey = "RightShift",

	-- Язык, тема и экран загрузки настраиваются из кода...
	Theme = "Dark",
	Language = "ru",                    -- "ru" | "en"
	Loading = {                          -- или false / true
		Enabled = true,
		Duration = 1.1,
		Title = "WindUI Rework",
		Steps = { "Конфиг…", "Вкладки…", "Готово" },
	},
	-- ...а в панели профиля есть секция «Настройки», где RU/EN и
	-- Dark/Light переключаются просто кликом. Settings = false её скрывает.
	Settings = { Language = "ru" },

	-- Профиль в нижнем левом углу сайдбара
	User = {
		Enabled = true,
		Anonymous = false,
		Callback = function()
			print("[WindUI] Клик по профилю")
		end,
	},

	-- Кнопка открытия/закрытия. Работает и на ПК, и на телефоне.
	OpenButton = {
		Enabled = true,
		OnlyMobile = false,   -- true = только телефоны (старое поведение)
		StayVisible = true,   -- не прячем при открытом окне -> кнопка и закрывает
		Draggable = true,
		OnlyIcon = false,
		Title = "Открыть UI",
		Scale = 1,
		StrokeThickness = 2,
		CornerRadius = UDim.new(1, 0),
		Color = ColorSequence.new(Color3.fromHex("40c9ff"), Color3.fromHex("e81cff")),
	},

	-- Панель профиля: открывается кликом по аватарке, перекрывает его
	-- сверху, в нижнем левом углу окна.
	Profile = {
		Config = "default",
		AutoLoad = true,
		Overlap = 16,
		Sections = {
			{
				Title = "Комбат",
				Items = {
					{ Title = "Сайлент аим", Flag = "SilentAim", Default = false,
						Callback = function(v) print("Сайлент аим:", v) end },
					{ Title = "Аимбот", Flag = "Aimbot", Default = false,
						Callback = function(v) print("Аимбот:", v) end },
					{ Title = "Триггербот", Flag = "TriggerBot", Default = false,
						Callback = function(v) print("Триггербот:", v) end },
					{ Title = "Kill All", Flag = "KillAll", Type = "Button",
						Callback = function() print("Kill All!") end },
				},
			},
			{
				Title = "Визуалы",
				Items = {
					{ Title = "ESP", Flag = "ESP", Default = true,
						Callback = function(v) print("ESP:", v) end },
					{ Title = "ESP Box", Flag = "ESPBox", Default = false,
						Callback = function(v) print("ESP Box:", v) end },
					{ Title = "ESP Skeleton", Flag = "ESPSkeleton", Default = false,
						Callback = function(v) print("ESP Skeleton:", v) end },
				},
			},
		},
	},
})

-- Можно менять кнопку в любой момент (в том числе с телефона)
Window:SetToggleKey(Enum.KeyCode.RightShift)
-- Window:EditOpenButton({ StayVisible = false, OnlyMobile = false })
-- Window:SetOpenButtonEnabled(true)
-- Window:SetAnimationProfile("Snappy")

-- ------------------------------------------------------------------
-- ConfigManager API: флаги привязываются к файлу конфига
-- ------------------------------------------------------------------
local Config = Window.ConfigManager:Config("default", true)
Config:SetAsCurrent()

-- ------------------------------------------------------------------
-- Вкладки
-- ------------------------------------------------------------------
local CombatTab = Window:Tab({ Title = "Комбат", Icon = "crosshair" })
CombatTab:Section({ Title = "Aim" })

CombatTab:Toggle({
	Title = "Сайлент аим",
	Desc = "Дублирует переключатель из панели профиля",
	Flag = "SilentAim",
	Default = false,
	Callback = function(value)
		print("[Tab] Сайлент аим:", value)
	end,
})

-- Слайдер с нулями: раньше такое ломалось (0/0, пропуск Set(0))
local ZeroSlider = CombatTab:Slider({
	Title = "FOV (Min = 0, Default = 0)",
	Desc = "Нулевые значения теперь работают",
	Flag = "AimFOV",
	Value = { Min = 0, Max = 180, Default = 0 },
	Step = 1,
	Callback = function(value)
		print("[Slider] FOV:", value)
	end,
})

-- Плоский синтаксис тоже поддерживается
CombatTab:Slider({
	Title = "Smoothness",
	Min = 0,
	Max = 100,
	Default = 0,
	Step = 1,
	Flag = "Smoothness",
	Callback = function(value) end,
})

-- Max = 0 и Step = 0 больше не делят на ноль
CombatTab:Slider({
	Title = "Тест Max = 0 / Step = 0",
	Value = { Min = 0, Max = 0, Default = 0 },
	Step = 0,
	Callback = function(value) end,
})

CombatTab:Slider({
	Title = "Дробный шаг (0.0)",
	Value = { Min = 0, Max = 1, Default = 0 },
	Step = 0.05,
	Callback = function(value) end,
})

CombatTab:Button({
	Title = "Установить FOV в 0",
	Callback = function()
		ZeroSlider:Set(0)               -- колбэк сработает даже если уже 0
		print("Текущее значение:", ZeroSlider:GetValue())
	end,
})

local VisualsTab = Window:Tab({ Title = "Визуалы", Icon = "eye" })
VisualsTab:Section({ Title = "ESP" })
VisualsTab:Toggle({ Title = "ESP", Flag = "ESP", Default = true, Callback = function() end })
VisualsTab:Toggle({ Title = "ESP Box", Flag = "ESPBox", Default = false, Callback = function() end })
VisualsTab:Toggle({ Title = "ESP Skeleton", Flag = "ESPSkeleton", Default = false, Callback = function() end })

-- ------------------------------------------------------------------
-- Панель профиля: программный доступ
-- ------------------------------------------------------------------
local Panel = Window.ProfilePanel or Window:Profile({ Config = "default" })

task.delay(2, function()
	-- Открыть/закрыть можно и кодом
	-- Panel:Open()
	print("Значения профиля:", Panel:GetValue("Aimbot"))
	Panel:AddItem("Комбат", {
		Title = "Anti Aim",
		Flag = "AntiAim",
		Default = false,
		Callback = function(value) print("Anti Aim:", value) end,
	})
	Panel:SetValue("ESP", true)
	Panel:SaveConfig()
end)

-- ------------------------------------------------------------------
-- Уведомление
-- ------------------------------------------------------------------
WindUI:Notify({
	Title = "WindUI Rework",
	Content = "ПК + телефон · слайдеры с 0 · плавные анимации · панель профиля",
	Icon = "sparkles",
	Duration = 6,
})
