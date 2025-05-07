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

    -- Update state from audio signals
    if ctx.audio_level then
        s.intensity = math.min(ctx.audio_level * 5, 1)
    end
    if ctx.frequency_bands then
        s.low_band = ctx.frequency_bands.low or 0
        s.mid_band = ctx.frequency_bands.mid or 0
        s.high_band = ctx.frequency_bands.high or 0
    end

    s.base_x = s.base_x or c.x
    
    -- Calculate dynamic parameters based on audio state
    local amplitude = s.amplitude * s.intensity
    local speed = s.speed + (s.low_band * 0.5)
    
    -- Update phase with speed
    s.phase = (s.phase or math.random() * 2 * math.pi) + speed * 0.1  -- Use fixed 0.1s interval
    
    -- Calculate new position
    local x = math.floor(s.base_x + amplitude * math.sin(s.phase + s.phase_offset))
    local geom = c:geometry()
    
    -- Only update if position changed
    if geom.x ~= x then
        c:geometry({ x = x })
    end
end
