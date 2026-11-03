--!strict
--[[
    WindUI Rework / bundle smoke test
    ------------------------------------------------------------------
    Loads dist/main.lua in a plain Luau VM with a tiny Roblox-like mock,
    then creates a window, a tab, zero-safe sliders and the profile panel.
    This catches broken requires, nil globals, bad top-level calls and
    runtime errors in the reworked components without a real Roblox client.

    Run with:  LUAU_BIN=/path/to/luau python3 tools/smoke_test.py
    (the runner inlines the bundle here, because Luau's `require()` gives
    modules a fresh Roblox-less global environment).
]]

----------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------
local function makeSignal()
	local s = { _callbacks = {} }
	function s:Connect(callback)
		table.insert(self._callbacks, callback)
		return {
			Disconnect = function() end,
		}
	end
	function s:Fire(...)
		for _, callback in ipairs(self._callbacks) do
			callback(...)
		end
	end
	return s
end

----------------------------------------------------------------------
-- Instances
----------------------------------------------------------------------
local function mockInstance(className: string)
	local object: any = { ClassName = className, _isInstance = true }
	local props: any = { Name = className } -- Roblox default Name = ClassName
	local children: any = {}
	local signals: any = {}
	local parent: any = nil

	local mt: any = {}
	mt.__index = function(_, key)
		if key == "Parent" then
			return parent
		end
		if props[key] ~= nil then
			return props[key]
		end
		-- Roblox lets you address children by name: frame.Topbar.Left
		for _, child in ipairs(children) do
			if child.Name == key then
				return child
			end
		end
		if key == "AbsoluteSize" then
			return { X = 600, Y = 460 }
		end
		if key == "AbsolutePosition" then
			return { X = 0, Y = 0 }
		end
		if key == "AbsoluteContentSize" then
			return { X = 0, Y = 0 }
		end
		if key == "IsA" then
			return function(self, name: string)
				return self.ClassName == name
			end
		end
		if key == "FindFirstChild" then
			return function(_, name: string)
				for _, child in ipairs(children) do
					if child.Name == name then
						return child
					end
				end
				return nil
			end
		end
		if key == "WaitForChild" then
			return function(_, name: string)
				for _, child in ipairs(children) do
					if child.Name == name then
						return child
					end
				end
				return mockInstance(name)
			end
		end
		if key == "GetPropertyChangedSignal" then
			return function(_, name: string)
				if not signals["prop:" .. name] then
					signals["prop:" .. name] = makeSignal()
				end
				return signals["prop:" .. name]
			end
		end
		if key == "GetChildren" then
			return function()
				return children
			end
		end
		if key == "Destroy" then
			return function() end
		end
		if key == "Clone" then
			return function()
				return mockInstance(className)
			end
		end
		if key == "InvokeServer" then
			return function()
				return {}
			end
		end
		if key == "GetMouseLocation" then
			return function()
				return { X = 0, Y = 0 }
			end
		end
		if key == "GetMouse" then
			return function()
				local mouse = mockInstance("Mouse")
				mouse.X = 0
				mouse.Y = 0
				return mouse
			end
		end
		if key == "TweenSize" or key == "TweenPosition" then
			return function() end
		end
		if key == "SetAttribute" or key == "GetAttribute" then
			return function() end
		end
		-- Unknown reads are treated as events (GuiObject signals).
		if not signals[key] then
			signals[key] = makeSignal()
		end
		return signals[key]
	end
	mt.__newindex = function(_, key, value)
		if key == "Parent" then
			if parent and parent._removeChild then
				parent._removeChild(object)
			end
			parent = value
			if value and value._addChild then
				value._addChild(object)
			end
			return
		end
		props[key] = value
	end
	object._addChild = function(child)
		table.insert(children, child)
	end
	object._removeChild = function(child)
		for i, c in ipairs(children) do
			if c == child then
				table.remove(children, i)
				break
			end
		end
	end
	return setmetatable(object, mt)
end

Instance = { new = function(className: string)
	return mockInstance(className)
end }

----------------------------------------------------------------------
-- Datatypes
----------------------------------------------------------------------
local function vec2(x: number?, y: number?)
	return { X = x or 0, Y = y or 0, _isVector2 = true }
end
Vector2 = { new = vec2, zero = vec2(0, 0) }

local function udim2(a: number?, b: number?, c: number?, d: number?)
	return {
		X = { Scale = a or 0, Offset = b or 0 },
		Y = { Scale = c or 0, Offset = d or 0 },
		_isUDim2 = true,
	}
end
UDim2 = { new = udim2, fromOffset = function(x, y)
	return udim2(0, x, 0, y)
end, fromScale = udim2 }
UDim = { new = function(scale, offset)
	return { Scale = scale or 0, Offset = offset or 0 }
end }

local function hexToRgb(hex: string)
	hex = hex:gsub("#", "")
	local r = tonumber(hex:sub(1, 2), 16) or 255
	local g = tonumber(hex:sub(3, 4), 16) or 255
	local b = tonumber(hex:sub(5, 6), 16) or 255
	return r / 255, g / 255, b / 255
end
local function color3(r: any, g: any?, b: any?)
	if typeof(r) == "string" then
		r, g, b = hexToRgb(r)
	end
	return { R = r or 1, G = g or r or 1, B = b or r or 1, _isColor3 = true }
end
Color3 = {
	new = color3,
	fromHex = function(hex: string)
		return color3(hex)
	end,
	fromRGB = function(r, g, b)
		return color3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
	end,
}

ColorSequenceKeypoint = { new = function(time, color)
	return { Time = time, Value = color }
end }
ColorSequence = { new = function(...)
	return { ... }
end }
NumberSequenceKeypoint = { new = function(time, value)
	return { Time = time, Value = value }
end }
NumberSequence = { new = function(...)
	return { ... }
end }
Rect = { new = function(a, b, c, d)
	return { a, b, c, d }
end }
Font = { new = function(id, weight, style)
	return { Family = id, Weight = weight, Style = style }
end }
TweenInfo = { new = function(...)
	return { ... }
end }

----------------------------------------------------------------------
-- typeof (Roblox version)
----------------------------------------------------------------------
typeof = function(value: any): string
	if type(value) ~= "table" then
		return type(value)
	end
	if rawget(value, "_isInstance") then
		return "Instance"
	end
	if rawget(value, "_isEnumItem") then
		return "EnumItem"
	end
	if rawget(value, "_isUDim2") then
		return "UDim2"
	end
	if rawget(value, "_isColor3") then
		return "Color3"
	end
	if rawget(value, "_isVector2") then
		return "Vector2"
	end
	if rawget(value, "_isUDim") then
		return "UDim"
	end
	return "table"
end

----------------------------------------------------------------------
-- Enum
----------------------------------------------------------------------
local function enumGroup()
	return setmetatable({}, {
		__index = function(t, name)
			local item = { Name = name, Value = 0, _isEnumItem = true }
			t[name] = item
			return item
		end,
	})
end
Enum = setmetatable({}, {
	__index = function(t, name)
		local group = enumGroup()
		t[name] = group
		return group
	end,
})

----------------------------------------------------------------------
-- Services
----------------------------------------------------------------------
local services: any = {}
local function getService(name: string)
	if services[name] then
		return services[name]
	end
	local service: any = mockInstance(name)

	if name == "HttpService" then
		service.GenerateGUID = function()
			return "00000000-0000-0000-0000-000000000000"
		end
		service.JSONDecode = function()
			return { version = "smoke-test" }
		end
		service.JSONEncode = function()
			return "{}"
		end
	elseif name == "RunService" then
		service.IsStudio = function()
			return true
		end
		service.Heartbeat = makeSignal()
		service.RenderStepped = makeSignal()
	elseif name == "TweenService" then
		service.Create = function()
			return { Play = function() end, Cancel = function() end }
		end
	elseif name == "UserInputService" then
		service.TouchEnabled = false
		service.KeyboardEnabled = true
		service.MouseEnabled = true
		service.GamepadEnabled = false
		service.GetMouseLocation = function()
			return { X = 0, Y = 0 }
		end
	elseif name == "Players" then
		service.LocalPlayer = mockInstance("Player")
		service.LocalPlayer.UserId = 1
		service.LocalPlayer.DisplayName = "Tester"
		service.LocalPlayer.Name = "Tester"
		service.GetUserThumbnailAsync = function()
			return "rbxassetid://0", true
		end
	elseif name == "LocalizationService" then
		service.SystemLocaleId = "en-us"
	end

	services[name] = service
	return service
end

game = {
	GetService = function(_, name: string)
		return getService(name)
	end,
	HttpGet = function()
		return "return {}"
	end,
}

workspace = { CurrentCamera = { ViewportSize = vec2(1920, 1080) } }

----------------------------------------------------------------------
-- Globals used by executors
----------------------------------------------------------------------
request = nil              -- Main-v2.lua falls back to the bundled icon tables
cloneref = nil
protectgui = nil
gethui = nil
writefile = nil
isfolder = nil
makefolder = nil
isfile = nil
readfile = nil
warn = function(...)
	print("[warn]", ...)
end

task = {
	spawn = function(fn, ...)
		return fn(...)
	end,
	defer = function(fn, ...)
		return fn(...)
	end,
	delay = function(_, fn, ...)
		return fn(...)
	end,
	wait = function() end,
	cancel = function() end,
}

----------------------------------------------------------------------
-- Load the bundle
----------------------------------------------------------------------
-- `tools/smoke_test.py` injects dist/main.lua in place of the marker and
-- runs this file with the Luau CLI. A plain `require()` would get a fresh
-- (Roblox-less) global environment in the CLI, so the bundle is inlined.
local WindUI = (function()
-- __WINDUI_BUNDLE__
end)()

if type(WindUI) ~= "table" then
	error("dist/main.lua did not return the WindUI table", 0)
end

local required = {
	"CreateWindow", "SetTheme", "GetThemes", "Notify", "Popup", "Gradient",
	"SetAnimationProfile", "GetAnimationProfile", "SetAnimationsEnabled",
	"SetAnimationSpeed", "Creator", "Animations", "Version", "ScreenGui",
}
for _, key in ipairs(required) do
	if WindUI[key] == nil then
		error("WindUI." .. key .. " is missing", 0)
	end
end

-- Animation profiles must be switchable without Roblox.
WindUI:SetAnimationProfile("None")
if WindUI:GetAnimationProfile() ~= "None" then
	error("SetAnimationProfile('None') did not apply", 0)
end
WindUI:SetAnimationProfile("Smooth")
if WindUI:GetAnimationProfile() ~= "Smooth" then
	error("SetAnimationProfile('Smooth') did not apply", 0)
end
if WindUI.Animations:Get("Open") <= 0 then
	error("Smooth profile must have a positive open duration", 0)
end
local tweenDummy = Instance.new("Frame")
local tween = WindUI.Animations:Play(
	tweenDummy, "Open", { BackgroundTransparency = 0.5 }, "Quint", "Out"
)
if tween == nil then
	error("Animations:Play did not create a tween in the Smooth profile", 0)
end

-- Icons must resolve from the vendored packs, with no HttpGet at all.
if WindUI.Creator.Icon("minus") == nil then
	error("vendored lucide icons did not resolve offline", 0)
end
local iconsAdded = pcall(function()
	WindUI.Creator.AddIcons("smokepack", { smoke = "rbxassetid://0" })
end)
if not iconsAdded or WindUI.Creator.Icon("smokepack:smoke") == nil then
	error("AddIcons on a vendored/flat pack failed", 0)
end

----------------------------------------------------------------------
-- UI smoke: window + zero slider + profile panel, all under the mock.
-- Animations are disabled so task.delay/task.spawn helpers stay finite.
----------------------------------------------------------------------
WindUI:SetAnimationProfile("None")

local created, Window = pcall(function()
	return WindUI:CreateWindow({
		Title = "Smoke",
		Folder = "SmokeTest",
		Size = UDim2.fromOffset(620, 470),
		ToggleKey = "RightShift",
		User = { Enabled = true },
		OpenButton = { Enabled = true, Draggable = true },
		Loading = { Enabled = true, Duration = 0.25 },
		Settings = { Language = "ru" },
		Theme = "Dark",
		Profile = {
			Config = "default",
			Sections = {
				{ Title = "Комбат", Items = {
					{ Title = "Аимбот", Flag = "Aimbot", Default = false },
					{ Title = "Kill All", Type = "Button", Callback = function() end },
				} },
				{ Title = "Визуалы", Items = {
					{ Title = "ESP", Flag = "ESP", Default = true },
				} },
			},
		},
	})
end)
if not created or type(Window) ~= "table" then
	error("CreateWindow failed: " .. tostring(Window), 0)
end
if Window.IsMobile ~= false or Window.IsPC ~= true then
	error("platform detection did not mark the mock as PC", 0)
end
if not Window.OpenButtonMain then
	error("OpenButtonMain is missing", 0)
end

-- Tab + zero-safe slider
local Tab = Window:Tab({ Title = "Тест", Icon = "crosshair" })
local callbackCount = 0
local Slider = Tab:Slider({
	Title = "Нулевой слайдер",
	Value = { Min = 0, Max = 100, Default = 0 },
	Step = 1,
	Callback = function()
		callbackCount += 1
	end,
})
if Slider:GetValue() ~= 0 then
	error("slider with Default = 0 did not start at 0", 0)
end
Slider:Set(0)
if callbackCount < 1 then
	error("Slider:Set(0) did not fire its callback (the zero bug)", 0)
end
Slider:SetMin(0)
Slider:SetMax(0)
Slider:SetStep(0)
if Slider.Value.Max <= Slider.Value.Min then
	error("SetMax(0) produced a zero-length range", 0)
end

local ZeroRange = Tab:Slider({
	Title = "Min=0 Max=0 Step=0",
	Value = { Min = 0, Max = 0, Default = 0 },
	Step = 0,
})
if ZeroRange:GetValue() ~= 0 or ZeroRange.Value.Max <= ZeroRange.Value.Min then
	error("slider with Min = 0, Max = 0, Step = 0 is broken", 0)
end

-- Profile panel (Neverlose-style, bottom-left)
local Panel = Window.ProfilePanel
if not Panel then
	error("Profile panel was not created from CreateWindow{ Profile = ... }", 0)
end
if Panel:GetValue("ESP") ~= true then
	error("profile default value is wrong", 0)
end
Panel:SetValue("Aimbot", true)
Panel:AddItem("Комбат", { Title = "Триггербот", Flag = "TriggerBot", Default = false })
local values = Panel:GetValues()
if values.Aimbot ~= true or values.ESP ~= true then
	error("profile values are not readable", 0)
end
Panel:Open()
Panel:Close()
Panel:GetSection("Визуалы"):Toggle()

-- Open/close button on PC: Toggle() must show the button after closing.
Window:Toggle() -- close
if not Window.OpenButtonMain:ShouldShow() then
	error("open button is hidden after closing on PC", 0)
end
Window:Toggle() -- open
if Window.OpenButtonMain.StayVisible then
	error("StayVisible should be false by default", 0)
end
Window:EditOpenButton({ StayVisible = true, OnlyMobile = false })
if not Window.OpenButtonMain.StayVisible then
	error("EditOpenButton({ StayVisible = true }) did not apply", 0)
end
Window:SetToggleKey("F5")
Window:SetOpenButtonEnabled(true)

----------------------------------------------------------------------
-- New rework features: settings panel, RU/EN, themes, loading, guards
----------------------------------------------------------------------
-- Bug 2: CreateWindow must never build a second window.
local Again = WindUI:CreateWindow({ Title = "Second" })
if Again ~= Window then
	error("CreateWindow created a second window", 0)
end

if WindUI.LoadingScreen == nil or WindUI.LoadingScreen.Enabled ~= true then
	error("Loading = { Enabled = true } did not create a loading screen", 0)
end
if WindUI.DisplayOrders.Loading <= WindUI.DisplayOrders.Dropdown then
	error("DisplayOrder layering is wrong", 0)
end
if WindUI.ScreenGui.DisplayOrder ~= WindUI.DisplayOrders.Window then
	error("Window ScreenGui DisplayOrder was not applied", 0)
end
WindUI:SetDisplayOrder("Window", 12)
if WindUI.ScreenGui.DisplayOrder ~= 12 then
	error("SetDisplayOrder did not apply", 0)
end

-- Settings section in the profile panel
local SettingsSection = Panel:GetSection("Настройки")
if not SettingsSection then
	error("profile panel has no settings section", 0)
end
if not Panel:GetItem("ReworkLanguage") or not Panel:GetItem("ReworkTheme") then
	error("RU/EN language or Dark/Light theme row is missing", 0)
end
if not Panel:GetItem("ReworkLoading") or not Panel:GetItem("ReworkAutoLoad") then
	error("loading / autoload toggle is missing", 0)
end

-- Switching language from the UI (not from code)
Panel:SetValue("ReworkLanguage", "en")
if WindUI:GetLanguage() ~= "en" then
	error("language row did not switch the library to EN", 0)
end
if Panel:GetValue("ReworkLanguage") ~= "en" then
	error("language row value was not stored", 0)
end
WindUI:SetLanguage("ru")
if WindUI:GetLanguage() ~= "ru" then
	error("WindUI:SetLanguage('ru') failed", 0)
end

-- Switching theme from the UI
Panel:SetValue("ReworkTheme", "Light")
if WindUI:GetCurrentTheme() ~= "Light" then
	error("theme row did not switch to Light", 0)
end
WindUI:SetTheme("Dark")
if WindUI:GetCurrentTheme() ~= "Dark" then
	error("WindUI:SetTheme('Dark') failed", 0)
end

-- Loading can be disabled both from the UI and from code
Panel:SetValue("ReworkLoading", false)
if WindUI.LoadingScreen.Enabled ~= false then
	error("loading toggle did not disable the overlay", 0)
end
WindUI:SetLoadingEnabled(false)

-- Bug 4: locked slider must not keep an Active hit surface.
local LockedSlider = Tab:Slider({
	Title = "Locked",
	Value = { Min = 0, Max = 10, Default = 0 },
	Locked = true,
})
if LockedSlider.UIElements.SliderContainer.Active ~= false then
	error("locked slider still has Active = true", 0)
end
LockedSlider:Unlock()
if LockedSlider.UIElements.SliderContainer.Active ~= true then
	error("unlocked slider did not restore Active", 0)
end

-- Bug 3: options can be replaced at runtime.
local Dropdown = Tab:Dropdown({
	Title = "Options",
	Values = { "One", "Two" },
	Value = "One",
	Callback = function() end,
})
Dropdown:SetValues({ "Alpha", "Beta", "Gamma" })
if #Dropdown.Values ~= 3 then
	error("Dropdown:SetValues did not update Values", 0)
end

-- Bug 8: DisconnectAll must actually clear the connection list.
local before = #WindUI.Creator.Signals
WindUI.Creator.DisconnectAll()
if #WindUI.Creator.Signals ~= 0 then
	error("DisconnectAll leaked connections", 0)
end

print(string.format(
	"bundle_smoke: OK (WindUI v%s | window, zero sliders, profile panel, PC open button, settings RU/EN + themes + loading, guards)",
	tostring(WindUI.Version)
))
