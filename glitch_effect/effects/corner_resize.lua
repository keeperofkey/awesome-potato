local BASE_WIDTH, BASE_HEIGHT = 800, 500
local AMPLITUDE, SPEED = 150, 1.5
local CORNERS = { "tl", "tr", "bl", "br" }
local MIN_WIDTH, MIN_HEIGHT = 50, 30
local naughty = require 'naughty'

return function(c, ctx, s)
    local scr = c.screen and c.screen.geometry or { x = 0, y = 0, width = BASE_WIDTH, height = BASE_HEIGHT }
    s.phase = s.phase or math.random() * 2 * math.pi
    s.corner = s.corner or CORNERS[math.random(1, 4)]

    -- Use RMS (audio_level) for amplitude and speed
    local amp = (ctx.rms and (AMPLITUDE * (ctx.rms * 2 + 0.5))) or AMPLITUDE
    local speed = (ctx.rms and (SPEED * (ctx.rms * 1.5 + 0.5))) or SPEED
    s.phase = (s.phase + speed * (ctx.tick or 0.1)) % (2 * math.pi)

    local w = math.floor(BASE_WIDTH + amp * math.cos(s.phase))
    local h = math.floor(BASE_HEIGHT + amp * math.sin(s.phase))
    if ctx.rms then
        s.phase = s.phase + (ctx.rms * 10)
    end

    -- Use MFCC[0] to pick corner
    if ctx.mfcc0 then
        local idx = math.floor(((ctx.mfcc0 + 500) / 1000) * 4) + 1
        idx = math.max(1, math.min(4, idx))
        s.corner = CORNERS[idx]
    end
    -- Use zero-crossing rate to jitter corner
    if ctx.zcr and ctx.zcr > 0.1 and math.random() < ctx.zcr then
        s.corner = CORNERS[math.random(1, 4)]
    end
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
