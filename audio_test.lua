-- Audio Test Module
-- Provides testing tools for the glitch effect audio system

local awful = require("awful")
local naughty = require("naughty")
local config = require("config")
local modkey = config.modkey

-- Load our modules
local pipewire_test = require("pipewire_test")
local synthetic_audio = require("synthetic_audio")

-- Add test keybindings
awful.keyboard.append_global_keybindings({
  -- Test PipeWire (Mod+Alt+p)
  awful.key({ modkey, "Mod1" }, "p", function()
    local success = pipewire_test.init()
    if success then
      naughty.notify {
        title = "PipeWire Test",
        text = "PipeWire test initialized successfully",
        timeout = 5
      }
    else
      naughty.notify {
        title = "PipeWire Test",
        text = "PipeWire test initialization failed",
        timeout = 5
      }
    end
  end, { description = "test PipeWire initialization", group = "custom" }),
  
  -- Synthetic Audio (Mod+Alt+y)
  awful.key({ modkey, "Mod1" }, "y", function()
    synthetic_audio.toggle()
  end, { description = "toggle synthetic audio generator", group = "custom" }),
  
  -- Manual Signal (Mod+Alt+x)
  awful.key({ modkey, "Mod1" }, "x", function()
    local level = 0.8
    awesome.emit_signal("glitch::audio", level)
    
    local bands = {
      low = 0.9,
      mid = 0.6,
      high = 0.3
    }
    awesome.emit_signal("glitch::fft", bands)
    
    naughty.notify {
      title = "Manual Signal",
      text = string.format("Sent test audio signal (%.1f)", level),
      timeout = 2
    }
  end, { description = "send manual test signal", group = "custom" })
})

-- Return a no-op module
return {}