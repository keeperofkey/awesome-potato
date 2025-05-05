-- Rules for client behavior
local awful = require 'awful'
local beautiful = require 'beautiful'

awful.rules.rules = {
  -- All clients will match this rule.
  {
    rule = {},
    properties = {
      border_width = beautiful.border_width,
      border_color = beautiful.border_normal,
      focus = awful.client.focus.filter,
      raise = true,
      keys = clientkeys,
      buttons = clientbuttons,
      screen = awful.screen.preferred,
      placement = awful.placement.no_overlap + awful.placement.no_offscreen,
    },
  },

  -- Floating clients.
  {
    rule_any = {
      class = {
        'Arandr',
        'Blueman-manager',
        'Gpick',
      },
    },
    properties = { floating = true },
  },
}

return {}