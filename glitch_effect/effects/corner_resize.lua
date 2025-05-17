-- Constants
local BASE_WIDTH, BASE_HEIGHT = 800, 500
local MIN_WIDTH, MIN_HEIGHT = 50, 30
local AMPLITUDE = 150
local SPEED = 1.5
local SCREEN_MARGIN = 10
local CORNERS = { "tl", "tr", "bl", "br" }
local TAU = 2 * math.pi

return function(client, audio_ctx, state)
    -- Get screen geometry
    local screen = client.screen and client.screen.geometry or { x = 0, y = 0, width = BASE_WIDTH, height = BASE_HEIGHT }

    -- Staggered update logic
    local UPDATE_EVERY = 3
    if not state.stagger_offset then
        -- Use client.window (XID) if available, otherwise fallback to math.random
        state.stagger_offset = (client.window or math.random(0, 100)) % UPDATE_EVERY
    end
    state.tick_count = (state.tick_count or 0) + 1
    local tick = (audio_ctx.tick and math.floor(audio_ctx.tick * 1000)) or state.tick_count
    if ((tick + state.stagger_offset) % UPDATE_EVERY) ~= 0 then
        return  -- Skip this tick for this window
    end

    -- Throttling: only update if enough ticks have passed since last update
    local THROTTLE_TICKS = 2
    state.last_update_tick = state.last_update_tick or 0
    if tick - state.last_update_tick < THROTTLE_TICKS then
        return  -- Throttle: skip update
    end
    state.last_update_tick = tick

    -- State initialization
    state.base_x = state.base_x or client.x
    state.base_y = state.base_y or client.y
    state.base_w = state.base_w or client.width or BASE_WIDTH
    state.base_h = state.base_h or client.height or BASE_HEIGHT
    state.phase = state.phase or math.random() * TAU
    state.corner = state.corner or CORNERS[math.random(1, 4)]

    -- Amplitude and speed modulated by audio
    local amp = AMPLITUDE
    if audio_ctx.rms then
        amp = amp * (audio_ctx.rms * 2 + 0.5)
    end
    local speed = SPEED
    if audio_ctx.rms then
        speed = speed * (audio_ctx.rms * 1.5 + 0.5)
    end

    -- Phase update for smooth animation
    local tick = audio_ctx.tick or 0.1
    state.phase = (state.phase + speed * tick) % TAU

    -- Calculate new target width/height
    local target_w = math.floor(state.base_w + amp * math.cos(state.phase))
    local target_h = math.floor(state.base_h + amp * math.sin(state.phase))
    target_w = math.max(MIN_WIDTH, math.min(target_w, screen.width - SCREEN_MARGIN))
    target_h = math.max(MIN_HEIGHT, math.min(target_h, screen.height - SCREEN_MARGIN))

    -- Use MFCC[0] to pick corner
    if audio_ctx.mfcc0 then
        local idx = math.floor(((audio_ctx.mfcc0 + 500) / 1000) * 4) + 1
        idx = math.max(1, math.min(4, idx))
        state.corner = CORNERS[idx]
    end
    -- Use zero-crossing rate to jitter corner
    if audio_ctx.zcr and audio_ctx.zcr > 0.1 and math.random() < audio_ctx.zcr then
        state.corner = CORNERS[math.random(1, 4)]
    end

    -- Calculate new target position based on corner
    local target_x, target_y = state.base_x, state.base_y
    if state.corner == "tr" then
        target_x = state.base_x + state.base_w - target_w
    elseif state.corner == "bl" then
        target_y = state.base_y + state.base_h - target_h
    elseif state.corner == "br" then
        target_x = state.base_x + state.base_w - target_w
        target_y = state.base_y + state.base_h - target_h
    end

    -- Clamp to screen bounds
    target_x = math.max(screen.x + SCREEN_MARGIN, math.min(target_x, screen.x + screen.width - target_w - SCREEN_MARGIN))
    target_y = math.max(screen.y + SCREEN_MARGIN, math.min(target_y, screen.y + screen.height - target_h - SCREEN_MARGIN))

    -- Initialize current geometry in state if needed
    state.current_x = state.current_x or target_x
    state.current_y = state.current_y or target_y
    state.current_w = state.current_w or target_w
    state.current_h = state.current_h or target_h

    -- Lerp factor (0.15 = slow, 1 = instant)
    local lerp = function(a, b, t) return a + (b - a) * t end
    local LERP_FACTOR = 0.15

    -- Smoothly interpolate current geometry toward target
    state.current_x = lerp(state.current_x, target_x, LERP_FACTOR)
    state.current_y = lerp(state.current_y, target_y, LERP_FACTOR)
    state.current_w = lerp(state.current_w, target_w, LERP_FACTOR)
    state.current_h = lerp(state.current_h, target_h, LERP_FACTOR)

    -- Round to integer for geometry
    local new_x = math.floor(state.current_x + 0.5)
    local new_y = math.floor(state.current_y + 0.5)
    local new_w = math.floor(state.current_w + 0.5)
    local new_h = math.floor(state.current_h + 0.5)

    -- Only update geometry if changed
    local geom = client:geometry()
    if geom.x ~= new_x or geom.y ~= new_y or geom.width ~= new_w or geom.height ~= new_h then
        client:geometry { x = new_x, y = new_y, width = new_w, height = new_h }
    end
end
