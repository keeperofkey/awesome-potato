"""
Configuration for audio_vfx system
"""
import os
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.expanduser('~/.config/awesome/audio_vfx/audio_vfx.log'))
    ]
)

# Audio settings
AUDIO_SETTINGS = {
    'device': None,  # None = auto-detect, or specify index
    'samplerate': 48000,
    'blocksize': 4096,  # Very large buffer to prevent overflow
    'channels': 2,
    'latency': 'high',  # Use high latency mode for more stable buffering
}

# MIDI settings
MIDI_SETTINGS = {
    'device': None,  # None = use first available
    'reconnect_delay': 5,  # seconds
}

# IPC settings
IPC_SETTINGS = {
    'socket_path': '/tmp/audio_vfx.sock',
}

# Signal analysis settings
SIGNAL_SETTINGS = {
    'peak_threshold': 1.5,     # Peak detection threshold multiplier
    'beat_threshold': 1.8,     # Beat detection threshold multiplier
    'history_size': 43,        # History buffer size (~0.5s at 512 blocksize/48kHz)
    'min_beat_interval': 10,   # Minimum frames between beats
}