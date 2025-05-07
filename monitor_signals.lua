-- Signal monitor for debugging glitch effect audio signals
local naughty = require("naughty")
local gears = require("gears")

local signal_monitor = {
  active = false,
  timer = nil,
  notification = nil,
  last_audio_level = 0,
  last_bands = { low = 0, mid = 0, high = 0 },
  audio_signals_received = 0,
  fft_signals_received = 0,
  last_audio_time = 0,
  last_fft_time = 0
}

-- Start monitoring function with improved visualization
function signal_monitor.start()
  if signal_monitor.active then
    return
  end
  
  -- Reset counters
  signal_monitor.audio_signals_received = 0
  signal_monitor.fft_signals_received = 0
  signal_monitor.last_audio_time = 0
  signal_monitor.last_fft_time = 0
  signal_monitor.last_audio_level = 0
  signal_monitor.active = true
  
  -- Create a persistent notification for visualizing levels
  signal_monitor.notification = naughty.notify {
    title = "Audio Monitor",
    text = "Starting audio signal monitor...",
    timeout = 0  -- Persistent
  }
  
  -- Add signal listeners with counters
  signal_monitor.audio_handler = function(level)
    signal_monitor.audio_signals_received = signal_monitor.audio_signals_received + 1
    signal_monitor.last_audio_time = os.time()
    signal_monitor.last_audio_level = level
  end
  
  signal_monitor.fft_handler = function(bands)
    signal_monitor.fft_signals_received = signal_monitor.fft_signals_received + 1
    signal_monitor.last_fft_time = os.time()
    signal_monitor.last_bands = bands
  end
  
  -- Connect to signals
  awesome.connect_signal("glitch::audio", signal_monitor.audio_handler)
  awesome.connect_signal("glitch::fft", signal_monitor.fft_handler)
  
  -- Create visualization timer
  signal_monitor.timer = gears.timer {
    timeout = 0.1,  -- 10Hz for smooth visualization
    autostart = true,
    starttime = os.time(),  -- Track when we started
    callback = function()
      if not signal_monitor.active or not signal_monitor.notification then
        return false
      end
      
      local now = os.time()
      local audio_age = now - signal_monitor.last_audio_time
      local fft_age = now - signal_monitor.last_fft_time
      
      -- Create nice ASCII bar graph
      local bar_length = 20
      local level_filled = math.floor(signal_monitor.last_audio_level * bar_length)
      local level_bar = ""
      
      for i = 1, bar_length do
        if i <= level_filled then
          level_bar = level_bar .. "▓"
        else
          level_bar = level_bar .. "░"
        end
      end
      
      -- Create bars for frequency bands
      local bands = signal_monitor.last_bands
      local bars = {}
      
      for _, band_name in ipairs({"low", "mid", "high"}) do
        local filled = math.floor((bands[band_name] or 0) * bar_length)
        local bar = ""
        
        for i = 1, bar_length do
          bar = bar .. (i <= filled and "▓" or "░")
        end
        
        bars[band_name] = bar
      end
      
      -- Update notification text
      signal_monitor.notification.text = string.format(
        "Audio Level: %.2f %s\n%s\n\n" ..
        "Low: %.2f %s\n%s\n\n" ..
        "Mid: %.2f %s\n%s\n\n" ..
        "High: %.2f %s\n%s\n\n" ..
        "Signals: Audio=%d, FFT=%d\n" ..
        "Rate: ~%.1f signals/sec",
        
        signal_monitor.last_audio_level,
        audio_age > 3 and "(STALE!)" or "",
        level_bar,
        
        bands.low or 0,
        fft_age > 3 and "(STALE!)" or "",
        bars.low,
        
        bands.mid or 0,
        fft_age > 3 and "(STALE!)" or "",
        bars.mid,
        
        bands.high or 0,
        fft_age > 3 and "(STALE!)" or "",
        bars.high,
        
        signal_monitor.audio_signals_received,
        signal_monitor.fft_signals_received,
        signal_monitor.audio_signals_received / math.max(1, os.time() - signal_monitor.timer.starttime)
      )
      
      -- Show diagnostics if no signals
      if signal_monitor.audio_signals_received == 0 and now - signal_monitor.timer.starttime > 5 then
        naughty.notify({
          title = "No Audio Signals",
          text = "No audio signals detected. Possible issues:\n" ..
                 "1. Audio capture is not working\n" ..
                 "2. No audio is playing\n" ..
                 "3. Volume is muted\n\n" ..
                 "Try restarting the audio module or use synthetic audio.",
          timeout = 5
        })
      end
      
      return true  -- Keep the timer running
    end
  }
  
  naughty.notify({
    title = "Signal Monitor",
    text = "Signal monitoring started with visual display.",
    timeout = 3
  })
end

-- Stop monitoring function
function signal_monitor.stop()
  if not signal_monitor.active then
    return
  end
  
  signal_monitor.active = false
  
  -- Disconnect signal handlers
  awesome.disconnect_signal("glitch::audio", signal_monitor.audio_handler)
  awesome.disconnect_signal("glitch::fft", signal_monitor.fft_handler)
  
  -- Stop the timer
  if signal_monitor.timer then
    signal_monitor.timer:stop()
    signal_monitor.timer = nil
  end
  
  -- Remove the notification
  if signal_monitor.notification then
    naughty.destroy(signal_monitor.notification)
    signal_monitor.notification = nil
  end
  
  naughty.notify({
    title = "Signal Monitor",
    text = "Signal monitoring stopped.",
    timeout = 3
  })
end

return signal_monitor