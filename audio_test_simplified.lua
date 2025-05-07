-- Simple Audio Test Module
local awful = require("awful")
local naughty = require("naughty")
local config = require("config")
local modkey = config.modkey

-- Load our modules
local pipewire_test = require("pipewire_test")
local synthetic_audio = require("synthetic_audio")

-- Add test keybindings
awful.keyboard.append_global_keybindings({
  -- Test simplified audio capture (Mod+Alt+1)
  awful.key({ modkey, "Mod1" }, "1", function()
    local success = pipewire_test.init()
    if success then
      naughty.notify {
        title = "Audio Test",
        text = "Simple audio capture started",
        timeout = 5
      }
    else
      naughty.notify {
        title = "Audio Test Error",
        text = "Simple audio capture failed to start",
        timeout = 5
      }
    end
  end, { description = "test simple audio capture", group = "custom" }),
  
  -- Stop audio capture (Mod+Alt+2)
  awful.key({ modkey, "Mod1" }, "2", function()
    pipewire_test.cleanup()
    naughty.notify {
      title = "Audio Test",
      text = "Simple audio capture stopped",
      timeout = 5
    }
  end, { description = "stop simple audio capture", group = "custom" }),
  
  -- Test synthetic audio (Mod+Alt+3)
  awful.key({ modkey, "Mod1" }, "3", function()
    synthetic_audio.start()
    naughty.notify {
      title = "Audio Test",
      text = "Synthetic audio generator started",
      timeout = 5
    }
  end, { description = "start synthetic audio", group = "custom" }),
  
  -- Stop synthetic audio (Mod+Alt+4)
  awful.key({ modkey, "Mod1" }, "4", function()
    synthetic_audio.stop()
    naughty.notify {
      title = "Audio Test",
      text = "Synthetic audio generator stopped",
      timeout = 5
    }
  end, { description = "stop synthetic audio", group = "custom" }),
  
  -- Enable wave effect (Mod+Alt+5)
  awful.key({ modkey, "Mod1" }, "5", function()
    local effect_core = require("glitch_effect.core")
    effect_core.enable_effect("wave")
    naughty.notify {
      title = "Effect",
      text = "Wave effect enabled",
      timeout = 3
    }
  end, { description = "enable wave effect", group = "custom" }),
  
  -- Display audio status (Mod+Alt+0)
  awful.key({ modkey, "Mod1" }, "0", function()
    local status = "Audio Status:\n"
    
    if pipewire_test.initialized then
      status = status .. "Simple audio capture: Active\n"
    else
      status = status .. "Simple audio capture: Inactive\n"
    end
    
    if synthetic_audio.active then
      status = status .. "Synthetic audio: Active\n"
    else
      status = status .. "Synthetic audio: Inactive\n"
    end
    
    -- Send test signal
    awesome.emit_signal("glitch::audio", 0.8)
    status = status .. "\nSent test signal with level 0.8"
    
    naughty.notify {
      title = "Audio Test",
      text = status,
      timeout = 5
    }
  end, { description = "show audio status", group = "custom" })
})

-- Return a no-op module
return {}