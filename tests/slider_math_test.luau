--!strict
--[[
    WindUI Rework / zero-slider regression tests
    ---------------------------------------------------------------
    Pure Luau, no Roblox globals needed.

    Run from anywhere:
        luau tests/slider_math_test.luau
    (Luau CLI: https://github.com/luau-lang/luau)

    Covers the bug "слайдеры с 0": Min = 0, Default = 0, Max = 0,
    Step = 0, Set(0), reversed ranges and NaN inputs.
]]

local SliderMath = require("../src/modules/SliderMath")

local checks = 0
local failures = 0

local function eq(actual, expected, message)
	checks += 1
	if actual ~= expected then
		failures += 1
		print(string.format("FAIL  %s : expected %s, got %s", message, tostring(expected), tostring(actual)))
	end
end

local function near(actual, expected, message)
	checks += 1
	if math.abs(actual - expected) > 1e-6 then
		failures += 1
		print(string.format("FAIL  %s : expected ~%s, got %s", message, tostring(expected), tostring(actual)))
	end
end

local function ok(value, message)
	checks += 1
	if not value then
		failures += 1
		print("FAIL  " .. message)
	end
end

-- 1. Baseline: 0 .. 100 with Default = 0
local r = SliderMath.Normalise({ Value = { Min = 0, Max = 100, Default = 0 } })
eq(r.Min, 0, "Min = 0 is kept")
eq(r.Max, 100, "Max = 100 is kept")
eq(r.Default, 0, "Default = 0 is kept (not replaced by Min via `or`)")
eq(r.Step, 1, "default Step = 1")
eq(r.IsFloat, false, "integer step is not float")
eq(SliderMath.Calculate(0, r), 0, "Calculate(0) = 0")
eq(SliderMath.Delta(0, r), 0, "Delta(0) = 0 (fill starts empty)")
eq(SliderMath.Delta(50, r), 0.5, "Delta(50) = 0.5")
eq(SliderMath.Delta(100, r), 1, "Delta(100) = 1")
eq(SliderMath.Calculate(150, r), 100, "value above Max is clamped")
eq(SliderMath.Calculate(-20, r), 0, "value below Min is clamped")
eq(SliderMath.Format(0, r), 0, "Format(0) = 0")

-- 2. The classic crash: Min = 0 AND Max = 0 (0 / 0 = nan)
local z = SliderMath.Normalise({ Value = { Min = 0, Max = 0, Default = 0 }, Step = 0 })
eq(z.Min, 0, "zero range: Min = 0")
eq(z.Max, 1, "zero range: Max is widened so the range is never 0")
eq(z.Step, 1, "Step = 0 is replaced with 1")
eq(z.Default, 0, "zero range: Default = 0")
eq(SliderMath.Delta(0, z), 0, "zero range: Delta(0) is finite")
eq(SliderMath.Calculate(0, z), 0, "zero range: Calculate(0) = 0")
ok(z.Max - z.Min > 0, "zero range: Max > Min")
ok(SliderMath.Delta(0, z) == SliderMath.Delta(0, z), "zero range: Delta is not NaN")

-- 3. Flat config keys and Value = number
local f = SliderMath.Normalise({ Min = 0, Max = 10, Default = 0 })
eq(SliderMath.Calculate(f.Default, f), 0, "flat Default = 0 works")
local n = SliderMath.Normalise({ Value = 0, Min = 0, Max = 10 })
eq(n.Default, 0, "Value = 0 (number) works")

-- 4. Reversed range and runtime SetMin(0) / SetMax(0)
local rev = SliderMath.Normalise({ Value = { Min = 10, Max = 0, Default = 5 } })
ok(rev.Max > rev.Min, "reversed range is repaired")
local sm = SliderMath.Normalise({ Value = { Min = -5, Max = 5, Default = 0 } })
eq(SliderMath.SetMin(sm, 0), 0, "SetMin(0) keeps the value at 0")
eq(sm.Min, 0, "SetMin(0) sets Min to exactly 0")
local sx = SliderMath.Normalise({ Value = { Min = 0, Max = 10, Default = 4 } })
SliderMath.SetMax(sx, 0)
ok(sx.Max > sx.Min, "SetMax(0) never creates a zero-length range")

-- 5. Snapping is relative to Min and step 0 is safe
local snap = SliderMath.Normalise({ Value = { Min = -5, Max = 5, Default = -5 }, Step = 3 })
eq(SliderMath.Calculate(-4, snap), -5, "snapping is relative to Min")
eq(SliderMath.Calculate(-3, snap), -2, "snapping follows the step")
local stepZero = SliderMath.Normalise({ Value = { Min = 0, Max = 10, Default = 3 }, Step = 0 })
eq(SliderMath.Calculate(3, stepZero), 3, "Step = 0 behaves like Step = 1")

-- 6. Floating point steps
local flt = SliderMath.Normalise({ Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.1 })
eq(flt.IsFloat, true, "fractional step is detected as float")
near(SliderMath.Calculate(0.57, flt), 0.6, "float snapping to 0.6")
eq(SliderMath.Calculate(0, flt), 0, "float slider accepts 0")

-- 7. Garbage input never produces NaN
eq(SliderMath.ToNumber("0", 7), 0, "string '0' converts to 0")
eq(SliderMath.ToNumber(nil, 7), 7, "nil falls back")
eq(SliderMath.ToNumber(0 / 0, 7), 7, "NaN falls back")
eq(SliderMath.ToNumber(math.huge, 7), 7, "infinity falls back")
local garbage = SliderMath.Normalise({ Value = { Min = "abc", Max = nil, Default = {} }, Step = "x" })
ok(SliderMath.Delta(0, garbage) >= 0, "garbage config produces a finite delta")
ok(garbage.Max > garbage.Min, "garbage config still has a valid range")

-- 8. Step rounding (bug 4 from the DeepSeek checklist)
-- A fractional Min with an integer Step must not be rounded to an int.
local half = SliderMath.Normalise({ Value = { Min = 0.5, Max = 5.5, Default = 0.5 }, Step = 1 })
eq(half.IsFloat, true, "fractional Min is detected as float")
near(SliderMath.Calculate(2.4, half), 2.5, "Step = 1 keeps the 0.5 offset")
near(SliderMath.Calculate(0, half), 0.5, "value below Min clamps to Min")

-- Small steps must not accumulate floating point noise.
local milli = SliderMath.Normalise({ Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.001 })
eq(milli.IsFloat, true, "Step = 0.001 is float")
near(SliderMath.Calculate(0.1234, milli), 0.123, "0.001 step snaps exactly")
eq(SliderMath.Precision(0.001), 3, "precision of 0.001 is 3 decimals")
eq(SliderMath.Precision(2), 0, "precision of 2 is 0 decimals")

local tenth = SliderMath.Normalise({ Value = { Min = 0, Max = 1, Default = 0 }, Step = 0.1 })
near(SliderMath.Calculate(0.25, tenth), 0.3, "0.1 step snaps to 0.3 without float noise")
eq(SliderMath.Calculate(1.9, tenth), 1, "snapped value is clamped to Max")

print(string.format("slider_math: %d checks, %d failures", checks, failures))
if failures > 0 then
	error("slider regression tests failed", 0)
end
print("ALL OK: sliders with 0 work.")
