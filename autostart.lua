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
  '~/.screenlayout/monitor.sh',
  'setxkbmap -option caps:ctrl_modifier',
  'picom --config ~/.config/picom.conf',
}

return {}

