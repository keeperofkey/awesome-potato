local awful = require 'awful'
local config = require 'config'
local naughty = require 'naughty'
local gears = require 'gears'
local modkey = config.modkey

local effect_core = require 'glitch_effect.core'
local wave = require 'glitch_effect.effects.wave'
local hack = require 'glitch_effect.effects.hack'
local glide = require 'glitch_effect.effects.glide'
local corner_resize = require 'glitch_effect.effects.corner_resize'

-- Register effects
effect_core.register_effect('glide', glide)
effect_core.register_effect('corner_resize', corner_resize)
effect_core.register_effect('hack', hack)
effect_core.register_effect('wave', wave)

-- Create context function to pass audio signals
local function create_context()
  return {
    audio_level = nil,
    frequency_bands = nil,
    tick = os.time()
  }
end

-- Store current context
local current_context = create_context()

-- Update context with audio signals
awesome.connect_signal('glitch::audio', function(level)
  current_context.audio_level = level
end)

awesome.connect_signal('glitch::fft', function(bands)
  current_context.frequency_bands = bands
end)

-- Start effects with context function
effect_core.start(create_context)

-- Path to Python script
local script_path = os.getenv("HOME") .. "/.config/awesome/glitch_effect/signal/audio_analyzer.py"

-- Make sure script is executable
awful.spawn.with_shell("chmod +x " .. script_path)

-- Variable to keep track of the audio process
local audio_process = nil

-- Function to start audio processing
local function start_audio_processor()
  if audio_process then
    naughty.notify {
      title = 'Audio Processor',
      text = 'Audio processor already running',
      timeout = 2,
    }
    return
  end
  
  -- Start the Python script in a terminal for visibility
  audio_process = awful.spawn.with_shell("python3 " .. script_path)
  
  naughty.notify {
    title = 'Audio Processor',
    text = 'Started audio processor with Python',
    timeout = 3,
  }
end

-- Function to stop audio processing
local function stop_audio_processor()
  if not audio_process then
    naughty.notify {
      title = 'Audio Processor',
      text = 'No audio processor running',
      timeout = 2,
    }
    return
  end
  
  -- Kill the Python process
  awful.spawn.with_shell("pkill -f 'python3 " .. script_path .. "'")
  audio_process = nil
  
  naughty.notify {
    title = 'Audio Processor',
    text = 'Stopped audio processor',
    timeout = 3,
  }
end

-- Direct signal generator as fallback
local signal_timer = nil

-- Function to start synthetic signals
local function start_synthetic_signals()
  if signal_timer then
    naughty.notify {
      title = 'Synthetic Signals',
      text = 'Synthetic signals already running',
      timeout = 2,
    }
    return
  end
  
  signal_timer = gears.timer {
    timeout = 0.05, -- 20Hz for smoother animation
    autostart = true,
    callback = function()
      -- Generate a simple pulsing signal
      local time = os.time()
      local level = 0.2 + 0.4 * math.abs(math.sin(time * 0.5))

      -- Send direct audio signal
      awesome.emit_signal('glitch::audio', level)

      -- Send FFT bands signal with different phases for more interesting effects
      local bands = {
        low = 0.5 + 0.5 * math.sin(time * 0.3),        -- Slower
        mid = 0.5 + 0.5 * math.sin(time * 0.5),        -- Medium
        high = 0.5 + 0.5 * math.sin(time * 0.7 + 0.5)  -- Faster with phase shift
      }
      awesome.emit_signal('glitch::fft', bands)

      return true
    end
  }
  
  naughty.notify {
    title = 'Synthetic Signals',
    text = 'Started synthetic audio signals',
    timeout = 3,
  }
end

-- Function to stop synthetic signals
local function stop_synthetic_signals()
  if not signal_timer then
    naughty.notify {
      title = 'Synthetic Signals',
      text = 'No synthetic signals running',
      timeout = 2,
    }
    return
  end
  
  signal_timer:stop()
  signal_timer = nil
  
  naughty.notify {
    title = 'Synthetic Signals',
    text = 'Stopped synthetic audio signals',
    timeout = 3,
  }
end

-- Register cleanup handler for when AwesomeWM exits
awesome.connect_signal('exit', function()
  if audio_process then
    awful.spawn.with_shell("pkill -f 'python3 " .. script_path .. "'")
  end
  
  if signal_timer then
    signal_timer:stop()
  end
end)

-- Start the audio processor by default
start_audio_processor()

-- If the audio processor fails, start synthetic signals after a delay
gears.timer.start_new(5, function() 
  -- Check if we're getting signals
  if not current_context.audio_level then
    naughty.notify {
      title = 'Audio Fallback',
      text = 'No audio signals detected. Starting synthetic signals as fallback.',
      timeout = 5,
    }
    start_synthetic_signals()
  end
  return false -- Only run once
end)

-- Load signal monitor module
local monitor_signals_module = nil
local is_monitoring = false

-- Create a function to toggle signal monitoring
local function toggle_signal_monitor()
  if not monitor_signals_module then
    -- Lazy load the module
    monitor_signals_module = require 'monitor_signals'
  end

  if is_monitoring then
    monitor_signals_module.stop()
    is_monitoring = false
  else
    monitor_signals_module.start()
    is_monitoring = true
  end
end

-- Toggle audio source
local function toggle_audio_source()
  if audio_process then
    -- Stop real audio and use synthetic
    stop_audio_processor()
    start_synthetic_signals()
  else
    -- Stop synthetic and try real audio
    stop_synthetic_signals()
    start_audio_processor()
  end
end

awful.keyboard.append_global_keybindings {
  -- Signal monitoring toggle (Mod+Alt+m)
  awful.key({ modkey, 'Mod1' }, 'm', function()
    toggle_signal_monitor()
  end, { description = 'toggle signal monitoring', group = 'custom' }),
  
  -- Toggle audio source (Mod+Alt+a)
  awful.key({ modkey, 'Mod1' }, 'a', function()
    toggle_audio_source()
  end, { description = 'toggle audio source', group = 'custom' }),

  -- Manual signal trigger (Mod+Alt+s)
  awful.key({ modkey, 'Mod1' }, 's', function()
    -- Emit a test signal directly
    awesome.emit_signal('glitch::audio', 0.8)
    -- Show notification
    naughty.notify {
      title = 'Manual Signal',
      text = 'Manually triggered audio signal (0.8)',
      timeout = 2,
    }
  end, { description = 'manually trigger audio signal', group = 'custom' }),

  -- Per-effect toggles (Mod+Alt+key)
  awful.key({ modkey, 'Mod1' }, 'g', function()
    if effect_core.is_effect_enabled 'glide' then
      effect_core.disable_effect 'glide'
      naughty.notify { title = 'Glide', text = 'Disabled' }
    else
      effect_core.enable_effect 'glide'
      naughty.notify { title = 'Glide', text = 'Enabled' }
    end
  end),
  
  awful.key({ modkey, 'Mod1' }, 'h', function()
    if effect_core.is_effect_enabled 'hack' then
      effect_core.disable_effect 'hack'
      naughty.notify { title = 'Hack', text = 'Disabled' }
    else
      effect_core.enable_effect 'hack'
      naughty.notify { title = 'Hack', text = 'Enabled' }
    end
  end),
  
  awful.key({ modkey, 'Mod1' }, 'w', function()
    if effect_core.is_effect_enabled 'wave' then
      effect_core.disable_effect 'wave'
      naughty.notify { title = 'Wave', text = 'Disabled' }
    else
      effect_core.enable_effect 'wave'
      naughty.notify { title = 'Wave', text = 'Enabled' }
    end
  end),
  
  awful.key({ modkey, 'Mod1' }, 'r', function()
    if effect_core.is_effect_enabled 'corner_resize' then
      effect_core.disable_effect 'corner_resize'
      naughty.notify { title = 'Corner Resize', text = 'Disabled' }
    else
      effect_core.enable_effect 'corner_resize'
      naughty.notify { title = 'Corner Resize', text = 'Enabled' }
    end
  end),
  
  -- Global toggle (Mod+Alt+t)
  awful.key({ modkey, 'Mod1' }, 't', function()
    local effects = { 'glide', 'wave', 'corner_resize', 'hack' }
    local any_enabled = false
    for _, name in ipairs(effects) do
      if effect_core.is_effect_enabled(name) then
        any_enabled = true
        break
      end
    end
    if any_enabled then
      for _, name in ipairs(effects) do
        effect_core.disable_effect(name)
      end
      naughty.notify { title = 'Effects', text = 'All Disabled' }
    else
      for _, name in ipairs(effects) do
        effect_core.enable_effect(name)
      end
      naughty.notify { title = 'Effects', text = 'All Enabled' }
    end
  end, { description = 'toggle effect on all windows', group = 'custom' }),
}