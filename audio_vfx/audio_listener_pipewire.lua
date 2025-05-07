-- audio_listener_pipewire.lua
-- Real-time audio spectrum analysis using PipeWire (pw-cat) and Lua
-- This script streams audio from the default input and analyzes it in real-time

local naughty = require("naughty")
local bit = require("bit")

-- FFT-like spectrum analysis (reuse from your original)
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

-- Parameters
local SAMPLE_RATE = 48000  -- pw-cat default
local CHANNELS = 1         -- mono for simplicity
local SAMPLE_FORMAT = "s16" -- 16-bit signed little-endian (PipeWire format string)
local FRAME_SIZE = 2       -- bytes per sample
local FFT_SIZE = 1024      -- samples per analysis window

-- Create a temporary file for audio capture
local tmpfile = os.tmpname()
local cmd = string.format("pw-cat --record --format %s --rate %d --channels %d %s", SAMPLE_FORMAT, SAMPLE_RATE, CHANNELS, tmpfile)
local pipe = io.popen(cmd, "r")
if not pipe then
    naughty.notify{title = "PipeWire Audio Listener", text = "Failed to start pw-cat"}
    return
end

-- Open the temporary file for reading
local audio_file = io.open(tmpfile, "rb")
if not audio_file then
    naughty.notify{title = "PipeWire Audio Listener", text = "Failed to open temporary audio file"}
    pipe:close()
    return
end

-- Function to clean up temporary file
local function cleanup()
    if audio_file then audio_file:close() end
    if pipe then pipe:close() end
    os.remove(tmpfile)
end

-- Main streaming loop
while true do
    local samples = {}
    for i = 1, FFT_SIZE do
        local bytes = audio_file:read(2)
        if not bytes or #bytes < 2 then break end
        local b1, b2 = bytes:byte(1, 2)
        samples[i] = bytes_to_int16(b1, b2) / 32768.0 -- normalize to [-1,1]
    end
    if #samples < FFT_SIZE then
        break -- end of stream
    end
    local spectrum = simple_fft(samples)
    -- Display or process spectrum (here: print first 8 bins)
    print(string.format("Spectrum: %s", table.concat({unpack(spectrum, 1, 8)}, ", ")))
    -- Optionally, use naughty.notify for UI feedback (rate-limit if needed)
    -- naughty.notify{title = "Spectrum", text = table.concat({unpack(spectrum, 1, 8)}, ", ")}
end

cleanup()

-- Helper to convert 2 bytes (S16LE) to signed integer
local function bytes_to_int16(b1, b2)
    local val = b1 + bit.lshift(b2, 8)
    if val >= 0x8000 then val = val - 0x10000 end
    return val
end

-- Main streaming loop
while true do
    local samples = {}
    for i = 1, FFT_SIZE do
        local bytes = pipe:read(2)
        if not bytes or #bytes < 2 then break end
        local b1, b2 = bytes:byte(1, 2)
        samples[i] = bytes_to_int16(b1, b2) / 32768.0 -- normalize to [-1,1]
    end
    if #samples < FFT_SIZE then
        break -- end of stream
    end
    local spectrum = simple_fft(samples)
    -- Display or process spectrum (here: print first 8 bins)
    print(string.format("Spectrum: %s", table.concat({unpack(spectrum, 1, 8)}, ", ")))
    -- Optionally, use naughty.notify for UI feedback (rate-limit if needed)
    -- naughty.notify{title = "Spectrum", text = table.concat({unpack(spectrum, 1, 8)}, ", ")}
end

pipe:close()
