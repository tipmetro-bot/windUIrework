--[[
    WindUI Rework / Slider
    ------------------------------------------------------------------
    Reworked version of Footagesus' elements/Slider.lua.

    Zero bug fixes:
      * `Min = 0`, `Default = 0`, `Max = 0` and `Step = 0` no longer break
        the element. Every value is normalised with `tonumber()` + explicit
        type checks, ranges are guarded (Max > Min, Step > 0) and all
        divisions go through a range that can never be zero.
      * `Slider:Set(0)` / config loading of `0` now always updates the UI
        and fires the callback (upstream skipped it because of
        `if Value ~= LastValue`).
      * snapping is relative to Min, and the result is always clamped to
        [Min, Max] (upstream could return values outside the range).
      * touch dragging uses InputChanged + pointer coordinates instead of
        a frozen `input.Position.X`, and release compares the input TYPE
        instead of the InputObject identity (which differs on phones and
        used to leave the slider stuck in "holding" state forever).
      * `SetMin(0)` / `SetMax(0)` are safe.

    Extra API: :GetValue(), :SetValue(), :SetStep(), :Refresh(), :SetMin(),
               :SetMax(), :Lock(), :Unlock(), :Set(), :Destroy()
    Config also accepts flat keys: Min / Max / Default (or Value = number).
]]

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local UserInputService = cloneref(game:GetService("UserInputService"))
local RunService = cloneref(game:GetService("RunService"))

local Creator = require("../modules/Creator")
local Animations = require("../modules/Animations")
local SliderMath = require("../modules/SliderMath")
local New = Creator.New

local Element = {}

-- Only one slider can be dragged at a time (mouse + multi-touch safety).
local IsSliderHolding = false

local ToNumber = SliderMath.ToNumber

function Element:New(Config)
	Config = Config or {}

	local Slider = {
		__type = "Slider",
		Title = Config.Title or nil,
		Desc = Config.Desc or nil,
		Locked = Config.Locked or nil,
		LockedTitle = Config.LockedTitle,
		Value = {},
		Icons = Config.Icons or nil,
		IsTooltip = Config.IsTooltip or false,
		IsTextbox = Config.IsTextbox,
		Callback = Config.Callback or function() end,
		UIElements = {},
		IsFocusing = false,

		Width = Config.Width or 130,
		TextBoxWidth = Config.Window.NewElements and 40 or 30,
		ThumbSize = 13,
		IconSize = 26,
	}

	------------------------------------------------------------------
	-- 1. Normalise numbers. `0` is a perfectly valid value everywhere.
	--    All the zero-safe math lives in the pure SliderMath module so it
	--    can be regression tested without Roblox (tests/slider_math_test.luau).
	------------------------------------------------------------------
	Slider.Value = SliderMath.Normalise(Config)
	Slider.Step = Slider.Value.Step

	local function GetRange()
		return SliderMath.Range(Slider.Value)
	end

	local function FormatValue(val)
		return SliderMath.Format(val, Slider.Value)
	end

	local function CalculateValue(rawValue)
		return SliderMath.Calculate(rawValue, Slider.Value)
	end

	local function GetDelta(val)
		return SliderMath.Delta(val, Slider.Value)
	end

	local Value = CalculateValue(Slider.Value.Default)
	local LastValue = Value
	Slider.Value.Default = FormatValue(Value)
	local delta = GetDelta(Value)

	if typeof(Slider.Icons) == "table" and not Slider.Icons.From and not Slider.Icons.To then
		Slider.Icons = nil -- `Icons = {}` used to be truthy but empty.
	end
	if Slider.IsTextbox == nil and Slider.Title == nil then
		Slider.IsTextbox = false
	else
		Slider.IsTextbox = Slider.IsTextbox ~= false
	end

	local SliderGroup = "slider_" .. tostring(Slider)
	local Holding = false
	local HasAppliedOnce = false
	local CanCallback = true
	local moveconnection, pointerconnection, releaseconnection
	local PointerX, ReleaseToken = nil, 0
	local Tooltip
	local isTouch = false

	------------------------------------------------------------------
	-- 2. UI (kept compatible with the original Element frame)
	------------------------------------------------------------------
	local IconFrom, IconTo
	local TotalSliderWidth = 32
	if Slider.Icons then
		if Slider.Icons.From then
			IconFrom = Creator.Image(
				Slider.Icons.From, Slider.Icons.From, 0, Config.Window.Folder,
				"SliderIconFrom", true, true, "SliderIconFrom"
			)
			IconFrom.Size = UDim2.new(0, Slider.IconSize, 0, Slider.IconSize)
			TotalSliderWidth = TotalSliderWidth + Slider.IconSize - 2
		end
		if Slider.Icons.To then
			IconTo = Creator.Image(
				Slider.Icons.To, Slider.Icons.To, 0, Config.Window.Folder,
				"SliderIconTo", true, true, "SliderIconTo"
			)
			IconTo.Size = UDim2.new(0, Slider.IconSize, 0, Slider.IconSize)
			TotalSliderWidth = TotalSliderWidth + Slider.IconSize - 2
		end
	end

	Slider.SliderFrame = require("../components/window/Element")({
		Title = Slider.Title,
		Desc = Slider.Desc,
		Parent = Config.Parent,
		TextOffset = Slider.Width,
		Hover = false,
		Tab = Config.Tab,
		Index = Config.Index,
		Window = Config.Window,
		ElementTable = Slider,
		ParentConfig = Config,
		Tags = Config.Tags,
	})

	local BaseThumbSize = UDim2.new(
		0,
		Config.Window.NewElements and (Slider.ThumbSize * 2) or (Slider.ThumbSize + 2),
		0,
		Config.Window.NewElements and (Slider.ThumbSize + 4) or (Slider.ThumbSize + 2)
	)
	local BigThumbSize = UDim2.new(
		0,
		(Config.Window.NewElements and (Slider.ThumbSize * 2) or Slider.ThumbSize) + 8,
		0,
		Slider.ThumbSize + 8
	)

	Slider.UIElements.SliderIcon = Creator.NewRoundFrame(99, "Squircle", {
		ImageTransparency = 0.95,
		Size = UDim2.new(1, not Slider.IsTextbox and -TotalSliderWidth or (-Slider.TextBoxWidth - 8), 0, 4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Name = "Frame",
		ThemeTag = {
			ImageColor3 = "Text",
		},
	}, {
		Creator.NewRoundFrame(99, "Squircle", {
			Name = "Frame",
			Size = UDim2.new(delta, 0, 1, 0),
			ImageTransparency = 0.1,
			ThemeTag = {
				ImageColor3 = "Slider",
			},
		}, {
			Creator.NewRoundFrame(99, "Squircle", {
				Size = BaseThumbSize,
				Position = UDim2.new(1, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ThemeTag = {
					ImageColor3 = "SliderThumb",
				},
				Name = "Thumb",
			}, {
				Creator.NewRoundFrame(999, "SquircleGlass", {
					Size = UDim2.new(1, 0, 1, 0),
					ImageColor3 = Color3.new(1, 1, 1),
					Name = "Highlight",
					ImageTransparency = 0.5,
				}),
			}),
		}),
	})

	Slider.UIElements.SliderContainer = New("Frame", {
		Size = UDim2.new(Slider.Title == nil and 1 or 0, Slider.Title == nil and 0 or Slider.Width, 0, 0),
		AutomaticSize = "Y",
		Position = UDim2.new(1, Slider.IsTextbox and (Config.Window.NewElements and -12 - 4 or 0) or 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Parent = Slider.SliderFrame.UIElements.Main,
		Name = "SliderContainer",
	}, {
		New("UIListLayout", {
			Padding = UDim.new(0, Slider.Title ~= nil and 8 or 12),
			FillDirection = "Horizontal",
			VerticalAlignment = "Center",
			HorizontalAlignment = "Center",
		}),
		IconFrom,
		Slider.UIElements.SliderIcon,
		IconTo,
		New("TextBox", {
			Size = UDim2.new(0, Slider.TextBoxWidth, 0, 0),
			TextXAlignment = "Left",
			Text = tostring(FormatValue(Value)),
			ThemeTag = {
				TextColor3 = "Text",
			},
			TextTransparency = 0.4,
			AutomaticSize = "Y",
			TextSize = 15,
			FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
			BackgroundTransparency = 1,
			LayoutOrder = -1,
			Visible = Slider.IsTextbox,
			Name = "TextBox",
		}),
	})

	local Thumb = Slider.UIElements.SliderIcon.Frame.Thumb
	local Fill = Slider.UIElements.SliderIcon.Frame
	local TextBox = Slider.UIElements.SliderContainer.TextBox

	if Slider.IsTooltip then
		local ok, result = pcall(function()
			return require("../components/ui/Tooltip").New(
				Value, Thumb, true, "Secondary", "Small", false
			)
		end)
		if ok and result then
			Tooltip = result
			Tooltip.Container.AnchorPoint = Vector2.new(0.5, 1)
			Tooltip.Container.Position = UDim2.new(0.5, 0, 0, -8)
		end
	end

	local function ScrollFrame()
		local tab = Config.Tab
		if tab and tab.UIElements and tab.UIElements.ContainerFrame
			and tab.UIElements.ContainerFrame:IsA("ScrollingFrame") then
			return tab.UIElements.ContainerFrame
		end
		return nil
	end

	------------------------------------------------------------------
	-- 3. Visual + callback helpers
	------------------------------------------------------------------
	local function UpdateVisual(newValue, time)
		local d = GetDelta(newValue)
		Animations:Play(Fill, time or "Fill", {
			Size = UDim2.new(d, 0, 1, 0),
		}, "Soft", "Out")
		local text = tostring(FormatValue(newValue))
		if TextBox then
			TextBox.Text = text
		end
		if Tooltip then
			pcall(function()
				Tooltip.TitleFrame.Text = text
			end)
		end
		Slider.Value.Default = FormatValue(newValue)
	end

	local function ApplyValue(newValue, time, force, silent)
		local changed = (newValue ~= LastValue)
		if force or changed or not HasAppliedOnce then
			HasAppliedOnce = true
			Value = newValue
			LastValue = newValue
			UpdateVisual(newValue, time)
			if not silent then
				Creator.SafeCallback(Slider.Callback, FormatValue(newValue))
			end
		end
	end

	local function SetThumbSize(size, transparency)
		if not Thumb then
			return
		end
		Animations:Play(Thumb, "Hover", {
			Size = size,
			ImageTransparency = transparency or 0,
		}, "Pop", "Out")
	end

	------------------------------------------------------------------
	-- 4. Pointer handling (works for mouse, touch and stylus)
	------------------------------------------------------------------
	local function ResolvePointerX(input)
		if isTouch and typeof(PointerX) == "number" then
			return PointerX
		end
		local ok, x = pcall(function()
			return UserInputService:GetMouseLocation().X
		end)
		if ok and typeof(x) == "number" and x > 0 then
			return x
		end
		if input and input.Position then
			return input.Position.X
		end
		return Slider.UIElements.SliderIcon.AbsolutePosition.X
	end

	local function ValueFromPointer(x)
		local bar = Slider.UIElements.SliderIcon
		local width = math.max(bar.AbsoluteSize.X, 1)
		local d = math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
		return CalculateValue(Slider.Value.Min + d * GetRange())
	end

	local function Release()
		if not Holding then
			return
		end
		Holding = false
		IsSliderHolding = false
		ReleaseToken = ReleaseToken + 1
		if moveconnection then moveconnection:Disconnect(); moveconnection = nil end
		if pointerconnection then pointerconnection:Disconnect(); pointerconnection = nil end
		if releaseconnection then releaseconnection:Disconnect(); releaseconnection = nil end
		local frame = ScrollFrame()
		if frame then
			frame.ScrollingEnabled = true
		end
		if Config.WindUI then
			Config.WindUI.CurrentInput = nil
		end
		SetThumbSize(BaseThumbSize, 0)
		PointerX = nil
		if Tooltip then
			pcall(function()
				Tooltip:Close(false)
			end)
		end
	end

	------------------------------------------------------------------
	-- 5. Public API
	------------------------------------------------------------------
	function Slider:Set(newValue, input, force, silent)
		if not CanCallback and not force then
			return Slider
		end
		if Slider.IsFocusing and not input and not force then
			return Slider
		end

		if input then
			if Holding or IsSliderHolding or Slider.Locked then
				return Slider
			end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return Slider
			end

			isTouch = (input.UserInputType == Enum.UserInputType.Touch)
			PointerX = input.Position and input.Position.X or nil
			Holding = true
			IsSliderHolding = true
			local frame = ScrollFrame()
			if frame then
				frame.ScrollingEnabled = false
			end
			SetThumbSize(BigThumbSize, 0.85)

			ApplyValue(ValueFromPointer(ResolvePointerX(input)), "Fill", true)

			pointerconnection = UserInputService.InputChanged:Connect(function(changed)
				if changed.UserInputType == input.UserInputType
					or changed == input then
					PointerX = changed.Position.X
				end
			end)

			moveconnection = RunService.RenderStepped:Connect(function()
				if not Holding then
					return
				end
				ApplyValue(ValueFromPointer(ResolvePointerX(input)), "Fill", false)
			end)

			local token = ReleaseToken + 1
			releaseconnection = UserInputService.InputEnded:Connect(function(endInput)
				-- Comparing the InputObject identity fails on touch devices;
				-- comparing the input type is reliable on PC and phones.
				if endInput == input
					or endInput.UserInputType == input.UserInputType then
					Release()
				end
			end)

			-- Failsafe: never leave every slider frozen if InputEnded is lost.
			task.delay(6, function()
				if Holding and token == ReleaseToken + 1 then
					Release()
				end
			end)
		else
			local value = CalculateValue(ToNumber(newValue, LastValue))
			-- Programmatic :Set() is always an explicit action: fire the
			-- callback even when the value is unchanged (this is the `Set(0)`
			-- case that upstream silently swallowed). `silent` is used by
			-- ConfigManager when applying saved values.
			ApplyValue(value, "Fast", true, silent == true)
		end
		return Slider
	end

	function Slider:SetValue(newValue)
		return Slider:Set(newValue, nil, true)
	end

	function Slider:GetValue()
		return FormatValue(LastValue)
	end

	function Slider:Refresh()
		UpdateVisual(LastValue, "Fast")
		return Slider
	end

	function Slider:SetMax(newMax)
		local max = ToNumber(newMax, Slider.Value.Max)
		if max <= Slider.Value.Min then
			max = Slider.Value.Min + 1
		end
		Slider.Value.Max = max
		if LastValue > max then
			Slider:Set(max, nil, true)
		else
			UpdateVisual(LastValue, "Fill")
		end
		return Slider
	end

	function Slider:SetMin(newMin)
		-- 0 is a valid minimum (the original bug was around this call).
		local min = ToNumber(newMin, Slider.Value.Min)
		if min >= Slider.Value.Max then
			min = Slider.Value.Max - 1
		end
		Slider.Value.Min = min
		if LastValue < min then
			Slider:Set(min, nil, true)
		else
			UpdateVisual(LastValue, "Fill")
		end
		return Slider
	end

	function Slider:SetStep(newStep)
		Slider.Step = SliderMath.SetStep(Slider.Value, newStep)
		Slider:Set(LastValue, nil, true)
		return Slider
	end

	-- Rework (bug 4): `Locked` alone is not enough. A transparent Frame
	-- with Active = true still receives InputBegan, so a locked slider
	-- could still be dragged. Toggle Active on every hit surface.
	local function SetActive(active)
		pcall(function()
			Slider.UIElements.SliderContainer.Active = active
		end)
		pcall(function()
			Slider.SliderFrame.UIElements.Main.Active = active
		end)
		pcall(function()
			Slider.UIElements.SliderIcon.Active = active
		end)
		if Slider.UIElements.SliderContainer.TextBox then
			pcall(function()
				Slider.UIElements.SliderContainer.TextBox.TextEditable = active
			end)
		end
	end

	function Slider:Lock()
		Slider.Locked = true
		CanCallback = false
		Release()
		SetActive(false)
		return Slider.SliderFrame:Lock(Slider.LockedTitle)
	end

	function Slider:Unlock()
		Slider.Locked = false
		CanCallback = true
		SetActive(true)
		return Slider.SliderFrame:Unlock()
	end

	function Slider:Destroy()
		Release()
		Creator.DisconnectGroup("slider_" .. tostring(Slider))
		if Slider.SliderFrame and Slider.SliderFrame.Destroy then
			pcall(function()
				Slider.SliderFrame:Destroy()
			end)
		end
	end

	if Slider.Locked then
		Slider:Lock()
	else
		SetActive(true)
	end

	------------------------------------------------------------------
	-- 6. Input
	------------------------------------------------------------------
	Creator.AddScopedSignal(SliderGroup, TextBox.Focused, function()
		Slider.IsFocusing = true
	end)
	Creator.AddScopedSignal(SliderGroup, TextBox.FocusLost, function()
		Slider.IsFocusing = false
		local newValue = ToNumber(TextBox.Text, nil)
		if newValue ~= nil then
			Slider:Set(newValue, nil, true)
		else
			TextBox.Text = tostring(FormatValue(LastValue))
			if Tooltip then
				pcall(function()
					Tooltip.TitleFrame.Text = tostring(FormatValue(LastValue))
				end)
			end
		end
	end)

	Creator.AddScopedSignal(SliderGroup, Slider.UIElements.SliderContainer.MouseEnter, function()
		if not Holding then
			SetThumbSize(BigThumbSize, 0)
		end
	end)
	Creator.AddScopedSignal(SliderGroup, Slider.UIElements.SliderContainer.MouseLeave, function()
		if not Holding then
			SetThumbSize(BaseThumbSize, 0)
		end
	end)

	local CurInput = Config.WindUI and Config.WindUI.GenerateGUID
		and Config.WindUI.GenerateGUID() or tostring(Slider)

	Creator.AddScopedSignal(SliderGroup, Slider.UIElements.SliderContainer.InputBegan, function(input)
		if Slider.Locked or Holding or IsSliderHolding then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			if Config.WindUI and Config.WindUI.CurrentInput
				and Config.WindUI.CurrentInput ~= CurInput then
				return
			end
			if Config.WindUI then
				Config.WindUI.CurrentInput = CurInput
			end
			Slider:Set(Value, input, false)
			if Tooltip then
				pcall(function()
					Tooltip:Open()
				end)
			end
		end
	end)

	return Slider.__type, Slider
end

return Element
