import sounddevice as sd
import numpy as np
import logging
import time
from config import AUDIO_SETTINGS

logger = logging.getLogger(__name__)

class AudioInput:
    def __init__(self, device=None, device_name=None, samplerate=48000, blocksize=512, channels=2):
        self.device = device
        self.device_name = device_name
        self.samplerate = samplerate
        self.blocksize = blocksize
        self.channels = channels
        self.stream = None
        self.callback_fn = None
        
        # Attempt to find a suitable audio input device
        try:
            # Case 1: Device specified by name
            if self.device_name is not None:
                # Find device matching the name (partial match)
                devices = sd.query_devices()
                for i, dev in enumerate(devices):
                    if (self.device_name.lower() in dev['name'].lower() and 
                        dev['max_input_channels'] > 0):
                        self.device = i
                        logger.info(f"Selected audio device by name: {dev['name']}")
                        break
                
                if self.device is None:
                    logger.warning(f"No device found matching '{self.device_name}'. Using default.")
                    
            # Case 2: No device specified, try to find a suitable one
            if self.device is None:
                # Find default or system monitor inputs
                devices = sd.query_devices()
                
                # First preference: ALSA monitor or loopback device
                for i, dev in enumerate(devices):
                    if dev['max_input_channels'] > 0:
                        name_lower = dev['name'].lower()
                        if ('monitor' in name_lower or 'loopback' in name_lower or 
                            'pulse' in name_lower):
                            self.device = i
                            logger.info(f"Selected monitor/loopback device: {dev['name']}")
                            break
                
                # Second preference: any input device
                if self.device is None:
                    try:
                        default_in = sd.query_devices(kind='input')
                        self.device = sd.query_devices().tolist().index(default_in)
                        logger.info(f"Using system default input: {default_in['name']}")
                    except:
                        # Last resort: first device with inputs
                        for i, dev in enumerate(devices):
                            if dev['max_input_channels'] > 0:
                                self.device = i
                                logger.info(f"Using first available input device: {dev['name']}")
                                break
                        
            # Check if we found a device
            if self.device is not None:
                device_info = sd.query_devices(self.device)
                logger.info(f"Audio device set to: {device_info['name']} (idx: {self.device})")
            else:
                logger.warning("No suitable audio input device found!")
                                
        except Exception as e:
            logger.error(f"Error finding audio device: {e}")

    def _error_callback(self, err):
        logger.error(f"Audio error: {err}")
        
    def start(self, callback):
        if self.stream is not None:
            logger.warning("Stopping existing audio stream before starting a new one")
            self.stop()
            
        self.callback_fn = callback
        
        try:
            # Get latency setting from config
            latency = AUDIO_SETTINGS.get('latency', 'low')
            logger.info(f"Using latency mode: {latency}")
            
            # Create input stream with optimized parameters
            self.stream = sd.InputStream(
                device=self.device,
                samplerate=self.samplerate,
                channels=self.channels,
                blocksize=self.blocksize,
                callback=lambda indata, frames, time, status: self._handle_audio(indata, frames, time, status),
                latency=latency,
                dtype='float32',  # Specify data type for better performance
                prime_output_buffers_using_stream_callback=False  # Reduce CPU usage
            )
            self.stream.start()
            logger.info(f"Audio stream started: device={self.device}, sr={self.samplerate}, blocksize={self.blocksize}")
        except Exception as e:
            logger.error(f"Failed to start audio stream: {e}")
            self.stream = None
            raise
            
    def _handle_audio(self, indata, frames, time, status):
        if status:
            # Log any errors/warnings from the audio stream
            logger.warning(f"Audio stream status: {status}")
        
        # Call the user's callback with the audio data
        try:
            self.callback_fn(indata)
        except Exception as e:
            logger.error(f"Error in audio callback: {e}")

    def stop(self):
        """Stop and clean up the audio stream"""
        stream_to_stop = self.stream
        self.stream = None  # Clear reference first to avoid double-close
        
        if stream_to_stop:
            try:
                stream_to_stop.stop()
                stream_to_stop.close()
                logger.info("Audio stream stopped")
            except Exception as e:
                logger.error(f"Error stopping audio stream: {e}")
        else:
            logger.info("No active audio stream to stop")
