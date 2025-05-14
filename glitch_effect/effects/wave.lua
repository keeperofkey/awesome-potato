-- Wave effect for AwesomeWM glitch effect
-- Moves the client window horizontally in a wave pattern based on audio input

return function(client, ctx, state)
  -- Initialize persistent state with defaults
  state.amplitude    = state.amplitude    or 50
  state.speed        = state.speed        or 1.0
  state.phase_offset = state.phase_offset or 0
  state.intensity    = state.intensity    or 2.0
  state.phase        = state.phase        or math.random() * 2 * math.pi
  state.base_x       = state.base_x       or client.x

  -- Update state from audio RMS (root mean square) if available
  if ctx.rms then
    local target_intensity = math.min(ctx.rms * 8, 1.5)
    state.intensity = (state.intensity * 0.7) + (target_intensity * 0.3)
    state.amplitude = 30 + (state.intensity * 70)
    state.speed     = 0.5 + (state.intensity * 1.5)
  end

  -- Update phase offset from MFCC0 if available
  if ctx.mfcc0 then
    local target_offset = (ctx.mfcc0 / 500) * math.pi
    state.phase_offset = (state.phase_offset * 0.7) + (target_offset * 0.3)
  end

  -- Advance the phase for animation
  state.phase = (state.phase + state.speed * 0.05 * math.pi) % (2 * math.pi)

  -- Calculate horizontal displacement
  local displacement = math.floor(state.amplitude * math.sin(state.phase + state.phase_offset) * state.intensity)

  -- Move the client window horizontally
  local geom = client:geometry()
  client:geometry { x = state.base_x + displacement }
end
