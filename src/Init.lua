local WindUI = {
	Window = nil,
	Theme = nil,
	Creator = require("./modules/Creator"),
	LocalizationModule = require("./modules/Localization"),
	NotificationModule = require("./components/Notification"),
	Themes = nil,
	Transparent = false,

	TransparencyValue = 0.15,

	UIScale = 1,

	ConfigManager = nil,
	Version = "0.0.0",
	Animations = require("./modules/Animations"),
	ReworkLocalization = require("./modules/ReworkLocalization"),

	Services = require("./utils/services/Init"),

	-- Rework: explicit, documented layering. Upstream used -99999 for the
	-- window and left every other ScreenGui at 0, so dropdowns / popups
	-- ended up behind (or in front of) the wrong things.
	DisplayOrders = {
		Window = 10,
		Profile = 20,
		Dropdown = 30,
		Tooltip = 40,
		Notification = 50,
		Popup = 60,
		KeySystem = 70,
		Loading = 100,
	},

	OnThemeChangeFunction = nil,

	cloneref = nil,
	UIScaleObj = nil,

	CreateWindow = nil,

	CurrentInput = nil,
}

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

WindUI.cloneref = cloneref

local HttpService = cloneref(game:GetService("HttpService"))
local Players = cloneref(game:GetService("Players"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))

function WindUI.GenerateGUID()
	return HttpService:GenerateGUID(false)
end

local CurInput = WindUI.GenerateGUID()

UserInputService.InputBegan:Connect(function(Input, GameProcessed)
	--[[if GameProcessed then
		return
	end]]

	task.defer(function()
		if
			Input.UserInputType == Enum.UserInputType.MouseButton1
			or Input.UserInputType == Enum.UserInputType.Touch
		then
			if WindUI.CurrentInput and WindUI.CurrentInput ~= CurInput then
				return
			end

			WindUI.CurrentInput = CurInput
			--print(CurInput)
			--WindUI.InputStartedOnUI = false
		end
	end)
end)
UserInputService.InputEnded:Connect(function(Input, GameProcessed)
	if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
		if WindUI.CurrentInput and WindUI.CurrentInput ~= CurInput then
			return
		end

		WindUI.CurrentInput = nil
	end
end)

local LocalPlayer = Players.LocalPlayer or nil

local Package = HttpService:JSONDecode(require("../build/package"))
if Package then
	WindUI.Version = Package.version
end

local KeySystem = require("./components/KeySystem")
local LoadingScreen = require("./components/window/LoadingScreen")

local Creator = WindUI.Creator

local New = Creator.New

--local Tween = Creator.Tween
--local ServicesModule = WindUI.Services

local Acrylic = require("./utils/Acrylic/Init")

local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end

local GUIParent = gethui and gethui() or (CoreGui or LocalPlayer:WaitForChild("PlayerGui"))
WindUI.GUIParent = GUIParent

local UIScaleObj = New("UIScale", {
	Scale = WindUI.UIScale,
})

WindUI.UIScaleObj = UIScaleObj

WindUI.ScreenGui = New("ScreenGui", {
	Name = "WindUI",
	Parent = GUIParent,
	IgnoreGuiInset = true,
	ScreenInsets = "None",
	ZIndexBehavior = "Sibling",
	DisplayOrder = WindUI.DisplayOrders.Window,
}, {

	New("Folder", {
		Name = "Window",
	}),
	-- New("Folder", {
	--     Name = "Notifications"
	-- }),
	-- New("Folder", {
	--     Name = "Dropdowns"
	-- }),
	New("Folder", {
		Name = "KeySystem",
	}),
	New("Folder", {
		Name = "Popups",
	}),
	New("Folder", {
		Name = "ToolTips",
	}),
})

WindUI.NotificationGui = New("ScreenGui", {
	Name = "WindUI/Notifications",
	Parent = GUIParent,
	IgnoreGuiInset = true,
	ScreenInsets = "None",
	ZIndexBehavior = "Sibling",
	DisplayOrder = WindUI.DisplayOrders.Notification,
})
WindUI.DropdownGui = New("ScreenGui", {
	Name = "WindUI/Dropdowns",
	Parent = GUIParent,
	IgnoreGuiInset = true,
	ScreenInsets = "None",
	ZIndexBehavior = "Sibling",
	DisplayOrder = WindUI.DisplayOrders.Dropdown,
})
WindUI.TooltipGui = New("ScreenGui", {
	Name = "WindUI/Tooltips",
	Parent = GUIParent,
	IgnoreGuiInset = true,
	ScreenInsets = "None",
	ZIndexBehavior = "Sibling",
	DisplayOrder = WindUI.DisplayOrders.Tooltip,
})
ProtectGui(WindUI.ScreenGui)
ProtectGui(WindUI.NotificationGui)
ProtectGui(WindUI.DropdownGui)
ProtectGui(WindUI.TooltipGui)

Creator.Init(WindUI)

function WindUI:SetParent(parent)
	if WindUI.ScreenGui then
		WindUI.ScreenGui.Parent = parent
	end
	if WindUI.NotificationGui then
		WindUI.NotificationGui.Parent = parent
	end
	if WindUI.DropdownGui then
		WindUI.DropdownGui.Parent = parent
	end
	if WindUI.TooltipGui then
		WindUI.TooltipGui.Parent = parent
	end
end
math.clamp(WindUI.TransparencyValue, 0, 1)

local Holder = WindUI.NotificationModule.Init(WindUI.NotificationGui)

function WindUI:Notify(Config)
	Config.Holder = Holder.Frame
	Config.Window = WindUI.Window
	--Config.WindUI = WindUI
	return WindUI.NotificationModule.New(Config)
end

function WindUI:SetNotificationLower(Val)
	Holder.SetLower(Val)
end

function WindUI:SetFont(FontId)
	Creator.UpdateFont(FontId)
end

--[[
    Rework / animation API
    Profiles: "Smooth" (default), "Snappy", "Calm", "Reduced", "None".
    "None" applies every property instantly (accessibility / weak devices).
]]
function WindUI:SetAnimationProfile(name)
	local ok = WindUI.Animations:SetProfile(name)
	return ok and name or WindUI.Animations:GetProfile()
end

function WindUI:GetAnimationProfile()
	return WindUI.Animations:GetProfile()
end

function WindUI:SetAnimationsEnabled(value)
	return WindUI.Animations:SetEnabled(value)
end

function WindUI:SetAnimationSpeed(value)
	return WindUI.Animations:SetSpeed(value)
end

function WindUI:OnThemeChange(func)
	if typeof(func) ~= "function" then
		return function() end
	end
	-- Rework: keep every subscriber. Upstream stored ONE callback, so the
	-- profile panel's theme row silently disabled the user's own handler.
	WindUI.ThemeChangeSubscribers = WindUI.ThemeChangeSubscribers or {}
	WindUI.ThemeChangeSubscribers[#WindUI.ThemeChangeSubscribers + 1] = func
	return function()
		for index, callback in ipairs(WindUI.ThemeChangeSubscribers or {}) do
			if callback == func then
				table.remove(WindUI.ThemeChangeSubscribers, index)
				break
			end
		end
	end
end

function WindUI:AddTheme(LTheme)
	if type(LTheme) ~= "table" or not LTheme.Name then
		return nil
	end
	WindUI.Themes[LTheme.Name] = LTheme
	-- Rework (bug 5): a theme added/replaced at runtime must be applied to
	-- already-created elements instead of only being stored in the table.
	if WindUI.CurrentTheme == LTheme.Name or WindUI.Theme == LTheme then
		WindUI:SetTheme(LTheme.Name)
	end
	return LTheme
end

function WindUI:SetTheme(Value)
	local Theme = WindUI.Themes[Value]
	if not Theme then
		-- Allow the pretty Name ("Monokai Pro") as well as the table key.
		for key, candidate in pairs(WindUI.Themes) do
			if type(candidate) == "table" and candidate.Name == Value then
				Theme, Value = candidate, key
				break
			end
		end
	end
	if Theme then
		WindUI.Theme = Theme
		WindUI.CurrentTheme = Value -- rework: custom elements read this
		Creator.SetTheme(Theme)

		if WindUI.OnThemeChangeFunction then
			Creator.SafeCallback(WindUI.OnThemeChangeFunction, Value)
		end
		for _, callback in ipairs(WindUI.ThemeChangeSubscribers or {}) do
			Creator.SafeCallback(callback, Value)
		end

		return Theme
	end
	return nil
end

function WindUI:GetThemes()
	return WindUI.Themes
end
function WindUI:GetCurrentTheme()
	-- Return the *table key* accepted by SetTheme. Some themes have a
	-- pretty Name ("Monokai Pro") that is not a valid SetTheme argument.
	return WindUI.CurrentTheme or (WindUI.Theme and WindUI.Theme.Name) or "Dark"
end
function WindUI:GetTransparency()
	return WindUI.Transparent or false
end
function WindUI:GetWindowSize()
	return WindUI.Window.UIElements.Main.Size
end
function WindUI:Localization(LocalizationConfig)
	return WindUI.LocalizationModule:New(LocalizationConfig, Creator)
end

function WindUI:SetLanguage(Value)
	if WindUI.ReworkLocalization.IsValid(Value) then
		return WindUI.ReworkLocalization.SetLanguage(WindUI, Value)
	end
	-- Any custom language registered by the user still works.
	if Creator.Localization then
		return Creator.SetLanguage(Value)
	end
	return false
end

function WindUI:ToggleAcrylic(Value)
	if WindUI.Window and WindUI.Window.AcrylicPaint and WindUI.Window.AcrylicPaint.Model then
		WindUI.Window.Acrylic = Value
		WindUI.Window.AcrylicPaint.Model.Transparency = Value and 0.98 or 1
		if Value then
			Acrylic.Enable()
		else
			Acrylic.Disable()
		end
	end
end

function WindUI:Gradient(stops, props)
	local colorSequence = {}
	local transparencySequence = {}

	for posStr, stop in next, stops do
		local position = tonumber(posStr)
		if position then
			position = math.clamp(position / 100, 0, 1)

			local color = stop.Color
			if typeof(color) == "string" and string.sub(color, 1, 1) == "#" then
				color = Color3.fromHex(color)
			end

			local transparency = stop.Transparency or 0

			table.insert(colorSequence, ColorSequenceKeypoint.new(position, color))
			table.insert(transparencySequence, NumberSequenceKeypoint.new(position, transparency))
		end
	end

	table.sort(colorSequence, function(a, b)
		return a.Time < b.Time
	end)
	table.sort(transparencySequence, function(a, b)
		return a.Time < b.Time
	end)

	if #colorSequence < 2 then
		table.insert(colorSequence, ColorSequenceKeypoint.new(1, colorSequence[1].Value))
		table.insert(transparencySequence, NumberSequenceKeypoint.new(1, transparencySequence[1].Value))
	end

	local gradientData = {
		Color = ColorSequence.new(colorSequence),
		Transparency = NumberSequence.new(transparencySequence),
	}

	if props then
		for k, v in pairs(props) do
			gradientData[k] = v
		end
	end

	return gradientData
end

function WindUI:Popup(PopupConfig)
	PopupConfig.WindUI = WindUI
	return require("./components/popup/Init").new(PopupConfig, WindUI.ScreenGui.Popups)
end

WindUI.Themes = require("./themes/Init")(WindUI, Creator)

Creator.Themes = WindUI.Themes

WindUI:SetTheme("Dark")

-- Rework: RU/EN is built in and can be switched from the profile panel
-- (or from code with `WindUI:SetLanguage("en")`).
WindUI.ReworkLocalization.Install(WindUI, nil)
WindUI:SetLanguage(WindUI.ReworkLocalization.GetLanguage())

function WindUI:GetLanguage()
	return Creator.Language
end

function WindUI:OnLanguageChange(callback)
	return WindUI.ReworkLocalization.OnChange(callback)
end

function WindUI:SetDisplayOrder(name, value)
	if WindUI.DisplayOrders[name] == nil or type(value) ~= "number" then
		return false
	end
	WindUI.DisplayOrders[name] = value
	local gui = ({
		Window = WindUI.ScreenGui,
		Dropdown = WindUI.DropdownGui,
		Tooltip = WindUI.TooltipGui,
		Notification = WindUI.NotificationGui,
	})[name]
	if gui then
		gui.DisplayOrder = value
	end
	return true
end

function WindUI:SetLoadingEnabled(value)
	WindUI.LoadingEnabled = value == true
	if WindUI.LoadingScreen and WindUI.LoadingScreen.SetEnabled then
		WindUI.LoadingScreen:SetEnabled(WindUI.LoadingEnabled)
	end
	return WindUI
end

function WindUI:CreateWindow(Config)
	local CreateWindow = require("./components/window/Init")

	-- Rework (bug 2): CreateWindow can be re-entered while the Key System
	-- dialog is open. Without this guard two windows were created.
	if WindUI.Window then
		return WindUI.Window
	end
	if WindUI.CreateWindowBusy then
		warn("[ WindUI ] CreateWindow is already in progress")
		return WindUI.Window
	end
	WindUI.CreateWindowBusy = true

	if not RunService:IsStudio() and typeof(writefile) == "function"
		and typeof(isfolder) == "function" and typeof(makefolder) == "function" then
		pcall(function()
			if not isfolder("WindUI") then
				makefolder("WindUI")
			end
			makefolder(Config.Folder or Config.Title)
		end)
	end

	Config.WindUI = WindUI
	Config.Window = WindUI.Window
	Config.Parent = WindUI.ScreenGui.Window

	local CanLoadWindow = true
	local KeySystemCancelled = false

	-- Rework (bug 5): go through the public API so `WindUI.Theme`,
	-- `WindUI.CurrentTheme` and OnThemeChange stay in sync. Calling
	-- Creator.SetTheme() directly left GetCurrentTheme() stale.
	if Config.Theme then
		WindUI:SetTheme(Config.Theme)
	else
		Creator.SetTheme(WindUI.Theme or WindUI.Themes.Dark)
	end

	-- Rework: language + loading are configurable from code.
	local Settings = type(Config.Settings) == "table" and Config.Settings or {}
	local requestedLanguage = Config.Language or Settings.Language
	if requestedLanguage then
		WindUI:SetLanguage(requestedLanguage)
	end
	local loadingConfig = Config.Loading
	if loadingConfig == nil then
		loadingConfig = Settings.Loading
	end
	WindUI.LoadingScreen = LoadingScreen.New(WindUI, loadingConfig)
	WindUI.LoadingEnabled = WindUI.LoadingScreen.Enabled

	local hwid = gethwid or function()
		return Players.LocalPlayer.UserId
	end

	local Filename = hwid()

	if Config.KeySystem then
		CanLoadWindow = false

		-- Rework (bug 2): one-shot resolution. The upstream callback could
		-- fire twice, and closing the dialog left the `repeat task.wait()`
		-- loop spinning forever (a real coroutine/CPU leak).
		local resolved = false
		local function resolveKey(success)
			if resolved then
				return
			end
			resolved = true
			if success == true then
				CanLoadWindow = true
			else
				KeySystemCancelled = true
			end
		end

		local function loadKeysystem()
			KeySystem.new(Config, Filename, resolveKey)
		end

		local keyPath = (Config.Folder or "Temp") .. "/" .. Filename .. ".key"
		-- Studio / plain Roblox have no executor filesystem API. Calling a
		-- nil isfile()/readfile() used to crash the whole Key System dialog.
		local function KeyFileExists(path)
			return typeof(isfile) == "function" and isfile(path) or false
		end
		local function ReadKeyFile(path)
			if typeof(readfile) ~= "function" then
				return nil
			end
			local ok, contents = pcall(readfile, path)
			return ok and contents or nil
		end

		if Config.KeySystem.KeyValidator then
			if Config.KeySystem.SaveKey and KeyFileExists(keyPath) then
				local savedKey = ReadKeyFile(keyPath)
				local isValid = Config.KeySystem.KeyValidator(savedKey)

				if isValid then
					resolveKey(true)
				else
					loadKeysystem()
				end
			else
				loadKeysystem()
			end
		elseif not Config.KeySystem.API then
			if Config.KeySystem.SaveKey and KeyFileExists(keyPath) then
				local savedKey = ReadKeyFile(keyPath)
				local isKey = (type(Config.KeySystem.Key) == "table") and table.find(Config.KeySystem.Key, savedKey)
					or tostring(Config.KeySystem.Key) == tostring(savedKey)

				if isKey then
					resolveKey(true)
				else
					loadKeysystem()
				end
			else
				loadKeysystem()
			end
		else
			if KeyFileExists(keyPath) then
				local fileKey = ReadKeyFile(keyPath)
				local isSuccess = false

				for _, i in next, Config.KeySystem.API do
					local serviceData = WindUI.Services[i.Type]
					if serviceData then
						local args = {}
						for _, argName in next, serviceData.Args do
							table.insert(args, i[argName])
						end

						local service = serviceData.New(table.unpack(args))
						local success = service.Verify(fileKey)
						if success then
							isSuccess = true
							break
						end
					end
				end

				if isSuccess then resolveKey(true) else loadKeysystem() end
				if not isSuccess then
					loadKeysystem()
				end
			else
				loadKeysystem()
			end
		end

		-- Bounded wait: yields a frame at a time (no busy spin) and always
		-- terminates, even if the dialog is closed without a key. A frame
		-- counter capped at 15 s on 60 FPS, which was far too short for a
		-- human to fetch and type a key, so use wall-clock time instead.
		local keyWaitStarted = os.time()
		repeat
			task.wait()
		until CanLoadWindow or KeySystemCancelled or (os.time() - keyWaitStarted) > 300

		if not CanLoadWindow then
			WindUI.CreateWindowBusy = false
			if WindUI.LoadingScreen then
				WindUI.LoadingScreen:Destroy()
			end
			return nil
		end
	end

	local Window = CreateWindow(Config)
	WindUI.CreateWindowBusy = false

	if not Window then
		if WindUI.LoadingScreen then
			WindUI.LoadingScreen:Destroy()
		end
		return nil
	end

	Window.LoadingScreen = WindUI.LoadingScreen
	Window.Settings = Settings
	WindUI.Transparent = Config.Transparent
	WindUI.Window = Window

	if Config.Acrylic then
		Acrylic.init()
	end

	-- function Window:ToggleTransparency(Value)
	--     WindUI.Transparent = Value
	--     WindUI.Window.Transparent = Value

	--     Window.UIElements.Main.Background.BackgroundTransparency = Value and WindUI.TransparencyValue or 0
	--     Window.UIElements.Main.Background.ImageLabel.ImageTransparency = Value and WindUI.TransparencyValue or 0
	--     Window.UIElements.Main.Gradient.UIGradient.Transparency = NumberSequence.new{
	--         NumberSequenceKeypoint.new(0, 1),
	--         NumberSequenceKeypoint.new(1, Value and 0.85 or 0.7),
	--     }
	-- end

	return Window
end

return WindUI
