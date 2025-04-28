local BASE_WIDTH, BASE_HEIGHT = 800, 500
local AMPLITUDE, SPEED = 150, 1.5
local CORNERS = { "tl", "tr", "bl", "br" }
local MIN_WIDTH, MIN_HEIGHT = 50, 30

return function(c, ctx, s)
    local scr = c.screen and c.screen.geometry or { x = 0, y = 0, width = BASE_WIDTH, height = BASE_HEIGHT }
    s.phase = s.phase or math.random() * 2 * math.pi
    s.corner = s.corner or CORNERS[math.random(1, 4)]

    local amp = ctx.beat and (AMPLITUDE * 10) or AMPLITUDE
    s.phase = (s.phase + SPEED * (ctx.tick or 0.1)) % (2 * math.pi)

    local w = math.floor(BASE_WIDTH + amp * math.cos(s.phase))
    local h = math.floor(BASE_HEIGHT + amp * math.sin(s.phase))
    local geom = c:geometry()
    local dw = w - geom.width
    local dh = h - geom.height
    local new_x, new_y = geom.x, geom.y
    if s.corner == "tr" then
        new_x = geom.x - dw
    elseif s.corner == "bl" then
        new_y = geom.y - dh
    elseif s.corner == "br" then
        new_x = geom.x - dw
        new_y = geom.y - dh
    end
    if geom.x ~= new_x or geom.y ~= new_y or geom.width ~= w or geom.height ~= h then
        c:geometry({ x = new_x, y = new_y, width = w, height = h })
    end
end
