local HISTORY_LENGTH = 5
local GLITCH_PROBABILITY = 1 -- chance per tick to glitch

return function(c, ctx, s)
    s.history = s.history or {}
    local geom = c:geometry()
    -- Store current geometry in history
    table.insert(s.history, 1, { x = geom.x, y = geom.y, width = geom.width, height = geom.height })
    if #s.history > HISTORY_LENGTH then
        table.remove(s.history)
    end

    -- Randomly glitch: jump to a previous geometry for 1 tick
    if math.random() < GLITCH_PROBABILITY and #s.history > 1 then
        local idx = math.random(2, #s.history)
        local ghost = s.history[idx]
        c:geometry({ x = ghost.x, y = ghost.y, width = ghost.width, height = ghost.height })
    end
end
