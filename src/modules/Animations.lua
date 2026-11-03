--[[
    WindUI Rework / Animations
    ------------------------------------------------------------------
    Small, dependency-light animation helper used by every reworked
    component (window, open button, sliders and the profile panel).

    Goals:
      * one place for timing/easing (no random 0.04 / 0.9 tweens)
      * smooth Quint / Exponential / Back motion instead of linear jumps
      * a global "reduce motion" switch (`WindUI:SetAnimationProfile`)
      * helpers that are safe to call on any GuiObject, even if the
        property does not exist on that class (pcall guarded)
]]

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local TweenService = cloneref(game:GetService("TweenService"))

local Animations = {}
Animations.__index = Animations

Animations.Enabled = true
Animations.ProfileName = "Smooth"
Animations.Speed = 1

local Styles = {
	Linear = Enum.EasingStyle.Linear,
	Sine = Enum.EasingStyle.Sine,
	Quad = Enum.EasingStyle.Quad,
	Quart = Enum.EasingStyle.Quart,
	Quint = Enum.EasingStyle.Quint,
	Exponential = Enum.EasingStyle.Exponential,
	Back = Enum.EasingStyle.Back,
	Elastic = Enum.EasingStyle.Elastic,
	Bounce = Enum.EasingStyle.Bounce,
	Circular = Enum.EasingStyle.Circular,
}

local Directions = {
	In = Enum.EasingDirection.In,
	Out = Enum.EasingDirection.Out,
	InOut = Enum.EasingDirection.InOut,
}

-- Durations are multiplied by `Speed`. "None" is instant (accessibility).
local Profiles = {
	Smooth = {
		Multiplier = 1,
		Open = 0.55,
		Close = 0.38,
		Slide = 0.44,
		Hover = 0.18,
		Fast = 0.12,
		Fill = 0.14,
		Style = "Quint",
		SoftStyle = "Sine",
		PopStyle = "Back",
		Direction = "Out",
	},
	Snappy = {
		Multiplier = 0.72,
		Open = 0.42,
		Close = 0.28,
		Slide = 0.3,
		Hover = 0.12,
		Fast = 0.08,
		Fill = 0.08,
		Style = "Exponential",
		SoftStyle = "Quad",
		PopStyle = "Back",
		Direction = "Out",
	},
	Calm = {
		Multiplier = 1.35,
		Open = 0.7,
		Close = 0.5,
		Slide = 0.6,
		Hover = 0.24,
		Fast = 0.16,
		Fill = 0.2,
		Style = "Sine",
		SoftStyle = "Sine",
		PopStyle = "Quint",
		Direction = "InOut",
	},
	Reduced = {
		Multiplier = 0.4,
		Open = 0.2,
		Close = 0.15,
		Slide = 0.16,
		Hover = 0.06,
		Fast = 0.05,
		Fill = 0.05,
		Style = "Linear",
		SoftStyle = "Linear",
		PopStyle = "Linear",
		Direction = "Out",
	},
	None = {
		Multiplier = 0,
		Open = 0,
		Close = 0,
		Slide = 0,
		Hover = 0,
		Fast = 0,
		Fill = 0,
		Style = "Linear",
		SoftStyle = "Linear",
		PopStyle = "Linear",
		Direction = "Out",
	},
}

function Animations:SetProfile(name)
	if typeof(name) ~= "string" or not Profiles[name] then
		return false
	end
	self.ProfileName = name
	self.Enabled = name ~= "None"
	return true
end

function Animations:GetProfile()
	return self.ProfileName
end

function Animations:SetEnabled(value)
	self.Enabled = value == true
	if not self.Enabled then
		self.ProfileName = "None"
	elseif self.ProfileName == "None" then
		self.ProfileName = "Smooth"
	end
	return self.Enabled
end

function Animations:SetSpeed(value)
	local n = tonumber(value)
	self.Speed = (n and n > 0 and math.clamp(n, 0.1, 4)) or 1
	return self.Speed
end

-- `key` can be a profile field ("Open", "Hover", ...) or a raw number.
function Animations:Get(key)
	local profile = Profiles[self.ProfileName] or Profiles.Smooth
	local base = tonumber(key) or profile[key] or profile.Fast or 0.12
	if not self.Enabled or profile.Multiplier == 0 then
		return 0
	end
	return math.max(base * profile.Multiplier * self.Speed, 0.001)
end

function Animations:Style(name)
	local profile = Profiles[self.ProfileName] or Profiles.Smooth
	if name == "Soft" then
		name = profile.SoftStyle
	elseif name == "Pop" then
		name = profile.PopStyle
	elseif not name then
		name = profile.Style
	end
	return Styles[name] or Enum.EasingStyle.Quint
end

function Animations:Direction(name)
	local profile = Profiles[self.ProfileName] or Profiles.Smooth
	return Directions[name or profile.Direction] or Enum.EasingDirection.Out
end

-- Create a Tween. With duration 0 the properties are applied instantly.
function Animations:Tween(Object, Time, Properties, Style, Direction)
	if not Object or typeof(Properties) ~= "table" then
		return nil
	end

	local duration = self:Get(Time)
	if duration <= 0 then
		for property, value in next, Properties do
			pcall(function()
				Object[property] = value
			end)
		end
		return nil
	end

	local info = TweenInfo.new(duration, self:Style(Style), self:Direction(Direction))
	local ok, tween = pcall(function()
		return TweenService:Create(Object, info, Properties)
	end)
	if not ok then
		return nil
	end
	return tween
end

function Animations:Play(Object, Time, Properties, Style, Direction)
	local tween = self:Tween(Object, Time, Properties, Style, Direction)
	if tween then
		pcall(function()
			tween:Play()
		end)
	end
	return tween
end

-- A tiny "springy" pop: useful for toggles, thumbs, pills.
function Animations:Pop(Object, Properties, Time, Direction)
	return self:Play(Object, Time or "Fast", Properties, "Pop", Direction or "Out")
end

-- Fade any GuiObject. CanvasGroup uses GroupTransparency, images use
-- ImageTransparency, text uses TextTransparency, frames BackgroundTransparency.
function Animations:Fade(Object, Target, Time, Property)
	if not Object then
		return nil
	end
	if not Property then
		if Object:IsA("CanvasGroup") then
			Property = "GroupTransparency"
		elseif Object:IsA("ImageLabel") or Object:IsA("ImageButton") or Object:IsA("ImageButton") then
			Property = "ImageTransparency"
		elseif Object:IsA("TextLabel") or Object:IsA("TextButton") or Object:IsA("TextBox") then
			Property = "TextTransparency"
		else
			Property = "BackgroundTransparency"
		end
	end
	return self:Play(Object, Time or "Fast", { [Property] = Target }, "Soft", "Out")
end

-- Staggered reveal for lists (sections, rows, tabs). Returns a stop handle.
function Animations:Stagger(Objects, Delay, Time, Properties, Style, Direction)
	if typeof(Objects) ~= "table" then
		return nil
	end

	local handle = { Cancelled = false }
	local profile = Profiles[self.ProfileName] or Profiles.Smooth
	local delay = (Delay or 0.035) * (profile.Multiplier > 0 and profile.Multiplier or 0)
	local time = Time or "Fast"

	for index, object in ipairs(Objects) do
		if handle.Cancelled then
			break
		end
		if object and object.Parent then
			local props = {}
			for property, value in next, Properties or {} do
				props[property] = value
			end
			if delay <= 0 or index == 1 then
				self:Play(object, time, props, Style, Direction)
			else
				task.delay(delay * (index - 1), function()
					if handle.Cancelled or not object.Parent then
						return
					end
					self:Play(object, time, props, Style, Direction)
				end)
			end
		end
	end

	function handle:Cancel()
		self.Cancelled = true
	end
	return handle
end

-- Press feedback: scale down then back with a soft overshoot.
function Animations:Press(UIScale, Normal, Pressed)
	if not UIScale then
		return
	end
	Normal = Normal or 1
	Pressed = Pressed or 0.94
	self:Play(UIScale, "Fast", { Scale = Pressed }, "Soft", "Out")
	task.delay(self:Get("Fast") + 0.01, function()
		self:Pop(UIScale, { Scale = Normal }, "Fast")
	end)
end

-- A soft endless glow pulse. Call :Stop() to cancel.
function Animations:Pulse(Object, Property, From, To, Time)
	if not Object or not self.Enabled then
		return { Stop = function() end }
	end
	local stopped = false
	local handle = {}
	task.spawn(function()
		while not stopped and Object and Object.Parent do
			self:Play(Object, Time or 1.6, { [Property] = To }, "Soft", "InOut")
			task.wait(self:Get(Time or 1.6))
			if stopped then
				break
			end
			self:Play(Object, Time or 1.6, { [Property] = From }, "Soft", "InOut")
			task.wait(self:Get(Time or 1.6))
		end
	end)
	function handle:Stop()
		stopped = true
	end
	return handle
end

return Animations
