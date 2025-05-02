#!/usr/bin/env python3

import os
import sounddevice as sd
import pyaudio
import numpy as np
import signal
from BeatNet.BeatNet import BeatNet

FIFO_PATH = "/tmp/beatnet_fifo"

if not os.path.exists(FIFO_PATH):
    os.mkfifo(FIFO_PATH)

print("Available audio devices:")
# print(sd.query_devices())
print(pyaudio.PyAudio())
MONITOR_DEVICE_INDEX = 28  # <-- Set this after running once

samplerate = 48000
channels = 2
blocksize = 1024

estimator = BeatNet(1, mode='stream', inference_model='PF', plot=[], thread=False)

import threading
import time

import threading
import time

stop_event = threading.Event()
fifo = None
stream = None

def signal_handler(sig, frame):
    global stream
    print("Exiting on Ctrl+C")
    stop_event.set()
    if stream:
        stream.abort()  # Immediately abort the audio stream

signal.signal(signal.SIGINT, signal_handler)

def audio_callback(indata, frames, time_info, status):
    global fifo
    if status:
        print("Sounddevice status:", status)
    try:
        mono = np.mean(indata, axis=1).astype(np.float32)
        for beat in estimator.process(mono):
            if fifo:
                try:
                    if beat[1] == 1:
                        fifo.write("downbeat\n")
                    else:
                        fifo.write("beat\n")
                    fifo.flush()
                except BrokenPipeError:
                    pass  # No reader on FIFO
    except Exception as e:
        print("Exception in callback:", e)

try:
    fifo = open(FIFO_PATH, 'w', buffering=1)
    with sd.InputStream(
        device=MONITOR_DEVICE_INDEX,
        channels=channels,
        samplerate=samplerate,
        callback=audio_callback,
        blocksize=blocksize,
        latency='low',
    ) as s:
        stream = s  # Save reference for signal handler
        print("Recording from monitor source. Press Ctrl+C to stop.")
        while not stop_event.is_set():
            time.sleep(0.1)
    fifo.close()
except Exception as e:
    print("Exception in main loop:", e)
finally:
    if fifo and not fifo.closed:
        fifo.close()

    time.sleep(1)