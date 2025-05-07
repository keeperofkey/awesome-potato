-- pipewire_native.lua
-- Native PipeWire audio analysis using LuaJIT FFI

local ffi = require("ffi")
local gears = require("gears")
local naughty = require("naughty")

-- Load PipeWire FFI bindings
local function load_pipewire_ffi()
    ffi.cdef[[
        typedef struct pw_loop pw_loop;
        typedef struct pw_core pw_core;
        typedef struct pw_stream pw_stream;
        typedef struct spa_pod spa_pod;
        typedef struct spa_pod_frame spa_pod_frame;
        typedef struct spa_pod_choice spa_pod_choice;
        typedef struct spa_pod_int spa_pod_int;
        typedef struct spa_pod_float spa_pod_float;
        typedef struct spa_pod_string spa_pod_string;
        typedef struct spa_pod_bytes spa_pod_bytes;
        typedef struct spa_pod_object spa_pod_object;
        typedef struct spa_pod_prop spa_pod_prop;
        typedef struct spa_pod_array spa_pod_array;
        typedef struct spa_pod_pointer spa_pod_pointer;
        typedef struct spa_pod_bool spa_pod_bool;
        typedef struct spa_pod_id spa_pod_id;
        typedef struct spa_pod_fraction spa_pod_fraction;
        typedef struct spa_pod_rectangle spa_pod_rectangle;
        typedef struct spa_pod_point spa_pod_point;
        typedef struct spa_pod_rectangle spa_pod_rectangle;
        typedef struct spa_pod_color spa_pod_color;
        typedef struct spa_pod_bitmask spa_pod_bitmask;
        typedef struct spa_pod_range spa_pod_range;
        typedef struct spa_pod_enum spa_pod_enum;
        typedef struct spa_pod_pointer spa_pod_pointer;
        typedef struct spa_pod_fd spa_pod_fd;
        typedef struct spa_pod_fd_range spa_pod_fd_range;
        typedef struct spa_pod_fd_enum spa_pod_fd_enum;
        typedef struct spa_pod_fd_array spa_pod_fd_array;
        typedef struct spa_pod_fd_pointer spa_pod_fd_pointer;
        typedef struct spa_pod_fd_bitmask spa_pod_fd_bitmask;
        typedef struct spa_pod_fd_range spa_pod_fd_range;
        // Core types
    typedef struct pw_loop pw_loop;
    typedef struct pw_core pw_core;
    typedef struct pw_stream pw_stream;
    typedef struct spa_pod spa_pod;
    
    // Core functions
    pw_loop* pw_loop_new(void);
    void pw_loop_destroy(pw_loop *loop);
    pw_core* pw_core_new(void);
    void pw_core_destroy(pw_core *core);
    pw_stream* pw_stream_new(pw_core *core, const char *name, const spa_dict *props);
    void pw_stream_destroy(pw_stream *stream);
    
    // Format functions
    struct spa_format_audio_raw {
        uint32_t format;
        uint32_t flags;
        uint32_t rate;
        uint32_t channels;
        uint32_t position[32];
        uint32_t format_info[32];
    };
    
    // Core functions
    pw_loop *pw_loop_new(void);
    void pw_loop_destroy(pw_loop *loop);
    int pw_loop_iterate(pw_loop *loop, int timeout);
    
    pw_core *pw_core_new(void);
    void pw_core_destroy(pw_core *core);
    
    // Stream functions
    pw_stream *pw_stream_new(pw_core *core, const char *name, const spa_pod *props);
    void pw_stream_destroy(pw_stream *stream);
    int pw_stream_connect(pw_stream *stream, uint32_t direction, uint32_t target_id, uint32_t flags, const spa_pod *format);
    ]]
    
    local libname = "libpipewire-0.3.so"
    local lib = ffi.load(libname)
    if not lib then
        naughty.notify{
            title = "PipeWire Error",
            text = string.format("Failed to load PipeWire library: %s", libname),
            timeout = 5
        }
        return nil
    end
    return lib
end

-- Audio processing
local function process_audio(data, length)
    -- Convert raw audio data to float
    local samples = {}
    for i = 0, length-1, 2 do
        local sample = ffi.cast("int16_t*", data)[i/2]
        table.insert(samples, sample / 32768.0)  -- Normalize to [-1, 1]
    end
    
    -- Simple RMS calculation
    local sum = 0
    for _, sample in ipairs(samples) do
        sum = sum + sample * sample
    end
    local rms = math.sqrt(sum / #samples)
    
    -- Debug audio level
    naughty.notify{
        title = "Audio Level",
        text = string.format("RMS: %.2f%%", rms * 100),
        timeout = 1
    }
    
    -- Emit signal to effects
    awesome.emit_signal("glitch::audio", rms)
    
    -- Simple FFT-like analysis
    local fft_size = 1024
    local spectrum = {}
    for i = 1, fft_size/2 do
        local sum_re = 0
        local sum_im = 0
        for j = 1, fft_size do
            local angle = 2 * math.pi * (j-1) * (i-1) / fft_size
            sum_re = sum_re + samples[j] * math.cos(angle)
            sum_im = sum_im + samples[j] * math.sin(angle)
        end
        spectrum[i] = math.sqrt(sum_re^2 + sum_im^2)
    end
    
    -- Debug frequency bands (show only low, mid, high)
    local low = 0
    local mid = 0
    local high = 0
        
    -- Calculate band averages
    for i = 1, 10 do low = low + spectrum[i] end
    for i = 11, 100 do mid = mid + spectrum[i] end
    for i = 101, #spectrum do high = high + spectrum[i] end
        
    low = low / 10
    mid = mid / 90
    high = high / (#spectrum - 100)
        
    naughty.notify{
        title = "Frequency Bands",
        text = string.format(
            "Low: %.2f\nMid: %.2f\nHigh: %.2f",
            low, mid, high
        ),
        timeout = 1
    }
    
    awesome.emit_signal("glitch::fft", spectrum)
end

-- Initialize PipeWire
local function init_pipewire()
    local pw = load_pipewire_ffi()
    if not pw then return nil end
    
    -- Create main loop
    local loop = pw.pw_loop_new()
    if loop == nil then
        naughty.notify{title = "PipeWire", text = "Failed to create loop"}
        return nil
    end
    
    -- Create core with loop
    local core = pw.pw_core_new(loop)
    if core == nil then
        naughty.notify{title = "PipeWire", text = "Failed to create core"}
        pw.pw_loop_destroy(loop)
        return nil
    end
    
    -- Create stream with core
    local stream = pw.pw_stream_new(core, "awesome_audio", nil)
    if stream == nil then
        naughty.notify{title = "PipeWire", text = "Failed to create stream"}
        pw.pw_core_destroy(core)
        pw.pw_loop_destroy(loop)
        return nil
    end
    
    -- Set up audio format
    local format = ffi.new("struct spa_format_audio_raw")
    format.format = 0x00000001  -- S16
    format.rate = 48000
    format.channels = 2
    
    -- Connect stream
    local ret = pw.pw_stream_connect(
        stream,
        0,  -- PW_DIRECTION_INPUT
        0,  -- Target node ID (0 means default)
        0,  -- Flags
        format
    )
    
    if ret < 0 then
        naughty.notify{title = "PipeWire", text = "Failed to connect stream"}
        pw.pw_stream_destroy(stream)
        pw.pw_core_destroy(core)
        pw.pw_loop_destroy(loop)
        return nil
    end
    
    return {
        loop = loop,
        core = core,
        stream = stream
    }
end

-- PipeWire context
local pipewire = {
    initialized = false,
    loop = nil,
    core = nil,
    stream = nil
}

-- Initialize audio system
function pipewire.init()
    if pipewire.initialized then return end
    
    local ctx = init_pipewire()
    if ctx then
        pipewire.loop = ctx.loop
        pipewire.core = ctx.core
        pipewire.stream = ctx.stream
        pipewire.initialized = true
        
        -- Start processing loop
        gears.timer.start_new(0, function()
            if pipewire.loop then
                pw.pw_loop_iterate(pipewire.loop, 10)
            end
            return true
        end)
    end
end

-- Cleanup
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
