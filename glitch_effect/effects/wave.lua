local BASE_WIDTH = 800
local AMPLITUDE = 50
local SPEED = 1.0

return function(c, ctx, s)
    s.base_x = s.base_x or c.x
    s.phase = (s.phase or math.random() * 2 * math.pi) + SPEED * (ctx.tick or 0.1)
    local x = math.floor(s.base_x + AMPLITUDE * math.sin(s.phase))
    local geom = c:geometry()
    if geom.x ~= x then
        c:geometry({ x = x })
    end
end
