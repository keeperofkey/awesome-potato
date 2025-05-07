-- Synthetic Audio Signal Generator
-- This module generates realistic-looking audio signals without actual audio capture
-- It's useful as a fallback when PipeWire/JACK isn't working

local gears = require("gears")
local naughty = require("naughty")

local synthetic = {
  active = false,
  timer = nil,
  phase = 0,
  last_level = 0.2,
  beat_phase = 0,
  config = {
    -- Adjust these values to change the effect
    base_level = 0.2,         -- Base audio level (min)
    pulse_frequency = 0.05,   -- How fast the main pulse occurs
    beat_frequency = 0.02,    -- Slower "beat" modulation
    variation = 0.3,          -- How much the level varies
    smoothing = 0.7,          -- Level smoothing (0-1, higher = smoother)
    update_rate = 0.025       -- Update interval in seconds (40Hz)
  }
}

-- Start the synthetic signal generator
function synthetic.start()
  if synthetic.active then
    return
  end
  
  synthetic.active = true
  synthetic.phase = 0
  synthetic.beat_phase = 0
  
  synthetic.timer = gears.timer({
    timeout = synthetic.config.update_rate,
    autostart = true,
    callback = function()
      -- Increment phases for various oscillators
      synthetic.phase = synthetic.phase + synthetic.config.pulse_frequency
      synthetic.beat_phase = synthetic.beat_phase + synthetic.config.beat_frequency
      
      -- Create a realistic-looking audio level that varies over time
      -- Combine multiple sine waves at different frequencies for natural variation
      local raw_level = synthetic.config.base_level + 
                      synthetic.config.variation * math.abs(math.sin(synthetic.phase)) +
                      synthetic.config.variation * 0.5 * math.abs(math.sin(synthetic.phase * 0.5 + 0.4)) +
                      synthetic.config.variation * 0.25 * math.abs(math.sin(synthetic.beat_phase))
      
      -- Apply smoothing for more natural transitions
      synthetic.last_level = synthetic.last_level * synthetic.config.smoothing + 
                            raw_level * (1 - synthetic.config.smoothing)
      
      -- Send the audio level signal
      awesome.emit_signal("glitch::audio", synthetic.last_level)
      
      -- Generate realistic-looking frequency bands
      -- These respond differently to the audio level for more interesting effects
      local bands = {
        -- Low frequencies respond strongly to the beat
        low = 0.2 + 0.8 * synthetic.last_level * (0.7 + 0.3 * math.sin(synthetic.beat_phase)),
        
        -- Mid frequencies follow the main level with some variation
        mid = 0.3 + 0.7 * synthetic.last_level * (0.8 + 0.2 * math.sin(synthetic.phase * 1.5)),
        
        -- High frequencies are more sporadic
        high = 0.1 + 0.9 * synthetic.last_level * (0.5 + 0.5 * math.sin(synthetic.phase * 3))
      }
      
      -- Normalize bands relative to each other (optional)
      local max_band = math.max(bands.low, bands.mid, bands.high)
      if max_band > 0 then
        bands.low = bands.low / max_band
        bands.mid = bands.mid / max_band
        bands.high = bands.high / max_band
      end
      
      -- Send the FFT bands signal
      awesome.emit_signal("glitch::fft", bands)
      
      -- Occasionally show status
      if math.floor(synthetic.phase) % 20 == 0 then
        naughty.notify {
          title = "Synthetic Audio",
          text = string.format("Level: %.2f", synthetic.last_level),
          timeout = 1
        }
      end
      
      return true
    end
  })
  
  naughty.notify {
    title = "Synthetic Audio",
    text = "Started synthetic audio signal generator",
    timeout = 3
  }
end

-- Stop the generator
function synthetic.stop()
  if not synthetic.active then
    return
  end
  
  if synthetic.timer then
    synthetic.timer:stop()
    synthetic.timer = nil
  end
  
  synthetic.active = false
  
  naughty.notify {
    title = "Synthetic Audio",
    text = "Stopped synthetic audio signal generator",
    timeout = 3
  }
end

-- Toggle generator state
function synthetic.toggle()
  if synthetic.active then
    synthetic.stop()
  else
    synthetic.start()
  end
end

-- Return the module
return synthetic