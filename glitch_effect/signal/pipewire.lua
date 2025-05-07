-- Audio integration wrapper
-- Selects the best available implementation

local naughty = require 'naughty'
local awful = require 'awful'
local config = require 'config'
local modkey = config.modkey

-- Try to load implementations in order of preference
local implementation_options = {
  -- Start with our new simplified implementation
  {
    name = 'Simple PipeWire',
    module = 'glitch_effect.signal.pw_simple',
  },
  -- Fall back to other implementations
  {
    name = 'Native FFI',
    module = 'glitch_effect.signal.pipewire_native',
  },
  {
    name = 'Stream API',
    module = 'glitch_effect.signal.pipewire_stream_improved',
  },
  {
    name = 'Simple Audio',
    module = 'glitch_effect.signal.simple_audio',
  },
  {
    name = 'ALSA Direct',
    module = 'glitch_effect.signal.alsa_capture',
  },
}

-- Store current implementation and source ID
local pipewire = nil
local current_source_id = nil

for _, impl in ipairs(implementation_options) do
  local success, module = pcall(require, impl.module)
  if success and module then
    pipewire = module
    naughty.notify {
      title = 'PipeWire',
      text = 'Using ' .. impl.name .. ' implementation',
      timeout = 300,
    }
    break
  end
end

if not pipewire then
  naughty.notify {
    title = 'PipeWire Error',
    text = 'Failed to load any PipeWire implementation',
    timeout = 500,
  }

  -- Return dummy implementation
  return {
    init = function()
      return false
    end,
    cleanup = function() end,
    initialized = false,
  }
end

-- Wrap the original module to add source selection functionality
local wrapper = {
  initialized = false
}

-- Get source ID from pactl - improved version
local function get_selected_source_id()
  local success, result = pcall(function()
    -- Check directly for RUNNING sources first, particularly the built-in audio monitor
    local f_running = io.popen('pactl list short sources 2>/dev/null')
    if f_running then
      local sources = f_running:read('*a')
      f_running:close()
      
      -- First priority: explicitly look for the built-in audio monitor in RUNNING state
      for line in sources:gmatch("([^\n]+)") do
        local id, name, _, _, state = line:match("(%d+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)")
        if id and name and state == "RUNNING" and 
           (name:match("pci.*analog.*monitor") or name:match("alsa_output.*analog.*monitor")) then
          naughty.notify {
            title = 'PipeWire Source',
            text = 'Using running built-in audio: ' .. name,
            timeout = 5,
          }
          return tonumber(id)
        end
      end
      
      -- Second priority: any RUNNING monitor source
      for line in sources:gmatch("([^\n]+)") do
        local id, name, _, _, state = line:match("(%d+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)")
        if id and name and name:match("%.monitor$") and state == "RUNNING" then
          naughty.notify {
            title = 'PipeWire Source',
            text = 'Using running monitor: ' .. name,
            timeout = 5,
          }
          return tonumber(id)
        end
      end
    end
  
    -- If no running sources found, try to get the default source
    local f = io.popen('pactl get-default-source 2>/dev/null')
    if f then
      local name = f:read('*l')
      f:close()
      
      if name then
        -- Get ID for this name
        local f2 = io.popen('pactl list short sources 2>/dev/null')
        if f2 then
          local sources = f2:read('*a')
          f2:close()
          
          for line in sources:gmatch("([^\n]+)") do
            local id, source_name = line:match("(%d+)%s+([^%s]+)")
            if id and source_name == name then
              naughty.notify {
                title = 'PipeWire Source',
                text = 'Using default source: ' .. name,
                timeout = 5,
              }
              return tonumber(id)
            end
          end
        end
      end
    end
    
    -- If default not found, fall back to any source
    local f3 = io.popen('pactl list short sources 2>/dev/null')
    if f3 then
      local sources = f3:read('*a')
      f3:close()
      
      -- Any monitor
      for line in sources:gmatch("([^\n]+)") do
        local id, name = line:match("(%d+)%s+([^%s]+)")
        if id and name and name:match("%.monitor$") then
          naughty.notify {
            title = 'PipeWire Source',
            text = 'Using fallback monitor: ' .. name,
            timeout = 5,
          }
          return tonumber(id)
        end
      end
      
      -- Then any source
      for line in sources:gmatch("([^\n]+)") do
        local id, name = line:match("(%d+)%s+([^%s]+)")
        if id and name then
          naughty.notify {
            title = 'PipeWire Source',
            text = 'Using last resort source: ' .. name,
            timeout = 5,
          }
          return tonumber(id)
        end
      end
    end
    
    return nil
  end)
  
  if success then
    return result
  else
    naughty.notify {
      title = 'PipeWire Error',
      text = 'Failed to find any audio source: ' .. tostring(result),
      timeout = 5,
    }
    return nil
  end
end

-- Initialize with automatic source detection
function wrapper.init()
  if wrapper.initialized then
    return true
  end
  
  -- Try to get default source ID
  current_source_id = get_selected_source_id()
  
  if current_source_id then
    naughty.notify {
      title = 'PipeWire',
      text = 'Detected source ID: ' .. current_source_id,
      timeout = 5,
    }
  else
    naughty.notify {
      title = 'PipeWire',
      text = 'No default source detected, using system default',
      timeout = 5,
    }
  end
  
  -- Initialize with detected source
  local success = pipewire.init(current_source_id)
  wrapper.initialized = success
  return success
end

-- Set a specific audio source
function wrapper.set_source(source_id)
  if wrapper.initialized then
    wrapper.cleanup()
  end
  
  current_source_id = source_id
  local success = pipewire.init(source_id)
  wrapper.initialized = success
  return success
end

-- Pass through other functions
function wrapper.cleanup()
  if not wrapper.initialized then
    return
  end
  
  pipewire.cleanup()
  wrapper.initialized = false
end

-- Add source selection keybinding
awful.keyboard.append_global_keybindings {
  -- Source selection (Mod+Alt+a)
  awful.key({ modkey, 'Mod1' }, 'a', function()
    -- Ask user for source ID
    awful.prompt.run {
      prompt = 'Enter audio source ID: ',
      textbox = awful.screen.focused().mypromptbox.widget,
      exe_callback = function(input)
        if input and input:match('^%d+$') then
          local source_id = tonumber(input)
          naughty.notify {
            title = 'PipeWire',
            text = 'Switching to audio source ID: ' .. source_id,
            timeout = 5,
          }
          wrapper.set_source(source_id)
        else
          naughty.notify {
            title = 'PipeWire',
            text = 'Invalid source ID. Please enter a number.',
            timeout = 5,
          }
        end
      end,
    }
  end, { description = 'select audio source', group = 'custom' }),
}

return wrapper

