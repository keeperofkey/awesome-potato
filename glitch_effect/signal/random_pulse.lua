local M = { last_pulse = false }
math.randomseed(os.time())

function M.poll()
    -- 10% chance to pulse each tick
    M.last_pulse = (math.random() < 0.1)
end

function M.get()
    return M.last_pulse
end

return M
