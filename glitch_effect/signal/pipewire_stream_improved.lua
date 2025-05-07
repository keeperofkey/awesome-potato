-- Improved PipeWire stream implementation using proper pw_stream API
-- Based on https://docs.pipewire.org/group__pw__stream.html

local ffi = require 'ffi'
local gears = require 'gears'
local naughty = require 'naughty'

-- Check for LuaJIT environment
local is_luajit = type(jit) == 'table'
if not is_luajit then
  naughty.notify {
    title = 'LuaJIT Required',
    text = 'PipeWire module requires LuaJIT. Standard Lua detected.\nMake sure AwesomeWM is compiled with LuaJIT support.',
    timeout = 10,
  }
  return {
    init = function()
      return false
    end,
    cleanup = function() end,
    initialized = false,
  }
end

-- FFI definitions for PipeWire
ffi.cdef [[
  // Core PipeWire definitions
  void pw_init(int *argc, char **argv);
  void pw_deinit(void);
  
  // Loop and thread-loop
  typedef struct pw_loop pw_loop;
  typedef struct pw_thread_loop pw_thread_loop;
  
  pw_thread_loop* pw_thread_loop_new(const char *name, const void *props);
  void pw_thread_loop_destroy(pw_thread_loop *loop);
  int pw_thread_loop_start(pw_thread_loop *loop);
  void pw_thread_loop_stop(pw_thread_loop *loop);
  void pw_thread_loop_lock(pw_thread_loop *loop);
  void pw_thread_loop_unlock(pw_thread_loop *loop);
  pw_loop* pw_thread_loop_get_loop(pw_thread_loop *loop);
  
  // Properties
  typedef struct pw_properties pw_properties;
  pw_properties* pw_properties_new(const char *key, ...);
  void pw_properties_free(pw_properties *properties);

  // Main context
  typedef struct pw_context pw_context;
  pw_context* pw_context_new(pw_loop *main_loop, pw_properties *props, size_t user_data_size);
  void pw_context_destroy(pw_context *context);
  
  // Stream definitions
  typedef struct pw_stream pw_stream;
  typedef struct pw_buffer pw_buffer;
  typedef void (*pw_stream_process_callback)(void* userdata);
  
  // Stream events
  struct pw_stream_events {
    uint32_t version;
    void (*destroy)(void *data);
    void (*state_changed)(void *data, uint32_t old_state, uint32_t new_state, const char *error);
    void (*control_info)(void *data, uint32_t id, const char *control);
    void (*io_changed)(void *data, uint32_t id, void *area, uint32_t size);
    void (*param_changed)(void *data, uint32_t id, const void *param);
    void (*add_buffer)(void *data, struct pw_buffer *buffer);
    void (*remove_buffer)(void *data, struct pw_buffer *buffer);
    void (*process)(void *data);
    void (*drained)(void *data);
    void (*command)(void *data, const char *command);
    void (*trigger_done)(void *data, uint32_t id);
  };
  
  // Stream functions
  pw_stream* pw_stream_new(pw_context *context, const char *name, pw_properties *props);
  pw_stream* pw_stream_new_simple(pw_loop *loop, const char *name, pw_properties *props, 
                                  const struct pw_stream_events *events, void *data);
  void pw_stream_destroy(pw_stream *stream);
  
  int pw_stream_connect(pw_stream *stream, uint32_t direction, uint32_t target_id, 
                       uint32_t flags, const void **params, uint32_t n_params);
  int pw_stream_disconnect(pw_stream *stream);
  int pw_stream_set_active(pw_stream *stream, bool active);
  uint32_t pw_stream_get_state(pw_stream *stream, const char **error);
  
  // Buffer handling
  pw_buffer* pw_stream_dequeue_buffer(pw_stream *stream);
  int pw_stream_queue_buffer(pw_stream *stream, pw_buffer *buffer);
  
  // SPA types and data structures
  typedef struct spa_pod spa_pod;
  
  typedef struct spa_audio_info_raw {
    uint32_t format;
    uint32_t flags;
    uint32_t rate;
    uint32_t channels;
    uint32_t position[64];
  } spa_audio_info_raw;
  
  typedef struct spa_pod_builder spa_pod_builder;
  typedef struct spa_pod_frame spa_pod_frame;

  spa_pod_builder* spa_pod_builder_new(void);
  void spa_pod_builder_init(spa_pod_builder *builder, void *data, size_t size);
  
  // Buffer data access
  typedef struct spa_data {
    uint32_t type;
    uint32_t flags;
    int fd;
    uint32_t mapoffset;
    uint32_t maxsize;
    uint32_t chunk_offset;
    uint32_t chunk_size;
    void *data;
  } spa_data;

  typedef struct spa_chunk {
    uint32_t offset;
    uint32_t size;
    int32_t stride;
    uint32_t flags;
  } spa_chunk;

  typedef struct spa_buffer {
    uint32_t n_metas;
    void *metas;
    uint32_t n_datas;
    spa_data *datas;
  } spa_buffer;
  
  // Constants
  static const uint32_t PW_DIRECTION_INPUT = 0;
  static const uint32_t PW_DIRECTION_OUTPUT = 1;
  
  static const uint32_t PW_STREAM_FLAG_AUTOCONNECT = (1 << 0);
  static const uint32_t PW_STREAM_FLAG_INACTIVE = (1 << 1);
  static const uint32_t PW_STREAM_FLAG_MAP_BUFFERS = (1 << 2);
  static const uint32_t PW_STREAM_FLAG_DRIVER = (1 << 3);
  static const uint32_t PW_STREAM_FLAG_RT_PROCESS = (1 << 4);
  
  static const uint32_t PW_STREAM_STATE_ERROR = -1;
  static const uint32_t PW_STREAM_STATE_UNCONNECTED = 0;
  static const uint32_t PW_STREAM_STATE_CONNECTING = 1;
  static const uint32_t PW_STREAM_STATE_PAUSED = 2;
  static const uint32_t PW_STREAM_STATE_STREAMING = 3;
]]

-- Module state
local pipewire = {
  initialized = false,
  thread_loop = nil,
  main_loop = nil,
  context = nil,
  stream = nil,
  events = nil,
  callbacks = nil,
  -- Store callback references to prevent garbage collection
  _callback_refs = {},
}

-- Try to load the PipeWire library
local function load_library()
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
      return lib
    end
  end

  naughty.notify {
    title = 'PipeWire Error',
    text = 'Failed to load any PipeWire library',
    timeout = 10,
  }
  return nil
end

-- Create format parameter for stream connection
local function create_audio_format()
  -- Create a proper audio format structure
  local format = ffi.new('struct spa_audio_info_raw')
  format.format = 2 -- SPA_AUDIO_FORMAT_F32 (32-bit float)
  format.rate = 48000
  format.channels = 2
  
  -- Set default position values for stereo
  format.position[0] = 0 -- FL - Front Left
  format.position[1] = 1 -- FR - Front Right
  
  -- NOTE: This is still simplified but safer than direct casting
  -- Ideally we should use proper SPA Pod builder API
  
  -- Allocate memory for the format pod that won't be garbage collected
  local pod_mem = ffi.new('uint8_t[?]', 1024)
  
  -- In a full implementation, we'd use spa_pod_builder here
  -- For now, we're just ensuring the memory is valid and aligned
  local pod = ffi.cast('spa_pod*', pod_mem)
  
  -- Store the pod memory reference to prevent GC
  if not pipewire._callback_refs.pod_mem then
    pipewire._callback_refs.pod_mem = {}
  end
  table.insert(pipewire._callback_refs.pod_mem, pod_mem)
  
  return pod
end

-- Process audio data to extract audio levels and frequency information
local function process_audio(samples, n_samples, channels)
  -- Safety checks
  if not samples or n_samples <= 0 or channels <= 0 then
    return
  end

  -- Apply reasonable limits to avoid crash from large FFT calculation
  n_samples = math.min(n_samples, 8192)
  
  -- Calculate RMS level
  local sum = 0
  local sample_data = {}

  -- Safely process samples with bounds checking
  for i = 0, n_samples - 1 do
    -- For stereo, average channels
    local sample_value = 0
    local valid_channels = 0
    
    for c = 0, channels - 1 do
      -- Safely access sample memory
      local sample_idx = i * channels + c
      if sample_idx < n_samples * channels then
        -- Use pcall to avoid crash from invalid memory access
        local success, value = pcall(function() return samples[sample_idx] end)
        if success and type(value) == "number" and value == value then -- check for NaN
          sample_value = sample_value + value
          valid_channels = valid_channels + 1
        end
      end
    end
    
    -- Avoid division by zero
    if valid_channels > 0 then
      sample_value = sample_value / valid_channels
    else
      sample_value = 0
    end

    -- Store for FFT calculation
    table.insert(sample_data, sample_value)

    -- Add squared value for RMS (protect against NaN/infinity)
    if sample_value == sample_value and sample_value ~= math.huge and sample_value ~= -math.huge then
      sum = sum + (sample_value * sample_value)
    end
  end

  -- Calculate RMS with safety check
  local rms = 0
  if n_samples > 0 then
    rms = math.sqrt(sum / n_samples)
  end

  -- Check for valid RMS value
  if rms ~= rms or rms == math.huge or rms == -math.huge then
    rms = 0
  end

  -- Cap RMS to reasonable range
  rms = math.min(math.max(rms, 0), 1)

  -- Perform simple FFT with size limitation for performance
  local fft_size = math.min(512, #sample_data) -- reduced from 1024 for better performance
  local spectrum = {}

  -- Calculate FFT with bounds checking
  for i = 1, math.floor(fft_size / 2) do
    local sum_real = 0
    local sum_imag = 0

    for j = 1, fft_size do
      if j > #sample_data then
        break
      end

      local angle = 2 * math.pi * (j - 1) * (i - 1) / fft_size
      sum_real = sum_real + sample_data[j] * math.cos(angle)
      sum_imag = sum_imag + sample_data[j] * math.sin(angle)
    end

    -- Protect against NaN/infinity
    if sum_real == sum_real and sum_imag == sum_imag and
       sum_real ~= math.huge and sum_real ~= -math.huge and
       sum_imag ~= math.huge and sum_imag ~= -math.huge then
      spectrum[i] = math.sqrt(sum_real ^ 2 + sum_imag ^ 2)
    else
      spectrum[i] = 0
    end
  end

  -- Calculate frequency bands safely
  local bands = {
    low = 0,
    mid = 0,
    high = 0,
  }

  local low_max = math.min(10, #spectrum)
  local mid_max = math.min(100, #spectrum)

  -- Sum the bands with bounds checking
  for i = 1, low_max do
    if spectrum[i] and spectrum[i] == spectrum[i] then -- check for NaN
      bands.low = bands.low + spectrum[i]
    end
  end

  for i = low_max + 1, mid_max do
    if spectrum[i] and spectrum[i] == spectrum[i] then -- check for NaN
      bands.mid = bands.mid + spectrum[i]
    end
  end

  for i = mid_max + 1, #spectrum do
    if spectrum[i] and spectrum[i] == spectrum[i] then -- check for NaN
      bands.high = bands.high + spectrum[i]
    end
  end

  -- Normalize the bands safely
  if low_max > 0 then
    bands.low = bands.low / low_max
  end
  if mid_max - low_max > 0 then
    bands.mid = bands.mid / (mid_max - low_max)
  end
  if #spectrum - mid_max > 0 then
    bands.high = bands.high / (#spectrum - mid_max)
  end

  -- Normalize bands relative to each other
  local max_band = math.max(bands.low, bands.mid, bands.high, 0.000001)
  bands.low = bands.low / max_band
  bands.mid = bands.mid / max_band
  bands.high = bands.high / max_band

  -- Final safety check before emitting signals
  if rms == rms and -- check for NaN
     bands.low == bands.low and
     bands.mid == bands.mid and
     bands.high == bands.high then
    -- Emit signals
    awesome.emit_signal('glitch::audio', rms)
    awesome.emit_signal('glitch::fft', bands)
  end
end

-- Stream processing callback
local function on_process(data)
  -- Safely handle data pointer - no need to cast it
  -- The stream pointer is stored in pipewire.stream already
  
  -- Wait for next available buffer
  local buffer = pipewire.pw.pw_stream_dequeue_buffer(pipewire.stream)
  if buffer == nil then
    return
  end

  -- Handle the buffer data
  local spa_buffer = buffer
  
  -- Safety checks
  if spa_buffer == nil then
    return
  end
  
  -- Check if we have data
  if spa_buffer.n_datas > 0 then
    local spa_data = spa_buffer.datas[0]

    -- Multiple safety checks to avoid accessing invalid memory
    if spa_data ~= nil and 
       spa_data.data ~= nil and 
       spa_data.chunk_size > 0 then
       
      -- Process the audio data based on format
      -- Assuming F32 stereo format (4 bytes per sample, 2 channels)
      local bytes_per_sample = 4
      local channels = 2
      
      -- Validate chunk size to avoid division by zero or float precision issues
      if spa_data.chunk_size < bytes_per_sample * channels then
        pipewire.pw.pw_stream_queue_buffer(pipewire.stream, buffer)
        return
      end
      
      -- Calculate number of samples and ensure it's valid
      local n_samples = math.floor(spa_data.chunk_size / (bytes_per_sample * channels))
      if n_samples <= 0 then
        pipewire.pw.pw_stream_queue_buffer(pipewire.stream, buffer)
        return
      end
      
      -- Get samples as float array with safe casting
      local samples = ffi.cast('float*', spa_data.data)
      
      -- Add safety limit to avoid processing too many samples
      n_samples = math.min(n_samples, 8192) -- reasonable upper limit
      
      -- Process the audio data
      pcall(process_audio, samples, n_samples, channels)
    end
  end

  -- Return the buffer when we're done
  pipewire.pw.pw_stream_queue_buffer(pipewire.stream, buffer)
end

-- State change callback
local function on_state_changed(data, old_state, new_state, error)
  local state_names = {
    [-1] = 'ERROR',
    [0] = 'UNCONNECTED',
    [1] = 'CONNECTING',
    [2] = 'PAUSED',
    [3] = 'STREAMING',
  }

  local old_name = state_names[old_state] or 'UNKNOWN'
  local new_name = state_names[new_state] or 'UNKNOWN'

  -- Only show notification for significant state changes
  if new_state == -1 then -- PW_STREAM_STATE_ERROR
    naughty.notify {
      title = 'PipeWire Error',
      text = string.format('Stream error: %s', error or 'unknown error'),
      timeout = 10,
    }
  elseif new_state == 3 then -- PW_STREAM_STATE_STREAMING
    naughty.notify {
      title = 'PipeWire',
      text = 'Audio stream is now active',
      timeout = 3,
    }
  end
end

-- Initialize PipeWire with improved error handling
function pipewire.init()
  -- Use a pcall wrapper for all operations to catch any unexpected errors
  local status, err = pcall(function()
    -- If already initialized, do nothing
    if pipewire.initialized then
      return true
    end
    
    -- Reset state to ensure clean initialization
    pipewire._callback_refs = pipewire._callback_refs or {}
    
    -- Load the library if not already loaded
    if not pipewire.pw then
      pipewire.pw = load_library()
      if not pipewire.pw then
        error("Failed to load PipeWire library")
      end
    end
    
    -- Initialize PipeWire with proper error handling
    local result = pcall(function() pipewire.pw.pw_init(nil, nil) end)
    if not result then
      error("Failed to initialize PipeWire")
    end
    
    -- Create the thread loop with error handling
    pipewire.thread_loop = pipewire.pw.pw_thread_loop_new('awesome-pipewire', nil)
    if pipewire.thread_loop == nil then
      error("Failed to create thread loop")
    end
    
    -- Get the loop from the thread loop
    pipewire.main_loop = pipewire.pw.pw_thread_loop_get_loop(pipewire.thread_loop)
    if pipewire.main_loop == nil then
      pipewire.pw.pw_thread_loop_destroy(pipewire.thread_loop)
      pipewire.thread_loop = nil
      error("Failed to get main loop from thread loop")
    end
    
    -- Create the context
    pipewire.context = pipewire.pw.pw_context_new(pipewire.main_loop, nil, 0)
    if pipewire.context == nil then
      if pipewire.thread_loop then
        pipewire.pw.pw_thread_loop_destroy(pipewire.thread_loop)
        pipewire.thread_loop = nil
      end
      pipewire.main_loop = nil
      error("Failed to create context")
    end
    
    -- Set up stream callbacks with additional safety
    pipewire._callback_refs.on_process_fn = on_process
    pipewire._callback_refs.on_state_changed_fn = on_state_changed
    
    -- Use pcall for FFI casts to catch any errors
    local process_cast_success, process_cast = pcall(function()
      return ffi.cast('void (*)(void*)', pipewire._callback_refs.on_process_fn)
    end)
    
    local state_changed_cast_success, state_changed_cast = pcall(function()
      return ffi.cast('void (*)(void*, uint32_t, uint32_t, const char*)', 
                      pipewire._callback_refs.on_state_changed_fn)
    end)
    
    if not process_cast_success or not state_changed_cast_success then
      -- Clean up already created resources
      if pipewire.context then
        pipewire.pw.pw_context_destroy(pipewire.context)
        pipewire.context = nil
      end
      if pipewire.thread_loop then
        pipewire.pw.pw_thread_loop_destroy(pipewire.thread_loop)
        pipewire.thread_loop = nil
      end
      pipewire.main_loop = nil
      error("Failed to create callback functions")
    end
    
    pipewire.callbacks = {
      process = process_cast,
      state_changed = state_changed_cast,
    }
    
    -- Store callback casts in _callback_refs to prevent garbage collection
    pipewire._callback_refs.process = pipewire.callbacks.process
    pipewire._callback_refs.state_changed = pipewire.callbacks.state_changed
    
    -- Create stream events structure with error handling
    local events_success, events = pcall(function() 
      local evt = ffi.new('struct pw_stream_events')
      evt.version = 0
      evt.process = pipewire._callback_refs.process
      evt.state_changed = pipewire._callback_refs.state_changed
      return evt
    end)
    
    if not events_success then
      -- Clean up resources
      if pipewire.context then
        pipewire.pw.pw_context_destroy(pipewire.context)
        pipewire.context = nil
      end
      if pipewire.thread_loop then
        pipewire.pw.pw_thread_loop_destroy(pipewire.thread_loop)
        pipewire.thread_loop = nil
      end
      pipewire.main_loop = nil
      
      -- Free callback casts
      if pipewire._callback_refs.process then
        pipewire._callback_refs.process:free()
      end
      if pipewire._callback_refs.state_changed then
        pipewire._callback_refs.state_changed:free()
      end
      
      error("Failed to create events structure")
    end
    
    pipewire.events = events
    
    -- Create a stream with properties
    local props_success, props = pcall(function()
      return pipewire.pw.pw_properties_new(
        "media.class", "Audio/Source",
        "node.name", "awesome-audio-capture",
        nil
      )
    end)
    
    -- Create the stream with error handling
    pipewire.stream = pipewire.pw.pw_stream_new(
      pipewire.context,
      'awesome-audio',
      props_success and props or nil
    )
    
    if props_success and props then
      pipewire.pw.pw_properties_free(props)
    end
    
    if pipewire.stream == nil then
      -- Clean up resources
      if pipewire.context then
        pipewire.pw.pw_context_destroy(pipewire.context)
        pipewire.context = nil
      end
      if pipewire.thread_loop then
        pipewire.pw.pw_thread_loop_destroy(pipewire.thread_loop)
        pipewire.thread_loop = nil
      end
      pipewire.main_loop = nil
      
      -- Free callback casts
      if pipewire._callback_refs.process then
        pipewire._callback_refs.process:free()
      end
      if pipewire._callback_refs.state_changed then
        pipewire._callback_refs.state_changed:free()
      end
      
      error("Failed to create stream")
    end
    
    -- Start the thread loop before connecting
    local start_result = pipewire.pw.pw_thread_loop_start(pipewire.thread_loop)
    if start_result ~= 0 then
      -- Clean up stream
      if pipewire.stream then
        pipewire.pw.pw_stream_destroy(pipewire.stream)
        pipewire.stream = nil
      end
      
      -- Clean up other resources
      if pipewire.context then
        pipewire.pw.pw_context_destroy(pipewire.context)
        pipewire.context = nil
      end
      if pipewire.thread_loop then
        pipewire.pw.pw_thread_loop_destroy(pipewire.thread_loop)
        pipewire.thread_loop = nil
      end
      pipewire.main_loop = nil
      
      -- Free callback casts
      if pipewire._callback_refs.process then
        pipewire._callback_refs.process:free()
      end
      if pipewire._callback_refs.state_changed then
        pipewire._callback_refs.state_changed:free()
      end
      
      error("Failed to start thread loop: " .. start_result)
    end
    
    -- Create audio format with error handling
    local format = create_audio_format()
    if not format then
      pipewire.cleanup()
      error("Failed to create audio format")
    end
    
    -- Connect the stream as an audio input with error handling
    local connect_success = pcall(function()
      pipewire.pw.pw_thread_loop_lock(pipewire.thread_loop)
      
      local connect_result = pipewire.pw.pw_stream_connect(
        pipewire.stream,
        0, -- PW_DIRECTION_INPUT
        0, -- Target ID (0 = default)
        1 | 2, -- PW_STREAM_FLAG_AUTOCONNECT | PW_STREAM_FLAG_INACTIVE
        ffi.new('const void*[1]', format),
        1 -- Number of params
      )
      
      pipewire.pw.pw_thread_loop_unlock(pipewire.thread_loop)
      
      if connect_result ~= 0 then
        error("Stream connect failed with code: " .. connect_result)
      end
      
      -- Activate the stream after connecting
      pipewire.pw.pw_thread_loop_lock(pipewire.thread_loop)
      local activate_result = pipewire.pw.pw_stream_set_active(pipewire.stream, true)
      pipewire.pw.pw_thread_loop_unlock(pipewire.thread_loop)
      
      if activate_result ~= 0 then
        error("Failed to activate stream: " .. activate_result)
      end
    end)
    
    if not connect_success then
      pipewire.cleanup()
      error("Failed to connect stream")
    end
    
    -- If we got here, everything succeeded
    pipewire.initialized = true
    
    naughty.notify {
      title = 'PipeWire',
      text = 'Audio capture initialized successfully',
      timeout = 5,
    }
    
    return true
  end)
  
  -- Handle any errors from the initialization process
  if not status then
    -- Clean up any resources that might have been partially initialized
    pcall(pipewire.cleanup)
    
    naughty.notify {
      title = 'PipeWire Error',
      text = tostring(err),
      timeout = 10,
    }
    
    pipewire.initialized = false
    return false
  end
  
  return pipewire.initialized
end

-- Clean up PipeWire resources with improved error handling
function pipewire.cleanup()
  -- Use pcall to catch any unexpected errors during cleanup
  local status, err = pcall(function()
    if not pipewire.initialized then
      return
    end
    
    -- Clean up order is important
    if pipewire.stream then
      if pipewire.thread_loop then
        -- Lock thread loop while disconnecting stream with error handling
        local lock_success = pcall(function()
          pipewire.pw.pw_thread_loop_lock(pipewire.thread_loop)
          pcall(function() pipewire.pw.pw_stream_disconnect(pipewire.stream) end)
          pipewire.pw.pw_thread_loop_unlock(pipewire.thread_loop)
        end)
        
        -- If locking failed, try to disconnect without the lock
        if not lock_success then
          pcall(function() pipewire.pw.pw_stream_disconnect(pipewire.stream) end)
        end
      else
        -- Try to disconnect without lock if thread_loop is gone
        pcall(function() pipewire.pw.pw_stream_disconnect(pipewire.stream) end)
      end
      
      -- Destroy stream
      pcall(function() pipewire.pw.pw_stream_destroy(pipewire.stream) end)
      pipewire.stream = nil
    end
    
    -- Stop thread loop
    if pipewire.thread_loop then
      pcall(function() pipewire.pw.pw_thread_loop_stop(pipewire.thread_loop) end)
    end
    
    -- Clean up context
    if pipewire.context then
      pcall(function() pipewire.pw.pw_context_destroy(pipewire.context) end)
      pipewire.context = nil
    end
    
    -- Clean up thread loop
    if pipewire.thread_loop then
      pcall(function() pipewire.pw.pw_thread_loop_destroy(pipewire.thread_loop) end)
      pipewire.thread_loop = nil
      pipewire.main_loop = nil
    end
    
    -- Clean up callbacks
    if pipewire._callback_refs then
      -- Free the C callback functions with error handling
      if pipewire._callback_refs.process then
        pcall(function() pipewire._callback_refs.process:free() end)
      end
      if pipewire._callback_refs.state_changed then
        pcall(function() pipewire._callback_refs.state_changed:free() end)
      end
      
      -- Free any pod memory that was allocated
      if pipewire._callback_refs.pod_mem then
        pipewire._callback_refs.pod_mem = nil
      end
      
      -- Clear all references
      pipewire._callback_refs = {}
    end
    
    pipewire.callbacks = nil
    pipewire.events = nil
    
    -- Deinitialize PipeWire
    pcall(function() pipewire.pw.pw_deinit() end)
    
    pipewire.initialized = false
    
    naughty.notify {
      title = 'PipeWire',
      text = 'Audio capture stopped',
      timeout = 3,
    }
  end)
  
  -- If cleanup fails, force reset of state but show error
  if not status then
    -- Force reset of all state
    pipewire.stream = nil
    pipewire.thread_loop = nil
    pipewire.main_loop = nil
    pipewire.context = nil
    pipewire.callbacks = nil
    pipewire.events = nil
    pipewire._callback_refs = {}
    pipewire.initialized = false
    
    naughty.notify {
      title = 'PipeWire Cleanup Error',
      text = 'Error during cleanup: ' .. tostring(err),
      timeout = 5,
    }
  end
end

return pipewire

