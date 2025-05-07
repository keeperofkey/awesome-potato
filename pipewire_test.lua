-- PipeWire Test Module - Simplified implementation
local gears = require("gears")
local naughty = require("naughty")
local awful = require("awful")

-- Global state
local test = {
  initialized = false,
  timer = nil
}

-- Process audio data using simple shell commands
local function capture_audio_level()
  awful.spawn.easy_async("pactl list sources | grep -A 15 RUNNING | grep -m 1 'Volume:' | awk '{print $5}' | sed 's/%//'", 
    function(stdout, stderr, reason, exit_code)
      local level = 0.1 -- Default fallback level
          
      if exit_code == 0 and stdout then
        -- Parse volume percentage
        local volume = tonumber(stdout:match("(%d+)"))
        if volume then
          -- Convert to 0-1 range and add some amplification
          level = (volume / 100) * 1.5
          -- Clamp between 0-1
          level = math.min(math.max(level, 0), 1)
        end
      end
      
      -- Send audio level signal
      awesome.emit_signal("glitch::audio", level)
      
      -- Generate simple frequency bands based on level
      -- Enhanced to make visualization more interesting
      local bands = {
        low = math.min(level * 1.2, 1.0), -- Emphasize bass
        mid = math.min(level * 0.8, 1.0),
        high = math.min(level * 0.6, 1.0)
      }
      awesome.emit_signal("glitch::fft", bands)
    end
  )
end

-- Initialize the test
function test.init()
  if test.initialized then
    return true
  end

  -- Test if pactl is available
  awful.spawn.easy_async("which pactl", function(stdout, stderr, reason, exit_code)
    if exit_code ~= 0 then
      naughty.notify {
        title = "PipeWire Test Error",
        text = "Command 'pactl' not found. Please install pulseaudio-utils package.",
        timeout = 10
      }
      return false
    end
    
    -- Start polling timer at higher frequency (20Hz)
    test.timer = gears.timer {
      timeout = 0.05,
      autostart = true,
      callback = function()
        capture_audio_level()
        return true
      end
    }
    
    test.initialized = true
    
    naughty.notify {
      title = "Audio Reactive",
      text = "Simple audio monitoring started",
      timeout = 3
    }
    
    -- Send initial test signal
    awesome.emit_signal("glitch::audio", 0.8)
    awesome.emit_signal("glitch::fft", {low = 0.9, mid = 0.7, high = 0.5})
  end)
  
  return true
end

-- Cleanup
function test.cleanup()
  if not test.initialized then
    return
  end
  
  if test.timer then
    test.timer:stop()
    test.timer = nil
  end
  
  test.initialized = false
  
  naughty.notify {
    title = "Audio Reactive",
    text = "Audio monitoring stopped",
    timeout = 3
  }
end

-- Return the module
return test