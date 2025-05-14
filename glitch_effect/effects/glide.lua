-- Constants
local DEFAULT_RADIUS = 10
local MIN_RADIUS = 1
local MAX_RADIUS = 100
local BASE_SPEED = 0.1
local SCREEN_MARGIN = 10  -- Minimum distance from screen edges
local AUDIO_MULTIPLIER = 10
local TAU = 2 * math.pi  -- One full rotation in radians

return function(client, audio_ctx, state)
    -- Initialize state if not exists
    local screen = client.screen and client.screen.geometry
    
    -- Initialize base position
    state.base_x = client.x
    state.base_y = client.y
    
    -- Initialize or get glide center point
    if not state.glide_center then
        state.glide_center = {
            x = math.random(screen.x + SCREEN_MARGIN, 
                          screen.x + screen.width - SCREEN_MARGIN),
            y = math.random(screen.y + SCREEN_MARGIN, 
                          screen.y + screen.height - SCREEN_MARGIN)
        }
    end
    
    -- Calculate radius based on audio input
    state.glide_radius = DEFAULT_RADIUS
    if audio_ctx.mfcc0 ~= 0 then
        state.glide_radius = state.glide_radius + math.abs(audio_ctx.mfcc0)
        state.glide_radius = math.min(MAX_RADIUS, math.max(MIN_RADIUS, state.glide_radius))
    end

    -- Beat reactivity: pulse radius on beat
    -- state.beat_pulse = state.beat_pulse or 0
    -- state.glide_direction = state.glide_direction or 1
    -- local BEAT_PULSE_AMOUNT = 20  -- how much to pulse radius per beat
    -- local BEAT_DECAY = 0.85       -- decay factor per tick (0 < BEAT_DECAY < 1)
    -- -- if audio_ctx.beat == 1 then
    --     -- state.beat_pulse = state.beat_pulse + BEAT_PULSE_AMOUNT
    -- -- end
    -- if math.random() % 10 == 0 then 
    --     state.glide_direction = -state.glide_direction  -- reverse direction on beat
    -- end
    -- state.beat_pulse = state.beat_pulse * BEAT_DECAY
    -- state.glide_radius = state.glide_radius + state.beat_pulse
    -- state.glide_radius = math.min(MAX_RADIUS, math.max(MIN_RADIUS, state.glide_radius))
    
    -- Calculate speed based on audio RMS
    state.glide_speed = audio_ctx.rms ~= 0 and 
                       (BASE_SPEED + (audio_ctx.rms * AUDIO_MULTIPLIER)) or 
                       BASE_SPEED
    
    -- Update phase with time and modulation
    state.glide_phase = state.glide_phase or math.random() * TAU
    local time_step = audio_ctx.tick or 0.1
    local modulation = 1 
    state.glide_phase = (state.glide_phase + state.glide_speed * time_step * modulation) % TAU
    
    -- Calculate new position
    local new_x = math.floor(state.base_x + state.glide_radius * math.cos(state.glide_phase))
    local new_y = math.floor(state.base_y + state.glide_radius * math.sin(state.glide_phase))
    
    -- Ensure window stays within screen bounds
    new_x = math.max(screen.x, math.min(new_x, screen.x + screen.width - client.width))
    new_y = math.max(screen.y, math.min(new_y, screen.y + screen.height - client.height))
    
    -- Update window position if changed
    local current_geom = client:geometry()
    if current_geom.x ~= new_x or current_geom.y ~= new_y then
        client:geometry { x = new_x, y = new_y }
    end
end
