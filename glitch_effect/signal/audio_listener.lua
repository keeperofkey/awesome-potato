local socket = require("socket.unix")
local gears = require("gears")
local json = require("dkjson") -- or your preferred JSON library

local sock_path = "/tmp/audio_vfx.sock"

-- Remove the socket file if it already exists (server only)
os.remove(sock_path)

-- Create the server socket
local server = assert(socket())
assert(server:setsockname(sock_path))
server:settimeout(0) -- non-blocking

-- Table to hold the latest audio data
local audio_data = {
    volume = 0,
    peak = false,
    beat = false,
    fft = {}
}

-- Timer to poll for new messages
gears.timer {
    timeout = 0.03, -- ~30 FPS
    autostart = true,
    callback = function()
        local msg = server:receive()
        if msg then
            local data, _, err = json.decode(msg)
            if data then
                -- Update the global table (or trigger your effect logic here)
                audio_data = data
                -- Example: print or trigger effect
                -- naughty.notify({text = "Volume: " .. tostring(data.volume)})
                -- if data.beat then ... end
            end
        end
    end
}

-- Export audio_data for use elsewhere
return {
    audio_data = audio_data
}
