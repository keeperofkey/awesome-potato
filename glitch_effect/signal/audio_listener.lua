-- audio_listener.lua
pcall(require, "luarocks.loader")
local ljack = require("ljack")
local auproc = require("auproc")
local mtmsg = require("mtmsg")
local fft = require("luafft")
local bit = require("bit")
local naughty = require("naughty")

-- Open JACK client
local client, err = ljack.client_open("awesome_audio")
if not client then
    naughty.notify{title = "Audio Listener", text = "Failed to open JACK client: " .. tostring(err)}
    return
end
client:activate()

-- Register audio and MIDI input ports
local in_l = client:port_register("in_left",  "AUDIO", "IN")
local in_r = client:port_register("in_right", "AUDIO", "IN")
local midi_in = client:port_register("midi_in", "MIDI", "IN")

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

-- FFT configuration
local fft_size = 1024
local fft_buffer = {}

-- Helper to compute average magnitude in a band
local function band_avg(s, e, spectrum)
    local sum = 0
    for i = s, e do
        local c = spectrum[i]
        sum = sum + math.sqrt(c.re * c.re + c.im * c.im)
    end
    return sum / (e - s + 1)
end

-- Main loop
while true do
    -- Get next audio buffers (blocking)
    local _, samples_l = buf_audio_l:nextmsg()
    local _, samples_r = buf_audio_r:nextmsg()
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

    -- FFT processing
    if #fft_buffer >= fft_size then
        local segment = {}
        for i = 1, fft_size do segment[i] = fft_buffer[i] end
        -- shift buffer
        for i = 1, fft_size do table.remove(fft_buffer, 1) end
        local spectrum = fft(segment)
        local low  = band_avg(1,        math.floor(fft_size/8),    spectrum)
        local mid  = band_avg(math.floor(fft_size/8)+1, math.floor(fft_size/4), spectrum)
        local high = band_avg(math.floor(fft_size/4)+1, math.floor(fft_size/2), spectrum)
        awesome.emit_signal("glitch::fft", {low = low, mid = mid, high = high})
    end
end