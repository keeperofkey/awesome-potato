-- UI elements like wibar, widgets, and taglist/tasklist
local awful = require 'awful'
local gears = require 'gears'
local wibox = require 'wibox'
local beautiful = require 'beautiful'
local lain = require 'lain'
-- local vicious = require 'vicious'

-- {{{ Menu
-- Create a launcher widget and a main menu
myawesomemenu = {
  {
    'hotkeys',
    function()
      hotkeys_popup.show_help(nil, awful.screen.focused())
    end,
  },
  { 'manual', terminal .. ' -e man awesome' },
  { 'edit config', editor_cmd .. ' ' .. awesome.conffile },
  { 'restart', awesome.restart },
  {
    'quit',
    function()
      awesome.quit()
    end,
  },
}

mymainmenu = awful.menu {
  items = {
    -- { "open terminal", terminal },

    {
      '  Shutdown',
      function()
        awful.spawn.with_shell 'systemctl poweroff'
      end,
    },
    {
      '  Reboot',
      function()
        awful.spawn.with_shell 'systemctl reboot'
      end,
    },
    {
      '  Suspend',
      function()
        awful.spawn.with_shell 'systemctl suspend'
      end,
    },
    {
      '󰒲  Hibernate',
      function()
        awful.spawn.with_shell 'systemctl hibernate'
      end,
    },
    {
      '  Lock',
      function()
        awful.spawn.with_shell '~/.config/i3/scripts/blur-lock'
      end,
    },
    {
      '  Logout',
      function()
        awesome.quit()
      end,
    },
    { '  Awesome', myawesomemenu },
    { '  Cancel', function() end },
  },
}

mylauncher = awful.widget.launcher { menu = mymainmenu }

-- Menubar configuration
-- menubar.utils.terminal = terminal -- Set the terminal for applications that require it
-- }}}

-- {{{ Wibar
-- Create a textclock widget
mytextclock = wibox.widget.textclock '%m.%d.%y | %I:%M '
local weatherwidget = awful.widget.watch(
  -- Path to your script
  os.getenv 'HOME' .. '/.config/awesome/scripts/openweather-city',
  600, -- Update interval in seconds (e.g., every 10 minutes)
  function(widget, stdout)
    widget:set_markup(stdout)
  end
)
local volwidget = awful.widget.watch(
  -- Path to your script
  os.getenv 'HOME' .. '/.config/awesome/scripts/volume',
  10, -- Update interval in seconds (e.g., every 10 minutes)
  function(widget, stdout)
    widget:set_markup(stdout)
  end
)
-- local cpuwidget = awful.widget.watch(
-- 	-- Path to your script
-- 	os.getenv("HOME") .. "/.config/awesome/i3_scripts/cpu_usage",
-- 	10, -- Update interval in seconds (e.g., every 10 seconds)
-- 	function(widget, stdout)
-- 		widget:set_markup(stdout)
-- 	end
-- )

-- Create a wibox for each screen and add it
local taglist_buttons = gears.table.join(
  awful.button({}, 1, function(t)
    t:view_only()
  end),
  awful.button({ modkey }, 1, function(t)
    if client.focus then
      client.focus:move_to_tag(t)
    end
  end),
  awful.button({}, 3, awful.tag.viewtoggle),
  awful.button({ modkey }, 3, function(t)
    if client.focus then
      client.focus:toggle_tag(t)
    end
  end),
  awful.button({}, 4, function(t)
    awful.tag.viewnext(t.screen)
  end),
  awful.button({}, 5, function(t)
    awful.tag.viewprev(t.screen)
  end)
)

local tasklist_buttons = gears.table.join(
  awful.button({}, 1, function(c)
    if c == client.focus then
      c.minimized = true
    else
      c:emit_signal('request::activate', 'tasklist', { raise = true })
    end
  end),
  awful.button({}, 3, function()
    awful.menu.client_list { theme = { width = 250 } }
  end),
  awful.button({}, 4, function()
    awful.client.focus.byidx(1)
  end),
  awful.button({}, 5, function()
    awful.client.focus.byidx(-1)
  end)
)

screen.connect_signal('request::wallpaper', function(s)
  gears.wallpaper.maximized(beautiful.wallpaper, s)
end)
-- -- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
-- screen.connect_signal('property::geometry', function(s)
--   gears.wallpaper.maximized(beautiful.wallpaper, s)
-- end)

-- Define tag names and layouts (similar to your i3 workspaces)
screen.connect_signal('request::desktop_decoration', function(s)
  -- Assign tags based on screen index
  if s.index == 1 then
    awful.tag.add('', {
      layout = awful.layout.suit.spiral,
      master_fill_policy = 'master_width_factor',
      gap_single_client = true,
      screen = s,
      selected = true,
    })
    awful.tag.add('󰖟', {
      layout = awful.layout.suit.tile,
      screen = s,
    })
    awful.tag.add('', {
      layout = awful.layout.suit.fairv,
      screen = s,
    })
    awful.tag.add('', {
      layout = awful.layout.suit.floating,
      screen = s,
    })
    awful.tag.add('', {
      layout = awful.layout.suit.max.fullscreen,
      screen = s,
    })
  elseif s.index == 2 then
    awful.tag.add('', {
      layout = awful.layout.suit.spiral,
      master_fill_policy = 'master_width_factor',
      gap_single_client = true,
      screen = s,
      selected = true,
    })
    awful.tag.add('', {
      layout = awful.layout.suit.max,
      screen = s,
    })
    awful.tag.add('', {
      layout = awful.layout.suit.fairv,
      screen = s,
    })
    awful.tag.add('', {
      layout = awful.layout.suit.floating,
      screen = s,
    })
    awful.tag.add('', {
      layout = awful.layout.suit.max,
      screen = s,
    })
  end

  -- Create a promptbox for each screen
  s.mypromptbox = awful.widget.prompt()

  -- Create an imagebox widget which will contain an icon indicating which layout we're using.
  -- We need one layoutbox per screen.
  s.mylayoutbox = wibox.container.margin(
    awful.widget.layoutbox {
      screen = s,
      buttons = {
        awful.button({}, 1, function()
          awful.layout.inc(1)
        end),
        awful.button({}, 3, function()
          awful.layout.inc(-1)
        end),
        awful.button({}, 4, function()
          awful.layout.inc(-1)
        end),
        awful.button({}, 5, function()
          awful.layout.inc(1)
        end),
      },
    },
    4,
    4,
    4,
    4
  )

  -- Create a taglist widget
  s.mytaglist = awful.widget.taglist {
    screen = s,
    filter = awful.widget.taglist.filter.all,
    buttons = {
      awful.button({}, 1, function(t)
        t:view_only()
      end),
      awful.button({ modkey }, 1, function(t)
        if client.focus then
          client.focus:move_to_tag(t)
        end
      end),
      awful.button({}, 3, awful.tag.viewtoggle),
      awful.button({ modkey }, 3, function(t)
        if client.focus then
          client.focus:toggle_tag(t)
        end
      end),
      awful.button({}, 4, function(t)
        awful.tag.viewprev(t.screen)
      end),
      awful.button({}, 5, function(t)
        awful.tag.viewnext(t.screen)
      end),
    },
    widget_template = {
      {
        {
          id = 'text_role',
          widget = wibox.widget.textbox,
          forced_width = 32, -- adjust for desired size
          -- forced_height = 32,
          halign = 'center',
          valign = 'center',
          justify = 'true',
        },
        widget = wibox.container.place,
        forced_width = 32, -- adjust for desired size
        halign = 'center',
        valign = 'center',
        widget = wibox.container.margin,
        left = 8,
        right = 8,
      },
      widget = wibox.container.background,
      id = 'background_role',
      shape = gears.shape.rounded_bar,
    },
  }

  -- Create a tasklist widget
  s.mytasklist = awful.widget.tasklist {
    screen = s,
    filter = awful.widget.tasklist.filter.currenttags,
    buttons = tasklist_buttons,
    style = {
      shape_border_width = 2,
      shape_border_color = '#282828',
      shape = gears.shape.rounded_bar,
    },
    widget_template = {
      {
        {
          {
            id = 'icon_role',
            widget = wibox.widget.imagebox,
          },
          margins = 2,
          widget = wibox.container.margin,
        },
        id = 'background_role',
        widget = wibox.container.background,
      },
      widget = wibox.container.margin,
      margins = 2,
    },
  }
  s.focused_client_text = wibox.widget {
    {
      {
        {
          id = 'txt',
          widget = wibox.widget.textbox,
          valign = 'center',
          -- halign = "center",
          forced_width = 512, -- Adjust as needed
          font = 'MartianMono Nerd Font Mono 8',
        },
        widget = wibox.container.margin,
        left = 10,
        right = 10,
        top = 2,
        bottom = 2,
      },
      fg = '#ebdbb2', -- text color
      shape = gears.shape.rounded_rect,
      -- shape_border_width = 2,
      -- shape_border_color = beautiful.bg_normal,
      widget = wibox.container.background,
    },
    widget = wibox.container.margin,
    margins = 2,
  }
  local function update_focused_client_text()
    local c = client.focus
    local txtbox = s.focused_client_text:get_children_by_id('txt')[1]
    if c and c.screen == s and not c.minimized then
      local title = c.name or c.class or '[No Name]'
      -- Helper to trim whitespace
      local function trim(s)
        return (s:gsub('^%s*(.-)%s*$', '%1'))
      end
      -- Format title as "first/last"
      local function format_title(str)
        local parts = {}
        for part in string.gmatch(str, '[^%-]+') do
          table.insert(parts, trim(part))
        end
        if #parts >= 2 then
          return parts[1] .. '/' .. parts[#parts]
        else
          return str
        end
      end
      local formatted_title = format_title(title)
      txtbox.markup = string.format("<span font_weight='medium'>%s</span>", formatted_title)
    else
      txtbox.markup = ''
    end
  end
  -- Connect signals
  client.connect_signal('focus', function(c)
    c.border_color = '#689d6a' -- Gruvbox aqua
    c.border_width = 2
    if c.screen == s then
      update_focused_client_text()
    end
  end)
  client.connect_signal('unfocus', function(c)
    c.border_color = '#00000000' -- Fully transparent
    if c.screen == s then
      update_focused_client_text()
    end
  end)
  client.connect_signal('property::name', function(c)
    if c == client.focus and c.screen == s then
      update_focused_client_text()
    end
  end)
  -- Initial update
  update_focused_client_text()
  local cpu = lain.widget.cpu {
    settings = function()
      widget:set_markup('  ' .. cpu_now.usage .. '% | ')
    end,
  }
  local mem = lain.widget.mem {
    settings = function()
      widget:set_markup('  ' .. mem_now.perc .. '% | ')
    end,
  }
  local fs = lain.widget.fs {
    partition = '/',
    settings = function()
      widget:set_markup('  ' .. fs_now['/'].percentage .. '% | ')
    end,
  }
  local vol = lain.widget.pulsebar {}
  local bat = lain.widget.bat {
    settings = function()
      widget:set_markup('  ' .. bat_now.perc .. '% | ')
    end,
  }
  -- vol.bar:buttons(awful.util.table.join(
  --   awful.button({}, 1, function() -- left click
  --     awful.spawn 'pavucontrol'
  --   end),
  --   awful.button({}, 2, function() -- middle click
  --     os.execute(string.format('pactl set-sink-vol %d 100%%', vol.device))
  --     vol.update()
  --   end),
  --   awful.button({}, 3, function() -- right click
  --     os.execute(string.format('pactl set-sink-mute %d toggle', vol.device))
  --     vol.update()
  --   end),
  --   awful.button({}, 4, function() -- scroll up
  --     os.execute(string.format('pactl set-sink-vol %d +1%%', vol.device))
  --     vol.update()
  --   end),
  --   awful.button({}, 5, function() -- scroll down
  --     os.execute(string.format('pactl set-sink-vol %d -1%%', vol.device))
  --     vol.update()
  --   end)
  -- ))
  -- CPU widget
  -- cpuwidget = wibox.widget.textbox()
  -- vicious.register(cpuwidget, vicious.widgets.cpu, '  $1% | ', 2)
  --
  -- -- Memory widget
  -- memwidget = wibox.widget.textbox()
  -- vicious.register(memwidget, vicious.widgets.mem, '  $1% | ', 5)
  --
  -- -- Filesystem widget
  -- fswidget = wibox.widget.textbox()
  -- vicious.register(fswidget, vicious.widgets.fs, '  ${/ avail_p}% | ', 120)
  --
  -- -- Network widget (replace 'enp3s0' with your interface)
  -- netwidget = wibox.widget.textbox()
  -- vicious.register(netwidget, vicious.widgets.net, '  ${enp66s0 up_gb} ${enp66s0 down_gb} | ', 3)
  --
  -- -- Volume widget (requires alsa-utils)
  -- volwidget = wibox.widget.textbox()
  -- vicious.register(volwidget, vicious.widgets.volume, '  $1% | ', 2, 'Master')
  --
  -- -- Battery widget
  -- batwidget = wibox.widget.textbox()
  -- vicious.register(batwidget, vicious.widgets.bat, '$1 $2% | ', 60, 'BAT1')

  -- Create the wibox
  s.mywibox = awful.wibar {
    position = 'top',
    screen = s,
    height = 28,
    bg = beautiful.bg_normal,
    fg = beautiful.fg_normal,
    -- shape = function(cr, width, height)
    -- 	gears.shape.rounded_rect(cr, width, height, 5)
    -- end,
  }

  -- Add widgets to the wibox
  s.mywibox:setup {
    layout = wibox.layout.stack,
    {
      layout = wibox.layout.align.horizontal,
      { -- Left widgets
        layout = wibox.layout.fixed.horizontal,
        -- mylauncher,
        s.mypromptbox,
        s.mytaglist,
        s.mytasklist,
        s.focused_client_text, -- Middle widget
      },
      nil, -- No middle widget
      { -- Right widgets
        layout = wibox.layout.fixed.horizontal,
        wibox.widget.systray(),
        cpu.widget,
        mem.widget,
        fs.widget,
        -- net.widget,
        -- vol.bar,
        volwidget,
        bat.widget,
        mytextclock,
        s.mylayoutbox,
      },
    },
    { -- Top layer: centered weather widget
      layout = wibox.layout.align.horizontal,
      nil,
      wibox.container.place(weatherwidget),
      nil,
    },
  }
end)
