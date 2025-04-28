import sounddevice as sd
import numpy as np
from aubio import tempo
import os

FIFO = "/tmp/audio_beat_fifo"
samplerate = 48000
win_s = 1024
hop_s = 512

# find monitor device
print(sd.query_devices())
MONITOR_DEVICE = 28
# Create FIFO if it doesn't exist
if not os.path.exists(FIFO):
    os.mkfifo(FIFO)

tempo_o = tempo("default", win_s, hop_s, samplerate)

import errno

def write_fifo_nonblocking(path, msg):
    try:
        fd = os.open(path, os.O_WRONLY | os.O_NONBLOCK)
        with os.fdopen(fd, 'w') as f:
            f.write(msg)
            f.flush()
    except OSError as e:
        if e.errno == errno.ENXIO:
            # No reader for FIFO, skip
            pass

def audio_callback(indata, frames, time, status):
    # rms = np.sqrt(np.mean(indata[:, 0]**2))
    # print(f"RMS: {rms:.6f}")
    is_beat = tempo_o(indata[:, 0].astype(np.float32))
    if is_beat:
        print("Beat detected!")
        write_fifo_nonblocking(FIFO, "1\n")

stream = sd.InputStream(device=MONITOR_DEVICE, channels=2, callback=audio_callback, samplerate=samplerate, blocksize=hop_s)
stream.start()
print("Listening for beats...")
try:
    while True:
        sd.sleep(1000)
except KeyboardInterrupt:
    print("Exiting...")
    stream.stop()
    stream.close()
    os.remove(FIFO)
    exit(0)