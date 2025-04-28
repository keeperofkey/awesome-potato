package.path = package.path .. ";/usr/share/lua/5.3/?.lua;/usr/share/lua/5.3/?/init.lua"
package.cpath = package.cpath .. ";/usr/lib/lua/5.3/?.so"
pcall(require, "luarocks.loader")
-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
local wibox = require("wibox")
local beautiful = require("beautiful")
local naughty = require("naughty")
local vicious = require("vicious")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
require("awful.hotkeys_popup.keys")
local xresources = require("beautiful.xresources")
local dpi = xresources.apply_dpi
-- require("mosh.audio_cpu_reactive")
-- {{{ Error handling
if awesome.startup_errors then
	naughty.notify({
		preset = naughty.config.presets.critical,
		title = "Oops, there were errors during startup!",
		text = awesome.startup_errors,
	})
end

-- Handle runtime errors after startup
do
	local in_error = false
	awesome.connect_signal("debug::error", function(err)
		-- Make sure we don't go into an endless error loop
		if in_error then
			return
		end
		in_error = true

		naughty.notify({
			preset = naughty.config.presets.critical,
			title = "Oops, an error happened!",
			text = tostring(err),
		})
		in_error = false
	end)
end
-- }}}

-- {{{ Variable definitions
-- awful.mouse.snap.edge_enabled = false
-- Themes define colours, icons, font and wallpapers.
beautiful.init(gears.filesystem.get_themes_dir() .. "gtk/theme.lua")

-- Match powermenu/rofi look
beautiful.menu_bg_normal = beautiful.bg_normal
beautiful.menu_fg_normal = beautiful.fg_normal
beautiful.menu_bg_focus = beautiful.bg_focus
beautiful.menu_fg_focus = beautiful.fg_focus
beautiful.menu_border_color = beautiful.border_color
beautiful.menu_border_width = 2
beautiful.menu_height = 36
beautiful.menu_width = 260
beautiful.menu_font = "MartianMono Nerd Font Propo 12"
beautiful.menu_icon_size = 1
-- Adjust values
beautiful.tasklist_shape_border_color_focus = "#8ec07c"
beautiful.tasklist_shape_border_color_minimized = "#d79921"
beautiful.tasklist_shape_border_width_minimized = 2
beautiful.tasklist_spacing = 5
beautiful.tasklist_shape_minimized = gears.shape.rounded_bar
beautiful.bg_normal = "#282828cc"
beautiful.font = "MartianMono Nerd Font Propo 10"

beautiful.useless_gap = 4
-- beautiful.gap_single_client = true

-- This is used later as the default terminal and editor to run.
terminal = "alacritty"
editor = os.getenv("EDITOR") or "nano"
editor_cmd = terminal .. " -e " .. editor

-- Default modkey (Mod4 is the Windows key, same as your i3 config)
modkey = "Mod4"
mod2 = "Mod1"

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
	awful.layout.suit.tile,
	awful.layout.suit.floating,
	awful.layout.suit.tile.left,
	awful.layout.suit.tile.bottom,
	awful.layout.suit.tile.top,
	awful.layout.suit.fair,
	awful.layout.suit.fair.horizontal,
	awful.layout.suit.spiral,
	awful.layout.suit.spiral.dwindle,
	awful.layout.suit.max,
	awful.layout.suit.max.fullscreen,
	awful.layout.suit.magnifier,
	awful.layout.suit.corner.nw,
}
-- }}}

-- {{{ Menu
-- Create a launcher widget and a main menu
myawesomemenu = {
	{
		"hotkeys",
		function()
			hotkeys_popup.show_help(nil, awful.screen.focused())
		end,
	},
	{ "manual", terminal .. " -e man awesome" },
	{ "edit config", editor_cmd .. " " .. awesome.conffile },
	{ "restart", awesome.restart },
	{
		"quit",
		function()
			awesome.quit()
		end,
	},
}

mymainmenu = awful.menu({
	items = {
		-- { "open terminal", terminal },

		{
			"  Shutdown",
			function()
				awful.spawn.with_shell("systemctl poweroff")
			end,
		},
		{
			"  Reboot",
			function()
				awful.spawn.with_shell("systemctl reboot")
			end,
		},
		{
			"  Suspend",
			function()
				awful.spawn.with_shell("systemctl suspend")
			end,
		},
		{
			"󰒲  Hibernate",
			function()
				awful.spawn.with_shell("systemctl hibernate")
			end,
		},
		{
			"  Lock",
			function()
				awful.spawn.with_shell("~/.config/i3/scripts/blur-lock")
			end,
		},
		{
			"  Logout",
			function()
				awesome.quit()
			end,
		},
		{ "  Awesome", myawesomemenu },
		{ "  Cancel", function() end },
	},
})

mylauncher = awful.widget.launcher({ menu = mymainmenu })

-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it
-- }}}

-- {{{ Wibar
-- Create a textclock widget
mytextclock = wibox.widget.textclock("<b>%m.%d.%y %I:%M</b> ")
local weatherwidget = awful.widget.watch(
	-- Path to your script
	os.getenv("HOME") .. "/.config/awesome/i3_scripts/openweather-city",
	600, -- Update interval in seconds (e.g., every 10 minutes)
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
			c:emit_signal("request::activate", "tasklist", { raise = true })
		end
	end),
	awful.button({}, 3, function()
		awful.menu.client_list({ theme = { width = 250 } })
	end),
	awful.button({}, 4, function()
		awful.client.focus.byidx(1)
	end),
	awful.button({}, 5, function()
		awful.client.focus.byidx(-1)
	end)
)

local function set_wallpaper(s)
	-- Wallpaper
	if beautiful.wallpaper then
		local wallpaper = beautiful.wallpaper
		-- If wallpaper is a function, call it with the screen
		if type(wallpaper) == "function" then
			wallpaper = wallpaper(s)
		end
		gears.wallpaper.maximized(wallpaper, s, true)
	end
end

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)

-- Define tag names and layouts (similar to your i3 workspaces)
screen.connect_signal("request::desktop_decoration", function(s)
	-- Assign tags based on screen index
	if s.index == 1 then
		awful.tag.add("", {
			layout = awful.layout.suit.spiral,
			master_fill_policy = "master_width_factor",
			gap_single_client = true,
			screen = s,
			selected = true,
		})
		awful.tag.add("󰖟", {
			layout = awful.layout.suit.tile,
			screen = s,
		})
		awful.tag.add("", {
			layout = awful.layout.suit.fairv,
			screen = s,
		})
		awful.tag.add("", {
			layout = awful.layout.suit.floating,
			screen = s,
		})
		awful.tag.add("", {
			layout = awful.layout.suit.max.fullscreen,
			screen = s,
		})
	elseif s.index == 2 then
		awful.tag.add("", {
			layout = awful.layout.suit.spiral,
			master_fill_policy = "master_width_factor",
			gap_single_client = true,
			screen = s,
			selected = true,
		})
		awful.tag.add("", {
			layout = awful.layout.suit.max,
			screen = s,
		})
		awful.tag.add("", {
			layout = awful.layout.suit.fairv,
			screen = s,
		})
		awful.tag.add("", {
			layout = awful.layout.suit.floating,
			screen = s,
		})
		awful.tag.add("", {
			layout = awful.layout.suit.max,
			screen = s,
		})
	end

	-- Create a promptbox for each screen
	s.mypromptbox = awful.widget.prompt()

	-- Create an imagebox widget which will contain an icon indicating which layout we're using.
	-- We need one layoutbox per screen.
	s.mylayoutbox = wibox.container.margin(
		awful.widget.layoutbox({
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
		}),
		4,
		4,
		4,
		4
	)

	-- Create a taglist widget
	s.mytaglist = awful.widget.taglist({
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
					id = "text_role",
					widget = wibox.widget.textbox,
					forced_width = 32, -- adjust for desired size
					-- forced_height = 32,
					halign = "center",
					valign = "center",
					justify = "true",
				},
				widget = wibox.container.place,
				forced_width = 32, -- adjust for desired size
				halign = "center",
				valign = "center",
				widget = wibox.container.margin,
				left = 8,
				right = 8,
			},
			widget = wibox.container.background,
			id = "background_role",
			shape = gears.shape.rounded_bar,
		},
	})

	-- Create a tasklist widget
	s.mytasklist = awful.widget.tasklist({
		screen = s,
		filter = awful.widget.tasklist.filter.currenttags,
		buttons = tasklist_buttons,
		style = {
			shape_border_width = 2,
			shape_border_color = "#282828",
			shape = gears.shape.rounded_bar,
		},
		widget_template = {
			{
				{
					{
						id = "icon_role",
						widget = wibox.widget.imagebox,
					},
					margins = 2,
					widget = wibox.container.margin,
				},
				id = "background_role",
				widget = wibox.container.background,
			},
			widget = wibox.container.margin,
			margins = 2,
		},
	})
	s.focused_client_text = wibox.widget({
		{
			{
				{
					id = "txt",
					widget = wibox.widget.textbox,
					valign = "center",
					-- halign = "center",
					forced_width = 512, -- Adjust as needed
					font = "MartianMono Nerd Font Mono 8",
				},
				widget = wibox.container.margin,
				left = 10,
				right = 10,
				top = 2,
				bottom = 2,
			},
			fg = "#ebdbb2", -- text color
			shape = gears.shape.rounded_rect,
			-- shape_border_width = 2,
			-- shape_border_color = beautiful.bg_normal,
			widget = wibox.container.background,
		},
		widget = wibox.container.margin,
		margins = 2,
	})
	local function update_focused_client_text()
		local c = client.focus
		local txtbox = s.focused_client_text:get_children_by_id("txt")[1]
		if c and c.screen == s and not c.minimized then
			local title = c.name or c.class or "[No Name]"
			-- Helper to trim whitespace
			local function trim(s)
				return (s:gsub("^%s*(.-)%s*$", "%1"))
			end
			-- Format title as "first/last"
			local function format_title(str)
				local parts = {}
				for part in string.gmatch(str, "[^%-]+") do
					table.insert(parts, trim(part))
				end
				if #parts >= 2 then
					return parts[1] .. "/" .. parts[#parts]
				else
					return str
				end
			end
			local formatted_title = format_title(title)
			txtbox.markup = string.format("<span font_weight='medium'>%s</span>", formatted_title)
		else
			txtbox.markup = ""
		end
	end
	-- Connect signals
	client.connect_signal("focus", function(c)
		c.border_color = "#689d6a" -- Gruvbox aqua
		c.border_width = 2
		if c.screen == s then
			update_focused_client_text()
		end
	end)
	client.connect_signal("unfocus", function(c)
		c.border_color = "#00000000" -- Fully transparent
		if c.screen == s then
			update_focused_client_text()
		end
	end)
	client.connect_signal("property::name", function(c)
		if c == client.focus and c.screen == s then
			update_focused_client_text()
		end
	end)
	-- Initial update
	update_focused_client_text()
	-- CPU widget
	cpuwidget = wibox.widget.textbox()
	vicious.register(cpuwidget, vicious.widgets.cpu, " <b>$1%</b> | ", 2)

	-- Memory widget
	memwidget = wibox.widget.textbox()
	vicious.register(memwidget, vicious.widgets.mem, "  <b>$1%</b> | ", 5)

	-- Filesystem widget
	fswidget = wibox.widget.textbox()
	vicious.register(fswidget, vicious.widgets.fs, "  <b>${/ avail_p}%</b> | ", 120)

	-- Network widget (replace 'enp3s0' with your interface)
	netwidget = wibox.widget.textbox()
	vicious.register(netwidget, vicious.widgets.net, "  <b>${enp66s0 up_gb} ${enp66s0 down_gb}</b> | ", 3)

	-- Volume widget (requires alsa-utils)
	volwidget = wibox.widget.textbox()
	vicious.register(volwidget, vicious.widgets.volume, "  <b>$1%</b> | ", 2, "Master")

	-- Create the wibox
	s.mywibox = awful.wibar({
		position = "top",
		screen = s,
		height = 28,
		bg = beautiful.bg_normal,
		fg = beautiful.fg_normal,
		-- shape = function(cr, width, height)
		-- 	gears.shape.rounded_rect(cr, width, height, 5)
		-- end,
	})

	-- Add widgets to the wibox
	s.mywibox:setup({
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
				cpuwidget,
				memwidget,
				fswidget,
				-- netwidget,
				volwidget,
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
	})
end)
-- }}}

-- {{{ Mouse bindings
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
-- }}}

local last_minimized_client = nil

client.connect_signal("property::minimized", function(c)
	if c.minimized then
		last_minimized_client = c
	end
end)

-- Modular effect system setup
local effect_core = require("glitch_effect.core")
local wave = require("glitch_effect.effects.wave")
local hack = require("glitch_effect.effects.hack")
local beat_signal = require("glitch_effect.signal.beat_fifo")
local random_pulse = require("glitch_effect.signal.random_pulse")
local glide = require("glitch_effect.effects.glide")
local corner_resize = require("glitch_effect.effects.corner_resize")

effect_core.register_effect("glide", glide)
effect_core.register_effect("corner_resize", corner_resize)
effect_core.register_effect("hack", hack)
-- effect_core.enable_effect("glide")
-- effect_core.enable_effect("corner_resize")
effect_core.register_effect("wave", wave)
-- effect_core.enable_effect("wave")

effect_core.start(
	function()
		-- Context for all effects, polled every tick
		return {
			beat = beat_signal.get(),
			pulse = random_pulse.get(),
			tick = 0.1,
		}
	end,
	0.1 -- tick interval
)

-- Poll FIFO asynchronously every tick to update beat_signal.last_beat
gears.timer({
	timeout = 0.1,
	autostart = true,
	call_now = true,
	callback = function()
		beat_signal.poll(function(_) end)
		random_pulse.poll()
	end,
})

-- {{{ Key bindings
globalkeys = gears.table.join(
	-- Per-effect toggles (Mod+Alt+key)
	awful.key({ modkey, "Mod1" }, "g", function()
		if effect_core.is_effect_enabled("glide") then
			effect_core.disable_effect("glide")
			naughty.notify({ title = "Glide", text = "Disabled" })
		else
			effect_core.enable_effect("glide")
			naughty.notify({ title = "Glide", text = "Enabled" })
		end
	end),
	awful.key({ modkey, "Mod1" }, "h", function()
		if effect_core.is_effect_enabled("hack") then
			effect_core.disable_effect("hack")
			naughty.notify({ title = "Hack", text = "Disabled" })
		else
			effect_core.enable_effect("hack")
			naughty.notify({ title = "Hack", text = "Enabled" })
		end
	end),
	awful.key({ modkey, "Mod1" }, "w", function()
		if effect_core.is_effect_enabled("wave") then
			effect_core.disable_effect("wave")
			naughty.notify({ title = "Wave", text = "Disabled" })
		else
			effect_core.enable_effect("wave")
			naughty.notify({ title = "Wave", text = "Enabled" })
		end
	end),
	-- awful.key({ modkey, "Mod1" }, "l", function()
	--     if effect_core.is_effect_enabled("glitch") then
	--         effect_core.disable_effect("glitch")
	--         naughty.notify({ title = "Glitch", text = "Disabled" })
	--     else
	--         effect_core.enable_effect("glitch")
	--         naughty.notify({ title = "Glitch", text = "Enabled" })
	--     end
	-- end),
	awful.key({ modkey, "Mod1" }, "r", function()
		if effect_core.is_effect_enabled("corner_resize") then
			effect_core.disable_effect("corner_resize")
			naughty.notify({ title = "Corner Resize", text = "Disabled" })
		else
			effect_core.enable_effect("corner_resize")
			naughty.notify({ title = "Corner Resize", text = "Enabled" })
		end
	end),
	-- Global toggle (Mod+Alt+t)
	awful.key({ modkey, "Mod1" }, "t", function()
		local effects = { "glide", "wave", "corner_resize", "hack" }
		local any_enabled = false
		for _, name in ipairs(effects) do
			if effect_core.is_effect_enabled(name) then
				any_enabled = true
				break
			end
		end
		if any_enabled then
			for _, name in ipairs(effects) do
				effect_core.disable_effect(name)
			end
			naughty.notify({ title = "Effects", text = "All Disabled" })
		else
			for _, name in ipairs(effects) do
				effect_core.enable_effect(name)
			end
			naughty.notify({ title = "Effects", text = "All Enabled" })
		end
	end, { description = "toggle effect on all windows", group = "custom" }),
	-- Standard program
	awful.key({ modkey }, "Return", function()
		awful.spawn(terminal)
	end, { description = "open a terminal", group = "launcher" }),
	awful.key({ modkey, "Shift" }, "Return", function()
		awful.spawn.with_shell(terminal .. ' --working-directory "$(xcwd)"')
	end, { description = "open a terminal in current directory", group = "launcher" }),
	awful.key({ modkey, "Control" }, "r", awesome.restart, { description = "reload awesome", group = "awesome" }),
	awful.key({ modkey, "Shift" }, "q", awesome.quit, { description = "quit awesome", group = "awesome" }),
	awful.key({ modkey, "Shift" }, "c", function()
		awful.spawn.with_shell("i3lock -i ~/.config/i3/i3-screen-lock.png -t")
	end, { description = "lock screen", group = "awesome" }),

	-- Layout manipulation
	awful.key({ modkey }, "h", function()
		awful.client.focus.global_bydirection("left")
	end, { description = "focus left", group = "client" }),
	awful.key({ modkey }, "j", function()
		awful.client.focus.global_bydirection("down")
	end, { description = "focus down", group = "client" }),
	awful.key({ modkey }, "k", function()
		awful.client.focus.global_bydirection("up")
	end, { description = "focus up", group = "client" }),
	awful.key({ modkey }, "l", function()
		awful.client.focus.global_bydirection("right")
	end, { description = "focus right", group = "client" }),
	awful.key({ modkey }, "Left", function()
		awful.client.focus.global_bydirection("left")
	end, { description = "focus left", group = "client" }),
	awful.key({ modkey }, "Down", function()
		awful.client.focus.global_bydirection("down")
	end, { description = "focus down", group = "client" }),
	awful.key({ modkey }, "Up", function()
		awful.client.focus.global_bydirection("up")
	end, { description = "focus up", group = "client" }),
	awful.key({ modkey }, "Right", function()
		awful.client.focus.global_bydirection("right")
	end, { description = "focus right", group = "client" }),

	awful.key({ modkey, "Shift" }, "h", function()
		awful.client.swap.global_bydirection("left")
	end, { description = "swap with left client", group = "client" }),
	awful.key({ modkey, "Shift" }, "j", function()
		awful.client.swap.global_bydirection("down")
	end, { description = "swap with down client", group = "client" }),
	awful.key({ modkey, "Shift" }, "k", function()
		awful.client.swap.global_bydirection("up")
	end, { description = "swap with up client", group = "client" }),
	awful.key({ modkey, "Shift" }, "l", function()
		awful.client.swap.global_bydirection("right")
	end, { description = "swap with right client", group = "client" }),
	awful.key({ modkey, "Shift" }, "Left", function()
		awful.client.swap.global_bydirection("left")
	end, { description = "swap with left client", group = "client" }),
	awful.key({ modkey, "Shift" }, "Down", function()
		awful.client.swap.global_bydirection("down")
	end, { description = "swap with down client", group = "client" }),
	awful.key({ modkey, "Shift" }, "Up", function()
		awful.client.swap.global_bydirection("up")
	end, { description = "swap with up client", group = "client" }),
	awful.key({ modkey, "Shift" }, "Right", function()
		awful.client.swap.global_bydirection("right")
	end, { description = "swap with right client", group = "client" }),

	-- Layout switching
	awful.key({ modkey }, "space", function()
		awful.layout.inc(1)
	end, { description = "select next layout", group = "layout" }),
	awful.key({ modkey, "Shift" }, "space", function()
		if client.focus then
			client.focus.floating = not client.focus.floating
		end
	end, { description = "toggle floating", group = "client" }),

	-- Tag switching (workspaces)
	awful.key({ modkey }, "Tab", awful.tag.viewnext, { description = "view next", group = "tag" }),
	awful.key({ modkey, "Shift" }, "Tab", awful.tag.viewprev, { description = "view previous", group = "tag" }),

	-- Directional client focus
	awful.key({ modkey }, "j", function()
		awful.client.focus.byidx(1)
	end, { description = "focus next by index", group = "client" }),
	awful.key({ modkey }, "k", function()
		awful.client.focus.byidx(-1)
	end, { description = "focus previous by index", group = "client" }),

	-- Splitting
	awful.key({ modkey }, "b", function()
		awful.spawn.with_shell("echo 'horizontal' > /tmp/awesomewm-split-direction")
	end, { description = "split horizontally", group = "layout" }),
	awful.key({ modkey }, "v", function()
		awful.spawn.with_shell("echo 'vertical' > /tmp/awesomewm-split-direction")
	end, { description = "split vertically", group = "layout" }),

	-- Fullscreen
	awful.key({ modkey }, "f", function()
		if client.focus then
			client.focus.fullscreen = not client.focus.fullscreen
			client.focus:raise()
		end
	end, { description = "toggle fullscreen", group = "client" }),

	-- Minimize/restore focused client (tasklist behavior)
	awful.key({ modkey }, "m", function()
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
	end, { description = "restore a minimized client or minimize focused", group = "client" }),

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
	awful.key({ modkey }, "q", function()
		if client.focus then
			client.focus:kill()
		end
	end, { description = "close", group = "client" }),

	-- Run dialog (like mod+r in i3)
	awful.key({ modkey }, "r", function()
		awful.screen.focused().mypromptbox:run()
	end, { description = "run prompt", group = "launcher" }),

	-- Rofi (application launcher, window switcher, clipboard)
	awful.key({ modkey }, "d", function()
		awful.spawn.with_shell("rofi -modi drun -show drun -config ~/.config/rofi/rofidmenu.rasi")
	end, { description = "show rofi drun menu", group = "launcher" }),
	awful.key({ modkey }, "t", function()
		awful.spawn.with_shell("rofi -show window -config ~/.config/rofi/rofidmenu.rasi")
	end, { description = "show rofi window menu", group = "launcher" }),
	awful.key({ modkey }, "c", function()
		awful.spawn.with_shell(
			'rofi -modi "clipboard:greenclip print" -show clipboard -config ~/.config/rofi/rofidmenu.rasi'
		)
	end, { description = "show rofi clipboard", group = "launcher" }),

	-- Power menu (like mod+shift+e in i3)
	awful.key({ modkey, "Shift" }, "e", function()
		mymainmenu:toggle()
	end, { description = "menu", group = "awesome" }),

	-- Browser shortcut (mod+w)
	awful.key({ modkey }, "w", function()
		awful.spawn("zen-browser")
	end, { description = "launch browser", group = "launcher" }),

	-- File manager shortcut (mod+n)
	awful.key({ modkey }, "n", function()
		awful.spawn("thunar")
	end, { description = "launch file manager", group = "launcher" }),

	-- Screenshot (Print key)
	awful.key({}, "Print", function()
		awful.spawn.with_shell(
			'scrot ~/%Y-%m-%d-%T-screenshot.png && notify-send "Screenshot saved to ~/$(date +"%Y-%m-%d-%T")-screenshot.png"'
		)
	end, { description = "take screenshot", group = "launcher" }),

	-- Power profiles menu (mod+shift+p)
	awful.key({ modkey, "Shift" }, "p", function()
		awful.spawn.with_shell("~/.config/i3/scripts/power-profiles")
	end, { description = "power profiles menu", group = "launcher" }),

	-- Volume controls
	awful.key({}, "XF86AudioRaiseVolume", function()
		awful.spawn.with_shell("amixer -D pulse sset Master 5%+ && pkill -RTMIN+1 i3blocks")
	end, { description = "raise volume", group = "audio" }),
	awful.key({}, "XF86AudioLowerVolume", function()
		awful.spawn.with_shell("amixer -D pulse sset Master 5%- && pkill -RTMIN+1 i3blocks")
	end, { description = "lower volume", group = "audio" }),
	awful.key({}, "XF86AudioMute", function()
		awful.spawn.with_shell("amixer sset Master toggle && killall -USR1 i3blocks")
	end, { description = "toggle mute", group = "audio" }),

	-- Media controls
	awful.key({}, "XF86AudioPlay", function()
		awful.spawn("playerctl play")
	end, { description = "play media", group = "audio" }),
	awful.key({}, "XF86AudioPause", function()
		awful.spawn("playerctl pause")
	end, { description = "pause media", group = "audio" }),
	awful.key({}, "XF86AudioNext", function()
		awful.spawn("playerctl next")
	end, { description = "next media", group = "audio" }),
	awful.key({}, "XF86AudioPrev", function()
		awful.spawn("playerctl previous")
	end, { description = "previous media", group = "audio" }),

	-- Firefox media controls
	awful.key({ modkey }, "XF86AudioPlay", function()
		awful.spawn("playerctl --player=firefox play")
	end, { description = "play firefox media", group = "audio" }),
	awful.key({ modkey }, "XF86AudioPause", function()
		awful.spawn("playerctl --player=firefox pause")
	end, { description = "pause firefox media", group = "audio" }),
	awful.key({ modkey }, "XF86AudioNext", function()
		awful.spawn("playerctl --player=firefox next")
	end, { description = "next firefox media", group = "audio" }),
	awful.key({ modkey }, "XF86AudioPrev", function()
		awful.spawn("playerctl --player=firefox previous")
	end, { description = "previous firefox media", group = "audio" }),

	-- Brightness controls
	awful.key({}, "XF86MonBrightnessUp", function()
		awful.spawn.with_shell("xbacklight +5 && notify-send \"Brightness - $(xbacklight -get | cut -d '.' -f 1)%\"")
	end, { description = "increase brightness", group = "screen" }),
	awful.key({}, "XF86MonBrightnessDown", function()
		awful.spawn.with_shell("xbacklight -5 && notify-send \"Brightness - $(xbacklight -get | cut -d '.' -f 1)%\"")
	end, { description = "decrease brightness", group = "screen" })
)

-- Bind all key numbers to tags
for i = 1, 10 do
	local key = "#" .. i + 9
	globalkeys = gears.table.join(
		globalkeys,
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
		end, { description = "view tag #" .. i, group = "tag" }),

		-- Toggle tag display.
		awful.key({ modkey, "Control" }, key, function()
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
		end, { description = "toggle tag #" .. i, group = "tag" }),

		-- Move client to tag.
		awful.key({ modkey, "Shift" }, key, function()
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
		end, { description = "move focused client to tag #" .. i, group = "tag" }),

		-- Toggle tag on focused client.
		awful.key({ modkey, "Control", "Shift" }, key, function()
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
		end, { description = "toggle focused client on tag #" .. i, group = "tag" })
	)
end

-- Mouse mode (similar to your i3 mouse mode)
local mouse_mode_keys = {
	h = "left",
	j = "down",
	k = "up",
	l = "right",
	Left = "left",
	Down = "down",
	Up = "up",
	Right = "right",
	f = "1", -- left click
	d = "2", -- middle click
	s = "3", -- right click
}

local mouse_mode = awful.keygrabber({
	keybindings = {
		{
			{},
			"Escape",
			function()
				awful.keygrabber.stop()
			end,
		},
	},
	stop_key = "Escape",
	stop_event = "release",
	start_callback = function()
		naughty.notify({ title = "Mouse Mode", text = "Mouse mode activated", timeout = 2 })
	end,
	stop_callback = function()
		naughty.notify({ title = "Mouse Mode", text = "Mouse mode deactivated", timeout = 2 })
	end,
})

-- Add mouse mode keybinding
globalkeys = gears.table.join(
	globalkeys,
	awful.key({ modkey, "Shift" }, "w", function()
		mouse_mode:start()

		-- Set up mouse mode keybindings
		for key, direction in pairs(mouse_mode_keys) do
			root.keys(gears.table.join(
				root.keys(),
				awful.key({}, key, function()
					if direction == "1" or direction == "2" or direction == "3" then
						awful.spawn.with_shell("xdotool click " .. direction)
					else
						awful.spawn.with_shell(
							"xdotool mousemove_relative -- "
								.. (
									direction == "left" and "-25 0"
									or direction == "right" and "25 0"
									or direction == "up" and "0 -25"
									or direction == "down" and "0 25"
									or "0 0"
								)
						)
					end
				end)
			))
		end
	end, { description = "activate mouse mode", group = "client" })
)

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
	-- All clients will match this rule.
	{
		rule = {},
		properties = {
			border_width = 0,
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
			instance = {
				"DTA", -- Firefox addon DownThemAll.
				"copyq", -- Includes session name in class.
				"pinentry",
			},
			class = {
				"Arandr",
				"Blueman-manager",
				"Gpick",
				"Kruler",
				"MessageWin", -- kalarm.
				"Sxiv",
				"Tor Browser", -- Needs a fixed window size to avoid fingerprinting by screen size.
				"Wpa_gui",
				"veromix",
				"xtightvncviewer",
				"Yad",
				"Galculator",
				"Blueberry.py",
				"Xsane",
				"Pavucontrol",
				"Bluetooth-sendto",
				"Pamac-manager",
				"Gimp",
			},
			-- Note that the name property shown in xprop might be set slightly after creation of the client
			-- and the name shown there might not match defined rules here.
			name = {
				"Event Tester", -- xev.
				"About",
			},
			role = {
				"AlarmWindow", -- Thunderbird's calendar.
				"ConfigManager", -- Thunderbird's about:config.
				"pop-up", -- e.g. Google Chrome's (detached) Developer Tools.
				"About",
				"Organizer",
				"Preferences",
				"bubble",
				"page-info",
				"toolbox",
				"webconsole",
			},
		},
		properties = { floating = true },
	},

	-- Set Firefox to always map on the tag named "2" in screen 1.
	{ rule = { class = "Firefox" }, properties = { screen = 1, tag = " " } },

	-- Set Thunar to always map on the tag named "3" in screen 1.
	{ rule = { class = "Thunar" }, properties = { screen = 1, tag = " " } },

	-- Set Houdini to always map on the tag named "4" in screen 1.
	{ rule = { class = "Houdini FX" }, properties = { screen = 1, tag = " " } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function(c)
	-- Set the windows at the slave,
	-- i.e. put it at the end of others instead of setting it master.
	-- if not awesome.startup then awful.client.setslave(c) end

	if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then
		-- Prevent clients from being unreachable after screen count changes.
		awful.placement.no_offscreen(c)
	end
end)

-- -- Enable sloppy focus, so that focus follows mouse
-- client.connect_signal("mouse::enter", function(c)
-- 	c:emit_signal("request::activate", "mouse_enter", { raise = false })
-- end)

client.connect_signal("focus", function(c)
	c.border_color = beautiful.border_focus
end)
client.connect_signal("unfocus", function(c)
	c.border_color = beautiful.border_normal
end)
-- }}}

-- {{{ Autostart applications
-- Run once function
local function run_once(cmd_arr)
	for _, cmd in ipairs(cmd_arr) do
		awful.spawn.with_shell(string.format("pgrep -u $USER -fx '%s' > /dev/null || (%s)", cmd, cmd))
	end
end

-- Autostart applications
awful.spawn.with_shell("~/.config/awesome/autostart.sh")

-- List of apps to run on start-up
run_once({
	"feh --bg-scale ~/Pictures/bg.jpg",
	"setxkbmap -option caps:ctrl_modifier",
	"xinput set-prop Kingston\\ HyperX\\ Pulsefire\\ Core libinput\\ Accel\\ Speed -0.1",
	"xinput set-prop 14 328 0, 0, 1",
	"xinput set-prop 14 339 0",
	"xinput set-prop 14 302 1",
	"xinput set-prop 14 339 0",
	"xinput set-prop 14 342 libinput\\ Click\\ Method\\ Enabled 1,1",
	"libinput-gestures-setup start",
	-- "polybar -r internal",
	-- "polybar -r external",
	"/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1",
	"picom --config ~/.config/picom.conf",
	"dbus-launch dunst --config ~/.config/dunst/dunstrc",
	"greenclip daemon>/dev/null",
})
-- }}}
