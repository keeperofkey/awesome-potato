-- Native PipeWire audio analysis using LuaJIT FFI

-- Check for proper LuaJIT environment
local is_luajit = type(jit) == 'table'
if not is_luajit then
  local naughty = require 'naughty'
  naughty.notify {
    title = 'LuaJIT Required',
    text = 'PipeWire native module requires LuaJIT. Standard Lua detected instead.\n' .. 'Make sure AwesomeWM is compiled with LuaJIT support.',
    timeout = 100,
  }
  return {
    init = function()
      return false
    end,
    cleanup = function() end,
    initialized = false,
  }
end

local ffi = require 'ffi'
local gears = require 'gears'
local naughty = require 'naughty'

-- Show LuaJIT version info
naughty.notify {
  title = 'LuaJIT Info',
  text = string.format('Using %s %s', jit.version, jit.arch),
  timeout = 10,
}

-- Global PipeWire library handle
local pw = nil

-- Load PipeWire FFI bindings
local function load_pipewire_ffi()
  -- Check JIT status - LuaJIT might be in interpreter mode
  if jit and not jit.status() then
    naughty.notify {
      title = 'LuaJIT Warning',
      text = 'JIT compiler is disabled. FFI performance may be reduced.\n' .. 'This is typically caused by a debugger or incompatible C modules.',
      timeout = 5,
    }
  end

  -- Check if FFI is properly initialized
  if not ffi or not ffi.load then
    naughty.notify {
      title = 'FFI Error',
      text = 'FFI module not properly loaded. This might be a LuaJIT integration issue.',
      timeout = 10,
    }
    return nil
  end

  -- Try to access the dynamic loader first
  local success, libdl = pcall(ffi.load, 'libdl.so.2')
  if not success then
    naughty.notify {
      title = 'Critical Dependency Missing',
      text = 'Cannot load libdl.so.2 - dynamic loading may not work.\n' .. 'This is required for loading other libraries.',
      timeout = 100,
    }
  end

  -- Check for all potential dependencies
  local dependencies = {
    required = {
      { 'libpipewire-0.3.so.0', 'PipeWire itself' },
      -- SPA is likely already included with PipeWire on your system
      -- but we still need to check for its presence
    },
    optional = {
      { 'libasound.so.2', 'ALSA support' },
      { 'libpulse.so.0', 'PulseAudio support' },
      { 'libjack.so.0', 'JACK support' },
    },
  }

  -- Special check for SPA directory contents
  local spa_dir_exists = false
  local spa_plugins_found = false
  local spa_paths = {
    '/usr/lib/spa-0.2',
    '/usr/lib64/spa-0.2',
    '/usr/lib/x86_64-linux-gnu/spa-0.2',
  }

  for _, path in ipairs(spa_paths) do
    local f = io.open(path, 'r')
    if f then
      f:close()
      spa_dir_exists = true

      -- Check if we have basic SPA plugins
      local support_lib = io.open(path .. '/support/libspa-support.so', 'r')
      if support_lib then
        support_lib:close()
        spa_plugins_found = true
      end

      break
    end
  end

  if not spa_dir_exists then
    naughty.notify {
      title = 'SPA Missing',
      text = 'SPA plugin directory not found. Install pipewire-spa-plugins package.',
      timeout = 100,
    }
  elseif not spa_plugins_found then
    naughty.notify {
      title = 'SPA Plugins Missing',
      text = 'SPA directory exists but core plugins are missing. Try reinstalling pipewire.',
      timeout = 100,
    }
  else
    naughty.notify {
      title = 'SPA Plugins Found',
      text = 'SPA plugins appear to be installed correctly.',
      timeout = 300,
    }
  end

  -- Check dependencies first with detailed logging
  local missing_deps = {}
  local found_deps = {}

  for _, dep in ipairs(dependencies.required) do
    local lib_name, description = dep[1], dep[2]
    local success, result = pcall(function()
      return ffi.load(lib_name)
    end)
    if success then
      table.insert(found_deps, string.format('%s (%s)', lib_name, description))
    else
      table.insert(missing_deps, string.format('%s (%s): %s', lib_name, description, tostring(result)))
    end
  end

  if #missing_deps > 0 then
    naughty.notify {
      title = 'PipeWire Missing Dependencies',
      text = string.format(
        'The following required libraries are missing:\n%s\n\nInstall with:\nArch: pacman -S pipewire\nDebian/Ubuntu: apt install pipewire libspa-0.2-modules\nFedora: dnf install pipewire pipewire-libs',
        table.concat(missing_deps, '\n')
      ),
      timeout = 150,
    }
    return nil
  end

  -- Try multiple possible library names
  local libraries = {
    'libpipewire-0.3.so.0', -- Versioned library name
    'libpipewire-0.3.so', -- Generic name
    '/usr/lib/libpipewire-0.3.so.0', -- Full path
    '/usr/lib/x86_64-linux-gnu/libpipewire-0.3.so.0', -- Debian/Ubuntu path
    '/usr/lib64/libpipewire-0.3.so.0', -- Fedora/RHEL path
  }

  -- First, define the FFI C interface
  ffi.cdef [[
        typedef struct pw_loop pw_loop;
        typedef struct pw_core pw_core;
        typedef struct pw_stream pw_stream;
        typedef struct spa_pod spa_pod;
        typedef struct pw_context pw_context;
        typedef struct pw_thread_loop pw_thread_loop;
        
        pw_thread_loop* pw_thread_loop_new(const char *name, const void *props);
        void pw_thread_loop_destroy(pw_thread_loop *loop);
        void pw_thread_loop_stop(pw_thread_loop *loop);
        int pw_thread_loop_start(pw_thread_loop *loop);
        void pw_thread_loop_lock(pw_thread_loop *loop);
        void pw_thread_loop_unlock(pw_thread_loop *loop);
        pw_loop* pw_thread_loop_get_loop(pw_thread_loop *loop);
        
        pw_context* pw_context_new(pw_loop *main_loop, void *props, size_t user_data_size);
        void pw_context_destroy(pw_context *context);

        pw_loop* pw_loop_new(void);
        void pw_loop_destroy(pw_loop *loop);
        pw_core* pw_core_new(pw_loop *loop);
        void pw_core_destroy(pw_core *core);
        pw_stream* pw_stream_new(pw_core *core, const char *name, const spa_pod *props);
        void pw_stream_destroy(pw_stream *stream);
        int pw_stream_connect(pw_stream *stream, uint32_t direction, uint32_t target_id, uint32_t flags, const spa_pod *format);
        int pw_loop_iterate(pw_loop *loop, int timeout);

        struct spa_format_audio_raw {
            uint32_t format;
            uint32_t flags;
            uint32_t rate;
            uint32_t channels;
            uint32_t position[32];
            uint32_t format_info[32];
        };
    ]]

  -- Try to load each library until one works
  local loaded = false
  local errors = {}

  for _, libname in ipairs(libraries) do
    local success, lib_or_error = pcall(ffi.load, libname)
    if success then
      pw = lib_or_error
      loaded = true
      naughty.notify {
        title = 'PipeWire',
        text = string.format('Successfully loaded PipeWire library: %s', libname),
        timeout = 30,
      }
      break
    else
      table.insert(errors, string.format('%s: %s', libname, tostring(lib_or_error)))
    end
  end

  if not loaded then
    naughty.notify {
      title = 'PipeWire Error',
      text = string.format('Failed to load PipeWire library. Tried:\n%s', table.concat(errors, '\n')),
      timeout = 100,
    }
    return nil
  end

  -- Check if PipeWire service is running with more thorough checks
  local pw_running = false
  local pw_pulse_running = false
  local service_info = {}

  -- Check process table first (more reliable)
  local success, result = pcall(function()
    local f = io.popen 'ps -ef | grep -v grep | grep pipewire'
    if f then
      local output = f:read '*a'
      f:close()
      if output and output:match 'pipewire' then
        pw_running = true
        table.insert(service_info, 'PipeWire process found')
      end
      if output and output:match 'pipewire%-pulse' then
        pw_pulse_running = true
        table.insert(service_info, 'PipeWire-PulseAudio process found')
      end
    end

    -- Try systemctl status as well
    f = io.popen 'systemctl --user status pipewire.service 2>/dev/null | grep Active:'
    if f then
      local status = f:read '*l'
      f:close()
      if status and status:match 'active' then
        pw_running = true
        table.insert(service_info, 'pipewire.service is active')
      elseif status then
        table.insert(service_info, 'pipewire.service status: ' .. status)
      end
    end
    
    -- Check for available audio sources
    f = io.popen 'pactl list short sources 2>/dev/null'
    if f then
      local sources = f:read '*a'
      f:close()
      if sources and #sources > 0 then
        -- Count the sources
        local count = 0
        for _ in sources:gmatch('\n') do
          count = count + 1
        end
        table.insert(service_info, string.format('Found %d audio sources', count))
        
        -- Display them
        local source_list = {}
        for line in sources:gmatch('([^\n]+)') do
          local id, name = line:match('(%d+)%s+([^%s]+)')
          if id and name then
            table.insert(source_list, string.format('- %s', name))
          end
        end
        
        if #source_list > 0 then
          table.insert(service_info, 'Available sources:')
          for i = 1, math.min(3, #source_list) do
            table.insert(service_info, source_list[i])
          end
          if #source_list > 3 then
            table.insert(service_info, string.format('... and %d more', #source_list - 3))
          end
        end
      else
        table.insert(service_info, 'No audio sources found via pactl')
      end
    end

    -- Check if SPA plugins are installed
    local spa_paths = {
      '/usr/lib/spa-0.2',
      '/usr/lib64/spa-0.2',
      '/usr/lib/x86_64-linux-gnu/spa-0.2',
    }
    local spa_plugins_found = false

    for _, path in ipairs(spa_paths) do
      local f = io.open(path, 'r')
      if f then
        f:close()
        spa_plugins_found = true
        table.insert(service_info, 'SPA plugins found at: ' .. path)
        break
      end
    end

    if not spa_plugins_found then
      table.insert(service_info, 'No SPA plugin directories found!')
    end

    return pw_running
  end)

  if success and not result then
    naughty.notify {
      title = 'PipeWire Not Running',
      text = 'The PipeWire service does not appear to be running.\n\n'
        .. 'Status details:\n'
        .. table.concat(service_info, '\n')
        .. '\n\n'
        .. 'Start with:\nsystemctl --user start pipewire.service pipewire-pulse.service',
      timeout = 150,
    }
  elseif success and result then
    naughty.notify {
      title = 'PipeWire Status',
      text = 'PipeWire appears to be running.\n\n' .. 'Status details:\n' .. table.concat(service_info, '\n'),
      timeout = 500,
    }
  end

  return pw
end

-- Get available audio sources
local function get_audio_sources()
  local sources = {}
  local default_source = nil
  
  local success, result = pcall(function()
    local f = io.popen('pactl list short sources 2>/dev/null')
    if f then
      local output = f:read('*a')
      f:close()
      
      for line in output:gmatch("([^\n]+)") do
        local id, name, _, _, state = line:match("(%d+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)")
        if id and name then
          table.insert(sources, {
            id = tonumber(id),
            name = name,
            state = state
          })
          
          -- Prefer monitor sources that are RUNNING
          if state == "RUNNING" and name:match("%.monitor$") then
            default_source = #sources
          -- Or any RUNNING source
          elseif state == "RUNNING" and not default_source then
            default_source = #sources
          -- Or any monitor source
          elseif name:match("%.monitor$") and not default_source then
            default_source = #sources
          end
        end
      end
      
      -- If no RUNNING sources found, just use the first one
      if not default_source and #sources > 0 then
        default_source = 1
      end
    end
    
    return sources, default_source
  end)
  
  if not success then
    naughty.notify {
      title = 'Audio Source Error',
      text = 'Failed to get audio sources: ' .. tostring(result),
      timeout = 5,
    }
    return {}, nil
  end
  
  return result, default_source
end

-- Create audio format as spa_pod
local function create_audio_format()
  local format = ffi.new 'struct spa_format_audio_raw'
  format.format = 0x00000001 -- SPA_AUDIO_FORMAT_S16 (16-bit signed integer)
  format.rate = 48000
  format.channels = 2
  
  -- Set position values for stereo
  format.position[0] = 0  -- FL - Front Left
  format.position[1] = 1  -- FR - Front Right
  
  -- Store the format in a table to prevent garbage collection
  if not _G._pipewire_format_refs then
    _G._pipewire_format_refs = {}
  end
  table.insert(_G._pipewire_format_refs, format)
  
  -- Print format information for debugging
  naughty.notify {
    title = 'Audio Format',
    text = string.format('Creating format with rate=%d, channels=%d, format=%d',
                        format.rate, format.channels, format.format),
    timeout = 5,
  }
  
  return ffi.cast('const spa_pod*', format)
end

-- Audio processing with enhanced responsiveness and improved signal detection
local function process_audio(data, length)
  -- Safely handle data conversion with bounds checking
  local samples = {}
  local sample_count = math.floor(length / 2)  -- 2 bytes per sample for S16 format
  
  -- Ensure reasonable limit on sample count to avoid excessive processing
  sample_count = math.min(sample_count, 4096)
  
  -- Skip silent audio (common cause of no signals being detected)
  local has_audio = false
  
  -- Process raw samples with improved error handling
  for i = 0, sample_count - 1 do
    if i * 2 < length then
      local sample_value = 0
      -- Use pcall to prevent crashes from bad memory access
      local success, sample = pcall(function() 
        return ffi.cast('int16_t*', data)[i] 
      end)
      
      if success and sample then
        -- Normalize to range [-1.0, 1.0] and add amplification for better effect
        sample_value = (sample / 32768.0) * 2.0  -- Increased amplification
        
        -- Check if we have non-silent audio
        if math.abs(sample_value) > 0.01 then
          has_audio = true
        end
      end
      
      table.insert(samples, sample_value)
    end
  end

  -- Safety check - abort if no samples or only silence
  if #samples == 0 or not has_audio then
    -- Still emit a minimal signal to keep effects responsive
    -- Use a very low level to indicate "silence" but not completely off
    awesome.emit_signal('glitch::audio', 0.05)
    awesome.emit_signal('glitch::fft', {low = 0.1, mid = 0.1, high = 0.1})
    return
  end

  -- Calculate RMS level with improved responsiveness
  local sum = 0
  local peak = 0
  for _, sample in ipairs(samples) do
    sum = sum + sample * sample
    peak = math.max(peak, math.abs(sample))
  end
  
  -- Use a blend of RMS and peak for better dynamic range
  local rms = math.sqrt(sum / #samples)
  local level = (rms * 0.7) + (peak * 0.3)  -- Blend RMS and peak
  
  -- Apply a non-linear curve to make low sounds more visible
  level = math.pow(level, 0.6)  -- More aggressive curve to boost low levels
  
  -- Apply amplification to make signals more visible and reactive
  level = level * 3.0
  
  -- Clamp the value
  level = math.min(math.max(level, 0), 1)
  
  -- Emit the audio level signal
  awesome.emit_signal('glitch::audio', level)

  -- Perform FFT analysis with optimized size for better frequency resolution
  local fft_size = math.min(256, #samples)  -- Further reduced for better performance
  local spectrum = {}
  
  for i = 1, math.floor(fft_size / 2) do
    local sum_re = 0
    local sum_im = 0
    
    for j = 1, fft_size do
      if j > #samples then
        break
      end
      local angle = 2 * math.pi * (j - 1) * (i - 1) / fft_size
      sum_re = sum_re + samples[j] * math.cos(angle)
      sum_im = sum_im + samples[j] * math.sin(angle)
    end
    
    -- The magnitude of the frequency component
    spectrum[i] = math.sqrt(sum_re^2 + sum_im^2)
  end

  -- Calculate frequency bands with optimized frequency splitting for visual effects
  -- These frequency ranges work better for visualization effects:
  -- Low (bass/sub): 0-150Hz, Mid: 150-1500Hz, High: 1500Hz+
  local freq_per_bin = 48000 / fft_size  -- Sample rate / FFT size
  
  local low_bin_max = math.floor(150 / freq_per_bin)
  local mid_bin_max = math.floor(1500 / freq_per_bin)
  
  low_bin_max = math.max(1, math.min(low_bin_max, #spectrum))
  mid_bin_max = math.max(low_bin_max + 1, math.min(mid_bin_max, #spectrum))
  
  -- Sum the energy in each band
  local low, mid, high = 0, 0, 0
  local low_count, mid_count, high_count = 0, 0, 0
  
  for i = 1, low_bin_max do
    low = low + spectrum[i]
    low_count = low_count + 1
  end
  
  for i = low_bin_max + 1, mid_bin_max do
    mid = mid + spectrum[i]
    mid_count = mid_count + 1
  end
  
  for i = mid_bin_max + 1, #spectrum do
    high = high + spectrum[i]
    high_count = high_count + 1
  end
  
  -- Avoid division by zero
  if low_count > 0 then low = low / low_count end
  if mid_count > 0 then mid = mid / mid_count end
  if high_count > 0 then high = high / high_count end
  
  -- Apply different non-linear scaling to emphasize each frequency range
  -- These create more dramatic visual effects
  low = math.pow(low, 0.4)   -- More emphasis on bass
  mid = math.pow(mid, 0.6)   -- Medium emphasis on mids
  high = math.pow(high, 0.8) -- Less emphasis on highs
  
  -- Apply overall amplification to bands
  low = low * 2.5
  mid = mid * 2.0
  high = high * 1.5
  
  -- Normalize all bands relative to each other
  local max_value = math.max(low, mid, high, 0.001)  -- Avoid division by zero
  low = math.min(low / max_value, 1.0)
  mid = math.min(mid / max_value, 1.0)
  high = math.min(high / max_value, 1.0)
  
  -- Create the bands structure with minimum floor values
  -- This ensures some minimal activity even during quiet parts
  local bands = {
    low = math.max(low, 0.1),
    mid = math.max(mid, 0.1),
    high = math.max(high, 0.1),
  }
  
  -- Emit the FFT signal
  awesome.emit_signal('glitch::fft', bands)
end

-- Initialize PipeWire
local function init_pipewire(source_id)
  -- Check if we already have loaded the library, if not, load it
  if not pw then
    if not load_pipewire_ffi() then
      naughty.notify {
        title = 'PipeWire Error',
        text = 'Failed to load PipeWire FFI bindings',
        timeout = 500,
      }
      return nil
    end
  end
  
  -- Get available audio sources
  local sources, default_index = get_audio_sources()
  
  -- Show available sources
  local sources_text = "Available audio sources:\n"
  for i, source in ipairs(sources) do
    sources_text = sources_text .. string.format(
      "%d. %s (ID: %d, State: %s)%s\n", 
      i, 
      source.name, 
      source.id, 
      source.state,
      (i == default_index) and " [DEFAULT]" or ""
    )
  end
  
  naughty.notify {
    title = 'PipeWire Audio Sources',
    text = sources_text,
    timeout = 10,
  }
  
  -- Select source: either the provided one or the default
  local selected_source = nil
  if source_id and source_id > 0 then
    -- Find source with matching ID
    for _, source in ipairs(sources) do
      if source.id == source_id then
        selected_source = source
        break
      end
    end
  elseif default_index and sources[default_index] then
    selected_source = sources[default_index]
  end
  
  if selected_source then
    naughty.notify {
      title = 'PipeWire Source Selected',
      text = string.format("Using source: %s (ID: %d, State: %s)", 
                         selected_source.name, selected_source.id, selected_source.state),
      timeout = 5,
    }
  else
    naughty.notify {
      title = 'PipeWire Warning',
      text = 'No suitable audio source found. Audio-reactive effects may not work.',
      timeout = 5,
    }
  end

  -- Try to use thread loop first (more robust)
  local thread_loop = nil
  local main_loop = nil
  local context = nil

  -- Try the thread loop method first (preferred)
  local success, result = pcall(function()
    thread_loop = pw.pw_thread_loop_new('awesome-pw-loop', nil)
    if thread_loop == nil then
      return nil, 'pw_thread_loop_new failed'
    end

    main_loop = pw.pw_thread_loop_get_loop(thread_loop)
    if main_loop == nil then
      pw.pw_thread_loop_destroy(thread_loop)
      return nil, 'pw_thread_loop_get_loop failed'
    end

    context = pw.pw_context_new(main_loop, nil, 0)
    if context == nil then
      pw.pw_thread_loop_destroy(thread_loop)
      return nil, 'pw_context_new failed'
    end

    local start_result = pw.pw_thread_loop_start(thread_loop)
    if start_result ~= 0 then
      pw.pw_context_destroy(context)
      pw.pw_thread_loop_destroy(thread_loop)
      return nil, 'pw_thread_loop_start failed with code ' .. tostring(start_result)
    end

    return {
      thread_loop = thread_loop,
      main_loop = main_loop,
      context = context,
    }
  end)

  local loop_info

  if success and result then
    loop_info = result
    naughty.notify {
      title = 'PipeWire Success',
      text = 'Successfully created PipeWire thread loop',
      timeout = 3,
    }
  else
    local error_msg = success and 'Unknown error' or tostring(result)
    naughty.notify {
      title = 'PipeWire Thread Loop Failed',
      text = 'Failed to create PipeWire thread loop: ' .. error_msg .. '\nFalling back to simple loop',
      timeout = 50,
    }

    -- Fall back to simple loop method
    success, result = pcall(function()
      return pw.pw_loop_new()
    end)
    if not success then
      naughty.notify {
        title = 'PipeWire Error',
        text = string.format('Exception in pw_loop_new: %s', tostring(result)),
        timeout = 50,
      }
      return nil
    end

    main_loop = result
    if main_loop == nil then
      local err = ffi.errno()
      local error_messages = {
        [2] = 'No such file or directory - library exists but dependencies missing',
        [12] = 'Out of memory',
        [13] = 'Permission denied - check library permissions',
        [22] = 'Invalid argument',
      }
      local error_text = error_messages[err] or 'Unknown error'

      if err == 2 then
        -- This is often caused by missing SPA plugins
        naughty.notify {
          title = 'PipeWire Missing Dependencies',
          text = string.format(
            'Failed to create loop: Missing SPA plugins\n\n'
              .. 'Try reinstalling and ensuring these packages are installed:\n'
              .. 'pacman -S pipewire pipewire-audio\n\n'
              .. 'Also ensure PipeWire is running:\n'
              .. 'systemctl --user start pipewire.service pipewire-pulse.service'
          ),
          timeout = 150,
        }
      else
        -- Generic error
        naughty.notify {
          title = 'PipeWire Error',
          text = string.format('Failed to create loop (errno: %d - %s)', err, error_text),
          timeout = 50,
        }
      end

      return nil
    end

    loop_info = {
      thread_loop = nil,
      main_loop = main_loop,
      context = nil,
    }
  end

  -- Continue with core creation using whatever loop method succeeded
  local core = nil
  success, result = pcall(function()
    if loop_info.context then
      -- For thread loop method, core may already exist via context
      return loop_info.context
    else
      -- For simple loop method
      return pw.pw_core_new(loop_info.main_loop)
    end
  end)

  if not success then
    naughty.notify {
      title = 'PipeWire Error',
      text = string.format('Exception in pw_core_new: %s', tostring(result)),
      timeout = 500,
    }
    if loop_info.thread_loop then
      pw.pw_thread_loop_destroy(loop_info.thread_loop)
    else
      pw.pw_loop_destroy(loop_info.main_loop)
    end
    return nil
  end
  core = result

  if core == nil then
    naughty.notify {
      title = 'PipeWire Error',
      text = 'Failed to create core (is PipeWire running?)',
      timeout = 50,
    }
    if loop_info.thread_loop then
      pw.pw_thread_loop_destroy(loop_info.thread_loop)
    else
      pw.pw_loop_destroy(loop_info.main_loop)
    end
    return nil
  end

  -- Create a stream for audio capture
  local stream = nil
  success, result = pcall(function()
    return pw.pw_stream_new(core, 'awesome_audio', nil)
  end)
  if not success then
    naughty.notify {
      title = 'PipeWire Error',
      text = string.format('Exception in pw_stream_new: %s', tostring(result)),
      timeout = 50,
    }
    if loop_info.thread_loop then
      pw.pw_thread_loop_destroy(loop_info.thread_loop) -- This will clean up context too
    else
      pw.pw_core_destroy(core)
      pw.pw_loop_destroy(loop_info.main_loop)
    end
    return nil
  end
  stream = result

  if stream == nil then
    naughty.notify {
      title = 'PipeWire Error',
      text = 'Failed to create stream',
      timeout = 5,
    }
    if loop_info.thread_loop then
      pw.pw_thread_loop_destroy(loop_info.thread_loop) -- This will clean up context too
    else
      pw.pw_core_destroy(core)
      pw.pw_loop_destroy(loop_info.main_loop)
    end
    return nil
  end

  -- Create audio format and connect stream
  local format = create_audio_format()
  local ret = -1
  
  -- Target node ID (source ID if provided, otherwise 0 for default)
  local target_id = selected_source and selected_source.id or 0
  
  naughty.notify {
    title = 'PipeWire Stream Connection',
    text = string.format('Connecting to source ID: %d', target_id),
    timeout = 5,
  }
  
  success, result = pcall(function()
    return pw.pw_stream_connect(
      stream,
      0, -- PW_DIRECTION_INPUT (capture audio)
      target_id, -- Target node ID (specific source or 0 for default)
      1, -- Flags: PW_STREAM_FLAG_AUTOCONNECT (1)
      format
    )
  end)

  if not success then
    naughty.notify {
      title = 'PipeWire Error',
      text = string.format('Exception in pw_stream_connect: %s', tostring(result)),
      timeout = 50,
    }
    pw.pw_stream_destroy(stream)
    if loop_info.thread_loop then
      pw.pw_thread_loop_destroy(loop_info.thread_loop) -- This will clean up context too
    else
      pw.pw_core_destroy(core)
      pw.pw_loop_destroy(loop_info.main_loop)
    end
    return nil
  end
  ret = result

  if ret < 0 then
    naughty.notify {
      title = 'PipeWire Error',
      text = string.format('Failed to connect stream (error code: %d)', ret),
      timeout = 50,
    }
    pw.pw_stream_destroy(stream)
    if loop_info.thread_loop then
      pw.pw_thread_loop_destroy(loop_info.thread_loop) -- This will clean up context too
    else
      pw.pw_core_destroy(core)
      pw.pw_loop_destroy(loop_info.main_loop)
    end
    return nil
  end

  naughty.notify {
    title = 'PipeWire',
    text = 'Successfully initialized PipeWire audio capture',
    timeout = 30,
  }

  return {
    thread_loop = loop_info.thread_loop,
    main_loop = loop_info.main_loop,
    context = loop_info.context,
    core = core,
    stream = stream,
  }
end

-- Normalize frequency bands
local function normalize_bands(spectrum)
  local max_value = math.max(unpack(spectrum))
  if max_value > 0 then
    for i = 1, #spectrum do
      spectrum[i] = spectrum[i] / max_value
    end
  end
  return spectrum
end

local pipewire = {
  initialized = false,
  thread_loop = nil,
  main_loop = nil,
  context = nil,
  core = nil,
  stream = nil,
}

function pipewire.init(source_id)
  if pipewire.initialized then
    return true
  end

  -- First try to initialize PipeWire with optional source ID
  local ctx = nil
  local success, result = pcall(function()
    return init_pipewire(source_id)
  end)
  
  if not success then
    naughty.notify {
      title = 'PipeWire Fatal Error',
      text = 'Exception during initialization: ' .. tostring(result),
      timeout = 100,
    }
    return false
  end

  ctx = result
  if not ctx then
    -- init_pipewire already showed an error notification
    return false
  end

  -- Setup the context
  pipewire.thread_loop = ctx.thread_loop
  pipewire.main_loop = ctx.main_loop
  pipewire.context = ctx.context
  pipewire.core = ctx.core
  pipewire.stream = ctx.stream
  pipewire.initialized = true

  -- Create PipeWire loop iteration timer with more frequent polling
  local loop_timer_id = gears.timer.start_new(0.02, function() -- Increased frequency to 20ms interval (50Hz)
    if not pipewire.main_loop then
      return false -- Stop the timer if loop is gone
    end

    local success, result = pcall(function()
      return pw.pw_loop_iterate(pipewire.main_loop, 5)  -- Reduced timeout for faster updates
    end)

    if not success then
      naughty.notify {
        title = 'PipeWire Runtime Error',
        text = 'Error during loop iteration: ' .. tostring(result),
        timeout = 50,
      }
      -- Don't stop the timer on single error
      return true
    end

    return true -- Continue the timer
  end)
  
  -- Timer for debug output (optional)
  local debug_timer_id = gears.timer.start_new(10, function() -- 10 second interval
    if not pipewire.initialized then
      return false
    end
    
    naughty.notify {
      title = 'PipeWire Status',
      text = 'Audio capture active using Native FFI implementation',
      timeout = 2,
    }
    
    return true
  end)
  
  -- Store timer IDs
  pipewire.timer_ids = {
    loop_timer_id = loop_timer_id,
    debug_timer_id = debug_timer_id
  }

  return true
end

function pipewire.cleanup()
  if not pipewire.initialized then
    return
  end

  -- Stop all timers with improved error handling
  if pipewire.timer_ids then
    -- Loop through all timer IDs and stop them safely
    for name, timer_id in pairs(pipewire.timer_ids) do
      pcall(function()
        gears.timer.stop(timer_id)
      end)
    end
    
    pipewire.timer_ids = nil
  end
  
  -- For backward compatibility
  if pipewire.timer_id then
    pcall(function()
      gears.timer.stop(pipewire.timer_id)
    end)
    pipewire.timer_id = nil
  end

  -- Clean up PipeWire resources with better error handling
  if pipewire.stream then
    pcall(function()
      -- Try to disconnect stream first before destroying
      pw.pw_stream_disconnect(pipewire.stream)
      pw.pw_stream_destroy(pipewire.stream)
    end)
    pipewire.stream = nil
  end

  -- Thread loop cleanup (handles both thread and normal loop cases)
  if pipewire.thread_loop then
    -- First stop the thread loop (important!)
    pcall(function()
      pw.pw_thread_loop_stop(pipewire.thread_loop)
    end)
    
    -- Then destroy it
    pcall(function()
      pw.pw_thread_loop_destroy(pipewire.thread_loop)
    end)
    
    pipewire.thread_loop = nil
    pipewire.main_loop = nil
    pipewire.context = nil
  else
    -- Handle non-thread loop cleanup
    if pipewire.core then
      pcall(function()
        pw.pw_core_destroy(pipewire.core)
      end)
      pipewire.core = nil
    end

    if pipewire.main_loop then
      pcall(function()
        pw.pw_loop_destroy(pipewire.main_loop)
      end)
      pipewire.main_loop = nil
    end
  end

  -- Reset all other state
  pipewire.initialized = false
  pipewire.core = nil
  pipewire.context = nil

  naughty.notify {
    title = 'PipeWire',
    text = 'Audio capture stopped and resources cleaned up',
    timeout = 5,
  }
end

return pipewire

