local naughty = require("naughty")
local gears = require("gears")

-- Initialize counters
local audio_count = 0
local fft_count = 0
local last_level = 0

-- Set up signal listeners
awesome.connect_signal("glitch::audio", function(level)
    audio_count = audio_count + 1
    last_level = level
    
    -- Show minimal debug info to avoid spamming
    if audio_count % 10 == 0 then
        naughty.notify({
            title = "DEBUG: Audio Signal",
            text = string.format("Count: %d, Level: %.3f", audio_count, level),
            timeout = 1
        })
    end
end)

awesome.connect_signal("glitch::fft", function(bands)
    fft_count = fft_count + 1
end)

-- Create status timer that runs regardless of other code
gears.timer({
    timeout = 3,
    autostart = true,
    callback = function()
        naughty.notify({
            title = "Signal Status",
            text = string.format(
                "Audio signals: %d\nFFT signals: %d\nLast level: %.4f",
                audio_count, fft_count, last_level
            ),
            timeout = 2
        })
        return true
    end
})

-- Return a no-op module
return {}