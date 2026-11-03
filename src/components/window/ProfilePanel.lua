--[[
    WindUI Rework / ProfilePanel
    ------------------------------------------------------------------
    A Neverlose-style profile/settings popup anchored in the BOTTOM-LEFT
    corner of the window, right above (and slightly overlapping) the user
    card that WindUI draws in the sidebar.

    Opened by clicking the profile card in the sidebar; also available as
    `Window.ProfilePanel:Open() / :Close() / :Toggle()`.
    Works with mouse, touch and gamepad (Activated + fallbacks).

    Default content (exactly the structure requested):
        КОМБАТ   -> Сайлент аим, Аимбот, Триггербот, Kill All
        ВИЗУАЛЫ  -> ESP, ESP Box, ESP Skeleton

    Values are stored through the WindUI ConfigManager API
    (`Window.ConfigManager:Config(name)` -> `ConfigModule:Register(flag, item)`
    -> `:Save()` / `:Load()`), so they survive script restarts when the
    executor has a filesystem. Without a filesystem everything is kept
    in memory.

    API:
        local Panel = Window:Profile({
            Config = "default",
            AutoLoad = true,
            AutoSave = false,
            Sections = { { Title = "Комбат", Items = { ... } }, ... },
        })
        Panel:Open() :Close() :Toggle() :Destroy()
        Panel:AddSection{...} :AddItem("Комбат", {...})
        Panel:SetValue("Aimbot", true) :GetValue("Aimbot") :GetValues()
        Panel:SetConfig("new") :SaveConfig() :LoadConfig() :GetConfigs()
]]

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local UserInputService = cloneref(game:GetService("UserInputService"))
local Players = cloneref(game:GetService("Players"))

local Creator = require("../../modules/Creator")
local Animations = require("../../modules/Animations")
local Localization = require("../../modules/ReworkLocalization")
local New = Creator.New

local ProfilePanel = {}
ProfilePanel.__index = ProfilePanel

local ON_COLOR = Color3.fromHex("33C759")
local OFF_COLOR = Color3.fromHex("52525B")
local ACCENT = Color3.fromHex("0091FF")

local DEFAULT_SECTIONS = {
	{
		Title = "Комбат",
		TitleKey = "combat",
		Icon = "crosshair",
		Items = {
			{ Title = "Сайлент аим", Flag = "SilentAim", TitleKey = "silentaim", Default = false },
			{ Title = "Аимбот", Flag = "Aimbot", TitleKey = "aimbot", Default = false },
			{ Title = "Триггербот", Flag = "TriggerBot", TitleKey = "triggerbot", Default = false },
			{ Title = "Kill All", Flag = "KillAll", TitleKey = "killall", Type = "Button" },
		},
	},
	{
		Title = "Визуалы",
		TitleKey = "visuals",
		Icon = "eye",
		Items = {
			{ Title = "ESP", Flag = "ESP", TitleKey = "esp", Default = false },
			{ Title = "ESP Box", Flag = "ESPBox", TitleKey = "espbox", Default = false },
			{ Title = "ESP Skeleton", Flag = "ESPSkeleton", TitleKey = "espskeleton", Default = false },
		},
	},
}

local function NormaliseBoolean(value, fallback)
	if typeof(value) == "boolean" then
		return value
	end
	if typeof(value) == "number" then
		return value ~= 0
	end
	if typeof(value) == "string" then
		local lower = string.lower(value)
		if lower == "true" or lower == "1" or lower == "on" then
			return true
		elseif lower == "false" or lower == "0" or lower == "off" or lower == "" then
			return false
		end
	end
	return fallback == true
end

-- Rework: "Choice" rows are a compact two/three-state selector used for
-- the RU/EN language switch and the Dark/Light theme switch.
local function NormaliseOptions(options)
	local result = {}
	for _, option in ipairs(options or {}) do
		if typeof(option) == "table" then
			result[#result + 1] = {
				Value = option.Value ~= nil and option.Value or (option.Label or option[1]),
				Label = option.Label,
				LabelKey = option.LabelKey,
			}
		else
			result[#result + 1] = { Value = option, Label = tostring(option) }
		end
	end
	return result
end

local function OptionLabel(option, language)
	if not option then
		return ""
	end
	if option.LabelKey then
		return Localization.Get(option.LabelKey, language)
	end
	return tostring(option.Label ~= nil and option.Label or option.Value)
end

--- WindUI ships many themes (Dark, Light, Rose, Plant, Red, Indigo, Sky,
--- Violet, Amber, Emerald, Midnight, Crimson, Monokai Pro, Cotton Candy,
--- Mellowsi, Rainbow). Build the list from the library itself instead of
--- hard-coding Dark/Light, so custom AddTheme() entries show up too.
local function ThemeKeyOf(WindUI, value)
	if not WindUI or not WindUI.GetThemes then
		return value
	end
	local themes = WindUI:GetThemes() or {}
	if themes[value] then
		return value
	end
	for key, theme in pairs(themes) do
		if type(theme) == "table" and (theme.Name == value or key == value) then
			return key
		end
	end
	return value
end

local function BuildThemeOptions(WindUI)
	local options = {}
	local themes = WindUI and WindUI.GetThemes and WindUI:GetThemes() or nil
	if type(themes) == "table" then
		local names = {}
		for key, theme in pairs(themes) do
			if type(theme) == "table" then
				names[#names + 1] = {
					Value = key,
					Label = tostring(theme.Name or key),
				}
			end
		end
		table.sort(names, function(a, b)
			-- Dark / Light first, then alphabetical.
			local rank = { Dark = 0, Light = 1 }
			local ra, rb = rank[a.Value] or 2, rank[b.Value] or 2
			if ra ~= rb then
				return ra < rb
			end
			return a.Label < b.Label
		end)
		for _, entry in ipairs(names) do
			options[#options + 1] = entry
		end
	end
	if #options == 0 then
		options = {
			{ Value = "Dark", LabelKey = "theme.dark" },
			{ Value = "Light", LabelKey = "theme.light" },
		}
	end
	return options
end

local function NormalizeText(value)
	return string.lower(tostring(value or ""))
end

-- A user-supplied section is usually written with the same Russian labels
-- as the built-in ones ("Комбат", "Аимбот", …). Inherit the known
-- translation keys so RU/EN switching also works for custom panels.
local SECTION_TITLE_KEYS = {}
local ITEM_TITLE_KEYS = {}
do
	local function remember(map, key, value)
		if key and value then
			map[NormalizeText(key)] = value
		end
	end
	for _, section in ipairs(DEFAULT_SECTIONS) do
		if section.TitleKey then
			remember(SECTION_TITLE_KEYS, section.Title, section.TitleKey)
			remember(SECTION_TITLE_KEYS, Localization.Get(section.TitleKey, "ru"), section.TitleKey)
			remember(SECTION_TITLE_KEYS, Localization.Get(section.TitleKey, "en"), section.TitleKey)
		end
		for _, item in ipairs(section.Items or {}) do
			if item.TitleKey then
				remember(ITEM_TITLE_KEYS, item.Title, item.TitleKey)
				remember(ITEM_TITLE_KEYS, Localization.Get(item.TitleKey, "ru"), item.TitleKey)
				remember(ITEM_TITLE_KEYS, Localization.Get(item.TitleKey, "en"), item.TitleKey)
			end
		end
	end
end

local function CopySections(sections)
	local result = {}
	for index, section in ipairs(sections or DEFAULT_SECTIONS) do
		-- Copy EVERY key (TitleKey in particular). Dropping it made the
		-- default Комбат / Визуалы sections stay Russian after RU -> EN.
		local copy = {}
		for key, value in next, section do
			if key ~= "Items" then
				copy[key] = value
			end
		end
		copy.Expanded = section.Expanded ~= false
		copy.Items = {}
		if not copy.TitleKey and copy.Title then
			copy.TitleKey = SECTION_TITLE_KEYS[NormalizeText(copy.Title)]
		end
		for itemIndex, item in ipairs(section.Items or {}) do
			local itemCopy = {}
			for key, value in next, item do
				itemCopy[key] = value
			end
			if not itemCopy.TitleKey and itemCopy.Title then
				itemCopy.TitleKey = ITEM_TITLE_KEYS[NormalizeText(itemCopy.Title)]
			end
			copy.Items[itemIndex] = itemCopy
		end
		result[index] = copy
	end
	return result
end

local function PositionWithOffset(position, offsetY)
	return UDim2.new(
		position.X.Scale,
		position.X.Offset,
		position.Y.Scale,
		position.Y.Offset + (offsetY or 0)
	)
end

local function IsInside(frame, x, y)
	if not frame then
		return false
	end
	local position, size = frame.AbsolutePosition, frame.AbsoluteSize
	return x >= position.X and x <= position.X + size.X
		and y >= position.Y and y <= position.Y + size.Y
end

local function GetUserThumbnail(anonymous)
	local ok, image = pcall(function()
		local player = Players.LocalPlayer
		if not player then
			return ""
		end
		local id, _ = Players:GetUserThumbnailAsync(
			anonymous and 1 or player.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size420x420
		)
		return id
	end)
	return (ok and image) or ""
end

----------------------------------------------------------------------
-- Constructor
----------------------------------------------------------------------
function ProfilePanel.New(Window, Config, WindUI)
	Config = Config or {}
	local self = setmetatable({}, ProfilePanel)
	-- Stable reference for nested closures (Item:Set has its own `self`).
	local Panel = self

	self.Window = Window
	self.WindUI = WindUI
	self.Config = Config
	self.Sections = {}
	self.Items = {}
	self.Values = {}
	self.Connections = {}
	self.Opened = false
	self.Destroyed = false
	self.OpenedAt = 0
	self.VisibilityToken = 0
	self.LastUserClick = 0
	self.StaggerHandle = nil

	local Parent = Window.UIElements and Window.UIElements.Main and Window.UIElements.Main.Main
	if not Parent then
		warn("[ WindUI.ProfilePanel ] Window main frame is not ready yet.")
		return self
	end

	-- Make sure the profile card in the bottom-left corner exists.
	if Window.User and Window.User.Enable and not Window.User.Enabled then
		pcall(function()
			Window.User:Enable()
		end)
	end
	local UserIcon = Window.UIElements.UserIcon

	------------------------------------------------------------------
	-- Geometry: bottom-left, overlapping the top of the profile card.
	------------------------------------------------------------------
	local Padding = Window.UIPadding or 14
	local Width = Config.Width or math.max((Window.SideBarWidth or 200) + 56, 268)
	local MaxHeight = (Window.Size and Window.Size.Y.Offset or 460) - (Window.Topbar.Height or 52) - 60
	local Height = math.clamp(Config.Height or 356, 220, math.max(220, MaxHeight))
	local Overlap = Config.Overlap == nil and 16 or Config.Overlap
	local BottomOffset = (42 + Padding) + (Padding / 2) - Overlap
	local BasePosition = UDim2.new(0, Padding / 2, 1, -BottomOffset)

	local Holder = New("CanvasGroup", {
		Name = "ProfilePanel",
		Parent = Parent,
		Size = UDim2.new(0, Width, 0, Height),
		Position = PositionWithOffset(BasePosition, 20),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Active = true,
		ZIndex = 200,
	})

	local UIScale = New("UIScale", {
		Scale = 1,
		Parent = Holder,
		Name = "ProfilePanelScale",
	})

	local Shadow = Creator.NewRoundFrame(Window.UICorner or 16, "Squircle", {
		Name = "Shadow",
		Parent = Holder,
		Size = UDim2.new(1, 18, 1, 18),
		Position = UDim2.new(0.5, 0, 0.5, 4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.72,
		ZIndex = 199,
	})

	local Background = Creator.NewRoundFrame(Window.UICorner or 16, "Squircle", {
		Name = "Background",
		Parent = Holder,
		Size = UDim2.new(1, 0, 1, 0),
		ImageTransparency = 0.02,
		ZIndex = 200,
		ThemeTag = {
			ImageColor3 = "WindowBackground",
		},
	})

	local Outline = Creator.NewRoundFrame(Window.UICorner or 16, "SquircleOutline", {
		Name = "Outline",
		Parent = Holder,
		Size = UDim2.new(1, 0, 1, 0),
		ImageTransparency = 0.8,
		ZIndex = 201,
		ThemeTag = {
			ImageColor3 = "Text",
		},
	})

	local Accent = New("Frame", {
		Name = "Accent",
		Parent = Holder,
		Size = UDim2.new(1, -24, 0, 2),
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = ACCENT,
		BackgroundTransparency = 0.25,
		ZIndex = 202,
	}, {
		New("UIGradient", {
			Color = ColorSequence.new(Color3.fromHex("40C9FF"), Color3.fromHex("E81CFF")),
		}),
	})

	------------------------------------------------------------------
	-- Header
	------------------------------------------------------------------
	local Header = New("Frame", {
		Name = "Header",
		Parent = Holder,
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundTransparency = 1,
		ZIndex = 202,
	}, {
		New("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 8),
		}),
	})

	local Avatar = New("ImageLabel", {
		Name = "Avatar",
		Parent = Header,
		Size = UDim2.new(0, 36, 0, 36),
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Image = GetUserThumbnail(Window.User and Window.User.Anonymous),
		BackgroundColor3 = Color3.fromHex("2A2A2C"),
		ZIndex = 203,
	}, {
		New("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
	})

	local DisplayName = (Players.LocalPlayer and Players.LocalPlayer.DisplayName) or "Player"
	if Window.User and Window.User.Anonymous then
		DisplayName = "Anonymous"
	end

	local NameLabel = New("TextLabel", {
		Name = "Name",
		Parent = Header,
		Position = UDim2.new(0, 58, 0, 12),
		Size = UDim2.new(1, -110, 0, 20),
		Text = DisplayName,
		TextSize = 15,
		TextXAlignment = "Left",
		BackgroundTransparency = 1,
		TextTruncate = "AtEnd",
		FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
		ZIndex = 203,
		ThemeTag = { TextColor3 = "Text" },
	})

	local Subtitle = New("TextLabel", {
		Name = "Subtitle",
		Parent = Header,
		Position = UDim2.new(0, 58, 0, 31),
		Size = UDim2.new(1, -110, 0, 16),
		Text = Config.Subtitle or Localization.Key("profile.subtitle"),
		TextSize = 12,
		TextTransparency = 0.45,
		TextXAlignment = "Left",
		BackgroundTransparency = 1,
		ZIndex = 203,
		ThemeTag = { TextColor3 = "Text" },
	})

	local CloseButton = New("TextButton", {
		Name = "CloseButton",
		Parent = Header,
		Size = UDim2.new(0, 30, 0, 30),
		Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Text = "×",
		TextSize = 20,
		BackgroundTransparency = 1,
		ZIndex = 204,
		ThemeTag = { TextColor3 = "Icon" },
	}, {
		Creator.NewRoundFrame(999, "Squircle", {
			Name = "Hover",
			Size = UDim2.new(1, 0, 1, 0),
			ImageTransparency = 1,
			ZIndex = 203,
			ThemeTag = { ImageColor3 = "Text" },
		}),
	})

	self.Connections[#self.Connections + 1] = Creator.AddSignal(CloseButton.Activated, function()
		self:Close()
	end)
	self.Connections[#self.Connections + 1] = Creator.AddSignal(CloseButton.MouseButton1Click, function()
		self:Close()
	end)
	self.Connections[#self.Connections + 1] = Creator.AddSignal(CloseButton.MouseEnter, function()
		Animations:Fade(CloseButton.Hover, 0.9, "Hover")
	end)
	self.Connections[#self.Connections + 1] = Creator.AddSignal(CloseButton.MouseLeave, function()
		Animations:Fade(CloseButton.Hover, 1, "Hover")
	end)

	------------------------------------------------------------------
	-- Config row (uses the ConfigManager API)
	------------------------------------------------------------------
	local ConfigRow = New("Frame", {
		Name = "ConfigRow",
		Parent = Holder,
		Size = UDim2.new(1, -24, 0, 38),
		Position = UDim2.new(0, 12, 0, 62),
		BackgroundTransparency = 1,
		ZIndex = 202,
	}, {
		Creator.NewRoundFrame(12, "Squircle", {
			Name = "Background",
			Size = UDim2.new(1, 0, 1, 0),
			ImageTransparency = 0.55,
			ZIndex = 202,
			ThemeTag = { ImageColor3 = "ElementBackground" },
		}),
		New("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 6),
		}),
	})

	local ConfigLabel = New("TextLabel", {
		Name = "ConfigLabel",
		Parent = ConfigRow,
		Size = UDim2.new(1, -140, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		Text = "Конфиг: " .. tostring(Config.Config or "default"),
		TextSize = 12,
		TextXAlignment = "Left",
		TextTruncate = "AtEnd",
		BackgroundTransparency = 1,
		ZIndex = 204,
		ThemeTag = { TextColor3 = "Text" },
	})

	local function CreateSmallButton(name, text, xOffset)
		local Button = New("TextButton", {
			Name = name,
			Parent = ConfigRow,
			Size = UDim2.new(0, 62, 0, 26),
			Position = UDim2.new(1, xOffset, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Text = text,
			TextSize = 11,
			BackgroundTransparency = 1,
			ZIndex = 205,
			ThemeTag = { TextColor3 = "Text" },
		}, {
			Creator.NewRoundFrame(9, "Squircle", {
				Name = "Background",
				Size = UDim2.new(1, 0, 1, 0),
				ImageTransparency = 0.35,
				ZIndex = 204,
				ThemeTag = { ImageColor3 = "Button" },
			}),
		})
		return Button
	end

	local SaveButton = CreateSmallButton("SaveButton", "Сохранить", -6)
	local LoadButton = CreateSmallButton("LoadButton", "Загрузить", -72)

	self.Connections[#self.Connections + 1] = Creator.AddSignal(SaveButton.Activated, function()
		self:SaveConfig()
	end)
	self.Connections[#self.Connections + 1] = Creator.AddSignal(SaveButton.MouseButton1Click, function()
		self:SaveConfig()
	end)
	self.Connections[#self.Connections + 1] = Creator.AddSignal(LoadButton.Activated, function()
		self:LoadConfig()
	end)
	self.Connections[#self.Connections + 1] = Creator.AddSignal(LoadButton.MouseButton1Click, function()
		self:LoadConfig()
	end)

	------------------------------------------------------------------
	-- Scrollable body
	------------------------------------------------------------------
	local Body = New("ScrollingFrame", {
		Name = "Body",
		Parent = Holder,
		Size = UDim2.new(1, -24, 1, -112),
		Position = UDim2.new(0, 12, 0, 108),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageTransparency = 0.6,
		ScrollingDirection = "Y",
		AutomaticCanvasSize = "Y",
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ZIndex = 202,
		Active = true,
	}, {
		New("UIListLayout", {
			Name = "Layout",
			Padding = UDim.new(0, 8),
			SortOrder = "LayoutOrder",
		}),
	})

	self.UIElements = {
		Holder = Holder,
		Body = Body,
		Header = Header,
		Background = Background,
		Outline = Outline,
		Shadow = Shadow,
		Avatar = Avatar,
		NameLabel = NameLabel,
		Subtitle = Subtitle,
		ConfigLabel = ConfigLabel,
		UIScale = UIScale,
		CloseButton = CloseButton,
	}
	self.BasePosition = BasePosition

	------------------------------------------------------------------
	-- ConfigManager hookup (API used instead of hand-rolled IO)
	------------------------------------------------------------------
	function self:SetConfig(name)
		name = name or Config.Config or "default"
		self.ConfigName = name
		if ConfigLabel then
			ConfigLabel.Text = "Конфиг: " .. tostring(name)
		end
		local manager = Window.ConfigManager
		if typeof(manager) ~= "table" then
			return false, "ConfigManager is unavailable (set Window.Folder and run in an executor)"
		end
		-- Reuse an existing config module instead of replacing the current
		-- one (tabs and the profile panel usually share `Config = "default"`).
		local existing = manager.Configs and manager.Configs[name]
		local module = existing
		if typeof(module) ~= "table" then
			local ok, created = pcall(function()
				return manager:Config(name, Config.AutoLoad == true)
			end)
			if not ok or typeof(created) ~= "table" then
				return false, "Failed to create config: " .. tostring(created)
			end
			module = created
		end
		self.ConfigModule = module
		pcall(function()
			module:SetAsCurrent()
		end)
		for _, item in ipairs(self.Items) do
			if item.Flag and item.__type ~= "Button" then
				pcall(function()
					module:Register(item.Flag, item)
				end)
			end
		end
		return module
	end

	function self:SaveConfig(name)
		if name then
			self:SetConfig(name)
		end
		if not self.ConfigModule then
			return false, "No config module (filesystem unavailable)"
		end
		local ok, result = pcall(function()
			return self.ConfigModule:Save()
		end)
		if WindUI and WindUI.Notify and ok then
			pcall(function()
				WindUI:Notify({
					Title = "Профиль",
					Content = "Конфиг «" .. tostring(self.ConfigName) .. "» сохранён",
					Icon = "check",
					Duration = 2.5,
				})
			end)
		end
		return ok, result
	end

	function self:LoadConfig(name)
		if name then
			self:SetConfig(name)
		end
		if not self.ConfigModule then
			return false, "No config module (filesystem unavailable)"
		end
		return pcall(function()
			return self.ConfigModule:Load()
		end)
	end

	function self:GetConfigs()
		if typeof(Window.ConfigManager) == "table" and Window.ConfigManager.AllConfigs then
			return Window.ConfigManager:AllConfigs()
		end
		return { self.ConfigName or "default" }
	end

	------------------------------------------------------------------
	-- Choice popup: a real scrollable list for selectors with many
	-- options (all WindUI themes). Two-option rows keep the one-tap
	-- toggle -- perfect for RU / EN.
	------------------------------------------------------------------
	local ChoicePopup = New("CanvasGroup", {
		Name = "ChoicePopup",
		Parent = Holder,
		Size = UDim2.new(0, 196, 0, 200),
		BackgroundTransparency = 1,
		GroupTransparency = 0,
		Visible = false,
		ZIndex = 260,
	}, {
		Creator.NewRoundFrame(10, "Squircle", {
			Name = "Background",
			Size = UDim2.new(1, 0, 1, 0),
			ImageTransparency = 0.02,
			ZIndex = 260,
			ThemeTag = { ImageColor3 = "WindowBackground" },
		}),
		Creator.NewRoundFrame(10, "SquircleOutline", {
			Name = "Outline",
			Size = UDim2.new(1, 0, 1, 0),
			ImageTransparency = 0.75,
			ZIndex = 261,
			ThemeTag = { ImageColor3 = "Text" },
		}),
	})

	local ChoiceList = New("ScrollingFrame", {
		Name = "List",
		Parent = ChoicePopup,
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.new(0, 4, 0, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageTransparency = 0.6,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ZIndex = 262,
	}, {
		New("UIListLayout", {
			Name = "Layout",
			Padding = UDim.new(0, 2),
			SortOrder = "LayoutOrder",
		}),
	})

	-- Exposed for tests / advanced users (and for outside-click handling).
	self.UIElements.ChoicePopup = ChoicePopup
	self.UIElements.ChoiceList = ChoiceList

	local ChoicePopupGroup = "ProfilePanelChoicePopup"
	local ChoicePopupItem = nil

	local function CloseChoicePopup()
		ChoicePopup.Visible = false
		ChoicePopupItem = nil
		Creator.DisconnectGroup(ChoicePopupGroup)
	end

	local function ShowChoicePopup(Item, Row)
		if ChoicePopupItem == Item and ChoicePopup.Visible then
			CloseChoicePopup()
			return
		end
		CloseChoicePopup()
		ChoicePopupItem = Item

		for _, child in ipairs(ChoiceList:GetChildren()) do
			if child.Name ~= "Layout" then
				pcall(function()
					child:Destroy()
				end)
			end
		end

		local rowHeight = 28
		for index, option in ipairs(Item.Options) do
			local OptionButton = New("TextButton", {
				Name = "Option" .. tostring(index),
				Parent = ChoiceList,
				Size = UDim2.new(1, -4, 0, rowHeight - 2),
				LayoutOrder = index,
				BackgroundTransparency = option.Value == Item.Value and 0.72 or 0.94,
				BackgroundColor3 = ACCENT,
				Text = OptionLabel(option, Localization.GetLanguage()),
				TextSize = 12,
				TextXAlignment = "Left",
				TextTruncate = "AtEnd",
				ZIndex = 263,
				ThemeTag = { TextColor3 = "Text" },
			}, {
				New("UIPadding", { PaddingLeft = UDim.new(0, 8) }),
				New("UICorner", { CornerRadius = UDim.new(0, 6) }),
			})
			local function Pick()
				Item:Set(option.Value, true)
				CloseChoicePopup()
			end
			Creator.AddScopedSignal(ChoicePopupGroup, OptionButton.Activated, Pick)
			Creator.AddScopedSignal(ChoicePopupGroup, OptionButton.MouseButton1Click, Pick)
		end

		ChoiceList.CanvasSize = UDim2.new(0, 0, 0, #Item.Options * rowHeight + 4)
		ChoicePopup.Size = UDim2.new(0, 196, 0, math.min(#Item.Options * rowHeight + 8, 232))

		local rowPos = Row.AbsolutePosition or { X = 0, Y = 0 }
		local holderPos = Holder.AbsolutePosition or { X = 0, Y = 0 }
		local holderWidth = (Holder.AbsoluteSize and Holder.AbsoluteSize.X) or 300
		local x = math.max(8, math.min(rowPos.X - holderPos.X, holderWidth - 204))
		local y = math.max(8, (rowPos.Y - holderPos.Y) - ChoicePopup.Size.Y.Offset / 2)
		ChoicePopup.Position = UDim2.new(0, x, 0, y)
		ChoicePopup.Visible = true
	end

	------------------------------------------------------------------
	-- Item row factory
	------------------------------------------------------------------
	local function CreateItem(Section, ItemConfig)
		local ItemType = ItemConfig.Type or "Toggle"
		local IsChoice = ItemType == "Choice"
		local Options = NormaliseOptions(ItemConfig.Options)
		local Row = New("TextButton", {
			Name = "Row",
			Parent = Section.Content,
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
			Text = "",
			Active = true,
			Selectable = true,
			ClipsDescendants = true,
			ZIndex = 204,
		}, {
			Creator.NewRoundFrame(10, "Squircle", {
				Name = "Background",
				Size = UDim2.new(1, 0, 1, 0),
				ImageTransparency = 0.6,
				ZIndex = 204,
				ThemeTag = { ImageColor3 = "ElementBackground" },
			}),
		})

		local Label = New("TextLabel", {
			Name = "Title",
			Parent = Row,
			Size = UDim2.new(1, -62, 1, 0),
			Position = UDim2.new(0, 12, 0, 0),
			Text = ItemConfig.TitleKey and Localization.Key(ItemConfig.TitleKey)
				or (ItemConfig.Title or "Item"),
			TextSize = 13,
			TextXAlignment = "Left",
			TextTruncate = "AtEnd",
			TextTransparency = 0.1,
			BackgroundTransparency = 1,
			ZIndex = 205,
			ThemeTag = { TextColor3 = "Text" },
		})

		local Pill, Knob, Arrow, ValueLabel
		if IsChoice then
			ValueLabel = New("TextLabel", {
				Name = "Value",
				Parent = Row,
				Size = UDim2.new(0, 96, 1, 0),
				Position = UDim2.new(1, -12, 0, 0),
				AnchorPoint = Vector2.new(1, 0),
				Text = "",
				TextSize = 12,
				TextXAlignment = "Right",
				TextTruncate = "AtEnd",
				TextTransparency = 0.15,
				BackgroundTransparency = 1,
				ZIndex = 205,
				ThemeTag = { TextColor3 = "Icon" },
			})
			Label.Size = UDim2.new(1, -120, 1, 0)
		elseif ItemType == "Button" then
			Arrow = New("TextLabel", {
				Name = "Arrow",
				Parent = Row,
				Size = UDim2.new(0, 24, 1, 0),
				Position = UDim2.new(1, -8, 0, 0),
				AnchorPoint = Vector2.new(1, 0),
				Text = "›",
				TextSize = 20,
				TextTransparency = 0.35,
				BackgroundTransparency = 1,
				ZIndex = 205,
				ThemeTag = { TextColor3 = "Icon" },
			})
		else
			Pill = New("Frame", {
				Name = "Pill",
				Parent = Row,
				Size = UDim2.new(0, 34, 0, 20),
				Position = UDim2.new(1, -10, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = OFF_COLOR,
				ZIndex = 205,
			}, {
				New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			})
			Knob = New("Frame", {
				Name = "Knob",
				Parent = Pill,
				Size = UDim2.new(0, 14, 0, 14),
				Position = UDim2.new(0, 3, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ZIndex = 206,
			}, {
				New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			})
		end

		local Item = {
			__type = IsChoice and "Choice" or (ItemType == "Button" and "Button" or "Toggle"),
			Type = ItemType,
			Title = ItemConfig.Title or "Item",
			TitleKey = ItemConfig.TitleKey,
			Flag = ItemConfig.Flag,
			Options = Options,
			Value = IsChoice
				and (ItemConfig.Default ~= nil and ItemConfig.Default or (Options[1] and Options[1].Value))
				or NormaliseBoolean(ItemConfig.Default, false),
			Callback = ItemConfig.Callback,
			UIElements = {
				Row = Row,
				Background = Row.Background,
				Label = Label,
				Pill = Pill,
				Knob = Knob,
				Arrow = Arrow,
				ValueLabel = ValueLabel,
			},
		}

		local LastClick = 0
		local function OnClick()
			local now = os.clock()
			if now - LastClick < 0.25 then
				return
			end
			LastClick = now
			Animations:Play(Row.Background, "Fast", { ImageTransparency = 0.4 }, "Soft", "Out")
			Animations:Play(Row, "Fast", { Size = UDim2.new(1, -3, 0, 34) }, "Soft", "Out")
			task.delay(Animations:Get("Fast") + 0.01, function()
				if Row and Row.Parent then
					Animations:Play(Row.Background, "Hover", { ImageTransparency = 0.6 }, "Soft", "Out")
					Animations:Play(Row, "Hover", { Size = UDim2.new(1, 0, 0, 34) }, "Pop", "Out")
				end
			end)
			if IsChoice then
				if #Options > 2 then
					-- 3+ options (e.g. the full WindUI theme list):
					-- opening a list beats clicking 16 times to cycle.
					ShowChoicePopup(Item, Row)
					return
				end
				local index = 1
				for i, option in ipairs(Options) do
					if option.Value == Item.Value then
						index = i
						break
					end
				end
				if #Options > 0 then
					Item:Set(Options[(index % #Options) + 1].Value, true)
				end
			elseif ItemType == "Button" then
				Creator.SafeCallback(Item.Callback, true)
			else
				Item:Set(not Item.Value, true)
			end
		end

		self.Connections[#self.Connections + 1] = Creator.AddSignal(Row.Activated, OnClick)
		self.Connections[#self.Connections + 1] = Creator.AddSignal(Row.MouseButton1Click, OnClick)
		self.Connections[#self.Connections + 1] = Creator.AddSignal(Row.TouchTap, OnClick)
		self.Connections[#self.Connections + 1] = Creator.AddSignal(Row.MouseEnter, function()
			Animations:Play(Row.Background, "Hover", { ImageTransparency = 0.45 }, "Soft", "Out")
		end)
		self.Connections[#self.Connections + 1] = Creator.AddSignal(Row.MouseLeave, function()
			Animations:Play(Row.Background, "Hover", { ImageTransparency = 0.6 }, "Soft", "Out")
		end)

		function Item:Set(value, fireCallback)
			if Item.Type == "Button" then
				if fireCallback ~= false then
					Creator.SafeCallback(Item.Callback, true)
				end
				return Item
			end
			if IsChoice then
				local wanted = value
				if Item.Flag == "ReworkLanguage" then
					wanted = Localization.Normalise(value) or wanted
				elseif Item.Flag == "ReworkTheme" then
					wanted = ThemeKeyOf(WindUI, value)
				end
				local index
				for i, option in ipairs(Options) do
					if option.Value == wanted then
						index = i
						break
					end
				end
				if not index then
					-- Unknown value: keep the current option instead of
					-- silently snapping back to the first one (the language
					-- row used to show RU while the library was EN).
					index = 1
					for i, option in ipairs(Options) do
						if option.Value == Item.Value then
							index = i
							break
						end
					end
				end
				local option = Options[index]
				if option then
					Item.Value = option.Value
					ValueLabel.Text = OptionLabel(option, Localization.GetLanguage())
				end
				if Item.Flag then
					Panel.Values[Item.Flag] = Item.Value
				end
				if fireCallback ~= false then
					Creator.SafeCallback(Item.Callback, Item.Value)
				end
				return Item
			end
			Item.Value = NormaliseBoolean(value, Item.Value)
			if Item.Flag then
				Panel.Values[Item.Flag] = Item.Value
			end
			if Knob then
				Animations:Play(Knob, "Fast", {
					Position = Item.Value and UDim2.new(0, 17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
				}, "Pop", "Out")
			end
			if Pill then
				Animations:Play(Pill, "Hover", {
					BackgroundColor3 = Item.Value and ON_COLOR or OFF_COLOR,
				}, "Soft", "Out")
			end
			if fireCallback ~= false then
				Creator.SafeCallback(Item.Callback, Item.Value)
			end
			return Item
		end

		function Item:Get()
			return Item.Value
		end

		if self.ConfigModule and Item.Flag and Item.__type ~= "Button" then
			pcall(function()
				self.ConfigModule:Register(Item.Flag, Item)
			end)
		end

		-- Apply the default (0 / false is a valid default here too).
		Item:Set(Item.Value, false)
		self.Items[#self.Items + 1] = Item
		if Item.Flag then
			self.Values[Item.Flag] = Item.Value
		end
		return Item
	end

	------------------------------------------------------------------
	-- Section factory
	------------------------------------------------------------------
	function self:AddSection(SectionConfig)
		if self.Destroyed or not self.UIElements then
			return nil
		end
		SectionConfig = SectionConfig or {}

		local Section = {
			Title = SectionConfig.Title or "Раздел",
			-- Keep the original name so GetSection("Комбат") keeps working
			-- after the UI is switched to English.
			OriginalTitle = SectionConfig.Title,
			TitleKey = SectionConfig.TitleKey,
			Expanded = SectionConfig.Expanded ~= false,
			ContentHeight = 0,
			Items = {},
		}

		local Wrapper = New("CanvasGroup", {
			Name = "Section",
			Parent = Body,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = "Y",
			BackgroundTransparency = 1,
			GroupTransparency = 0,
			LayoutOrder = #self.Sections + 1,
			ZIndex = 203,
		}, {
			New("UIListLayout", {
				Name = "Layout",
				Padding = UDim.new(0, 4),
				SortOrder = "LayoutOrder",
			}),
		})

		local SectionHeader = New("TextButton", {
			Name = "Header",
			Parent = Wrapper,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Text = "",
			LayoutOrder = 1,
			ZIndex = 204,
		}, {
			New("Frame", {
				Name = "Accent",
				Size = UDim2.new(0, 3, 0, 14),
				Position = UDim2.new(0, 2, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = ACCENT,
				ZIndex = 205,
			}, {
				New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
			New("TextLabel", {
				Name = "Title",
				Size = UDim2.new(1, -44, 1, 0),
				Position = UDim2.new(0, 14, 0, 0),
				Text = Section.TitleKey and Localization.Key(Section.TitleKey)
					or string.upper(Section.Title),
				TextSize = 12,
				TextXAlignment = "Left",
				TextTransparency = 0.2,
				BackgroundTransparency = 1,
				FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
				ZIndex = 205,
				ThemeTag = { TextColor3 = "Text" },
			}),
			New("TextLabel", {
				Name = "Chevron",
				Size = UDim2.new(0, 22, 0, 22),
				Position = UDim2.new(1, -4, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				Text = "⌄",
				TextSize = 16,
				TextTransparency = 0.35,
				BackgroundTransparency = 1,
				Rotation = 0,
				ZIndex = 205,
				ThemeTag = { TextColor3 = "Icon" },
			}),
		})

		local Content = New("Frame", {
			Name = "Content",
			Parent = Wrapper,
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			LayoutOrder = 2,
			ZIndex = 204,
		}, {
			New("UIListLayout", {
				Name = "Layout",
				Padding = UDim.new(0, 4),
				SortOrder = "LayoutOrder",
			}),
			New("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
			}),
		})

		Section.UIElements = {
			Wrapper = Wrapper,
			Header = SectionHeader,
			TitleLabel = SectionHeader.Title,
			Content = Content,
			Layout = Content.Layout,
		}

		local function RefreshHeight(animate)
			local height = math.max(Content.Layout.AbsoluteContentSize.Y + 2, 0)
			Section.ContentHeight = height
			local target = Section.Expanded and height or 0
			if animate then
				Animations:Play(Content, "Slide", {
					Size = UDim2.new(1, 0, 0, target),
				}, "Quint", "Out")
			else
				Content.Size = UDim2.new(1, 0, 0, target)
			end
		end

		self.Connections[#self.Connections + 1] = Creator.AddSignal(
			Content.Layout:GetPropertyChangedSignal("AbsoluteContentSize"),
			function()
				RefreshHeight(false)
			end
		)

		function Section:SetExpanded(value, animate)
			Section.Expanded = value == true
			RefreshHeight(animate ~= false)
			if SectionHeader.Chevron then
				Animations:Play(SectionHeader.Chevron, "Hover", {
					Rotation = Section.Expanded and 0 or 180,
				}, "Soft", "Out")
			end
			return Section
		end

		function Section:Toggle()
			return Section:SetExpanded(not Section.Expanded, true)
		end

		function Section:AddItem(ItemConfig)
			local item = CreateItem(Section, ItemConfig or {})
			Section.Items[#Section.Items + 1] = item
			RefreshHeight(false)
			return item
		end

		local LastHeaderClick = 0
		local function OnHeaderClick()
			local now = os.clock()
			if now - LastHeaderClick < 0.25 then
				return
			end
			LastHeaderClick = now
			Section:Toggle()
		end
		self.Connections[#self.Connections + 1] = Creator.AddSignal(SectionHeader.Activated, OnHeaderClick)
		self.Connections[#self.Connections + 1] = Creator.AddSignal(SectionHeader.MouseButton1Click, OnHeaderClick)
		self.Connections[#self.Connections + 1] = Creator.AddSignal(SectionHeader.TouchTap, OnHeaderClick)

		for _, itemConfig in ipairs(SectionConfig.Items or {}) do
			Section:AddItem(itemConfig)
		end
		Section:SetExpanded(Section.Expanded, false)

		self.Sections[#self.Sections + 1] = Section
		return Section
	end

	------------------------------------------------------------------
	-- Built-in settings (language, theme, loading, config autoload)
	-- Everything here is clickable in the UI: no code editing required.
	------------------------------------------------------------------
	function self:AddSettings()
		if self.SettingsAdded then
			return self.SettingsSection
		end
		self.SettingsAdded = true

		local WindUI = self.WindUI
		local Section = self:AddSection({
			Title = Localization.Get("settings"),
			TitleKey = "settings",
			Icon = "settings",
			Expanded = true,
		})

		Section:AddItem({
			Type = "Choice",
			Title = Localization.Get("language"),
			TitleKey = "language",
			Flag = "ReworkLanguage",
			Options = {
				{ Value = "ru", LabelKey = "language.ru" },
				{ Value = "en", LabelKey = "language.en" },
			},
			Default = Localization.GetLanguage(),
			Callback = function(value)
				Localization.SetLanguage(WindUI, value)
			end,
		})

		Section:AddItem({
			Type = "Choice",
			Title = Localization.Get("theme"),
			TitleKey = "theme",
			Flag = "ReworkTheme",
			-- Every theme shipped by WindUI (plus any AddTheme() entries).
			Options = BuildThemeOptions(WindUI),
			Default = ThemeKeyOf(WindUI, (WindUI.GetCurrentTheme and WindUI:GetCurrentTheme()) or "Dark"),
			Callback = function(value)
				if WindUI.SetTheme then
					WindUI:SetTheme(value)
				end
			end,
		})

		Section:AddItem({
			Type = "Toggle",
			Title = Localization.Get("loading"),
			TitleKey = "loading",
			Flag = "ReworkLoading",
			Default = WindUI.LoadingEnabled == true,
			Callback = function(value)
				if WindUI.SetLoadingEnabled then
					WindUI:SetLoadingEnabled(value)
				end
				if Window.Settings then
					Window.Settings.Loading = value
				end
			end,
		})

		Section:AddItem({
			Type = "Toggle",
			Title = Localization.Get("autoload"),
			TitleKey = "autoload",
			Flag = "ReworkAutoLoad",
			Default = Config.AutoLoad ~= false,
			Callback = function(value)
				Config.AutoLoad = value == true
				if self.ConfigModule and self.ConfigModule.SetAutoLoad then
					pcall(function()
						self.ConfigModule:SetAutoLoad(value)
					end)
				end
			end,
		})

		self.SettingsSection = Section
		return Section
	end

	function self:RefreshLanguage(language)
		local lang = Localization.Normalise(language) or Localization.GetLanguage()
		CloseChoicePopup()
		for _, section in ipairs(self.Sections) do
			if section.TitleKey then
				section.Title = Localization.Get(section.TitleKey, lang)
				local label = section.UIElements and section.UIElements.TitleLabel
				if label then
					label.Text = section.Title
					pcall(function()
						Creator:ChangeTranslationKey(label, Localization.Key(section.TitleKey))
					end)
				end
			end
		end
		for _, item in ipairs(self.Items) do
			if item.TitleKey and item.UIElements and item.UIElements.Label then
				item.Title = Localization.Get(item.TitleKey, lang)
				item.UIElements.Label.Text = item.Title
			end
			if item.Type == "Choice" then
				local wanted = item.Value
				if item.Flag == "ReworkLanguage" then
					-- The row must mirror the ACTUAL library language.
					-- WindUI:SetLanguage("ru") used to leave it on "en".
					wanted = lang
				elseif item.Flag == "ReworkTheme" then
					wanted = ThemeKeyOf(self.WindUI,
						(self.WindUI.GetCurrentTheme and self.WindUI:GetCurrentTheme()) or wanted)
				end
				item:Set(wanted, false)
			end
		end
		return self
	end

	self.LanguageUnsubscribe = Localization.OnChange(function(language)
		if not self.Destroyed then
			self:RefreshLanguage(language)
		end
	end)

	-- A theme changed from code (WindUI:SetTheme / Creator.SetTheme) must
	-- be reflected in the panel row, and clicking the row must not recurse.
	local function SyncTheme(value)
		if self.Destroyed then
			return
		end
		local item = self:GetItem("ReworkTheme")
		if item then
			item:Set(ThemeKeyOf(self.WindUI, value), false)
		end
	end

	if WindUI and WindUI.OnThemeChange then
		self.ThemeUnsubscribe = WindUI:OnThemeChange(SyncTheme)
	end
	if WindUI and WindUI.Creator and WindUI.Creator.OnThemeChange then
		self.CreatorThemeConnection = WindUI.Creator:OnThemeChange(function(theme)
			SyncTheme(theme and theme.Name or (WindUI.GetCurrentTheme and WindUI:GetCurrentTheme()))
		end)
	end

	-- Public convenience API (the UI rows call these too).
	function self:SetLanguage(language)
		return Localization.SetLanguage(self.WindUI, language)
	end

	function self:SetTheme(name)
		if self.WindUI.SetTheme then
			self.WindUI:SetTheme(name)
		end
		return self
	end

	function self:SetLoadingEnabled(value)
		if self.WindUI.SetLoadingEnabled then
			self.WindUI:SetLoadingEnabled(value)
		end
		return self
	end

	------------------------------------------------------------------
	-- Generic value helpers
	------------------------------------------------------------------
	function self:GetSection(name)
		local wanted = string.lower(tostring(name))
		local function matches(value)
			return value ~= nil and string.lower(tostring(value)) == wanted
		end
		for _, section in ipairs(self.Sections) do
			-- Language-independent: works with "Комбат", "Combat" and
			-- "combat" regardless of the currently selected language.
			if matches(section.Title) or matches(section.OriginalTitle) or matches(section.TitleKey) then
				return section
			end
			if section.TitleKey then
				if matches(Localization.Get(section.TitleKey, "ru"))
					or matches(Localization.Get(section.TitleKey, "en")) then
					return section
				end
			end
		end
		return nil
	end

	function self:AddItem(sectionOrName, ItemConfig)
		local section = typeof(sectionOrName) == "table" and sectionOrName
			or self:GetSection(tostring(sectionOrName))
		if not section then
			section = self:AddSection({ Title = tostring(sectionOrName) })
		end
		return section and section:AddItem(ItemConfig or {}) or nil
	end

	function self:GetItem(flag)
		for _, item in ipairs(self.Items) do
			if item.Flag == flag or item.Title == flag then
				return item
			end
		end
		return nil
	end

	function self:SetValue(flag, value)
		local item = self:GetItem(flag)
		if item then
			return item:Set(value, true)
		end
		return nil
	end

	function self:GetValue(flag)
		local item = self:GetItem(flag)
		return item and item.Value or nil
	end

	function self:GetValues()
		local values = {}
		for _, item in ipairs(self.Items) do
			if item.Type ~= "Button" then
				values[item.Flag or item.Title] = item.Value
			end
		end
		return values
	end

	function self:SetTitle(text)
		if NameLabel and text then
			NameLabel.Text = tostring(text)
		end
		return self
	end

	function self:SetSubtitle(text)
		if Subtitle and text then
			Subtitle.Text = tostring(text)
		end
		return self
	end

	------------------------------------------------------------------
	-- Open / close (smooth slide + fade + spring scale + stagger)
	------------------------------------------------------------------
	function self:Open()
		if self.Destroyed or self.Opened or not Holder then
			return self
		end
		self.Opened = true
		self.OpenedAt = os.clock()
		self.VisibilityToken = self.VisibilityToken + 1
		Holder.Visible = true
		Holder.GroupTransparency = 1
		Holder.Position = PositionWithOffset(BasePosition, 22)
		UIScale.Scale = 0.96

		Animations:Play(Holder, "Slide", {
			GroupTransparency = 0,
			Position = BasePosition,
		}, "Quint", "Out")
		Animations:Pop(UIScale, { Scale = 1 }, "Slide")

		if self.StaggerHandle then
			self.StaggerHandle:Cancel()
		end
		local wrappers = {}
		for _, section in ipairs(self.Sections) do
			if section.UIElements.Wrapper then
				section.UIElements.Wrapper.GroupTransparency = 1
				wrappers[#wrappers + 1] = section.UIElements.Wrapper
			end
		end
		self.StaggerHandle = Animations:Stagger(wrappers, 0.045, "Fast", {
			GroupTransparency = 0,
		}, "Soft", "Out")

		if Config.OnOpen then
			Creator.SafeCallback(Config.OnOpen, self)
		end
		return self
	end

	function self:Close()
		if self.Destroyed or not self.Opened or not Holder then
			return self
		end
		self.Opened = false
		self.VisibilityToken = self.VisibilityToken + 1
		local token = self.VisibilityToken
		if self.StaggerHandle then
			self.StaggerHandle:Cancel()
		end

		Animations:Play(Holder, "Close", {
			GroupTransparency = 1,
			Position = PositionWithOffset(BasePosition, 22),
		}, "Quint", "InOut")
		Animations:Play(UIScale, "Close", { Scale = 0.96 }, "Quint", "InOut")

		task.delay(Animations:Get("Close") + 0.03, function()
			if token == self.VisibilityToken and not self.Opened and not self.Destroyed then
				Holder.Visible = false
			end
		end)
		if Config.OnClose then
			Creator.SafeCallback(Config.OnClose, self)
		end
		return self
	end

	function self:Toggle()
		if self.Opened then
			return self:Close()
		end
		return self:Open()
	end

	function self:IsOpen()
		return self.Opened
	end

	function self:Destroy()
		if self.Destroyed then
			return
		end
		self.Destroyed = true
		self.Opened = false
		if self.LanguageUnsubscribe then
			pcall(self.LanguageUnsubscribe)
			self.LanguageUnsubscribe = nil
		end
		if self.ThemeUnsubscribe then
			pcall(self.ThemeUnsubscribe)
			self.ThemeUnsubscribe = nil
		end
		if self.CreatorThemeConnection then
			pcall(function()
				self.CreatorThemeConnection:Disconnect()
			end)
			self.CreatorThemeConnection = nil
		end
		CloseChoicePopup()
		if self.StaggerHandle then
			self.StaggerHandle:Cancel()
		end
		for _, connection in ipairs(self.Connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		if Holder then
			Holder:Destroy()
		end
		if Window.ProfilePanel == self then
			Window.ProfilePanel = nil
		end
	end

	------------------------------------------------------------------
	-- Wiring: profile card click, outside click, Escape
	------------------------------------------------------------------
	local function ToggleFromUserCard()
		local now = os.clock()
		if now - self.LastUserClick < 0.3 then
			return
		end
		self.LastUserClick = now
		if Config.OnUserClick then
			Creator.SafeCallback(Config.OnUserClick, self)
		end
		self:Toggle()
	end

	if UserIcon then
		self.Connections[#self.Connections + 1] = Creator.AddSignal(UserIcon.Activated, ToggleFromUserCard)
		self.Connections[#self.Connections + 1] = Creator.AddSignal(UserIcon.MouseButton1Click, ToggleFromUserCard)
		self.Connections[#self.Connections + 1] = Creator.AddSignal(UserIcon.TouchTap, ToggleFromUserCard)
	end

	self.Connections[#self.Connections + 1] = Creator.AddSignal(UserInputService.InputBegan, function(input)
		if not self.Opened or self.Destroyed then
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Escape then
				self:Close()
			end
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if os.clock() - self.OpenedAt < 0.25 then
			return
		end
		local position = input.Position
		if ChoicePopup.Visible and IsInside(ChoicePopup, position.X, position.Y) then
			return
		end
		if ChoicePopup.Visible then
			CloseChoicePopup()
			return
		end
		if not IsInside(Holder, position.X, position.Y)
			and not IsInside(UserIcon, position.X, position.Y) then
			self:Close()
		end
	end)

	------------------------------------------------------------------
	-- Build sections and config
	------------------------------------------------------------------
	self:SetConfig(Config.Config or "default")
	for _, sectionConfig in ipairs(CopySections(Config.Sections)) do
		self:AddSection(sectionConfig)
	end
	if Config.AutoLoad ~= false and self.ConfigModule then
		task.spawn(function()
			task.wait(0.35)
			if not self.Destroyed then
				pcall(function()
					self.ConfigModule:Load()
				end)
			end
		end)
	end
	if Config.OpenByDefault then
		task.defer(function()
			self:Open()
		end)
	end

	Window.ProfilePanel = self
	return self
end

return ProfilePanel
