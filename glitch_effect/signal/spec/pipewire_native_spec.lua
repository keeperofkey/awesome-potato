local pipewire = require 'glitch_effect.signal.pipewire_native'
local ffi = require 'ffi'

describe('process_audio', function()
  local process_audio
  setup(function()
    -- Extract process_audio from the module (if not exported, copy logic here)
    process_audio = package.loaded['glitch_effect.signal.pipewire_native'].process_audio
  end)

  it('calculates correct RMS for constant signal', function()
    local n = 100
    local data = ffi.new('int16_t[?]', n)
    for i = 0, n - 1 do
      data[i] = 16384
    end -- Half amplitude
    local rms
    _G.awesome = {
      emit_signal = function(_, val)
        rms = val
      end,
    }
    _G.naughty = { notify = function() end }
    process_audio(ffi.cast('void*', data), n * 2)
    assert.is_true(math.abs(rms - 0.5) < 0.01)
  end)

  it('handles zero input', function()
    local n = 100
    local data = ffi.new('int16_t[?]', n)
    for i = 0, n - 1 do
      data[i] = 0
    end
    local rms
    _G.awesome = {
      emit_signal = function(_, val)
        rms = val
      end,
    }
    _G.naughty = { notify = function() end }
    process_audio(ffi.cast('void*', data), n * 2)
    assert.is_true(rms == 0)
  end)
end)

describe('pipewire.init and cleanup', function()
  it('sets initialized flag', function()
    pipewire.initialized = false
    pipewire.init()
    assert.is_true(pipewire.initialized)
  end)

  it('cleans up and resets initialized flag', function()
    pipewire.initialized = true
    pipewire.cleanup()
    assert.is_false(pipewire.initialized)
  end)
end)
