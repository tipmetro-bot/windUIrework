--[[
    WindUI Rework / SliderMath
    ------------------------------------------------------------------
    Pure (Roblox-free) numeric core of the slider. Kept separate so the
    "zero bug" can be regression-tested with a plain Luau VM:

        luau tests/slider_math_test.luau

    The old implementation broke when Min / Default / Max / Step was 0:
      * `Slider.Value.Max or 100` was fine for 0, but
        `(Value - Min) / (Max - Min)` produced 0/0 = nan when Max == Min,
      * `Step = Config.Step or 1` accepted Step = 0 -> division by zero,
      * `if Value ~= LastValue` silently skipped Set(0) and config loads,
      * snapping was not relative to Min and was never clamped.

    All of that lives here now and is deterministic/testable.
]]

local SliderMath = {}

local function ToNumber(value, fallback)
	local number = tonumber(value)
	if number == nil or number ~= number or number == math.huge or number == -math.huge then
		return fallback
	end
	return number
end
SliderMath.ToNumber = ToNumber

-- Accepts { Min, Max, Default, Step } in any of these shapes:
--   Config.Value = { Min = 0, Max = 100, Default = 0 }
--   Config.Value = 0            (plus Config.Min / Config.Max)
--   Config.Min / Config.Max / Config.Default / Config.Step
function SliderMath.Normalise(Config)
	Config = Config or {}
	local rawMin, rawMax, rawDefault
	if type(Config.Value) == "table" then
		rawMin, rawMax, rawDefault = Config.Value.Min, Config.Value.Max, Config.Value.Default
	elseif type(Config.Value) == "number" then
		rawMin, rawMax, rawDefault = Config.Min, Config.Max, Config.Value
	else
		rawMin, rawMax, rawDefault = Config.Min, Config.Max, Config.Default
	end

	local Min = ToNumber(rawMin, 0)
	local Max = ToNumber(rawMax, 100)
	if Max <= Min then
		Max = Min + 1 -- zero-length / reversed range -> no 0/0
	end

	local Step = ToNumber(Config.Step, 1)
	if Step <= 0 then
		Step = 1 -- Step = 0 would divide by zero
	end
	Step = math.min(Step, Max - Min)

	return {
		Min = Min,
		Max = Max,
		Step = Step,
		IsFloat = (Step % 1) ~= 0,
		Default = ToNumber(rawDefault, Min),
	}
end

function SliderMath.Range(range)
	return math.max(range.Max - range.Min, 1e-9)
end

function SliderMath.Delta(value, range)
	return math.clamp((value - range.Min) / SliderMath.Range(range), 0, 1)
end

function SliderMath.Format(value, range)
	value = ToNumber(value, range.Min)
	if range.IsFloat then
		return ToNumber(string.format("%.2f", value), value)
	end
	return math.floor(value + 0.5)
end

function SliderMath.Calculate(rawValue, range)
	rawValue = ToNumber(rawValue, range.Min)
	local snapped = range.Min + math.floor((rawValue - range.Min) / range.Step + 0.5) * range.Step
	return math.clamp(SliderMath.Format(snapped, range), range.Min, range.Max)
end

function SliderMath.SetMin(range, newMin)
	local min = ToNumber(newMin, range.Min)
	if min >= range.Max then
		min = range.Max - 1
	end
	range.Min = min
	return math.clamp(range.Default, min, range.Max)
end

function SliderMath.SetMax(range, newMax)
	local max = ToNumber(newMax, range.Max)
	if max <= range.Min then
		max = range.Min + 1
	end
	range.Max = max
	return math.clamp(range.Default, range.Min, max)
end

function SliderMath.SetStep(range, newStep)
	local step = ToNumber(newStep, range.Step)
	if step <= 0 then
		step = 1
	end
	range.Step = math.min(step, SliderMath.Range(range))
	range.IsFloat = (range.Step % 1) ~= 0
	return range.Step
end

return SliderMath
