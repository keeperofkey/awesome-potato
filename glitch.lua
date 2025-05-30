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
local spectral_slide = require 'glitch_effect.effects.spectral_slide'

-- Register effects
effect_core.register_effect('glide', glide)
effect_core.register_effect('corner_resize', corner_resize)
effect_core.register_effect('hack', hack)
effect_core.register_effect('wave', wave)
effect_core.register_effect('spectral_slide', spectral_slide)
-- Store current context
local current_context = {
  rms = 0, -- RMS
  mfcc0 = 0, -- MFCC[0]
  zcr = 0, -- Zero-Crossing Rate
  contrast = 0, -- Spectral Contrast (optional)
  beat = 0, -- Beat (optional)
  bpm = 0, -- BPM (optional)
  melspec_mean = 0, -- Mel-spectrogram mean (optional)
  poly_mean = 0, -- Poly features (optional)

}

-- Update context with audio signals
awesome.connect_signal('glitch::rms', function(val)
  current_context.rms = val
  -- naughty.notify {
  --   title = 'Signal: RMS',
  --   text = tostring(val),
  --   timeout = 1,
  -- }
end)
awesome.connect_signal('glitch::mfcc0', function(val)
  current_context.mfcc0 = val
  -- naughty.notify {
  --   title = 'Signal: MFCC0',
  --   text = tostring(val),
  --   timeout = 1,
  -- }

end)
awesome.connect_signal('glitch::zcr', function(val)
  current_context.zcr = val
  -- naughty.notify {
  --   title = 'Signal: ZCR',
  --   text = tostring(val),
  --   timeout = 1,
  -- }
end)

awesome.connect_signal('glitch::contrast', function(val)

  current_context.contrast = val
  -- naughty.notify {
  --   title = 'Signal: Spectral Contrast',
  --   text = tostring(val),
  --   timeout = 1,
  -- }
end)
awesome.connect_signal('glitch::beat', function(val)
  current_context.beat = val
end)
awesome.connect_signal('glitch::bpm', function(val)
  current_context.bpm = val
end)
awesome.connect_signal('glitch::melspec_mean', function(val)
  current_context.melspec_mean = val
end)
awesome.connect_signal('glitch::poly_mean', function(val)
  -- Parse comma-separated string into a Lua table
  local t = {}
  for num in string.gmatch(val, '([^,]+)') do
    table.insert(t, tonumber(num))
  end
  current_context.poly_mean = t
end)

-- Create context function to pass audio signals
local function create_context()
  return current_context
end

-- Start effects with context function
effect_core.start(create_context)

-- Path to Python script
-- local script_path = os.getenv 'HOME' .. '/.config/awesome/glitch_effect/signal/audio_analyzer.py'

-- -- Make sure script is executable
-- awful.spawn.with_shell(script_path)


awful.keyboard.append_global_keybindings {
  awful.key({ modkey, 'Mod1' }, 'x', function()
    -- Emit a test signal directly
    awesome.emit_signal('glitch::rms', 0.8)
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

  awful.key({ modkey, 'Mod1' }, 's', function()
    if effect_core.is_effect_enabled 'spectral_slide' then
      effect_core.disable_effect 'spectral_slide'
      naughty.notify { title = 'Spectral Slide', text = 'Disabled' }
    else
      effect_core.enable_effect 'spectral_slide'
      naughty.notify { title = 'Spectral Slide', text = 'Enabled' }
    end
  end),

  awful.key({ modkey, 'Mod1' }, 'w', function()
    if effect_core.is_effect_enabled 'wave' then
      effect_core.disable_effect 'wave'
      naughty.notify { title = 'Wave', text = 'Disabled' }
    else
      -- -- notify the rms value
      -- if current_context.rms then
      --   naughty.notify { title = 'RMS', text = tostring(current_context.rms) }
      -- end
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
