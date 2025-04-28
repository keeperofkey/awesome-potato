local gears = require("gears")
local M = {}
local fifo_path = "/tmp/beatnet_fifo"
local last_beat = false
local last_downbeat = false

function M.get()
    return last_beat, last_downbeat
end

local function poll_fifo()
    local f = io.open(fifo_path, "r")
    if not f then return end
    for line in f:lines() do
        if line == "beat" then
            last_beat = true
            last_downbeat = false
        elseif line == "downbeat" then
            last_beat = true
            last_downbeat = true
        end
    end
    f:close()
end

gears.timer({
    timeout = 0.05,
    autostart = true,
    call_now = true,
    callback = function()
        poll_fifo()
        last_beat = false
        last_downbeat = false
    end,
})

return M