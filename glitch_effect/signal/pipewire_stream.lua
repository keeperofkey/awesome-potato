local ffi = require 'ffi'
local gears = require 'gears'
local naughty = require 'naughty'

ffi.cdef[[
  void pw_init(int *argc, char **argv);

  typedef struct pw_stream pw_stream;
  typedef struct pw_loop pw_loop;
  typedef struct pw_properties pw_properties;
  typedef struct pw_buffer pw_buffer;
  typedef struct pw_stream_events {
    uint32_t version;
    void (*process)(void *data);
  } pw_stream_events;

  pw_stream* pw_stream_new_simple(
    pw_loop *loop,
    const char *name,
    pw_properties *props,
    const pw_stream_events *events,
    void *data
  );

  int pw_stream_connect(
    pw_stream *stream,
    int direction,
    uint32_t target_id,
    uint32_t flags,
    const void **params,
    uint32_t n_params
  );

  void pw_stream_destroy(pw_stream *stream);

  pw_buffer* pw_stream_dequeue_buffer(pw_stream *stream);
  void pw_stream_queue_buffer(pw_stream *stream, pw_buffer *buffer);

  typedef struct spa_data {
    uint32_t type;
    uint32_t flags;
    int32_t fd;
    uint32_t mapoffset;
    uint32_t maxsize;
    uint32_t chunk_offset;
    uint32_t chunk_size;
    void *data;
  } spa_data;

  typedef struct spa_buffer {
    uint32_t n_datas;
    spa_data *datas;
  } spa_buffer;
]]

local pw = ffi.load('libpipewire-0.3.so')
pw.pw_init(nil, nil)

local stream = nil

local function process_cb(data)
  local buffer = pw.pw_stream_dequeue_buffer(stream)
  if buffer == nil then return end

  local spa_buf = ffi.cast('struct spa_buffer*', buffer)
  if spa_buf.n_datas == 0 then
    pw.pw_stream_queue_buffer(stream, buffer)
    return
  end

  local spa_data = spa_buf.datas[0]
  if spa_data.data == nil or spa_data.chunk_size == 0 then
    pw.pw_stream_queue_buffer(stream, buffer)
    return
  end

  -- Assume S16LE stereo, 2 bytes per sample
  local num_samples = spa_data.chunk_size / 2
  local samples = ffi.cast('int16_t*', spa_data.data)
  local sum = 0
  local sample_list = {}
  for i = 0, num_samples - 1 do
    local sample = samples[i] / 32768.0
    sum = sum + sample * sample
    sample_list[#sample_list+1] = sample
  end
  local rms = math.sqrt(sum / num_samples)

  naughty.notify {
    title = 'PipeWire Audio',
    text = string.format('RMS: %.2f%%', rms * 100),
    timeout = 1,
  }

  awesome.emit_signal('glitch::audio', rms)

  -- Simple FFT (optional, for demonstration)
  local fft_size = math.min(1024, #sample_list)
  local spectrum = {}
  for i = 1, fft_size / 2 do
    local sum_re = 0
    local sum_im = 0
    for j = 1, fft_size do
      local angle = 2 * math.pi * (j - 1) * (i - 1) / fft_size
      sum_re = sum_re + sample_list[j] * math.cos(angle)
      sum_im = sum_im + sample_list[j] * math.sin(angle)
    end
    spectrum[i] = math.sqrt(sum_re ^ 2 + sum_im ^ 2)
  end

  awesome.emit_signal('glitch::fft', spectrum)

  pw.pw_stream_queue_buffer(stream, buffer)
end

local events = ffi.new('struct pw_stream_events')
events.version = 2
events.process = ffi.cast('void(*)(void*)', process_cb)

stream = pw.pw_stream_new_simple(nil, 'awesome_audio', nil, events, nil)
if stream == nil then
  naughty.notify { title = 'PipeWire', text = 'Failed to create stream' }
  return
end

local ret = pw.pw_stream_connect(stream, 0, 0, 0, nil, 0)
if ret < 0 then
  naughty.notify { title = 'PipeWire', text = 'Failed to connect stream' }
  pw.pw_stream_destroy(stream)
  return
end

local function cleanup()
  if stream ~= nil then
    pw.pw_stream_destroy(stream)
  end
end

return {
  cleanup = cleanup
}
