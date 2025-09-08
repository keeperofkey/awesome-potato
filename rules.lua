-- Rules for client behavior
local awful = require 'awful'
local beautiful = require 'beautiful'
local ruled = require 'ruled'
local naughty = require 'naughty'
-- All clients will match this rule.
ruled.client.append_rule {
  rule = {},
  properties = {
    border_width = beautiful.border_width,
    border_color = beautiful.border_normal,
    focus = awful.client.focus.filter,
    raise = true,
    -- buttons = clientbuttons,
    screen = awful.screen.preferred,
    placement = awful.placement.no_overlap + awful.placement.no_offscreen,
  },
}

-- Floating clients.
ruled.client.append_rule {
  rule_any = {
    instance = {
      'DTA', -- Firefox addon DownThemAll.
      'copyq', -- Includes session name in class.
      'pinentry',
    },
    class = {
      'Arandr',
      'Blueman-manager',
      'Gpick',
      'Kruler',
      'MessageWin', -- kalarm.
      'Sxiv',
      -- 'Tor Browser', -- Needs a fixed window size to avoid fingerprinting by screen size.
      'Wpa_gui',
      'veromix',
      'xtightvncviewer',
    },

    -- Note that the name property shown in xprop might be set slightly after creation of the client
    -- and the name shown there might not match defined rules here.
    name = {
      'Event Tester', -- xev.
    },
    role = {
      'AlarmWindow', -- Thunderbird's calendar.
      'ConfigManager', -- Thunderbird's about:config.
      'pop-up', -- e.g. Google Chrome's (detached) Developer Tools.
    },
  },
  properties = { floating = true },
}

-- Add titlebars to normal clients and dialogs
ruled.client.append_rule {
  rule_any = { type = { 'normal', 'dialog' } },
  properties = { titlebars_enabled = true },
}

-- Force Zen Browser to tile properly
ruled.client.append_rule {
  rule = { class = "zen" },
  properties = { 
    floating = false,
    maximized = false,
    size_hints_honor = false
  },
}
