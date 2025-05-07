-- ALSA Audio Capture Module
-- Uses ALSA directly for audio capture (simpler than PipeWire)

local ffi = require("ffi")
local gears = require("gears")
local naughty = require("naughty")

-- Check if we have LuaJIT
if type(jit) ~= 'table' then
  naughty.notify {
    title = 'ALSA Module',
    text = 'LuaJIT is required for ALSA audio capture',
    timeout = 5,
  }
  return {
    init = function() return false end,
    cleanup = function() end,
    initialized = false
  }
end

-- Define ALSA interface
ffi.cdef[[
  typedef struct snd_pcm snd_pcm_t;
  
  // PCM open/close
  int snd_pcm_open(snd_pcm_t **pcm, const char *name, int stream, int mode);
  int snd_pcm_close(snd_pcm_t *pcm);
  
  // Hardware parameters
  typedef struct snd_pcm_hw_params snd_pcm_hw_params_t;
  int snd_pcm_hw_params_malloc(snd_pcm_hw_params_t **params);
  int snd_pcm_hw_params_free(snd_pcm_hw_params_t *params);
  int snd_pcm_hw_params_any(snd_pcm_t *pcm, snd_pcm_hw_params_t *params);
  int snd_pcm_hw_params_set_access(snd_pcm_t *pcm, snd_pcm_hw_params_t *params, int access);
  int snd_pcm_hw_params_set_format(snd_pcm_t *pcm, snd_pcm_hw_params_t *params, int format);
  int snd_pcm_hw_params_set_channels(snd_pcm_t *pcm, snd_pcm_hw_params_t *params, unsigned int val);
  int snd_pcm_hw_params_set_rate_near(snd_pcm_t *pcm, snd_pcm_hw_params_t *params, unsigned int *val, int *dir);
  int snd_pcm_hw_params(snd_pcm_t *pcm, snd_pcm_hw_params_t *params);
  
  // PCM state
  int snd_pcm_prepare(snd_pcm_t *pcm);
  int snd_pcm_start(snd_pcm_t *pcm);
  int snd_pcm_drain(snd_pcm_t *pcm);
  
  // Reading
  int snd_pcm_readi(snd_pcm_t *pcm, void *buffer, unsigned long size);
  
  // Error handling
  const char *snd_strerror(int errnum);
]]

-- Load ALSA library
local alsa, err = ffi.load("libasound.so.2")
if not alsa then
  naughty.notify {
    title = 'ALSA Error',
    text = 'Failed to load ALSA library: ' .. tostring(err),
    timeout = 5,
  }
  return {
    init = function() return false end,
    cleanup = function() end,
    initialized = false
  }
end

-- ALSA constants
local SND_PCM_STREAM_CAPTURE = 0
local SND_PCM_NONBLOCK = 1
local SND_PCM_ACCESS_RW_INTERLEAVED = 3
local SND_PCM_FORMAT_S16_LE = 2

-- Module state
local capture = {
  initialized = false,
  pcm = nil,
  buffer = nil,
  params = nil,
  timer = nil,
  rate = 44100,
  channels = 2,
  buffer_size = 1024
}

-- Calculate audio level from buffer
local function calculate_level(buffer, size, channels)
  local sum = 0
  local count = 0
  
  for i = 0, size - 1 do
    local sample = buffer[i]
    -- Convert signed 16-bit to float (-1.0 to 1.0)
    local value = sample / 32768.0
    sum = sum + value * value
    count = count + 1
  end
  
  if count > 0 then
    -- Calculate RMS (root mean square)
    local rms = math.sqrt(sum / count)
    -- Apply some scaling to make it more visible
    local level = math.min(rms * 5.0, 1.0)
    return level
  else
    return 0
  end
end

-- Simple frequency analysis (approximation without FFT)
local function analyze_frequencies(buffer, size, channels)
  local low_sum = 0
  local mid_sum = 0
  local high_sum = 0
  local count = 0
  
  -- Split buffer into regions (pseudo-frequency bands)
  local low_end = math.floor(size / 5)
  local mid_end = math.floor(size * 3 / 5)
  
  for i = 0, low_end - 1 do
    local sample = math.abs(buffer[i] / 32768.0)
    low_sum = low_sum + sample
  end
  
  for i = low_end, mid_end - 1 do
    local sample = math.abs(buffer[i] / 32768.0)
    mid_sum = mid_sum + sample
  end
  
  for i = mid_end, size - 1 do
    local sample = math.abs(buffer[i] / 32768.0)
    high_sum = high_sum + sample
  end
  
  -- Normalize
  local low = low_sum / low_end
  local mid = mid_sum / (mid_end - low_end)
  local high = high_sum / (size - mid_end)
  
  -- Scale for better visibility
  low = math.min(low * 5.0, 1.0)
  mid = math.min(mid * 5.0, 1.0)
  high = math.min(high * 5.0, 1.0)
  
  return {
    low = low,
    mid = mid,
    high = high
  }
end

-- Initialize ALSA capture
function capture.init(device)
  if capture.initialized then
    return true
  end
  
  -- Default to default capture device if not specified
  device = device or "default"
  
  -- Allocate PCM handle
  local pcm_ptr = ffi.new("snd_pcm_t*[1]")
  local ret = alsa.snd_pcm_open(pcm_ptr, device, SND_PCM_STREAM_CAPTURE, SND_PCM_NONBLOCK)
  if ret < 0 then
    naughty.notify {
      title = 'ALSA Error',
      text = 'Failed to open PCM device: ' .. ffi.string(alsa.snd_strerror(ret)),
      timeout = 5,
    }
    return false
  end
  
  -- Store PCM handle
  capture.pcm = pcm_ptr[0]
  
  -- Allocate hardware parameters
  local params_ptr = ffi.new("snd_pcm_hw_params_t*[1]")
  ret = alsa.snd_pcm_hw_params_malloc(params_ptr)
  if ret < 0 then
    alsa.snd_pcm_close(capture.pcm)
    naughty.notify {
      title = 'ALSA Error',
      text = 'Failed to allocate hardware parameters: ' .. ffi.string(alsa.snd_strerror(ret)),
      timeout = 5,
    }
    return false
  end
  
  -- Store parameters
  capture.params = params_ptr[0]
  
  -- Initialize parameters with defaults
  ret = alsa.snd_pcm_hw_params_any(capture.pcm, capture.params)
  if ret < 0 then
    alsa.snd_pcm_hw_params_free(capture.params)
    alsa.snd_pcm_close(capture.pcm)
    naughty.notify {
      title = 'ALSA Error',
      text = 'Failed to initialize parameters: ' .. ffi.string(alsa.snd_strerror(ret)),
      timeout = 5,
    }
    return false
  end
  
  -- Set access type
  ret = alsa.snd_pcm_hw_params_set_access(capture.pcm, capture.params, SND_PCM_ACCESS_RW_INTERLEAVED)
  if ret < 0 then
    alsa.snd_pcm_hw_params_free(capture.params)
    alsa.snd_pcm_close(capture.pcm)
    naughty.notify {
      title = 'ALSA Error',
      text = 'Failed to set access type: ' .. ffi.string(alsa.snd_strerror(ret)),
      timeout = 5,
    }
    return false
  end
  
  -- Set sample format
  ret = alsa.snd_pcm_hw_params_set_format(capture.pcm, capture.params, SND_PCM_FORMAT_S16_LE)
  if ret < 0 then
    alsa.snd_pcm_hw_params_free(capture.params)
    alsa.snd_pcm_close(capture.pcm)
    naughty.notify {
      title = 'ALSA Error',
      text = 'Failed to set sample format: ' .. ffi.string(alsa.snd_strerror(ret)),
      timeout = 5,
    }
    return false
  end
  
  -- Set channel count
  ret = alsa.snd_pcm_hw_params_set_channels(capture.pcm, capture.params, capture.channels)
  if ret < 0 then
    alsa.snd_pcm_hw_params_free(capture.params)
    alsa.snd_pcm_close(capture.pcm)
    naughty.notify {
      title = 'ALSA Error',
      text = 'Failed to set channel count: ' .. ffi.string(alsa.snd_strerror(ret)),
      timeout = 5,
    }
    return false
  end
  
  -- Set sample rate
  local rate_ptr = ffi.new("unsigned int[1]")
  rate_ptr[0] = capture.rate
  local dir_ptr = ffi.new("int[1]")
  dir_ptr[0] = 0
  ret = alsa.snd_pcm_hw_params_set_rate_near(capture.pcm, capture.params, rate_ptr, dir_ptr)
  if ret < 0 then
    alsa.snd_pcm_hw_params_free(capture.params)
    alsa.snd_pcm_close(capture.pcm)
    naughty.notify {
      title = 'ALSA Error',
      text = 'Failed to set sample rate: ' .. ffi.string(alsa.snd_strerror(ret)),
      timeout = 5,
    }
    return false
  end
  
  -- Use the actual rate
  capture.rate = rate_ptr[0]
  
  -- Apply parameters
  ret = alsa.snd_pcm_hw_params(capture.pcm, capture.params)
  if ret < 0 then
    alsa.snd_pcm_hw_params_free(capture.params)
    alsa.snd_pcm_close(capture.pcm)
    naughty.notify {
      title = 'ALSA Error',
      text = 'Failed to apply parameters: ' .. ffi.string(alsa.snd_strerror(ret)),
      timeout = 5,
    }
    return false
  end
  
  -- Allocate buffer for audio data
  capture.buffer = ffi.new("int16_t[?]", capture.buffer_size)
  
  -- Prepare PCM for use
  ret = alsa.snd_pcm_prepare(capture.pcm)
  if ret < 0 then
    alsa.snd_pcm_hw_params_free(capture.params)
    alsa.snd_pcm_close(capture.pcm)
    naughty.notify {
      title = 'ALSA Error',
      text = 'Failed to prepare PCM: ' .. ffi.string(alsa.snd_strerror(ret)),
      timeout = 5,
    }
    return false
  end
  
  -- Start PCM
  ret = alsa.snd_pcm_start(capture.pcm)
  if ret < 0 then
    -- Non-fatal error, we'll try to read anyway
    naughty.notify {
      title = 'ALSA Warning',
      text = 'Failed to start PCM: ' .. ffi.string(alsa.snd_strerror(ret)),
      timeout = 5,
    }
  }
  
  -- Start audio processing timer
  capture.timer = gears.timer {
    timeout = 0.05,  -- 50ms (20Hz)
    autostart = true,
    callback = function()
      -- Read audio data
      local frames = alsa.snd_pcm_readi(capture.pcm, capture.buffer, capture.buffer_size / capture.channels)
      
      if frames > 0 then
        -- Calculate audio level
        local level = calculate_level(capture.buffer, frames * capture.channels, capture.channels)
        
        -- Emit audio level signal
        awesome.emit_signal("glitch::audio", level)
        
        -- Analyze frequencies
        local bands = analyze_frequencies(capture.buffer, frames * capture.channels, capture.channels)
        
        -- Emit FFT signal
        awesome.emit_signal("glitch::fft", bands)
      end
      
      return true
    end
  }
  
  capture.initialized = true
  
  naughty.notify {
    title = 'ALSA Capture',
    text = 'Successfully initialized audio capture',
    timeout = 5,
  }
  
  return true
end

-- Cleanup
function capture.cleanup()
  if not capture.initialized then
    return
  end
  
  -- Stop timer
  if capture.timer then
    capture.timer:stop()
    capture.timer = nil
  end
  
  -- Clean up ALSA resources
  if capture.pcm then
    alsa.snd_pcm_drain(capture.pcm)
    alsa.snd_pcm_close(capture.pcm)
    capture.pcm = nil
  end
  
  if capture.params then
    alsa.snd_pcm_hw_params_free(capture.params)
    capture.params = nil
  end
  
  capture.initialized = false
  
  naughty.notify {
    title = 'ALSA Capture',
    text = 'Audio capture stopped',
    timeout = 5,
  }
end

-- Return module
return capture