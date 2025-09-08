-- Theme settings
local beautiful = require 'beautiful'
local gears = require 'gears'
local naughty = require 'naughty'
local awful = require 'awful'
local wibox = require 'wibox'

-- Display the current theme with naughty using beautiful.get() which returns a table it needs to be formated as a string
local empty = '#28282800'
beautiful.init(gears.filesystem.get_themes_dir() .. 'xresources/theme.lua')
beautiful.bg_normal = '#282828cc'
beautiful.fg_normal = '#eeeee0'

beautiful.font = 'SauceCodePro Nerd Font Propo Bold 10'
beautiful.wallpaper = os.getenv 'HOME' .. '/Pictures/bg.jpg'
beautiful.border_width = 2
-- beautiful.border_color = '#282828cc'

beautiful.useless_gap = 4

-- Custom theme settings
beautiful.menu_bg_normal = beautiful.bg_normal
beautiful.menu_fg_normal = beautiful.fg_normal
beautiful.menu_bg_focus = beautiful.bg_focus
beautiful.menu_fg_focus = beautiful.fg_focus
beautiful.menu_border_color = beautiful.border_color
beautiful.menu_border_width = 2
beautiful.menu_height = 36
beautiful.menu_width = 260
beautiful.menu_font = 'SauceCodePro Nerd Font Propo Heavy 12'
beautiful.menu_icon_size = 1
-- Adjust values
beautiful.tasklist_shape_border_color_focus = beautiful.bg_focus
beautiful.tasklist_shape_border_color_minimized = '#8ec07c'
beautiful.tasklist_shape_border_width_minimized = 2
beautiful.tasklist_spacing = 5
beautiful.tasklist_shape_minimized = gears.shape.rounded_rect
-- beautiful.taglist_fg_occupied = '#8ec07c'
-- beautiful.taglist_fg_urgent = '#cc6666'
beautiful.taglist_fg_empty = '#666666'
-- beautiful.taglist_fg_focus = '#d79921'
beautiful.taglist_fg_occupied = beautiful.bg_occupied
beautiful.taglist_fg_urgent = beautiful.bg_urgent
-- beautiful.taglist_fg_empty = beautiful.fg_normal
beautiful.taglist_fg_focus = beautiful.bg_focus
beautiful.taglist_bg_occupied = beautiful.bg_normal
beautiful.taglist_bg_urgent = beautiful.bg_normal
beautiful.taglist_bg_empty = empty
beautiful.taglist_bg_focus = beautiful.bg_normal
beautiful.taglist_bg_volatile = beautiful.bg_normal
beautiful.taglist_shape = gears.shape.rounded_bar
beautiful.taglist_font = 'SauceCodePro Nerd Font Propo 10'
beautiful.taglist_spacing = 4
local lain_icons = os.getenv 'HOME' .. '/.config/awesome/lain/icons/layout/default/'
beautiful.layout_stablefair = lain_icons .. 'termfairw.png'
beautiful.layout_centerfair = lain_icons .. 'centerfairw.png' -- termfair.center
beautiful.layout_cascade = lain_icons .. 'cascadew.png'
beautiful.layout_cascadetile = lain_icons .. 'cascadetilew.png' -- cascade.tile
beautiful.layout_centerwork = lain_icons .. 'centerworkw.png'
beautiful.layout_centerworkh = lain_icons .. 'centerworkhw.png' -- centerwork.horizontal

return beautiful
