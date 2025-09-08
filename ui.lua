-- UI elements like wibar, widgets, and taglist/tasklist
local awful = require 'awful'
local gears = require 'gears'
local wibox = require 'wibox'
local beautiful = require 'beautiful'
local lain = require 'lain'
local hotkeys_popup = require 'awful.hotkeys_popup'
local config = require 'config'
local terminal = config.terminal
local editor_cmd = config.editor_cmd

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
mytextclock = wibox.widget.textclock()
mytextclock.font = 'SauceCodePro Nerd Font Mono Bold 8'
mytextclock.format = '%m.%d.%y | %I:%M '
-- mytextclock = wibox.widget.textclock '%m.%d.%y | %I:%M '
local weatherwidget = wibox.widget {
  {
    awful.widget.watch(
      -- Path to your script
      os.getenv 'HOME' .. '/.config/awesome/scripts/openweather-city',
      600, -- Update interval in seconds (e.g., every 10 minutes)
      function(widget, stdout)
        widget:set_markup(stdout)
      end
    ),
    font = 'SauceCodePro Nerd Font Mono Bold 8',
    widget = wibox.container.margin,
    left = 10,
    -- right = 10,
    top = 4,
    bottom = 4,
  },
  widget = wibox.container.margin,
  left = 4,
  right = 4,
}
local volwidget = awful.widget.watch(
  -- Path to your script
  os.getenv 'HOME' .. '/.config/awesome/scripts/volume',
  10, -- Update interval in seconds (e.g., every 10 seconds)
  function(widget, stdout)
    local output = stdout:gsub('\n', '')
    if output and output ~= '' then
      widget:set_markup('<span font_weight="medium" font_size="small">' .. output .. '</span>')
    else
      widget:set_markup('<span font_weight="medium" font_size="small"> N/A | </span>')
    end
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
-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal('property::geometry', function(s)
  gears.wallpaper.maximized(beautiful.wallpaper, s)
end)
-- Define tag names and layouts (similar to your i3 workspaces)
screen.connect_signal('request::desktop_decoration', function(s)
  -- Assign tags based on screen index
  if s.index == 1 then
    awful.tag.add('', {
      layout = awful.layout.suit.spiral.dwindle,
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
      layout = lain.layout.termfair.stable,
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
        -- widget = wibox.container.place,
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
      shape = gears.shape.circle,
    },
    widget_template = {
      {
        {
          {
            -- id = 'icon_role',
            -- widget = wibox.widget.imagebox,
            awful.widget.clienticon,
            margins = 2,
            widget = wibox.container.margin,
          },
          margins = 2,
          widget = wibox.container.margin,
        },
        id = 'background_role',
        bg = '#282828cc',
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
          -- Dynamic width based on text content
          font = 'SauceCodePro Nerd Font Propo Ultra-Light 8',
        },
        widget = wibox.container.margin,
        left = 10,
        right = 10,
        top = 2,
        bottom = 2,
      },
      -- fg = '#ebdbb2', -- text color
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
  client.connect_signal('manage', function(c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    if not awesome.startup then
      -- if #awful.screen.focused().clients == 1 then
      --   awful.client.setmaster(c)
      -- else
      awful.client.setslave(c)
      -- end
    end
    -- else
    --   -- Optional: Log a message if a managed client doesn't have a valid tag.
    --   -- This can help diagnose which client type or situation causes this.
    --   -- awful.print_error("Warning: manage signal fired for client without a valid tag.", c)
    -- end

    if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then
      -- Prevent clients from being unreachable after screen count changes.
      awful.placement.no_offscreen(c)
    end
  end)
  client.connect_signal('focus', function(c)
    -- Set border styling
    c.border_color = '#ebdbb2cc' -- Gruvbox fg
    c.border_width = 2
    
    -- Raise window to top
    c:raise()
    
    -- Update focused client text if on this screen
    if c.screen == s then
      update_focused_client_text()
    end
  end)
  
  client.connect_signal('unfocus', function(c)
    c.border_color = '#0c0d0fcc' -- 80% transparent
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
      widget:set_markup('<span font_weight="medium" font_size="small">   ' .. cpu_now.usage .. '% | </span>')
    end,
  }
  local mem = lain.widget.mem {
    settings = function()
      widget:set_markup('<span font_weight="medium" font_size="small">  ' .. mem_now.perc .. '% | </span>')
    end,
  }
  local fs = lain.widget.fs {
    partition = '/',
    settings = function()
      widget:set_markup('<span font_weight="medium" font_size="small">  ' .. fs_now['/'].percentage .. '% | </span>')
    end,
  }
  -- PulseAudio volume (based on multicolor theme)
  -- local volume = lain.widget.pulse {
  --   settings = function()
  --     -- cmd = 'pacmd list-' .. pulse.devicetype .. "s | grep -e $(pactl info | grep -e 'ink' | cut -d' ' -f3) -e 'volume: front' -e 'muted'"
  --     vlevel = volume_now.left .. '-' .. volume_now.right .. '% | ' .. volume_now.device
  --     if volume_now.muted == 'yes' then
  --       vlevel = vlevel .. ' M'
  --     end
  --     widget:set_markup(lain.util.markup('#7493d2', vlevel))
  --   end,
  -- }
  local bat = lain.widget.bat {
    settings = function()
      widget:set_markup('<span font_weight="medium" font_size="small">   ' .. bat_now.perc .. '% | </span>')
    end,
  }

  local gpu = awful.widget.watch(
    os.getenv 'HOME' .. '/.config/awesome/scripts/gpu-usage',
    5, -- Update every 5 seconds
    function(widget, stdout)
      local output = stdout:gsub('\n', '')
      if output and output ~= '' then
        widget:set_markup('<span font_weight="medium" font_size="small">' .. output .. ' | </span>')
      else
        widget:set_markup '<span font_weight="medium" font_size="small">󰢮 N/A | </span>'
      end
    end
  )

  -- Create the main wibox (transparent background)
  s.mywibox = awful.wibar {
    position = 'top',
    screen = s,
    height = 32,
    bg = '#00000000', -- Transparent background
    fg = beautiful.fg_normal,
  }

  -- Helper function to create pill-shaped containers that only take up needed space
  local function create_pill_section(widgets, bg_color, margins)
    margins = margins or { left = 4, right = 4, top = 2, bottom = 2 }
    return wibox.widget {
      {
        {
          widgets,
          widget = wibox.container.margin,
          left = margins.left,
          right = margins.right,
          top = margins.top,
          bottom = margins.bottom,
        },
        bg = bg_color or beautiful.bg_normal,
        shape = gears.shape.rounded_rect,
        widget = wibox.container.background,
      },
      widget = wibox.container.margin,
      left = 4,
      right = 4,
      top = 2,
      bottom = 2,
    }
  end

  -- Create left section (tags and tasks)
  local left_section = create_pill_section {
    layout = wibox.layout.fixed.horizontal,
    s.mypromptbox,
    s.mytaglist,
    s.mytasklist,
    s.focused_client_text,
  }

  -- Create center section (focused client and weather)
  local center_section = create_pill_section {
    layout = wibox.layout.fixed.horizontal,
    weatherwidget,
  }

  -- Create right section (system info)
  local right_section = create_pill_section {
    layout = wibox.layout.fixed.horizontal,
    -- wibox.widget.systray(),
    cpu.widget,
    mem.widget,
    fs.widget,
    gpu,
    volwidget,
    mytextclock,
  }

  -- Stack layout for true screen centering
  s.mywibox:setup {
    layout = wibox.layout.stack,
    -- Bottom layer: left and right sections
    {
      layout = wibox.layout.align.horizontal,
      left_section,
      nil,
      right_section,
    },
    -- Top layer: center section, truly centered on screen
    wibox.container.place(center_section, 'center', 'center'),
  }
end)
