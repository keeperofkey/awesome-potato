-- Key and mouse bindings
local awful = require 'awful'
local gears = require 'gears'
local naughty = require 'naughty'
local config = require 'config'
local modkey = config.modkey
-- local modkey = require 'config.modkey'
-- local modkey = 'mod4'
local last_minimized_client = nil

client.connect_signal('property::minimized', function(c)
  if c.minimized then
    last_minimized_client = c
  end
end)

-- Global key bindings
awful.keyboard.append_global_keybindings {
  -- Standard program
  awful.key({ modkey }, 'Return', function()
    awful.spawn(terminal)
  end, { description = 'open a terminal', group = 'launcher' }),
  awful.key({ modkey, 'Shift' }, 'Return', function()
    awful.spawn.with_shell(terminal .. ' --working-directory "$(xcwd)"')
  end, { description = 'open a terminal in current directory', group = 'launcher' }),
  awful.key({ modkey, 'Control' }, 'r', awesome.restart, { description = 'reload awesome', group = 'awesome' }),
  awful.key({ modkey, 'Shift' }, 'q', awesome.quit, { description = 'quit awesome', group = 'awesome' }),
  awful.key({ modkey, 'Shift' }, 'c', function()
    awful.spawn.with_shell 'i3lock -i ~/.config/i3/i3-screen-lock.png -t'
  end, { description = 'lock screen', group = 'awesome' }),

  -- Layout manipulation
  awful.key({ modkey }, 'h', function()
    awful.client.focus.global_bydirection 'left'
  end, { description = 'focus left', group = 'client' }),
  awful.key({ modkey }, 'j', function()
    awful.client.focus.global_bydirection 'down'
  end, { description = 'focus down', group = 'client' }),
  awful.key({ modkey }, 'k', function()
    awful.client.focus.global_bydirection 'up'
  end, { description = 'focus up', group = 'client' }),
  awful.key({ modkey }, 'l', function()
    awful.client.focus.global_bydirection 'right'
  end, { description = 'focus right', group = 'client' }),
  awful.key({ modkey }, 'Left', function()
    awful.client.focus.global_bydirection 'left'
  end, { description = 'focus left', group = 'client' }),
  awful.key({ modkey }, 'Down', function()
    awful.client.focus.global_bydirection 'down'
  end, { description = 'focus down', group = 'client' }),
  awful.key({ modkey }, 'Up', function()
    awful.client.focus.global_bydirection 'up'
  end, { description = 'focus up', group = 'client' }),
  awful.key({ modkey }, 'Right', function()
    awful.client.focus.global_bydirection 'right'
  end, { description = 'focus right', group = 'client' }),

  awful.key({ modkey, 'Shift' }, 'h', function()
    awful.client.swap.global_bydirection 'left'
  end, { description = 'swap with left client', group = 'client' }),
  awful.key({ modkey, 'Shift' }, 'j', function()
    awful.client.swap.global_bydirection 'down'
  end, { description = 'swap with down client', group = 'client' }),
  awful.key({ modkey, 'Shift' }, 'k', function()
    awful.client.swap.global_bydirection 'up'
  end, { description = 'swap with up client', group = 'client' }),
  awful.key({ modkey, 'Shift' }, 'l', function()
    awful.client.swap.global_bydirection 'right'
  end, { description = 'swap with right client', group = 'client' }),
  awful.key({ modkey, 'Shift' }, 'Left', function()
    awful.client.swap.global_bydirection 'left'
  end, { description = 'swap with left client', group = 'client' }),
  awful.key({ modkey, 'Shift' }, 'Down', function()
    awful.client.swap.global_bydirection 'down'
  end, { description = 'swap with down client', group = 'client' }),
  awful.key({ modkey, 'Shift' }, 'Up', function()
    awful.client.swap.global_bydirection 'up'
  end, { description = 'swap with up client', group = 'client' }),
  awful.key({ modkey, 'Shift' }, 'Right', function()
    awful.client.swap.global_bydirection 'right'
  end, { description = 'swap with right client', group = 'client' }),

  -- Layout switching
  awful.key({ modkey }, 'space', function()
    awful.layout.inc(1)
  end, { description = 'select next layout', group = 'layout' }),
  awful.key({ modkey, 'Shift' }, 'space', function()
    if client.focus then
      client.focus.floating = not client.focus.floating
    end
  end, { description = 'toggle floating', group = 'client' }),

  -- Tag switching (workspaces)
  awful.key({ modkey }, 'Tab', awful.tag.viewnext, { description = 'view next', group = 'tag' }),
  awful.key({ modkey, 'Shift' }, 'Tab', awful.tag.viewprev, { description = 'view previous', group = 'tag' }),

  -- Directional client focus
  awful.key({ modkey }, 'j', function()
    awful.client.focus.byidx(1)
  end, { description = 'focus next by index', group = 'client' }),
  awful.key({ modkey }, 'k', function()
    awful.client.focus.byidx(-1)
  end, { description = 'focus previous by index', group = 'client' }),

  -- Splitting
  awful.key({ modkey }, 'b', function()
    awful.spawn.with_shell "echo 'horizontal' > /tmp/awesomewm-split-direction"
  end, { description = 'split horizontally', group = 'layout' }),
  awful.key({ modkey }, 'v', function()
    awful.spawn.with_shell "echo 'vertical' > /tmp/awesomewm-split-direction"
  end, { description = 'split vertically', group = 'layout' }),

  -- Fullscreen
  awful.key({ modkey }, 'f', function()
    if client.focus then
      client.focus.fullscreen = not client.focus.fullscreen
      client.focus:raise()
    end
  end, { description = 'toggle fullscreen', group = 'client' }),

  -- Minimize/restore focused client (tasklist behavior)
  awful.key({ modkey }, 'm', function()
    local s = awful.screen.focused()
    local restored = false
    for _, c in ipairs(s.all_clients) do
      if c.minimized then
        c.minimized = false
        client.focus = c
        c:raise()
        restored = true
        break
      end
    end
    if not restored and client.focus and not client.focus.minimized then
      client.focus.minimized = true
    end
  end, { description = 'restore a minimized client or minimize focused', group = 'client' }),

  -- -- Layout switching
  -- awful.key({ modkey }, "s", function()
  -- 	awful.layout.set(awful.layout.suit.floating)
  -- end, { description = "set floating layout", group = "layout" }),
  -- awful.key({ modkey }, "a", function()
  -- 	awful.layout.set(awful.layout.suit.max)
  -- end, { description = "set max layout", group = "layout" }),
  -- awful.key({ modkey }, "x", function()
  -- 	awful.layout.set(awful.layout.suit.tile)
  -- end, { description = "set tiled layout", group = "layout" }),
  -- awful.key({ modkey }, "z", function()
  -- 	awful.layout.set(awful.layout.suit.fair)
  -- end, { description = "set fair layout", group = "layout" }),

  -- Kill focused window (like mod+q in i3)
  awful.key({ modkey }, 'q', function()
    if client.focus then
      client.focus:kill()
    end
  end, { description = 'close', group = 'client' }),

  -- Run dialog (like mod+r in i3)
  awful.key({ modkey }, 'r', function()
    awful.screen.focused().mypromptbox:run()
  end, { description = 'run prompt', group = 'launcher' }),

  -- Rofi (application launcher, window switcher, clipboard)
  awful.key({ modkey }, 'd', function()
    awful.spawn.with_shell 'rofi -modi drun -show drun -config ~/.config/rofi/rofidmenu.rasi'
  end, { description = 'show rofi drun menu', group = 'launcher' }),
  awful.key({ modkey }, 't', function()
    awful.spawn.with_shell 'rofi -show window -config ~/.config/rofi/rofidmenu.rasi'
  end, { description = 'show rofi window menu', group = 'launcher' }),
  awful.key({ modkey }, 'c', function()
    awful.spawn.with_shell 'rofi -modi "clipboard:greenclip print" -show clipboard -config ~/.config/rofi/rofidmenu.rasi'
  end, { description = 'show rofi clipboard', group = 'launcher' }),

  -- Power menu (like mod+shift+e in i3)
  awful.key({ modkey, 'Shift' }, 'e', function()
    mymainmenu:toggle()
  end, { description = 'menu', group = 'awesome' }),

  -- Browser shortcut (mod+w)
  awful.key({ modkey }, 'w', function()
    awful.spawn 'zen-browser'
  end, { description = 'launch browser', group = 'launcher' }),

  -- File manager shortcut (mod+n)
  awful.key({ modkey }, 'n', function()
    awful.spawn 'thunar'
  end, { description = 'launch file manager', group = 'launcher' }),

  -- Screenshot (Print key)
  awful.key({}, 'Print', function()
    awful.spawn.with_shell 'scrot ~/%Y-%m-%d-%T-screenshot.png && notify-send "Screenshot saved to ~/$(date +"%Y-%m-%d-%T")-screenshot.png"'
  end, { description = 'take screenshot', group = 'launcher' }),

  -- Power profiles menu (mod+shift+p)
  awful.key({ modkey, 'Shift' }, 'p', function()
    awful.spawn.with_shell '~/.config/i3/scripts/power-profiles'
  end, { description = 'power profiles menu', group = 'launcher' }),

  -- Volume controls
  awful.key({}, 'XF86AudioRaiseVolume', function()
    awful.spawn.with_shell 'amixer -D pulse sset Master 5%+ && pkill -RTMIN+1 i3blocks'
  end, { description = 'raise volume', group = 'audio' }),
  awful.key({}, 'XF86AudioLowerVolume', function()
    awful.spawn.with_shell 'amixer -D pulse sset Master 5%- && pkill -RTMIN+1 i3blocks'
  end, { description = 'lower volume', group = 'audio' }),
  awful.key({}, 'XF86AudioMute', function()
    awful.spawn.with_shell 'amixer sset Master toggle && killall -USR1 i3blocks'
  end, { description = 'toggle mute', group = 'audio' }),

  -- Media controls
  awful.key({}, 'XF86AudioPlay', function()
    awful.spawn 'playerctl play'
  end, { description = 'play media', group = 'audio' }),
  awful.key({}, 'XF86AudioPause', function()
    awful.spawn 'playerctl pause'
  end, { description = 'pause media', group = 'audio' }),
  awful.key({}, 'XF86AudioNext', function()
    awful.spawn 'playerctl next'
  end, { description = 'next media', group = 'audio' }),
  awful.key({}, 'XF86AudioPrev', function()
    awful.spawn 'playerctl previous'
  end, { description = 'previous media', group = 'audio' }),

  -- Firefox media controls
  awful.key({ modkey }, 'XF86AudioPlay', function()
    awful.spawn 'playerctl --player=firefox play'
  end, { description = 'play firefox media', group = 'audio' }),
  awful.key({ modkey }, 'XF86AudioPause', function()
    awful.spawn 'playerctl --player=firefox pause'
  end, { description = 'pause firefox media', group = 'audio' }),
  awful.key({ modkey }, 'XF86AudioNext', function()
    awful.spawn 'playerctl --player=firefox next'
  end, { description = 'next firefox media', group = 'audio' }),
  awful.key({ modkey }, 'XF86AudioPrev', function()
    awful.spawn 'playerctl --player=firefox previous'
  end, { description = 'previous firefox media', group = 'audio' }),

  -- Brightness controls
  awful.key({}, 'XF86MonBrightnessUp', function()
    awful.spawn.with_shell 'xbacklight +5 && notify-send "Brightness - $(xbacklight -get | cut -d \'.\' -f 1)%"'
  end, { description = 'increase brightness', group = 'screen' }),
  awful.key({}, 'XF86MonBrightnessDown', function()
    awful.spawn.with_shell 'xbacklight -5 && notify-send "Brightness - $(xbacklight -get | cut -d \'.\' -f 1)%"'
  end, { description = 'decrease brightness', group = 'screen' }),
}

-- Bind all key numbers to tags
for i = 1, 10 do
  local key = '#' .. i + 9
 awful.keyboard.append_global_keybindings { 
    -- View tag only.
    awful.key({ modkey }, key, function()
      local s, tag
      if i <= 5 then
        s = screen[1]
        tag = s.tags[i]
      else
        s = screen[2]
        tag = s.tags[i - 5] -- 1st tag on screen 2 for Super+6, etc.
      end
      if tag then
        tag:view_only()
      end
    end, { description = 'view tag #' .. i, group = 'tag' }),

    -- Toggle tag display.
    awful.key({ modkey, 'Control' }, key, function()
      local s, tag
      if i <= 5 then
        s = screen[1]
        tag = s.tags[i]
      else
        s = screen[2]
        tag = s.tags[i - 5]
      end
      if tag then
        awful.tag.viewtoggle(tag)
      end
    end, { description = 'toggle tag #' .. i, group = 'tag' }),

    -- Move client to tag.
    awful.key({ modkey, 'Shift' }, key, function()
      if client.focus then
        local s, tag
        if i <= 5 then
          s = screen[1]
          tag = s.tags[i]
        else
          s = screen[2]
          tag = s.tags[i - 5]
        end
        if tag then
          client.focus:move_to_tag(tag)
        end
      end
    end, { description = 'move focused client to tag #' .. i, group = 'tag' }),

    -- Toggle tag on focused client.
    awful.key({ modkey, 'Control', 'Shift' }, key, function()
      if client.focus then
        local s, tag
        if i <= 5 then
          s = screen[1]
          tag = s.tags[i]
        else
          s = screen[2]
          tag = s.tags[i - 5]
        end
        if tag then
          client.focus:toggle_tag(tag)
        end
      end
    end, { description = 'toggle focused client on tag #' .. i, group = 'tag' })
  }
end

-- Mouse bindings
root.buttons(gears.table.join(awful.button({}, 2, function()
  mymainmenu:toggle()
end)))
clientbuttons = gears.table.join(
  awful.button({}, 1, function(c)
    client.focus = c
    c:raise()
  end),
  awful.button({ modkey }, 1, awful.mouse.client.move),
  awful.button({ modkey }, 3, awful.mouse.client.resize)
)

-- root.keys(globalkeys)
