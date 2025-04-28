local BASE_WIDTH, BASE_HEIGHT = 800, 500
local SPEED = 1.5
local RANDOM_MARGIN = 100

return function(c, ctx, s)
    s.base_x = s.base_x or c.x
    s.base_y = s.base_y or c.y
    local scr = c.screen and c.screen.geometry or { x = 0, y = 0, width = BASE_WIDTH, height = BASE_HEIGHT }
    s.glide_phase = s.glide_phase or math.random() * 2 * math.pi
    s.glide_center = s.glide_center or {
        x = math.random(scr.x + RANDOM_MARGIN, scr.x + scr.width - RANDOM_MARGIN),
        y = math.random(scr.y + RANDOM_MARGIN, scr.y + scr.height - RANDOM_MARGIN),
    }
    s.glide_radius = s.glide_radius or math.random(60, 220)
    s.glide_speed = s.glide_speed or ((math.random() * 0.8 + 0.4) * (math.random(0, 1) == 0 and 1 or -1))

    s.glide_phase = (s.glide_phase + s.glide_speed * (ctx.tick or 0.1)) % (2 * math.pi)
    local glide_center = s.glide_center

    local w = c.width
    local h = c.height
    local glide_x = math.floor(s.base_x + s.glide_radius * math.cos(s.glide_phase))
    local glide_y = math.floor(s.base_y + s.glide_radius * math.sin(s.glide_phase))
    local new_x, new_y = glide_x, glide_y

    -- Clamp to screen
    new_x = math.max(scr.x, math.min(new_x, scr.x + scr.width - w))
    new_y = math.max(scr.y, math.min(new_y, scr.y + scr.height - h))
    local geom = c:geometry()
    if geom.x ~= new_x or geom.y ~= new_y then
        c:geometry({ x = new_x, y = new_y })
    end
end
