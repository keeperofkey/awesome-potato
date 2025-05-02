import sounddevice as sd
import numpy as np

class AudioInput:
    def __init__(self, device=None, samplerate=48000, blocksize=512, channels=2):
        self.device = device
        self.samplerate = samplerate
        self.blocksize = blocksize
        self.channels = channels
        self.stream = None

    def start(self, callback):
        self.stream = sd.InputStream(
            device=self.device,
            samplerate=self.samplerate,
            channels=self.channels,
            blocksize=self.blocksize,
            callback=lambda indata, frames, time, status: callback(indata)
        )
        self.stream.start()

    def stop(self):
        if self.stream:
            self.stream.stop()
            self.stream.close()
