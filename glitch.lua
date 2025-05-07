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

local random_pulse = require 'glitch_effect.signal.random_pulse'
-- Register effects
local pipewire = require 'glitch_effect.signal.pipewire_native'

effect_core.register_effect('glide', glide)
effect_core.register_effect('corner_resize', corner_resize)
effect_core.register_effect('hack', hack)
effect_core.register_effect('wave', wave)

-- Create context function to pass audio signals
local function create_context()
    return {
        audio_level = nil,
        frequency_bands = nil,
        tick = os.time()  -- Use os.time() instead of gears.timer.now()
    }
end

-- Store current context
local current_context = create_context()

-- Update context with audio signals
awesome.connect_signal("glitch::audio", function(level)
    current_context.audio_level = level
end)

awesome.connect_signal("glitch::fft", function(bands)
    current_context.frequency_bands = bands
end)

-- Start effects with context function
pipewire.init()
effect_core.start()

-- Subscribe to MIDI note-on triggers
-- awesome.connect_signal("glitch::midi", function(note)
--     -- retrigger a random pulse
--     random_pulse.trigger()
-- end)

awful.keyboard.append_global_keybindings {
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
  -- awful.key({ modkey, "Mod1" }, "l", function()
  --     if effect_core.is_effect_enabled("glitch") then
  --         effect_core.disable_effect("glitch")
  --         naughty.notify({ title = "Glitch", text = "Disabled" })
  --     else
  --         effect_core.enable_effect("glitch")
  --         naughty.notify({ title = "Glitch", text = "Enabled" })
  --     end
  -- end),
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
