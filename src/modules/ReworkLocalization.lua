--[[
    WindUI Rework / ReworkLocalization
    ------------------------------------------------------------------
    Built-in RU / EN translations for the rework UI (profile panel,
    settings rows, Key System dialog and the loading screen).

    It plugs into the *existing* WindUI localization API instead of
    inventing a second one:

        WindUI:Localization({ Translations = { ru = {...}, en = {...} } })
        WindUI:SetLanguage("ru" | "en")

    `Creator.New` automatically registers every `Text = "loc:<key>"`
    property, so changing the language updates every already-created
    label. User translations are merged, never overwritten.

    API (module level):
        Install(WindUI, language?)   -> enable + merge, idempotent
        Key(name)                    -> "loc:rework.<name>"
        Get(name, language?)         -> resolved plain string
        SetLanguage(WindUI, lang)    -> switch + notify subscribers
        GetLanguage()                -> "ru" | "en"
        OnChange(callback)           -> returns an unsubscribe function
        Languages()                  -> { "ru", "en" }
]]

local Localization = {}

local PREFIX = "rework."
local LANGUAGES = { "ru", "en" }

local Translations = {
	ru = {
		["settings"] = "Настройки",
		["language"] = "Язык / Language",
		["language.ru"] = "Русский",
		["language.en"] = "English",
		["theme"] = "Тема оформления",
		["theme.dark"] = "Тёмная",
		["theme.light"] = "Светлая",
		["loading"] = "Экран загрузки",
		["autoload"] = "Загружать настройки",
		["keysystem"] = "Ключ / Key System",
		["keysystem.title"] = "Key System",
		["keysystem.enter"] = "Введите ключ",
		["keysystem.get"] = "Get Key",
		["keysystem.check"] = "Check Key",
		["keysystem.exit"] = "Выход",
		["keysystem.invalid"] = "Неверный ключ.",
		["keysystem.copied"] = "Ссылка на ключ скопирована.",
		["keysystem.nolink"] = "Ссылка на ключ не задана (KeySystem.URL / KeySystem.API).",
		["loading.title"] = "Загрузка",
		["loading.status"] = "Подготовка интерфейса…",
		["loading.ready"] = "Готово",
		["profile.title"] = "Профиль",
		["profile.subtitle"] = "Настройки WindUI",
		["profile.config"] = "Конфиг",
		["profile.save"] = "Сохранить",
		["profile.load"] = "Загрузить",
		["profile.close"] = "Закрыть",
		["combat"] = "Комбат",
		["visuals"] = "Визуалы",
		["silentaim"] = "Сайлент аим",
		["aimbot"] = "Аимбот",
		["triggerbot"] = "Триггербот",
		["killall"] = "Kill All",
		["esp"] = "ESP",
		["espbox"] = "ESP Box",
		["espskeleton"] = "ESP Skeleton",
		["open"] = "Открыть",
		["close"] = "Закрыть",
	},
	en = {
		["settings"] = "Settings",
		["language"] = "Language / Язык",
		["language.ru"] = "Русский",
		["language.en"] = "English",
		["theme"] = "Theme",
		["theme.dark"] = "Dark",
		["theme.light"] = "Light",
		["loading"] = "Loading screen",
		["autoload"] = "Load saved settings",
		["keysystem"] = "Key System",
		["keysystem.title"] = "Key System",
		["keysystem.enter"] = "Enter key",
		["keysystem.get"] = "Get Key",
		["keysystem.check"] = "Check Key",
		["keysystem.exit"] = "Exit",
		["keysystem.invalid"] = "Invalid key.",
		["keysystem.copied"] = "Key link copied to clipboard.",
		["keysystem.nolink"] = "No key link configured (KeySystem.URL / KeySystem.API).",
		["loading.title"] = "Loading",
		["loading.status"] = "Preparing interface…",
		["loading.ready"] = "Ready",
		["profile.title"] = "Profile",
		["profile.subtitle"] = "WindUI settings",
		["profile.config"] = "Config",
		["profile.save"] = "Save",
		["profile.load"] = "Load",
		["profile.close"] = "Close",
		["combat"] = "Combat",
		["visuals"] = "Visuals",
		["silentaim"] = "Silent Aim",
		["aimbot"] = "Aimbot",
		["triggerbot"] = "TriggerBot",
		["killall"] = "Kill All",
		["esp"] = "ESP",
		["espbox"] = "ESP Box",
		["espskeleton"] = "ESP Skeleton",
		["open"] = "Open",
		["close"] = "Close",
	},
}

local CurrentLanguage = "ru"
local Subscribers = {}

function Localization.Languages()
	return table.clone(LANGUAGES)
end

function Localization.IsValid(language)
	return language == "ru" or language == "en"
end

function Localization.Key(name)
	return "loc:" .. PREFIX .. tostring(name)
end

function Localization.Get(name, language)
	local lang = Localization.IsValid(language) and language or CurrentLanguage
	local entry = Translations[lang] and Translations[lang][name]
	if entry ~= nil then
		return entry
	end
	return (Translations.en[name] ~= nil and Translations.en[name]) or tostring(name)
end

function Localization.GetLanguage()
	return CurrentLanguage
end

function Localization.OnChange(callback)
	if type(callback) ~= "function" then
		return function() end
	end
	Subscribers[#Subscribers + 1] = callback
	return function()
		for index, subscriber in ipairs(Subscribers) do
			if subscriber == callback then
				table.remove(Subscribers, index)
				break
			end
		end
	end
end

--- Merge the built-in dictionary into whatever localization the user has
--- already installed. Never replaces user-provided keys.
function Localization.Install(WindUI, language)
	if not WindUI or not WindUI.Creator then
		return false
	end

	local Creator = WindUI.Creator
	local existing = Creator.Localization
	if type(existing) ~= "table" then
		existing = WindUI:Localization({
			Enabled = true,
			Translations = {},
			Prefix = "loc:",
			DefaultLanguage = "ru",
		})
	end
	if type(existing) ~= "table" then
		return false
	end

	existing.Enabled = true
	existing.Translations = existing.Translations or {}
	for lang, dictionary in pairs(Translations) do
		existing.Translations[lang] = existing.Translations[lang] or {}
		for key, value in pairs(dictionary) do
			existing.Translations[lang][PREFIX .. key] = value
		end
	end

	if Localization.IsValid(language) then
		CurrentLanguage = language
	elseif Localization.IsValid(Creator.Language) then
		CurrentLanguage = Creator.Language
	end
	WindUI:SetLanguage(CurrentLanguage)
	WindUI.ReworkLanguage = CurrentLanguage
	return true
end

--- Switch the whole library (and every rework label) to RU or EN.
function Localization.SetLanguage(WindUI, language)
	local lang = tostring(language or ""):lower()
	if not Localization.IsValid(lang) then
		return false, "Unsupported language (use 'ru' or 'en')"
	end
	CurrentLanguage = lang
	-- Call Creator directly: WindUI:SetLanguage delegates back to this
	-- function, so going through the public API would recurse forever.
	local Creator = WindUI and WindUI.Creator
	if Creator and Creator.SetLanguage then
		Creator.SetLanguage(lang)
		Creator.Language = lang
	end
	if WindUI then
		WindUI.ReworkLanguage = lang
	end
	for _, callback in ipairs(Subscribers) do
		pcall(callback, lang)
	end
	return true
end

return Localization
