import numpy as np
from scipy.fft import rfft

class SignalAnalyzer:
    def __init__(self, samplerate=48000, blocksize=512):
        self.samplerate = samplerate
        self.blocksize = blocksize
        self.last_fft = None
        self.last_volume = 0

    def process_audio(self, indata):
        mono = indata.mean(axis=1)
        self.last_volume = float(np.sqrt(np.mean(mono**2)))
        self.last_fft = np.abs(rfft(mono))
        # --- Peak detection (simple energy threshold) ---
        energy = np.sum(mono ** 2)
        if not hasattr(self, 'energy_history'):
            self.energy_history = [energy] * 43  # ~0.5s at 512 blocksize/48kHz
        self.energy_history.append(energy)
        if len(self.energy_history) > 43:
            self.energy_history.pop(0)
        avg_energy = np.mean(self.energy_history)
        self.last_peak = energy > avg_energy * 1.5
        # --- Beat detection (simple moving average crossing) ---
        if not hasattr(self, 'beat_history'):
            self.beat_history = []
        beat_detected = False
        if self.last_peak:
            if len(self.beat_history) == 0 or (len(self.beat_history) > 0 and self.beat_history[-1] > 10):
                beat_detected = True
                self.beat_history.append(0)
            else:
                self.beat_history.append(self.beat_history[-1] + 1)
        else:
            if len(self.beat_history) > 0:
                self.beat_history.append(self.beat_history[-1] + 1)
        if len(self.beat_history) > 100:
            self.beat_history = self.beat_history[-100:]
        self.last_beat = beat_detected
        return self.last_volume, self.last_fft, self.last_peak, self.last_beat
