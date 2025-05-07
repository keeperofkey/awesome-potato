local BASE_WIDTH = 800

return function(c, ctx, s)
  -- Initialize client state if needed
  s.amplitude = s.amplitude or 50
  s.speed = s.speed or 1.0
  s.phase_offset = s.phase_offset or 0
  s.intensity = s.intensity or 1.0
  s.low_band = s.low_band or 0
  s.mid_band = s.mid_band or 0
  s.high_band = s.high_band or 0

  -- Update state from audio signals with better responsiveness
  if ctx.audio_level then
    -- Apply a stronger scaling and smoother blend for better visual impact
    local target_intensity = math.min(ctx.audio_level * 8, 1.5)
    -- Smooth the transitions (higher values = smoother)
    s.intensity = s.intensity and (s.intensity * 0.7 + target_intensity * 0.3) or target_intensity
    
    -- Adjust amplitude based on audio level for more dramatic effect
    s.amplitude = 30 + (s.intensity * 70)
    
    -- Make speed responsive to audio level too
    s.speed = 0.5 + (s.intensity * 1.5)
  end
  
  -- Normalize frequency bands with enhanced response
  if ctx.frequency_bands then
    local max_band = math.max(ctx.frequency_bands.low or 0, ctx.frequency_bands.mid or 0, ctx.frequency_bands.high or 0, 0.01) -- Avoid division by zero
    
    -- Use frequency bands to influence different aspects of the wave
    local new_low = (ctx.frequency_bands.low or 0) / max_band
    local new_mid = (ctx.frequency_bands.mid or 0) / max_band
    local new_high = (ctx.frequency_bands.high or 0) / max_band
    
    -- Smooth transitions for band values
    s.low_band = s.low_band and (s.low_band * 0.7 + new_low * 0.3) or new_low
    s.mid_band = s.mid_band and (s.mid_band * 0.7 + new_mid * 0.3) or new_mid
    s.high_band = s.high_band and (s.high_band * 0.7 + new_high * 0.3) or new_high
    
    -- Use low frequencies to affect phase offset
    s.phase_offset = s.low_band * math.pi
  end

  -- Initialize phase if needed
  s.phase = s.phase or math.random() * 2 * math.pi
  
  -- Update phase based on speed and time delta (smoother with actual animation)
  -- 0.05 is roughly our tick rate in seconds
  s.phase = s.phase + (s.speed * 0.05 * math.pi)
  
  -- Wrap phase within [0, 2π]
  s.phase = s.phase % (2 * math.pi)

  -- Store initial position if not already set
  s.base_x = s.base_x or c.x
  
  -- Calculate new position with smoothed intensity
  local displacement = s.amplitude * math.sin(s.phase + s.phase_offset) * s.intensity
  local x = math.floor(s.base_x + displacement)
  local geom = c:geometry()

  -- Only update if position changed
  if geom.x ~= x then
    c:geometry { x = x }
  end
end
