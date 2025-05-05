-- General configuration
local awful = require 'awful'
local lain = require 'lain'

-- Default applications
terminal = 'alacritty'
editor = os.getenv 'EDITOR' or 'nano'
editor_cmd = terminal .. ' -e ' .. editor

-- Modkey
modkey = 'Mod4'
-- Layouts
awful.layout.layouts = {
  awful.layout.suit.tile,
  awful.layout.suit.floating,
  awful.layout.suit.max,
  awful.layout.suit.spiral.dwindle,
  lain.layout.termfair.stable,
  lain.layout.cascade,
  lain.layout.cascade.tile,
  lain.layout.centerwork,
  lain.layout.centerwork.horizontal,
}

return { terminal = terminal, editor = editor, modkey = modkey }
