# Audio VFX

A modular, low-latency Python toolkit for real-time audio signal analysis, MIDI control, and integration with AwesomeWM glitch effects.

## Features

- System audio capture with automatic device detection
- Real-time FFT/beat/signal analysis with configurable parameters
- MIDI controller support with hot-plugging and device selection
- Direct communication with AwesomeWM via Unix socket
- Headless operation - no visualization window needed

## Requirements

- Python 3.6+
- PipeWire/PulseAudio for system audio capture
- AwesomeWM with glitch_effect module

## Installation

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Make sure the audio_vfx.sock Unix socket is properly configured in AwesomeWM

## Usage

Basic usage:
```bash
python main.py
```

Options:
```
--device INDEX        Audio device index to use
--midi-device NAME    MIDI device name to use  
--list-devices        List available audio and MIDI devices then exit
--socket PATH         Socket path for AwesomeWM communication
--debug               Enable debug logging
```

List available audio and MIDI devices:
```bash
python main.py --list-devices
```

## Configuration

Edit `config.py` to adjust audio settings, MIDI parameters, and signal analysis thresholds.

## Integration with AwesomeWM

Add a Unix socket listener in your AwesomeWM config to receive the audio analysis data:

```lua
-- In your rc.lua or glitch_effect module
local socket = require("socket.unix")
local json = require("json")

local server = socket.unix()
server:bind("/tmp/audio_vfx.sock")

-- Process the data in your effects
gears.timer({
    timeout = 0.1,
    autostart = true,
    callback = function()
        local data = server:receive()
        if data then
            local audio_data = json.decode(data)
            -- Use audio_data.volume, audio_data.beat, etc.
        end
    end
})
```

## Troubleshooting

- Run with `--debug` to see detailed logging
- Use `--list-devices` to find the correct audio input
- Check permissions on the Unix socket
- Verify that AwesomeWM is listening on the socket