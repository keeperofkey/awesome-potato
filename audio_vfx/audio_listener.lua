-- Audio listener module for AwesomeWM
-- Listens for audio analysis data from audio_vfx

local gears = require("gears")
local naughty = require("naughty")
local socket = require("socket")
local unix = require("socket.unix")

-- Path to UNIX socket for communication
local socket_path = "/tmp/audio_vfx.sock"

-- Socket client variable
local client = nil

-- Connect to the UNIX socket (non-blocking)
function connect_socket()
    if client then
        client:close()
        client = nil
    end
    local c, err = unix()
    if not c then
        naughty.notify{title = "Audio Listener", text = "Socket error: " .. tostring(err)}
        return
    end
    local ok, conn_err = c:connect(socket_path)
    if not ok then
        naughty.notify{title = "Audio Listener", text = "Failed to connect: " .. tostring(conn_err)}
        return
    end
    c:settimeout(0) -- non-blocking
    client = c
end

-- Simple JSON parser for our needs (no external dependencies)
local json = {}
json.decode = function(str)
    if not str or str == "" then return nil end
    
    -- Create a table to hold our data
    local data = {}
    
    -- Match patterns like "volume":0.123
    local volume = string.match(str, '"volume":([%d%.]+)')
    if volume then data.volume = tonumber(volume) end
    
    -- Match patterns like "beat":true or "beat":false
    local beat = string.match(str, '"beat":(true|false)')
    if beat then data.beat = (beat == "true") end
    
    -- Match patterns like "peak":true or "peak":false
    local peak = string.match(str, '"peak":(true|false)')
    if peak then data.peak = (peak == "true") end
    
    return data
end

-- Table to hold the latest audio data
local audio_data = {
    volume = 0,
    peak = false,
    beat = false,
    fft = {}
}


-- Debug notification function
local function notify(title, text)
    naughty.notify({
        title = title or "Audio VFX",
        text = text or "",
        timeout = 5
    })
end

-- Read from socket (non-blocking)
local function read_socket()
    if not client then return nil end
    local data, err, partial = client:receive("*l")
    if data then
        return data
    elseif err == "closed" then
        connect_socket() -- try to reconnect next time
        return nil
    elseif partial and #partial > 0 then
        return partial
    end
    return nil
end

-- Timer to poll socket for new messages
gears.timer {
    timeout = 0.05, -- 50ms, ~20 FPS
    autostart = true,
    call_now = true,
    callback = function()
        if not client then connect_socket() end
        local data = read_socket()
        if data and #data > 0 then
            -- Try to parse JSON data
            local parsed, _, err = json.decode(data)
            if parsed then
                -- Update the global table
                audio_data = parsed
                -- Uncomment for debugging:
                -- if parsed.beat then
                --     notify("Beat detected", "Volume: " .. tostring(parsed.volume))
                -- end
            elseif err then
                -- Uncomment to debug JSON errors:
                -- notify("JSON Error", err)
            end
        end
    end
}

-- On startup notification
-- notify("Audio Listener", "Started")

-- Export audio_data for use elsewhere
return {
    audio_data = audio_data
}