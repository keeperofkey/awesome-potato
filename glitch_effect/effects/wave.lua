local BASE_WIDTH = 800
local naughty = require 'naughty'

return function(c, ctx, s)
  -- Initialize client state if needed
  s.amplitude = s.amplitude or 50
  s.speed = s.speed or 1.0
  s.phase_offset = s.phase_offset or 0
  s.intensity = s.intensity or 2.0
  s.low_band = s.low_band or 0
  s.mid_band = s.mid_band or 0
  s.high_band = s.high_band or 0
  -- notify client name
  -- notify ctx parse the table

  -- Update state from audio signals with better responsiveness
  if ctx.rms then
    -- Apply a stronger scaling and smoother blend for better visual impact
    local target_intensity = math.min(ctx.rms * 8, 1.5)
    -- Smooth the transitions (higher values = smoother)
    s.intensity = s.intensity and (s.intensity * 0.7 + target_intensity * 0.3) or target_intensity

    -- Adjust amplitude based on audio level for more dramatic effect
    s.amplitude = 30 + (s.intensity * 70)

    -- Make speed responsive to audio level too
    s.speed = 0.5 + (s.intensity * 1.5)
  end

  -- Normalize frequency bands with enhanced response
  -- if ctx.frequency_bands then
  --   local max_band = math.max(ctx.frequency_bands.low or 0, ctx.frequency_bands.mid or 0, ctx.frequency_bands.high or 0, 0.01) -- Avoid division by zero

  --   -- Use frequency bands to influence different aspects of the wave
  --   local new_low = (ctx.frequency_bands.low or 0) / max_band
  --   local new_mid = (ctx.frequency_bands.mid or 0) / max_band
  --   local new_high = (ctx.frequency_bands.high or 0) / max_band

  --   -- Use MFCC[0] (if present) to affect phase offset; fallback to low band
  if ctx.mfcc0 then
    s.phase_offset = s.phase_offset and (s.phase_offset * 0.7 + (ctx.mfcc0 / 500) * math.pi * 0.3) or (ctx.mfcc0 / 500) * math.pi
  end
  -- end

  s.phase = s.phase or math.random() * 2 * math.pi
  -- Update phase based on speed and time delta (smoother with actual animation)
  -- 0.05 is roughly our tick rate in seconds
  s.phase = s.phase + (s.speed * 0.05 * math.pi)

  -- Wrap phase within [0, 2π]
  s.phase = s.phase % (2 * math.pi)

  s.base_x = s.base_x or c.x
  -- Calculate relative displacement
  local displacement = math.floor(s.amplitude * math.sin(s.phase + s.phase_offset) * s.intensity)
  -- if displacement ~= 0 then
  local x = math.floor(s.base_x + displacement)
  local geom = c:geometry()
  c:geometry { x = geom.x + displacement }
  -- end
end
