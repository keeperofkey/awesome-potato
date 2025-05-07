-- Simplified and robust PipeWire audio capture implementation
-- Based on the official PipeWire documentation

local ffi = require('ffi')
local gears = require('gears')
local naughty = require('naughty')

-- Check for LuaJIT environment
local is_luajit = type(jit) == 'table'
if not is_luajit then
  naughty.notify {
    title = 'LuaJIT Required',
    text = 'PipeWire module requires LuaJIT. Standard Lua detected.',
    timeout = 10,
  }
  return {
    init = function() return false end,
    cleanup = function() end,
    initialized = false,
  }
end

-- Log LuaJIT version
naughty.notify {
  title = 'LuaJIT Info',
  text = string.format('Using %s %s', jit.version, jit.arch),
  timeout = 5,
}

-- FFI definitions for PipeWire
ffi.cdef [[
  // Core PipeWire definitions
  void pw_init(int *argc, char **argv);
  void pw_deinit(void);
  
  // Main loop for synchronous operations
  typedef struct pw_main_loop pw_main_loop;
  pw_main_loop* pw_main_loop_new(const void *props);
  void pw_main_loop_destroy(pw_main_loop *loop);
  void* pw_main_loop_get_loop(pw_main_loop *loop);
  
  // Core objects
  typedef struct pw_context pw_context;
  pw_context* pw_context_new(void *main_loop, void *props, size_t user_data_size);
  void pw_context_destroy(pw_context *context);
  
  typedef struct pw_core pw_core;
  pw_core* pw_context_connect(pw_context *context, void *properties, size_t user_data_size);
  void pw_core_disconnect(pw_core *core);
  
  // Simple API for audio capture
  typedef struct pw_stream pw_stream;
  typedef struct pw_buffer pw_buffer;
  typedef struct pw_properties pw_properties;
  typedef struct spa_pod spa_pod;
  typedef struct spa_data spa_data;
  
  pw_properties* pw_properties_new(const char *key, ...);
  void pw_properties_free(pw_properties *properties);
  void pw_properties_set(pw_properties *properties, const char *key, const char *value);
  
  pw_stream* pw_stream_new(pw_core *core, const char *name, pw_properties *props);
  pw_stream* pw_stream_new_simple(void *loop, 
                                  const char *name, 
                                  pw_properties *props,
                                  const void *events,
                                  void *data);
  void pw_stream_destroy(pw_stream *stream);
  
  int pw_stream_connect(pw_stream *stream, 
                       int direction, 
                       uint32_t target_id,
                       int flags, 
                       const void **params,
                       uint32_t n_params);
                       
  int pw_stream_update_params(pw_stream *stream,
                             const void **params,
                             uint32_t n_params);
                             
  pw_buffer* pw_stream_dequeue_buffer(pw_stream *stream);
  int pw_stream_queue_buffer(pw_stream *stream, pw_buffer *buffer);
  
  // For timer functions
  int pw_loop_iterate(void *loop, int timeout);
  
  // For audio data access
  typedef struct {
    uint32_t type;
    uint32_t flags;
    int fd;
    uint32_t mapoffset;
    uint32_t maxsize;
    uint32_t chunk_size;
    uint32_t chunk_offset;
    void *data;
  } spa_data;
  
  typedef struct {
    uint32_t n_datas;
    spa_data *datas;
  } spa_buffer;
]]

-- Global module table
local pipewire = {
  initialized = false,
  main_loop = nil,
  context = nil,
  core = nil,
  stream = nil,
  pw = nil,       -- PipeWire library handle
  timer_id = nil,
  debug_interval = 200,  -- Print debug message every 200 ticks
  debug_count = 0,
}

-- Load PipeWire library
local function load_pipewire_library()
  local libraries = {
    'libpipewire-0.3.so.0',
    'libpipewire-0.3.so',
    '/usr/lib/libpipewire-0.3.so.0',
    '/usr/lib/x86_64-linux-gnu/libpipewire-0.3.so.0',
    '/usr/lib64/libpipewire-0.3.so.0',
  }
  
  for _, libname in ipairs(libraries) do
    local success, lib = pcall(ffi.load, libname)
    if success then
      naughty.notify {
        title = 'PipeWire',
        text = 'Successfully loaded PipeWire library: ' .. libname,
        timeout = 5,
      }
      return lib
    end
  end
  
  naughty.notify {
    title = 'PipeWire Error',
    text = 'Failed to load PipeWire library',
    timeout = 10,
  }
  return nil
end

-- Process audio data from buffer
local function process_audio_data(buffer)
  if buffer == nil then
    -- No buffer available
    return
  end
  
  local spa_buffer = ffi.cast('spa_buffer*', buffer.buffer)
  if spa_buffer == nil or spa_buffer.n_datas == 0 then
    -- Invalid buffer
    return
  end

  -- Get pointer to data
  local data = spa_buffer.datas[0].data
  local size = spa_buffer.datas[0].chunk_size

  if data == nil or size == 0 then
    -- No data in buffer
    return
  end
  
  -- Process as 32-bit float samples (typical for PipeWire)
  local samples = ffi.cast('float*', data)
  local n_samples = math.floor(size / 4) -- 4 bytes per float
  
  -- Safety check - limit sample count for performance
  n_samples = math.min(n_samples, 4096)
  
  -- Calculate RMS level (Root Mean Square - audio volume)
  local sum = 0
  local peak = 0
  
  for i = 0, n_samples - 1 do
    local sample_value = samples[i]
    
    -- Check for valid sample (protection from NaN)
    if sample_value == sample_value then
      sum = sum + (sample_value * sample_value)
      peak = math.max(peak, math.abs(sample_value))
    end
  end
  
  -- Calculate RMS with peak blend for better dynamic range
  local rms = 0
  if n_samples > 0 then
    rms = math.sqrt(sum / n_samples)
  end
  
  -- Blend RMS and peak for more responsive level
  local level = (rms * 0.7) + (peak * 0.3)
  
  -- Apply curve and amplification to make low levels more visible
  level = math.pow(level, 0.5) * 2.5
  
  -- Clamp to valid range
  level = math.min(math.max(level, 0), 1)
  
  -- Debug info occasionally
  pipewire.debug_count = pipewire.debug_count + 1
  if pipewire.debug_count >= pipewire.debug_interval then
    pipewire.debug_count = 0
    naughty.notify {
      title = 'Audio Level',
      text = string.format('Captured audio level: %.3f', level),
      timeout = 1,
    }
  end
  
  -- Emit the audio level signal
  awesome.emit_signal('glitch::audio', level)
  
  -- Perform a very simple frequency analysis
  -- This is much less CPU intensive than a full FFT
  local band_size = math.floor(n_samples / 3)
  if band_size > 0 then
    local bands = {
      low = 0,
      mid = 0,
      high = 0
    }
    
    -- Calculate energy in each band
    for i = 0, band_size - 1 do
      if i < n_samples then
        bands.low = bands.low + math.abs(samples[i])
      end
    end
    
    for i = band_size, band_size * 2 - 1 do
      if i < n_samples then
        bands.mid = bands.mid + math.abs(samples[i])
      end
    end
    
    for i = band_size * 2, band_size * 3 - 1 do
      if i < n_samples then
        bands.high = bands.high + math.abs(samples[i])
      end
    end
    
    -- Normalize by band size
    bands.low = bands.low / band_size
    bands.mid = bands.mid / band_size
    bands.high = bands.high / band_size
    
    -- Apply non-linear curve to make low signals more visible
    bands.low = math.pow(bands.low, 0.5) * 3.0
    bands.mid = math.pow(bands.mid, 0.5) * 2.5
    bands.high = math.pow(bands.high, 0.5) * 2.0
    
    -- Normalize relative to each other
    local max_band = math.max(bands.low, bands.mid, bands.high, 0.001)
    bands.low = bands.low / max_band
    bands.mid = bands.mid / max_band
    bands.high = bands.high / max_band
    
    -- Send FFT bands signal
    awesome.emit_signal('glitch::fft', bands)
  end
end

-- Initialize PipeWire
function pipewire.init(source_id)
  if pipewire.initialized then
    return true
  end

  -- Load library
  pipewire.pw = load_pipewire_library()
  if not pipewire.pw then
    return false
  end
  
  -- Initialize PipeWire
  local success, result = pcall(function()
    -- Initialize PipeWire
    pipewire.pw.pw_init(nil, nil)
    
    -- Create a main loop
    pipewire.main_loop = pipewire.pw.pw_main_loop_new(nil)
    if pipewire.main_loop == nil then
      error("Failed to create main loop")
    end
    
    -- Get the loop handle
    local loop = pipewire.pw.pw_main_loop_get_loop(pipewire.main_loop)
    if loop == nil then
      error("Failed to get loop handle")
    end
    
    -- Create context
    pipewire.context = pipewire.pw.pw_context_new(loop, nil, 0)
    if pipewire.context == nil then
      error("Failed to create context")
    end
    
    -- Connect to PipeWire
    pipewire.core = pipewire.pw.pw_context_connect(pipewire.context, nil, 0)
    if pipewire.core == nil then
      error("Failed to connect to PipeWire")
    end
    
    -- Create stream properties 
    local props = pipewire.pw.pw_properties_new(
      "media.class", "Audio/Source",
      "media.name", "AwesomeWM Glitch Audio Capture",
      nil
    )
    
    -- Set target node ID if provided
    if source_id then
      pipewire.pw.pw_properties_set(props, "target.object", tostring(source_id))
    end
    
    -- Create audio capture stream
    pipewire.stream = pipewire.pw.pw_stream_new(
      pipewire.core,
      "awesome_audio_input",
      props
    )
    
    -- Free properties (they're now owned by the stream)
    pipewire.pw.pw_properties_free(props)
    
    if pipewire.stream == nil then
      error("Failed to create stream")
    end
    
    -- Connect the stream (0 = input direction, capture mode)
    -- Flags: AUTOCONNECT (1) | INACTIVE (2)
    local connect_result = pipewire.pw.pw_stream_connect(
      pipewire.stream,
      0,  -- PW_DIRECTION_INPUT (capture)
      source_id or 0, -- Target ID (0 = default)
      3,  -- PW_STREAM_FLAG_AUTOCONNECT | PW_STREAM_FLAG_INACTIVE
      nil,
      0
    )
    
    if connect_result < 0 then
      error("Failed to connect stream with error: " .. connect_result)
    end
    
    return true
  end)
  
  if not success then
    naughty.notify {
      title = 'PipeWire Init Error',
      text = tostring(result),
      timeout = 10,
    }
    
    -- Clean up any partially initialized resources
    pipewire.cleanup()
    return false
  end
  
  -- Set up a timer to process audio data
  pipewire.timer_id = gears.timer.start_new(0.02, function() -- 50Hz (20ms)
    if not pipewire.initialized then
      return false
    end
    
    -- Iterate the main loop
    pcall(function() 
      if pipewire.main_loop then
        pipewire.pw.pw_loop_iterate(
          pipewire.pw.pw_main_loop_get_loop(pipewire.main_loop),
          0
        )
      end
    end)
    
    -- Try to dequeue a buffer
    pcall(function()
      if pipewire.stream then
        local buffer = pipewire.pw.pw_stream_dequeue_buffer(pipewire.stream)
        
        if buffer ~= nil then
          -- Process the audio data
          process_audio_data(buffer)
          
          -- Return the buffer
          pipewire.pw.pw_stream_queue_buffer(pipewire.stream, buffer)
        end
      end
    end)
    
    return true
  end)
  
  pipewire.initialized = true
  
  naughty.notify {
    title = 'PipeWire',
    text = 'Audio capture initialized',
    timeout = 5,
  }
  
  return true
end

-- Clean up resources
function pipewire.cleanup()
  if not pipewire.initialized then
    return
  end
  
  -- Stop timer
  if pipewire.timer_id then
    pcall(function() gears.timer.stop(pipewire.timer_id) end)
    pipewire.timer_id = nil
  end
  
  -- Clean up PipeWire resources
  if pipewire.stream then
    pcall(function() pipewire.pw.pw_stream_destroy(pipewire.stream) end)
    pipewire.stream = nil
  end
  
  if pipewire.core then
    pcall(function() pipewire.pw.pw_core_disconnect(pipewire.core) end)
    pipewire.core = nil
  end
  
  if pipewire.context then
    pcall(function() pipewire.pw.pw_context_destroy(pipewire.context) end)
    pipewire.context = nil
  end
  
  if pipewire.main_loop then
    pcall(function() pipewire.pw.pw_main_loop_destroy(pipewire.main_loop) end)
    pipewire.main_loop = nil
  end
  
  -- Deinitialize PipeWire if it was initialized
  if pipewire.pw then
    pcall(function() pipewire.pw.pw_deinit() end)
  end
  
  pipewire.initialized = false
  
  naughty.notify {
    title = 'PipeWire',
    text = 'Audio capture stopped',
    timeout = 5,
  }
end

return pipewire