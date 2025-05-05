-- Main AwesomeWM configuration file
pcall(require, 'luarocks.loader')

local naughty = require 'naughty'
local hotkeys_popup = require 'awful.hotkeys_popup'
require 'awful.hotkeys_popup.keys'
-- -- Error handling
if awesome.startup_errors then
  naughty.notify {
    preset = naughty.config.presets.critical,
    title = 'Oops, there were errors during startup!',
    text = awesome.startup_errors,
  }
end

-- Handle runtime errors after startup
do
  local in_error = false
  awesome.connect_signal('debug::error', function(err)
    -- Make sure we don't go into an endless error loop
    if in_error then
      return
    end
    in_error = true

    naughty.notify {
      preset = naughty.config.presets.critical,
      title = 'Oops, an error happened!',
      text = tostring(err),
    }
    in_error = false
  end)
end
-- naughty.connect_signal('request::display_error', function(message, startup)
--   naughty.notification {
--     urgency = 'critical',
--     title = 'Oops, an error happened' .. (startup and ' during startup!' or '!'),
--     message = message,
--   }
-- end)

require 'beauty' -- Theme settings before ui
require 'binds'
require 'config'
require 'ui'
require 'rules'
require 'autostart'
require 'glitch'
