-- Constants
local DEFAULT_AMPLITUDE = 2  -- Small amplitude for relative movement
local MIN_AMPLITUDE = 0.1
local MAX_AMPLITUDE = 10
local BASE_FREQUENCY = 0.5
local AUDIO_MULTIPLIER = 5  -- Lower multiplier for relative movement
local TAU = 2 * math.pi  -- One full rotation in radians

return function(client, audio_ctx, state)
    -- Initialize state if not exists
    local screen = client.screen and client.screen.geometry
    
    -- Initialize phase with unique offsets per client if not exists
    if not state.initialized then
        -- Use client window ID to generate unique but consistent offsets
        local unique_seed = client.window or 0
        math.randomseed(unique_seed)
        state.phase_x = math.random() * TAU  -- Random initial phase (0 to 2π)
        state.phase_y = math.random() * TAU  -- Different phase for y axis
        state.freq_mod = 0.8 + (math.random() * 0.4)  -- Slight frequency variation (0.8 to 1.2)
        state.initialized = true
    end
    
    -- Initialize wave parameters
    state.amplitude_x = state.amplitude_x or DEFAULT_AMPLITUDE
    state.amplitude_y = state.amplitude_y or DEFAULT_AMPLITUDE
    state.frequency_x = state.frequency_x or BASE_FREQUENCY
    state.frequency_y = state.frequency_y or BASE_FREQUENCY
    
    -- Calculate amplitude based on audio input
    if audio_ctx.mfcc0 ~= 0 then
        local audio_boost = math.abs(audio_ctx.mfcc0) * AUDIO_MULTIPLIER
        state.amplitude_x = math.min(MAX_AMPLITUDE, 
                                   math.max(MIN_AMPLITUDE, 
                                           DEFAULT_AMPLITUDE + audio_boost))
        state.amplitude_y = math.min(MAX_AMPLITUDE, 
                                   math.max(MIN_AMPLITUDE, 
                                           DEFAULT_AMPLITUDE + audio_boost))
    end

    -- Beat reactivity: pulse amplitude on beat
    state.beat_pulse = state.beat_pulse or 0
    local BEAT_PULSE_AMOUNT = 30  -- how much to pulse amplitude per beat
    local BEAT_DECAY = 0.9        -- decay factor per tick (0 < BEAT_DECAY < 1)
    
    if audio_ctx.beat == 1 then
        state.beat_pulse = BEAT_PULSE_AMOUNT
    end
    
    state.beat_pulse = state.beat_pulse * BEAT_DECAY
    
    -- Calculate time step
    local time_step = audio_ctx.tick or 0.1
    
    -- Get audio signal for modulation (using mfcc1 for phase modulation)
    local audio_mod = audio_ctx.mfcc1 or 0
    
    -- Calculate BPM-based speed factor (normalized around 1.0)
    local bpm_speed = 1.0
    if audio_ctx.bpm and audio_ctx.bpm > 0 then
        -- Normalize around 120 BPM (1.0 at 120 BPM)
        bpm_speed = audio_ctx.bpm / 120.0
        -- Limit the range to avoid extreme speeds
        bpm_speed = math.max(0.5, math.min(2.0, bpm_speed))
    end
    
    -- Calculate phase modulation based on audio
    -- Scale audio_mod to a reasonable range (0.5 to 1.5)
    local phase_mod = 0.5 + (math.abs(audio_mod) * 2)
    
    -- Update phases with BPM-based speed and audio modulation
    local freq_mod = state.freq_mod or 1
    local base_speed = 0.5  -- Base speed multiplier
    state.phase_x = (state.phase_x + state.frequency_x * time_step * phase_mod * freq_mod * bpm_speed * base_speed) % TAU
    state.phase_y = (state.phase_y + state.frequency_y * time_step * (2 - phase_mod) * (1/freq_mod) * bpm_speed * base_speed) % TAU
    
    -- Calculate relative offsets with sine waves
    local pulse_boost = state.beat_pulse  * 0.2-- Very small pulse boost for relative movement
    local offset_x = (state.amplitude_x + pulse_boost) * math.sin(state.phase_x)
    local offset_y = (state.amplitude_y + pulse_boost) * math.cos(state.phase_y)
    
    -- Get current geometry and screen bounds
    local current_geom = client:geometry()
    local screen_geom = client.screen.workarea
    
    -- Calculate new position with relative offset
    local new_x = current_geom.x + offset_x
    local new_y = current_geom.y + offset_y
    
    -- Constrain to screen bounds with margin
    local margin = 20  -- pixels from screen edge
    new_x = math.max(screen_geom.x + margin, 
                    math.min(new_x, 
                           screen_geom.x + screen_geom.width - current_geom.width - margin))
    new_y = math.max(screen_geom.y + margin, 
                    math.min(new_y, 
                           screen_geom.y + screen_geom.height - current_geom.height - margin))
    
    -- Update window position if changed
    local current_geom = client:geometry()
    if math.floor(current_geom.x) ~= math.floor(new_x) or 
       math.floor(current_geom.y) ~= math.floor(new_y) then
        client:geometry { 
            x = math.floor(new_x), 
            y = math.floor(new_y) 
        }
    end
end