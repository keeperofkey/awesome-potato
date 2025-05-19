-- Rules for client behavior
local awful = require 'awful'
local beautiful = require 'beautiful'
local ruled = require 'ruled'
local naughty = require 'naughty'
ruled.client.append_rule {
  rule = {},
  properties = {
    border_width = beautiful.border_width,
    border_color = beautiful.border_normal,
    focus = awful.client.focus.filter,
    raise = true,
    keys = clientkeys,
    buttons = clientbuttons,
    -- screen = awful.screen.preferred,
    placement = awful.placement.no_overlap + awful.placement.no_offscreen,
  },
  callback = function(c)
    if not awesome.startup then
      -- Only apply to tiled windows
      if not c.floating then
        -- Get current clients
        local clients = awful.client.tiled(c.screen)
        -- If there's more than 1 existing client, set this one as slave
        if #clients > 1 then
          awful.client.setslave(c)
        end
      end
    end
  end,
}
ruled.client.append_rule {
  rule = { class = 'WallpaperTerminal' },
  properties = {
    floating = true,
    below = true,
    sticky = true,
    ontop = false,
    focusable = false,
    -- x = screen[1].geometry.x,
    -- y = screen[1].geometry.y,
    -- width = screen[1].geometry.width,
    -- height = screen[1].geometry.height,
    -- maximized = true,

    placement = awful.placement.centered,

    skip_taskbar = true,
    skip_pager = true,
    titlebars_enabled = false,
    window_type = 'desktop',
    border_width = 0,
  },
}

ruled.client.append_rule {
  rule_any = {
    class = {
      'Arandr',
      'Blueman-manager',
      'Gpick',
    },
  },
  properties = { floating = true },
}

-- awful.rules.rules = {
--   -- All clients will match this rule.
--   {
--     rule = {},
--     properties = {
--       border_width = beautiful.border_width,
--       border_color = beautiful.border_normal,
--       focus = awful.client.focus.filter,
--       raise = true,
--       keys = clientkeys,
--       buttons = clientbuttons,
--       screen = awful.screen.preferred,
--       placement = awful.placement.no_overlap + awful.placement.no_offscreen,
--     },
--     callback = function(c)
--       -- Move new clients to the bottom of the stack
--       local master = awful.client.getmaster(c.screen)
--       if master and c ~= master then
--         c:swap(master)
--       end
--     end
--   },

--   -- Floating clients.
--   {
--     rule_any = {
--       class = {
--         'Arandr',
--         'Blueman-manager',
--         'Gpick',
--       },
--     },
--     properties = { floating = true },
--   },
-- }
