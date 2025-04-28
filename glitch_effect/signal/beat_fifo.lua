local awful = require("awful")
local FIFO_PATH = "/tmp/audio_beat_fifo"

local M = { last_beat = false }
function M.poll(callback)
    awful.spawn.easy_async_with_shell("timeout 0.1 cat " .. FIFO_PATH, function(stdout, stderr)
        if stderr and #stderr > 0 then
            callback(false)
            return
        end
        local beat = stdout and stdout:match("1") and true or false
        M.last_beat = beat
        callback(beat)
    end)
end
function M.get() return M.last_beat end
return M
