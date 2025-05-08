local HISTORY_LENGTH = 5
local BASE_GLITCH_PROBABILITY = 0.1 -- default low chance
local GLITCH_PROBABILITY = BASE_GLITCH_PROBABILITY


return function(c, ctx, s)
    s.history = s.history or {}
    local geom = c:geometry()
    -- Store current geometry in history
    table.insert(s.history, 1, { x = geom.x, y = geom.y, width = geom.width, height = geom.height })
    if #s.history > HISTORY_LENGTH then
        table.remove(s.history)
    end

    -- Use zcr or spectral_contrast to modulate glitch probability
    local prob = BASE_GLITCH_PROBABILITY
    if ctx.zcr and ctx.zcr > 0.1 then
        prob = math.min(1, prob + ctx.zcr * 2)
    end
    if ctx.spectral_contrast and ctx.spectral_contrast > 0.2 then
        prob = math.min(1, prob + ctx.spectral_contrast)
    end
    -- Randomly glitch: jump to a previous geometry for 1 tick
    if math.random() < prob and #s.history > 1 then
        local idx = math.random(2, #s.history)
        local ghost = s.history[idx]
        c:geometry({ x = ghost.x, y = ghost.y, width = ghost.width, height = ghost.height })
    else
        c:geometry({ x = s.state.x, y = s.state.y, width = s.state.width, height = s.state.height })
    end
end
