-- Native PipeWire audio analysis using LuaJIT FFI

local ffi = require 'ffi'
local gears = require 'gears'
local naughty = require 'naughty'

-- Global PipeWire library handle
local pw = nil

-- Load PipeWire FFI bindings
local function load_pipewire_ffi()
  ffi.cdef [[
        typedef struct pw_loop pw_loop;
        typedef struct pw_core pw_core;
        typedef struct pw_stream pw_stream;
        typedef struct spa_pod spa_pod;

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

  local libname = 'libpipewire-0.3.so'
  pw = ffi.load(libname)
  if not pw then
    naughty.notify {
      title = 'PipeWire Error',
      text = string.format('Failed to load PipeWire library: %s', libname),
      timeout = 5,
    }
    return nil
  end
  return pw
end

-- Create audio format as spa_pod
local function create_audio_format()
  local format = ffi.new 'struct spa_format_audio_raw'
  format.format = 0x00000001 -- S16
  format.rate = 48000
  format.channels = 2
  return ffi.cast('const spa_pod*', format)
end

-- Audio processing
local function process_audio(data, length)
  local samples = {}
  for i = 0, length - 1, 2 do
    local sample = ffi.cast('int16_t*', data)[i / 2]
    table.insert(samples, sample / 32768.0)
  end

  local sum = 0
  for _, sample in ipairs(samples) do
    sum = sum + sample * sample
  end
  local rms = #samples > 0 and math.sqrt(sum / #samples) or 0

  naughty.notify {
    title = 'Audio Level',
    text = string.format('RMS: %.2f%%', rms * 100),
    timeout = 1,
  }

  awesome.emit_signal('glitch::audio', rms)

  local fft_size = math.min(1024, #samples)
  local spectrum = {}
  for i = 1, fft_size / 2 do
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
    spectrum[i] = math.sqrt(sum_re ^ 2 + sum_im ^ 2)
  end

  local low, mid, high = 0, 0, 0
  for i = 1, math.min(10, #spectrum) do
    low = low + spectrum[i]
  end
  for i = 11, math.min(100, #spectrum) do
    mid = mid + spectrum[i]
  end
  for i = 101, #spectrum do
    high = high + spectrum[i]
  end

  low = low / math.max(1, math.min(10, #spectrum))
  mid = mid / math.max(1, math.min(90, #spectrum - 10))
  high = high / math.max(1, #spectrum - 100)

  naughty.notify {
    title = 'Frequency Bands',
    text = string.format('Low: %.2f\nMid: %.2f\nHigh: %.2f', low, mid, high),
    timeout = 1,
  }

  awesome.emit_signal('glitch::fft', spectrum)
end

-- Initialize PipeWire
local function init_pipewire()
  if not pw then
    if not load_pipewire_ffi() then
      return nil
    end
  end

  local loop = pw.pw_loop_new()
  if loop == nil then
    local err = ffi.errno()
    naughty.notify {
      title = 'PipeWire',
      text = string.format('Failed to create loop (errno: %d)', err),
    }
    return nil
  end

  local core = pw.pw_core_new(loop)
  if core == nil then
    naughty.notify { title = 'PipeWire', text = 'Failed to create core' }
    pw.pw_loop_destroy(loop)
    return nil
  end

  local stream = pw.pw_stream_new(core, 'awesome_audio', nil)
  if stream == nil then
    naughty.notify { title = 'PipeWire', text = 'Failed to create stream' }
    pw.pw_core_destroy(core)
    pw.pw_loop_destroy(loop)
    return nil
  end

  local format = create_audio_format()
  local ret = pw.pw_stream_connect(
    stream,
    0, -- PW_DIRECTION_INPUT
    0, -- Target node ID (0 means default)
    0, -- Flags
    format
  )

  if ret < 0 then
    naughty.notify { title = 'PipeWire', text = 'Failed to connect stream' }
    pw.pw_stream_destroy(stream)
    pw.pw_core_destroy(core)
    pw.pw_loop_destroy(loop)
    return nil
  end

  return {
    loop = loop,
    core = core,
    stream = stream,
  }
end

local pipewire = {
  initialized = false,
  loop = nil,
  core = nil,
  stream = nil,
}

function pipewire.init()
  if pipewire.initialized then
    return
  end

  local ctx = init_pipewire()
  if ctx then
    pipewire.loop = ctx.loop
    pipewire.core = ctx.core
    pipewire.stream = ctx.stream
    pipewire.initialized = true

    gears.timer.start_new(0, function()
      if pipewire.loop then
        pw.pw_loop_iterate(pipewire.loop, 10)
      end
      return true
    end)
  end
end

function pipewire.cleanup()
  if pipewire.stream then
    pw.pw_stream_destroy(pipewire.stream)
  end
  if pipewire.core then
    pw.pw_core_destroy(pipewire.core)
  end
  if pipewire.loop then
    pw.pw_loop_destroy(pipewire.loop)
  end
  pipewire.initialized = false
end

return pipewire
