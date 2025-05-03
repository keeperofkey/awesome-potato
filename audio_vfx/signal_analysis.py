import numpy as np
from scipy.fft import rfft
import logging
import time
from config import SIGNAL_SETTINGS

logger = logging.getLogger(__name__)

class SignalAnalyzer:
    def __init__(self, samplerate=48000, blocksize=512):
        self.samplerate = samplerate
        self.blocksize = blocksize
        self.last_fft = None
        self.last_volume = 0
        self.last_peak = False
        self.last_beat = False
        self.energy_history = []
        self.beat_history = []
        
        # Get settings from config
        self.peak_threshold = SIGNAL_SETTINGS['peak_threshold']
        self.beat_threshold = SIGNAL_SETTINGS['beat_threshold']
        self.history_size = SIGNAL_SETTINGS['history_size']
        self.min_beat_interval = SIGNAL_SETTINGS['min_beat_interval']
        
        logger.info(f"Signal analyzer initialized: sr={samplerate}, bs={blocksize}")

    def process_audio(self, indata):
        """
        Process audio buffer and extract features
        
        Parameters:
        - indata: numpy array of audio samples (channels, samples)
        
        Returns:
        - volume: RMS volume (float)
        - fft: FFT magnitude spectrum (numpy array)
        - peak: Boolean indicating energy peak
        - beat: Boolean indicating beat detected
        """
        try:
            # Start timer for performance monitoring
            start_time = time.time()
            
            # Convert to mono by averaging channels - use numpy for efficiency
            mono = np.mean(indata, axis=1)
            
            # Calculate RMS volume efficiently
            self.last_volume = float(np.sqrt(np.mean(mono**2)))
            
            # Calculate FFT - only if we need it (optimization)
            # We could skip this if we're only interested in volume/beats
            self.last_fft = np.abs(rfft(mono))
            
            # --- Peak detection (energy threshold) ---
            # Calculate energy more efficiently
            energy = np.sum(mono ** 2) / len(mono)  # Normalize by length
            
            # Initialize energy history if needed
            if len(self.energy_history) == 0:
                self.energy_history = [energy] * self.history_size
            
            # Update energy history
            self.energy_history.append(energy)
            if len(self.energy_history) > self.history_size:
                self.energy_history.pop(0)
            
            # Calculate moving average and detect peaks
            avg_energy = np.mean(self.energy_history)
            self.last_peak = energy > avg_energy * self.peak_threshold
            
            # --- Beat detection (with minimum interval) ---
            beat_detected = False
            
            if self.last_peak:
                if len(self.beat_history) == 0 or (
                    len(self.beat_history) > 0 and 
                    self.beat_history[-1] > self.min_beat_interval
                ):
                    beat_detected = True
                    self.beat_history.append(0)  # Reset counter
                else:
                    # Increment counter
                    if len(self.beat_history) > 0:
                        self.beat_history.append(self.beat_history[-1] + 1)
            else:
                # Increment counter if we have history
                if len(self.beat_history) > 0:
                    self.beat_history.append(self.beat_history[-1] + 1)
            
            # Trim beat history to avoid memory growth
            if len(self.beat_history) > 100:
                self.beat_history = self.beat_history[-100:]
            
            self.last_beat = beat_detected
            
            # Log performance for debugging if processing takes too long
            process_time = (time.time() - start_time) * 1000  # Convert to ms
            if process_time > 20:  # Log if processing takes more than 20ms
                buffer_time = (self.blocksize / self.samplerate) * 1000  # Buffer time in ms
                logger.warning(f"Audio processing took {process_time:.2f}ms (buffer time: {buffer_time:.2f}ms)")
            
            return self.last_volume, self.last_fft, self.last_peak, self.last_beat
            
        except Exception as e:
            logger.error(f"Error processing audio: {e}")
            # Return last values in case of error
            return self.last_volume, self.last_fft, False, False
