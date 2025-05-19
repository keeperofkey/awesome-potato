-- Autostart applications
local awful = require 'awful'

local function run_once(cmd_arr)
  for _, cmd in ipairs(cmd_arr) do
    awful.spawn.with_shell(string.format("pgrep -u $USER -fx '%s' > /dev/null || (%s)", cmd, cmd))
  end
end

-- List of apps to run on start-up
run_once {
  -- 'feh --bg-scale ~/Pictures/bg.jpg',
  -- 'alacritty --class WallpaperTerminal --config-file ~/.config/alacritty/alacritty-bg.toml -e chafa --speed 0.5 --dither fs -c 240 -f symbols --symbols all --fg-only -t 0.2 --scale max  ~/Pictures/gif/out.gif',
  '~/.screenlayout/monitor.sh',
  'setxkbmap -option caps:ctrl_modifier',
  'picom --config ~/.config/picom.conf',
}

return {}
