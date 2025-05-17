-- Spectral Slide Effect
-- Moves the window based on spectral features:
-- Horizontal movement (dx) controlled by poly_mean[1] (spectral slope)
-- Vertical movement (dy) controlled by poly_mean[2] (spectral curvature)
-- Opacity modulated by melspec_mean

local SLIDE_SPEED = 20  -- pixels per tick at max speed

return function(c, ctx, s)
    -- Get current geometry
    local geom = c:geometry()
    s.state = s.state or { x = geom.x, y = geom.y, width = geom.width, height = geom.height }

    -- Use poly_mean[1] for horizontal movement (spectral slope)
    local slope_x = (ctx.poly_mean and ctx.poly_mean[1]) or 0
    local slide_x = math.max(-1, math.min(1, slope_x / 10))  -- Normalize to [-1, 1]
    
    -- Use poly_mean[2] for vertical movement (spectral curvature)
    local slope_y = (ctx.poly_mean and ctx.poly_mean[2]) or 0
    local slide_y = math.max(-1, math.min(1, slope_y / 10))  -- Normalize to [-1, 1]

    -- Calculate movement deltas
    local dx = slide_x * SLIDE_SPEED
    local dy = slide_y * SLIDE_SPEED

    -- Optionally, modulate opacity with melspec_mean
    if ctx.melspec_mean then
        c.opacity = 0.7 + math.min(0.3, ctx.melspec_mean * 0.01)
    end

    -- Move window, clamping to screen bounds
    local screen = c.screen.workarea
    local new_x = math.max(screen.x, math.min(geom.x + dx, screen.x + screen.width - geom.width))
    local new_y = math.max(screen.y, math.min(geom.y + dy, screen.y + screen.height - geom.height))

    c:geometry({ x = new_x, y = new_y, width = geom.width, height = geom.height })
end
