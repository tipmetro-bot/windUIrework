--[[
    WindUI Rework / LoadingScreen
    ------------------------------------------------------------------
    Optional, configurable loading overlay shown while the UI boots.

    Enable it from code (no UI code required):

        WindUI:CreateWindow({
            ...
            Loading = true,                  -- shorthand
            -- or
            Loading = {
                Enabled   = true,
                Duration  = 1.2,             -- seconds, 0 = no auto hide
                Title     = "My Hub",
                Subtitle  = "loc:rework.loading.status",
                AutoHide  = true,
                Steps     = { "Loading config…", "Building tabs…" },
            },
        })

    A `Loading` toggle in the profile panel settings can turn it on/off
    at runtime; `WindUI:SetLoadingEnabled(bool)` does the same from code.
    `Loading = false` (the default) creates nothing at all.
]]

local Creator = require("../../modules/Creator")
local Animations = require("../../modules/Animations")
local Localization = require("../../modules/ReworkLocalization")
local New = Creator.New

local LoadingScreen = {}

local function NormaliseConfig(value)
	if value == true then
		return { Enabled = true }
	end
	if typeof(value) == "table" then
		local copy = {}
		for key, item in pairs(value) do
			copy[key] = item
		end
		copy.Enabled = copy.Enabled ~= false
		return copy
	end
	return { Enabled = false }
end

function LoadingScreen.New(WindUI, value)
	local Config = NormaliseConfig(value)

	local Screen = {
		Enabled = Config.Enabled == true,
		Visible = false,
		Destroyed = false,
		Progress = 0,
		Duration = math.max(tonumber(Config.Duration) or 1.1, 0),
		AutoHide = Config.AutoHide ~= false,
		Steps = type(Config.Steps) == "table" and Config.Steps or nil,
	}

	if not Screen.Enabled then
		-- Fully inert: no ScreenGui, no connections, no task.delay.
		function Screen:SetProgress() return self end
		function Screen:SetStatus() return self end
		function Screen:Finish() return self end
		function Screen:Destroy() return self end
		function Screen:SetEnabled() return self end
		return Screen
	end

	local Parent = (WindUI and WindUI.GUIParent)
		or (WindUI and WindUI.ScreenGui and WindUI.ScreenGui.Parent)
		or nil

	local Gui = New("ScreenGui", {
		Name = "WindUI/Loading",
		Parent = Parent,
		IgnoreGuiInset = true,
		ScreenInsets = "None",
		ResetOnSpawn = false,
		ZIndexBehavior = "Sibling",
		DisplayOrder = (WindUI and WindUI.DisplayOrders and WindUI.DisplayOrders.Loading) or 100,
	})

	local Backdrop = New("Frame", {
		Name = "Backdrop",
		Parent = Gui,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromHex("#0A0A0C"),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 1,
	})

	local Card = New("Frame", {
		Name = "Card",
		Parent = Backdrop,
		Size = UDim2.new(0, 340, 0, 148),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromHex("#141418"),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 16) }),
		New("UIStroke", {
			Color = Color3.fromHex("#FFFFFF"),
			Transparency = 0.88,
			Thickness = 1,
		}),
	})

	local Title = New("TextLabel", {
		Name = "Title",
		Parent = Card,
		Size = UDim2.new(1, -40, 0, 30),
		Position = UDim2.new(0, 20, 0, 22),
		Text = tostring(Config.Title or Localization.Get("loading.title")),
		TextSize = 20,
		TextXAlignment = "Left",
		FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
	})

	local Status = New("TextLabel", {
		Name = "Status",
		Parent = Card,
		Size = UDim2.new(1, -40, 0, 20),
		Position = UDim2.new(0, 20, 0, 54),
		Text = tostring(Config.Subtitle or Localization.Get("loading.status")),
		TextSize = 13,
		TextXAlignment = "Left",
		TextTransparency = 0.45,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
	})

	local Track = New("Frame", {
		Name = "Track",
		Parent = Card,
		Size = UDim2.new(1, -40, 0, 6),
		Position = UDim2.new(0, 20, 1, -40),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})

	local Fill = New("Frame", {
		Name = "Fill",
		Parent = Track,
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Color3.fromHex("#0091FF"),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})

	local Percent = New("TextLabel", {
		Name = "Percent",
		Parent = Card,
		Size = UDim2.new(0, 60, 0, 18),
		Position = UDim2.new(1, -20, 1, -34),
		AnchorPoint = Vector2.new(1, 0),
		Text = "0%",
		TextSize = 12,
		TextXAlignment = "Right",
		TextTransparency = 0.4,
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
	})

	Screen.UIElements = { Gui = Gui, Card = Card, Title = Title, Status = Status }
	Screen.Visible = true

	function Screen:SetProgress(value, status)
		if self.Destroyed then
			return self
		end
		local progress = math.clamp(tonumber(value) or 0, 0, 1)
		self.Progress = progress
		Animations:Play(Fill, "Fast", { Size = UDim2.new(progress, 0, 1, 0) }, "Quint", "Out")
		Percent.Text = tostring(math.floor(progress * 100 + 0.5)) .. "%"
		if status ~= nil then
			Status.Text = tostring(status)
		end
		return self
	end

	function Screen:SetStatus(text)
		if not self.Destroyed then
			Status.Text = tostring(text)
		end
		return self
	end

	function Screen:Finish()
		if self.Destroyed or not self.Visible then
			return self
		end
		self:SetProgress(1, Localization.Get("loading.ready"))
		self.Visible = false
		Animations:Play(Backdrop, "Close", { BackgroundTransparency = 1 }, "Quint", "Out")
		Animations:Play(Card, "Close", { Size = UDim2.new(0, 300, 0, 130) }, "Quint", "InOut")
		task.delay(Animations:Get("Close") + 0.05, function()
			if Gui and Gui.Parent then
				Gui:Destroy()
			end
		end)
		return self
	end

	function Screen:Destroy()
		if self.Destroyed then
			return self
		end
		self.Destroyed = true
		self.Visible = false
		if Gui and Gui.Parent then
			Gui:Destroy()
		end
		return self
	end

	function Screen:SetEnabled(value)
		self.Enabled = value == true
		if not self.Enabled then
			self:Destroy()
		end
		return self
	end

	-- Auto progress: a handful of discrete steps, no infinite loops.
	if Screen.AutoHide and Screen.Duration > 0 then
		local steps = Screen.Steps
		local total = (steps and #steps > 0 and #steps) or 4
		for index = 1, total do
			local progress = index / total
			local label = steps and steps[index] or nil
			task.delay(Screen.Duration * (index / total), function()
				if Screen.Visible and not Screen.Destroyed then
					Screen:SetProgress(progress, label)
				end
			end)
		end
		task.delay(Screen.Duration + 0.1, function()
			if Screen.Visible and not Screen.Destroyed then
				Screen:Finish()
			end
		end)
	end

	return Screen
end

return LoadingScreen
