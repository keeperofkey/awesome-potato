-- audio_listener.lua
pcall(require, "luarocks.loader")
local ljack = require("ljack")
local auproc = require("auproc")
local mtmsg = require("mtmsg")
local gears = require("gears")
local bit = require("bit")
local naughty = require("naughty")

-- Implement a simple FFT-like spectrum analysis without external dependencies
local function simple_fft(data)
    local n = #data
    local spectrum = {}
    for i = 1, n/2 do
        local sum_re = 0
        local sum_im = 0
        for j = 1, n do
            local angle = 2 * math.pi * (j-1) * (i-1) / n
            sum_re = sum_re + data[j] * math.cos(angle)
            sum_im = sum_im + data[j] * math.sin(angle)
        end
        spectrum[i] = math.sqrt(sum_re^2 + sum_im^2)
    end
    return spectrum
end

-- Open JACK client
local client, err = ljack.client_open("awesome_audio")
if not client then
    naughty.notify{title = "Audio Listener", text = "Failed to open JACK client: " .. tostring(err)}
    return
end

-- Register audio and MIDI input ports
local in_l = client:port_register("awesome_audio_in_left",  "AUDIO", "IN")
if not in_l then naughty.notify{title = "Audio Listener", text = "Failed to register in_left"} end
local in_r = client:port_register("awesome_audio_in_right", "AUDIO", "IN")
if not in_r then naughty.notify{title = "Audio Listener", text = "Failed to register in_right"} end
local midi_in = client:port_register("awesome_audio_midi_in", "MIDI", "IN")
if not midi_in then naughty.notify{title = "Audio Listener", text = "Failed to register midi_in"} end

-- Register loopback output ports
local loopback_out_l = client:port_register("awesome_loopback_out_left", "AUDIO", "OUT")
local loopback_out_r = client:port_register("awesome_loopback_out_right", "AUDIO", "OUT")

if not loopback_out_l or not loopback_out_r then
    naughty.notify{title = "Audio Listener", text = "Failed to register loopback ports"}
    return
end

-- Connect loopback ports to input ports
local success = client:connect("awesome_loopback_out_left", "awesome_audio_in_left")
if not success then
    naughty.notify{title = "Audio Connection", text = "Failed to connect loopback left"}
end

success = client:connect("awesome_loopback_out_right", "awesome_audio_in_right")
if not success then
    naughty.notify{title = "Audio Connection", text = "Failed to connect loopback right"}
end

-- Debug: notify port objects and names
naughty.notify{
    title = "Audio Listener Debug",
    text = string.format(
        "in_l: %s\nin_r: %s\nmidi_in: %s",
        tostring(in_l), tostring(in_r), tostring(midi_in)
    )
}
-- if in_l and in_l.name and in_l:name() then
--     naughty.notify{title = "Port Name", text = "in_left: " .. tostring(in_l:name())}
-- end
-- if in_r and in_r.name and in_r:name() then
--     naughty.notify{title = "Port Name", text = "in_right: " .. tostring(in_r:name())}
-- end
-- if midi_in and midi_in.name and midi_in:name() then
--     naughty.notify{title = "Port Name", text = "midi_in: " .. tostring(midi_in:name())}
-- end


-- Create message buffers for processors
local buf_audio_l = mtmsg.newbuffer()
local buf_audio_r = mtmsg.newbuffer()
local buf_midi    = mtmsg.newbuffer()

-- Create and activate processor objects
local recv_l = auproc.new_audio_receiver(in_l, buf_audio_l)
local recv_r = auproc.new_audio_receiver(in_r, buf_audio_r)
local midi_recv = auproc.new_midi_receiver(midi_in, buf_midi)

recv_l:activate()
recv_r:activate()
midi_recv:activate()

-- Activate JACK client after ports and receivers are set up
client:activate()

-- Debug: list all JACK ports containing 'awesome_audio' after activation
if ljack and ljack.get_ports then
    local all_ports = ljack.get_ports()
    local aa_ports = {}
    for i, p in ipairs(all_ports or {}) do
        if tostring(p):match("awesome_audio") then
            local pname = p.name and p:name() or tostring(p)
            table.insert(aa_ports, pname)
        end
    end
    naughty.notify{
        title = "Audio Listener Debug",
        text = (#aa_ports > 0) and ("JACK ports with 'awesome_audio':\n" .. table.concat(aa_ports, "\n")) or "No JACK ports found for awesome_audio."
    }
end


-- FFT configuration
local fft_size = 1024
local fft_buffer = {}

-- Helper to compute average magnitude in a band
local function band_avg(s, e, spectrum)
    local sum = 0
    for i = s, e do
        sum = sum + spectrum[i]
    end
    return sum / (e - s + 1)
end

-- Main processing function
gears.timer.start_new(0, function()
    -- Get next audio buffers (non-blocking)
    local _, samples_l = buf_audio_l:nextmsg(0)
    local _, samples_r = buf_audio_r:nextmsg(0)
    if not samples_l or not samples_r then return true end
    
    local n_l = samples_l:len()
    local n_r = samples_r:len()
    local n = math.min(n_l, n_r)

    -- RMS and FFT buffer collection
    local sum = 0
    for i = 1, n do
        local v = samples_l:get(i) + samples_r:get(i)
        sum = sum + v * v
        fft_buffer[#fft_buffer + 1] = v
    end
    local rms = math.sqrt(sum / (2 * n))
    awesome.emit_signal("glitch::audio", rms)

    -- Handle MIDI events (non-blocking)
    while true do
        local time, data = buf_midi:nextmsg(0)
        if not time then break end
        if data:len() >= 3 then
            local status = bit.band(data:get(1), 0xF0)
            if status == 0x90 and data:get(3) > 0 then
                awesome.emit_signal("glitch::midi", data:get(2))
            end
        end
    end

    -- Simple spectrum analysis
    if #fft_buffer >= fft_size then
        local segment = {}
        for i = 1, fft_size do segment[i] = fft_buffer[i] end
        -- shift buffer
        for i = 1, fft_size do table.remove(fft_buffer, 1) end
        
        local spectrum = simple_fft(segment)
        -- Calculate band averages
        local low  = band_avg(1,        math.floor(fft_size/16),    spectrum)
        local mid  = band_avg(math.floor(fft_size/16)+1, math.floor(fft_size/8), spectrum)
        local high = band_avg(math.floor(fft_size/8)+1, math.floor(fft_size/4), spectrum)
        awesome.emit_signal("glitch::fft", {low = low, mid = mid, high = high})
    end

    return true -- Keep the timer running
end)

-- Cleanup function when AwesomeWM exits
awesome.connect_signal("exit", function()
    client:deactivate()
    client:close()
end)