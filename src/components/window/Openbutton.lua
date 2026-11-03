--[[
    WindUI Rework / OpenButton
    ------------------------------------------------------------------
    Reworked version of Footagesus' Openbutton.lua.

    Fixed:
      * the button is now available on PC **and** on phones/tablets
        (upstream only showed it when `not Window.IsPC`);
      * activation uses `Activated` (mouse + touch + gamepad) with a
        MouseButton1Click / TouchTap fallback and a debounce, so a tap
        on a phone can no longer be ignored or fired twice;
      * `Edit()` no longer corrupts `Window.IsPC`, handles Draggable=true,
        nil-safety, OnlyIcon, Enabled=false and a custom Position;
      * show/hide is animated (fade + slide + spring scale) and supports
        `StayVisible`, which turns the button into a real open/close
        toggle that stays on screen while the window is open.

    New config keys for `Window:EditOpenButton{...}`:
      Enabled      = true  | show the button at all
      OnlyMobile   = false | set true to show it only on touch devices
      StayVisible  = false | keep visible while the window is open
      Draggable    = true  | allow moving the button
      ShowOnPC     = true  | alias for OnlyMobile=false
]]

local Creator = require("../../modules/Creator")
local Animations = require("../../modules/Animations")
local Localization = require("../../modules/ReworkLocalization")
local New = Creator.New

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)
local UserInputService = cloneref(game:GetService("UserInputService"))

local OpenButton = {}

function OpenButton.New(Window)
	local OpenButtonMain = {
		Button = nil,
		Enabled = true,
		OnlyMobile = false,
		StayVisible = false,
		Draggable = true,
		VisibleState = false,
		WindowClosed = false,
		DefaultTitle = Window.Title or "WindUI",
		CustomTitle = nil,
		Destroyed = false,
	}

	local Icon
	local DragModule
	local PulseHandle
	local VisibilityToken = 0
	local LastActivation = 0

	local IsTouchDevice = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
		or (UserInputService.TouchEnabled and not UserInputService.MouseEnabled)

	-- Slightly bigger hit area on phones (Apple/Google HIG recommend 44+ px).
	local ButtonHeight = IsTouchDevice and 48 or 44

	local Title = New("TextLabel", {
		Text = Window.Title or "WindUI",
		TextSize = 17,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
		BackgroundTransparency = 1,
		AutomaticSize = "XY",
		Name = "Title",
		ThemeTag = {
			TextColor3 = "Text",
		},
	})

	local DragIconData = Creator.Icon("move")
	local Drag = New("Frame", {
		Size = UDim2.new(0, ButtonHeight - 8, 0, ButtonHeight - 8),
		BackgroundTransparency = 1,
		Name = "Drag",
		Active = true,
	}, {
		New("ImageLabel", {
			Image = DragIconData and DragIconData[1],
			ImageRectOffset = DragIconData and DragIconData[2] and DragIconData[2].ImageRectPosition,
			ImageRectSize = DragIconData and DragIconData[2] and DragIconData[2].ImageRectSize,
			Size = UDim2.new(0, 18, 0, 18),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ThemeTag = {
				ImageColor3 = "Icon",
			},
			ImageTransparency = 0.3,
			Name = "DragIcon",
		}),
	})

	local Divider = New("Frame", {
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(0, 20 + 16, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.9,
		Name = "Divider",
	})

	-- CanvasGroup lets us fade the whole button (including the icon) at once.
	local BasePosition = UDim2.new(0.5, 0, 0, 6 + ButtonHeight / 2)
	local Container = New("CanvasGroup", {
		Size = UDim2.new(0, 0, 0, 0),
		Position = BasePosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = Window.Parent,
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Active = true,
		Visible = false,
		Name = "OpenButtonContainer",
		ZIndex = 100,
	})

	local UIScale = New("UIScale", {
		Scale = 1,
		Name = "OpenButtonScale",
	})

	local TextButton = New("TextButton", {
		AutomaticSize = "XY",
		Active = true,
		Selectable = true,
		ClipsDescendants = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, ButtonHeight - 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		Name = "TextButton",
		ZIndex = 102,
	}, {
		New("UICorner", {
			CornerRadius = UDim.new(1, -4),
		}),
		New("UIListLayout", {
			Padding = UDim.new(0, Window.UIPadding or 14),
			FillDirection = "Horizontal",
			VerticalAlignment = "Center",
		}),
		Title,
		New("UIPadding", {
			PaddingLeft = UDim.new(0, 7 + 4),
			PaddingRight = UDim.new(0, 7 + 4),
		}),
	})

	local Button = New("Frame", {
		Size = UDim2.new(0, 0, 0, ButtonHeight),
		AutomaticSize = "X",
		Parent = Container,
		Active = true,
		BackgroundTransparency = 0.25,
		ZIndex = 101,
		BackgroundColor3 = Color3.new(0, 0, 0),
		Name = "Button",
	}, {
		UIScale,
		New("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
		New("UIStroke", {
			Thickness = 2,
			ApplyStrokeMode = "Border",
			Color = Color3.new(1, 1, 1),
			Transparency = 0,
			Name = "UIStroke",
		}, {
			New("UIGradient", {
				Color = ColorSequence.new(Color3.fromHex("40c9ff"), Color3.fromHex("e81cff")),
				Name = "UIGradient",
			}),
		}),
		Drag,
		Divider,
		New("UIListLayout", {
			Padding = UDim.new(0, 4),
			FillDirection = "Horizontal",
			VerticalAlignment = "Center",
		}),
		TextButton,
		New("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
		}),
	})

	OpenButtonMain.Button = Button
	-- Fallback size: AbsoluteSize can still be 0 while the CanvasGroup is
	-- hidden; the GetPropertyChangedSignal below keeps it exact afterwards.
	Container.Size = UDim2.new(0, 160, 0, ButtonHeight)
	OpenButtonMain.Container = Container
	OpenButtonMain.TextButton = TextButton
	OpenButtonMain.Title = Title
	OpenButtonMain.BasePosition = BasePosition

	------------------------------------------------------------------
	-- Icon
	------------------------------------------------------------------
	function OpenButtonMain:SetIcon(newIcon)
		if Icon and Icon.Parent then
			Icon:Destroy()
		end
		Icon = nil
		if newIcon then
			local ok, image = pcall(function()
				return Creator.Image(
					newIcon,
					Window.Title or "OpenButton",
					0,
					Window.Folder,
					"OpenButton",
					true,
					Window.IconThemed
				)
			end)
			if ok and image then
				Icon = image
				Icon.Size = UDim2.new(0, 22, 0, 22)
				Icon.LayoutOrder = -1
				Icon.Name = "Icon"
				Icon.Parent = TextButton
			end
		end
	end

	if Window.Icon then
		OpenButtonMain:SetIcon(Window.Icon)
	end

	------------------------------------------------------------------
	-- Ripple + press feedback (mouse, touch and gamepad)
	------------------------------------------------------------------
	local function PlayRipple()
		if not Animations.Enabled then
			return
		end
		local Ripple = New("Frame", {
			Size = UDim2.new(0, 0, 0, 0),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.72,
			ZIndex = 103,
			Parent = TextButton,
		}, {
			New("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		})
		Animations:Play(Ripple, "Slide", {
			Size = UDim2.new(1, 46, 1, 46),
			BackgroundTransparency = 1,
		}, "Soft", "Out")
		task.delay(Animations:Get("Slide") + 0.05, function()
			if Ripple and Ripple.Parent then
				Ripple:Destroy()
			end
		end)
	end

	local function Activate()
		local now = os.clock()
		if now - LastActivation < 0.3 then
			return
		end
		LastActivation = now

		Animations:Press(UIScale, 1, 0.93)
		PlayRipple()

		if OpenButtonMain.Callback then
			Creator.SafeCallback(OpenButtonMain.Callback)
		elseif Window.Toggle then
			-- A real open/close button: works the same on PC and phone.
			Window:Toggle()
		elseif Window.Open then
			Window:Open()
		end
	end

	-- `Activated` is the cross-platform event (MouseButton1, Touch, Gamepad).
	Creator.AddSignal(TextButton.Activated, Activate)
	-- Fallbacks for executors that do not synthesize `Activated` on touch.
	Creator.AddSignal(TextButton.MouseButton1Click, Activate)
	Creator.AddSignal(TextButton.TouchTap, Activate)

	Creator.AddSignal(TextButton.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			Animations:Play(UIScale, "Fast", { Scale = 0.96 }, "Soft", "Out")
		end
	end)
	Creator.AddSignal(TextButton.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			Animations:Pop(UIScale, { Scale = 1 }, "Fast")
		end
	end)
	Creator.AddSignal(TextButton.MouseEnter, function()
		Animations:Play(TextButton, "Hover", { BackgroundTransparency = 0.93 }, "Soft", "Out")
		Animations:Play(UIScale, "Hover", { Scale = 1.04 }, "Soft", "Out")
	end)
	Creator.AddSignal(TextButton.MouseLeave, function()
		Animations:Play(TextButton, "Hover", { BackgroundTransparency = 1 }, "Soft", "Out")
		Animations:Play(UIScale, "Hover", { Scale = 1 }, "Soft", "Out")
	end)

	Creator.AddSignal(Button:GetPropertyChangedSignal("AbsoluteSize"), function()
		Container.Size = UDim2.new(0, Button.AbsoluteSize.X, 0, Button.AbsoluteSize.Y)
	end)

	DragModule = Creator.Drag(Container, { Drag })

	------------------------------------------------------------------
	-- Visibility (animated, works on every platform)
	------------------------------------------------------------------
	local function PositionWithOffset(position, offsetY)
		return UDim2.new(
			position.X.Scale,
			position.X.Offset,
			position.Y.Scale,
			position.Y.Offset + (offsetY or 0)
		)
	end

	-- Rework: the button has an explicit open/closed state. Writing a raw
	-- `loc:rework.open` string into Title.Text used to display the key
	-- itself on the button, and switching language never updated it.
	-- Register the key through Creator so it resolves AND stays in sync.
	function OpenButtonMain:RefreshTitle()
		if self.Destroyed or not Title then
			return self
		end
		local key
		if self.StayVisible and self.WindowClosed and self.CustomTitle then
			-- A real toggle, but respect a user-supplied label for "open".
			Title.Text = self.CustomTitle
			pcall(function()
				Creator:ChangeTranslationKey(Title, self.CustomTitle)
			end)
			return self
		elseif self.StayVisible then
			key = self.WindowClosed and "open" or "close"
		elseif self.CustomTitle then
			Title.Text = self.CustomTitle
			pcall(function()
				Creator:ChangeTranslationKey(Title, self.CustomTitle)
			end)
			return self
		else
			key = "open"
		end
		Title.Text = Localization.Get(key)
		pcall(function()
			Creator:ChangeTranslationKey(Title, Localization.Key(key))
		end)
		return self
	end

	function OpenButtonMain:SetOpenState(windowClosed)
		local closed = windowClosed == true
		self.WindowClosed = closed
		-- Always refresh: StayVisible / language may have changed even when
		-- the window state did not.
		return self:RefreshTitle()
	end

	function OpenButtonMain:IsWindowOpen()
		return not self.WindowClosed
	end

	function OpenButtonMain:ShouldShow()
		if self.Destroyed or not self.Enabled or Window.Destroyed then
			return false
		end
		if self.OnlyMobile and Window.IsMobile == false then
			return false
		end
		if self.StayVisible then
			return true
		end
		return Window.Closed == true
	end

	function OpenButtonMain:Visible(value)
		if self.Destroyed then
			return self
		end
		if value == nil then
			value = self:ShouldShow()
		end
		VisibilityToken = VisibilityToken + 1
		local token = VisibilityToken

		if value == true then
			-- Rework: never replay the "appear" animation when the button is
			-- already on screen (Window:Open() used to call Visible(true)
			-- every time, making the button flash/teleport).
			if self.VisibleState and Container.Visible then
				return self
			end
			self.VisibleState = true
			Container.Size = UDim2.new(
				0, math.max(Button.AbsoluteSize.X, 120),
				0, (Button.AbsoluteSize.Y > 0 and Button.AbsoluteSize.Y) or ButtonHeight
			)
			Container.Visible = true
			Container.GroupTransparency = 1
			UIScale.Scale = (OpenButtonMain.BaseScale or 1) * 0.86
			Container.Position = PositionWithOffset(BasePosition, 16)

			Animations:Play(Container, "Slide", {
				GroupTransparency = 0,
				Position = BasePosition,
			}, "Quint", "Out")
			Animations:Pop(UIScale, { Scale = OpenButtonMain.BaseScale or 1 }, "Slide")

			if not PulseHandle and Animations.Enabled and Button.UIStroke then
				PulseHandle = Animations:Pulse(Button.UIStroke, "Transparency", 0.1, 0.45, 2.2)
			end
		else
			if not self.VisibleState and not Container.Visible then
				return self
			end
			self.VisibleState = false
			if PulseHandle then
				PulseHandle:Stop()
				PulseHandle = nil
			end
			if not Container.Visible then
				Container.GroupTransparency = 1
				return
			end
			Animations:Play(Container, "Close", {
				GroupTransparency = 1,
			}, "Quint", "InOut")
			Animations:Play(UIScale, "Close", {
				Scale = (OpenButtonMain.BaseScale or 1) * 0.9,
			}, "Quint", "InOut")
			task.delay(Animations:Get("Close") + 0.02, function()
				if token == VisibilityToken and not self:ShouldShow() and not self.VisibleState then
					Container.Visible = false
				end
			end)
		end
	end

	function OpenButtonMain:Refresh()
		return self:Visible(self:ShouldShow())
	end

	function OpenButtonMain:SetEnabled(value)
		self.Enabled = value ~= false
		if Window.SetOpenButtonEnabled then
			Window.IsOpenButtonEnabled = self.Enabled
		end
		return self:Refresh()
	end

	function OpenButtonMain:SetScale(scale)
		local n = tonumber(scale)
		self.BaseScale = (n and n > 0 and n) or 1
		UIScale.Scale = self.BaseScale
		return self
	end

	function OpenButtonMain:SetTitle(text)
		if Title and text then
			self.CustomTitle = tostring(text)
			Title.Text = self.CustomTitle
			pcall(function()
				Creator:ChangeTranslationKey(Title, self.CustomTitle)
			end)
			self:RefreshTitle()
		end
		return self
	end

	function OpenButtonMain:SetPosition(position)
		if typeof(position) == "UDim2" then
			BasePosition = position
			self.BasePosition = position
			Container.Position = position
		end
		return self
	end

	function OpenButtonMain:SetCallback(callback)
		self.Callback = callback
		return self
	end

	------------------------------------------------------------------
	-- Edit (fully nil-safe; no more `Window.IsPC = false` side effect)
	------------------------------------------------------------------
	function OpenButtonMain:Edit(OpenButtonConfig)
		OpenButtonConfig = OpenButtonConfig or {}
		local Module = {
			Title = OpenButtonConfig.Title,
			Icon = OpenButtonConfig.Icon,
			Enabled = OpenButtonConfig.Enabled,
			Position = OpenButtonConfig.Position,
			OnlyIcon = OpenButtonConfig.OnlyIcon,
			Draggable = OpenButtonConfig.Draggable,
			OnlyMobile = OpenButtonConfig.OnlyMobile,
			ShowOnPC = OpenButtonConfig.ShowOnPC,
			StayVisible = OpenButtonConfig.StayVisible,
			CornerRadius = OpenButtonConfig.CornerRadius or UDim.new(1, 0),
			StrokeThickness = OpenButtonConfig.StrokeThickness or 2,
			Scale = OpenButtonConfig.Scale or 1,
			Color = OpenButtonConfig.Color
				or ColorSequence.new(Color3.fromHex("40c9ff"), Color3.fromHex("e81cff")),
		}

		self.Enabled = Module.Enabled ~= false
		Window.IsOpenButtonEnabled = self.Enabled

		-- Backwards compatible: OnlyMobile = true keeps the old behaviour.
		if Module.OnlyMobile == true or Module.ShowOnPC == false then
			self.OnlyMobile = true
		else
			self.OnlyMobile = false
		end
		self.StayVisible = Module.StayVisible == true
		-- Refresh the label for the new StayVisible value.
		local wasClosed = self.WindowClosed
		self.WindowClosed = nil
		self:SetOpenState(wasClosed)

		if Module.Draggable ~= nil then
			self.Draggable = Module.Draggable == true
			Drag.Visible = self.Draggable
			Divider.Visible = self.Draggable
			if DragModule then
				DragModule:Set(self.Draggable)
			end
		end

		if typeof(Module.Position) == "UDim2" then
			self:SetPosition(Module.Position)
		end

		if Module.OnlyIcon == true then
			if not Icon and Window.Icon then
				self:SetIcon(Window.Icon)
			end
			if Icon then
				Title.Visible = false
				TextButton.UIPadding.PaddingLeft = UDim.new(0, 7)
				TextButton.UIPadding.PaddingRight = UDim.new(0, 7)
			else
				-- Without an icon an icon-only button would be empty.
				Title.Visible = true
			end
		elseif Module.OnlyIcon == false then
			Title.Visible = true
			TextButton.UIPadding.PaddingLeft = UDim.new(0, 7 + 4)
			TextButton.UIPadding.PaddingRight = UDim.new(0, 7 + 4)
		end

		if Module.Title ~= nil then
			self:SetTitle(Module.Title)
		end
		if Module.Icon ~= nil then
			self:SetIcon(Module.Icon)
		end

		if Button.UIStroke and Button.UIStroke.UIGradient then
			Button.UIStroke.UIGradient.Color = Module.Color
		end
		pcall(function()
			Button.UICorner.CornerRadius = Module.CornerRadius
			TextButton.UICorner.CornerRadius = UDim.new(
				Module.CornerRadius.Scale,
				Module.CornerRadius.Offset - 4
			)
			Button.UIStroke.Thickness = Module.StrokeThickness
		end)

		self:SetScale(Module.Scale)
		return self:Refresh()
	end

	------------------------------------------------------------------
	-- Keep the button in sync with the window state on resize / theme.
	------------------------------------------------------------------
	pcall(function()
		Creator.AddSignal(UserInputService.LastInputTypeChanged, function()
			-- A keyboard can be connected/disconnected on tablets at runtime.
			local isMobileNow = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
				or (UserInputService.TouchEnabled and not UserInputService.MouseEnabled)
			Window.IsMobile = isMobileNow
			Window.IsPC = not isMobileNow
			OpenButtonMain:Refresh()
		end)
	end)

	-- Keep the label in sync when the language is switched from the panel.
	OpenButtonMain.LanguageUnsubscribe = Localization.OnChange(function()
		if not OpenButtonMain.Destroyed then
			OpenButtonMain:RefreshTitle()
		end
	end)

	function OpenButtonMain:Destroy()
		if self.Destroyed then
			return
		end
		self.Destroyed = true
		if self.LanguageUnsubscribe then
			pcall(self.LanguageUnsubscribe)
			self.LanguageUnsubscribe = nil
		end
		if DragModule and DragModule.Destroy then
			pcall(function()
				DragModule:Destroy()
			end)
		end
		if Container and Container.Destroy then
			pcall(function()
				Container:Destroy()
			end)
		end
	end

	OpenButtonMain:SetScale(1)
	OpenButtonMain:RefreshTitle()
	return OpenButtonMain
end

return OpenButton
