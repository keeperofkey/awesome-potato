-- Simple Audio Capture Module
-- Uses command-line tools to capture audio levels without FFI complexity

local gears = require("gears")
local naughty = require("naughty")
local awful = require("awful")

local simple_audio = {
  initialized = false,
  timer = nil,
  volume_cmd = "pactl list sources | grep -A 15 RUNNING | grep -m 1 'Volume:' | awk '{print $5}' | sed 's/%//'"
}

-- Start audio monitoring
function simple_audio.init(device)
  if simple_audio.initialized then
    return true
  end
  
  -- If a device was specified, modify our command
  if device and type(device) == "string" then
    -- Extract just the source name from the device string
    local source_name = device:match("([^%s]+)$")
    if source_name then
      simple_audio.volume_cmd = "pactl list sources | grep -A 15 '" .. source_name .. "' | grep -m 1 'Volume:' | awk '{print $5}' | sed 's/%//'"
    end
  end
  
  -- Always start our timer, even if pactl fails (fallback)
  local started = false
  
  -- Check if we have the necessary tools
  awful.spawn.easy_async("which pactl", function(stdout, stderr, reason, exit_code)
    if exit_code ~= 0 then
      naughty.notify {
        title = "Simple Audio Warning",
        text = "Missing pactl, using fallback mode",
        timeout = 5
      }
      -- Don't return, we'll use the fallback
    end
    
    -- Start monitoring timer
    simple_audio.timer = gears.timer {
      timeout = 0.1, -- 100ms
      autostart = true,
      callback = function()
        -- Get current audio level
        awful.spawn.easy_async(simple_audio.volume_cmd, function(stdout, stderr, reason, exit_code)
          local level = 0.1 -- Default fallback level
          
          if exit_code == 0 and stdout then
            -- Parse volume percentage
            local volume = tonumber(stdout:match("(%d+)"))
            if volume then
              -- Convert to 0-1 range
              level = volume / 100
            end
          end
          
          -- Always send a signal, even if we couldn't get the volume
          awesome.emit_signal("glitch::audio", level)
          
          -- Generate simple frequency bands based on level
          local bands = {
            low = level * 0.8,
            mid = level * 0.6,
            high = level * 0.4
          }
          awesome.emit_signal("glitch::fft", bands)
        end)
        
        return true
      end
    }
    
    simple_audio.initialized = true
    
    naughty.notify {
      title = "Simple Audio",
      text = "Started simple audio monitoring",
      timeout = 3
    }
    
    -- After 5 seconds, check if we're getting signals
    gears.timer.start_new(5, function()
      awesome.emit_signal("glitch::audio", 0.8) -- Send a test signal
      naughty.notify {
        title = "Simple Audio",
        text = "Sent test signal (0.8)",
        timeout = 2
      }
      return false -- Only send once
    end)
  end)
  
  return true
end

-- Stop audio monitoring
function simple_audio.cleanup()
  if not simple_audio.initialized then
    return
  end
  
  if simple_audio.timer then
    simple_audio.timer:stop()
    simple_audio.timer = nil
  end
  
  simple_audio.initialized = false
  
  naughty.notify {
    title = "Simple Audio",
    text = "Stopped simple audio monitoring",
    timeout = 3
  }
end

-- Return module
return simple_audio