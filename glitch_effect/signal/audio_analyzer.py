#!/usr/bin/env python3
"""
Audio Analyzer for AwesomeWM Glitch Effects
Captures live audio from the default input device and sends levels to AwesomeWM
"""

import numpy as np
import pyaudio
import time
import subprocess
import sys
import signal
import os
from threading import Thread

# Configuration
CHUNK = 1024  # Number of frames per buffer
FORMAT = pyaudio.paInt16  # Audio format
CHANNELS = 1  # Mono
RATE = 44100  # Sampling rate
UPDATE_INTERVAL = 0.05  # Update interval in seconds (20 Hz)

# Initialize PyAudio
p = pyaudio.PyAudio()

# For graceful exit
running = True

def signal_handler(sig, frame):
    global running
    print("\nShutting down...")
    running = False

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

def calculate_fft(audio_data, rate):
    """Calculate frequency spectrum using FFT"""
    # Normalize audio data to -1.0 to 1.0
    normalized_data = audio_data / 32768.0
    
    # Apply window function to reduce spectral leakage
    windowed_data = normalized_data * np.hamming(len(normalized_data))
    
    # Compute FFT
    fft_data = np.abs(np.fft.rfft(windowed_data))
    
    # Define frequency bands
    freqs = np.fft.rfftfreq(len(windowed_data), 1.0/rate)
    
    # Define band ranges in Hz
    low_range = (20, 250)    # Bass
    mid_range = (250, 2000)  # Midrange
    high_range = (2000, 8000) # Treble
    
    # Get indices for each range
    low_idx = np.where((freqs >= low_range[0]) & (freqs <= low_range[1]))[0]
    mid_idx = np.where((freqs > mid_range[0]) & (freqs <= mid_range[1]))[0]
    high_idx = np.where((freqs > high_range[0]) & (freqs <= high_range[1]))[0]
    
    # Perform more dynamic band calculations
    def calculate_band_energy(indices):
        if len(indices) == 0:
            return 0.1  # Default fallback
        
        # Get the data for this band
        band_data = fft_data[indices]
        
        # Calculate energy (sum of squares)
        energy = np.sum(np.square(band_data))
        
        # Normalize by number of frequency bins to keep consistent across bands
        energy = energy / len(indices) if len(indices) > 0 else 0
        
        return energy
    
    # Calculate raw energy for each band
    low_energy = calculate_band_energy(low_idx)
    mid_energy = calculate_band_energy(mid_idx)
    high_energy = calculate_band_energy(high_idx)
    
    # Dynamic scaling - detect peaks and adjust scaling over time
    # These will be populated in the main loop to allow for adaptive scaling
    global max_energies, min_energies, smooth_energies
    
    if 'max_energies' not in globals():
        max_energies = {
            'low': low_energy * 1.2,  # Initial guess
            'mid': mid_energy * 1.2,
            'high': high_energy * 1.2
        }
        min_energies = {
            'low': low_energy * 0.8,  # Initial guess
            'mid': mid_energy * 0.8,
            'high': high_energy * 0.8
        }
        smooth_energies = {
            'low': low_energy,
            'mid': mid_energy,
            'high': high_energy
        }
    
    # Update maxima and minima with slow decay
    decay_factor = 0.995  # Slow decay of maximums
    growth_factor = 1.005  # Slow growth of minimums
    
    # Update max values with peaks and decay
    max_energies['low'] = max(low_energy, max_energies['low'] * decay_factor)
    max_energies['mid'] = max(mid_energy, max_energies['mid'] * decay_factor)
    max_energies['high'] = max(high_energy, max_energies['high'] * decay_factor)
    
    # Update min values with decay
    min_energies['low'] = min(low_energy, min_energies['low'] * growth_factor)
    min_energies['mid'] = min(mid_energy, min_energies['mid'] * growth_factor)
    min_energies['high'] = min(high_energy, min_energies['high'] * growth_factor)
    
    # Apply smoothing to the energy values
    smooth_factor = 0.7  # Higher = smoother
    smooth_energies['low'] = smooth_factor * smooth_energies['low'] + (1 - smooth_factor) * low_energy
    smooth_energies['mid'] = smooth_factor * smooth_energies['mid'] + (1 - smooth_factor) * mid_energy
    smooth_energies['high'] = smooth_factor * smooth_energies['high'] + (1 - smooth_factor) * high_energy
    
    # Scale to 0-1 range with dynamic range
    def scale_band(value, band_name):
        min_val = min_energies[band_name]
        max_val = max_energies[band_name]
        
        # Ensure we have a valid range
        if max_val <= min_val:
            max_val = min_val * 2
        
        # Scale to 0-1
        scaled = (value - min_val) / (max_val - min_val)
        
        # Apply some non-linear scaling to emphasize changes
        scaled = np.clip(scaled, 0, 1) ** 0.7  # Power curve to boost lower values
        
        # Add minimum value to ensure it's never completely zero
        return min(0.1 + scaled * 0.9, 1.0)
    
    # Calculate final normalized values
    low_band = scale_band(smooth_energies['low'], 'low')
    mid_band = scale_band(smooth_energies['mid'], 'mid')
    high_band = scale_band(smooth_energies['high'], 'high')
    
    # Apply different weights to create more visual variety
    # Bass often has less dynamic range, so boost it
    low_band = 0.2 + (low_band * 0.8)
    
    # Make sure we don't exceed 1.0
    low_band = min(low_band, 1.0)
    mid_band = min(mid_band, 1.0)
    high_band = min(high_band, 1.0)
    
    # Make sure values are not exactly the same
    if abs(low_band - mid_band) < 0.05:
        mid_band += 0.05
    if abs(mid_band - high_band) < 0.05:
        high_band += 0.05
    
    # Final clamping
    low_band = min(max(low_band, 0.1), 1.0)
    mid_band = min(max(mid_band, 0.1), 1.0)
    high_band = min(max(high_band, 0.1), 1.0)
    
    return {
        "low": low_band,
        "mid": mid_band,
        "high": high_band
    }

def send_to_awesome(signal_name, value):
    """Send signal to AwesomeWM using awesome-client"""
    if isinstance(value, dict):
        # Format the table for frequency bands
        table_str = "{ low = " + str(value["low"]) + ", mid = " + str(value["mid"]) + ", high = " + str(value["high"]) + " }"
        awesome_command = f'awesome.emit_signal("{signal_name}", {table_str})'
    else:
        # For simple numeric values
        awesome_command = f'awesome.emit_signal("{signal_name}", {value})'
    
    try:
        subprocess.run(["awesome-client", awesome_command], 
                      stdout=subprocess.DEVNULL, 
                      stderr=subprocess.DEVNULL)
    except Exception as e:
        if running:  # Only print errors if we're still running
            print(f"Error sending to AwesomeWM: {e}", file=sys.stderr)

def print_audio_info():
    """Print available audio devices"""
    print("Available audio devices:")
    info = p.get_host_api_info_by_index(0)
    num_devices = info.get('deviceCount')
    
    for i in range(0, num_devices):
        device_info = p.get_device_info_by_host_api_device_index(0, i)
        name = device_info.get('name')
        inputs = device_info.get('maxInputChannels')
        if inputs > 0:
            print(f"  Input Device {i}: {name}")
            # Set the default input device for convenience
            if "input" in name.lower() or "mic" in name.lower() or "monitor" in name.lower():
                print(f"  (This looks like a good input source)")
    
    print("\nUsing default input device")
    print("Press Ctrl+C to stop\n")

def log_message(msg):
    """Print a log message with timestamp"""
    print(f"[{time.strftime('%H:%M:%S')}] {msg}")

def process_audio():
    """Main audio processing loop"""
    # Try to get a suitable input device
    input_device = None
    
    # Try to find a monitor device first (for music playback)
    for i in range(p.get_device_count()):
        device_info = p.get_device_info_by_index(i)
        name = device_info.get('name')
        inputs = device_info.get('maxInputChannels')
        if inputs > 0 and "monitor" in name.lower():
            input_device = i
            log_message(f"Selected monitor device: {name}")
            break
    
    # If no monitor found, use default input
    if input_device is None:
        input_device = p.get_default_input_device_info()['index']
        log_message(f"Using default input device: {p.get_device_info_by_index(input_device)['name']}")
    
    # Open an audio stream
    try:
        stream = p.open(format=FORMAT,
                        channels=CHANNELS,
                        rate=RATE,
                        input=True,
                        input_device_index=input_device,
                        frames_per_buffer=CHUNK)
    except Exception as e:
        log_message(f"Error opening audio stream: {e}")
        log_message("Trying default input device instead...")
        try:
            # Try again with default device
            stream = p.open(format=FORMAT,
                            channels=CHANNELS,
                            rate=RATE,
                            input=True,
                            frames_per_buffer=CHUNK)
            log_message("Successfully opened default input device")
        except Exception as e2:
            log_message(f"Error opening default audio device: {e2}")
            return
    
    log_message("Audio stream opened successfully")
    log_message(f"Capturing audio at {RATE}Hz, {UPDATE_INTERVAL*1000:.0f}ms updates")
    
    # Send an initial signal to let AwesomeWM know we're running
    send_to_awesome("glitch::audio", 0.5)
    send_to_awesome("glitch::fft", {"low": 0.4, "mid": 0.5, "high": 0.6})
    log_message("Sent initial test signals to AwesomeWM")
    
    # Audio processing loop
    smooth_level = 0.1  # Start with a small value
    last_update = time.time()
    
    # Keep a history of levels for better visualization
    level_history = []
    history_size = 10
    
    # Initialize variables for RMS autocalibration
    min_rms = 0.001
    max_rms = 0.1
    
    while running:
        try:
            # Read audio data
            audio_data = np.frombuffer(stream.read(CHUNK, exception_on_overflow=False), dtype=np.int16)
            
            # Check if it's time to send an update
            now = time.time()
            if now - last_update >= UPDATE_INTERVAL:
                # Calculate RMS (root mean square) for audio level
                rms = np.sqrt(np.mean(np.square(audio_data.astype(np.float32) / 32768.0)))
                
                # Update min/max RMS for autocalibration
                min_rms = min(min_rms * 1.001, rms)  # Slow increase in minimum
                max_rms = max(max_rms * 0.995, rms)  # Slow decay for maximum
                
                # Make sure we have a valid range
                if max_rms <= min_rms * 1.2:
                    max_rms = min_rms * 2
                
                # Apply smoothing
                smooth_factor = 0.7  # Higher = smoother
                smooth_level = smooth_level * smooth_factor + rms * (1 - smooth_factor)
                
                # Add to history
                level_history.append(smooth_level)
                if len(level_history) > history_size:
                    level_history.pop(0)
                
                # Apply dynamic scaling with autocalibration
                if max_rms > min_rms:
                    level = (smooth_level - min_rms) / (max_rms - min_rms)
                else:
                    level = smooth_level / max_rms
                
                # Apply some non-linear scaling to emphasize changes
                level = min(level ** 0.7, 1.0)  # Power curve makes small values more visible
                
                # Make sure level is at least 0.1 if we detect any audio
                if rms > 0.001:
                    level = max(0.1, level)
                
                # Make sure level is at most 1.0
                level = min(level, 1.0)
                
                # Calculate frequency spectrum
                bands = calculate_fft(audio_data, RATE)
                
                # Send values to AwesomeWM
                send_to_awesome("glitch::audio", level)
                send_to_awesome("glitch::fft", bands)
                
                # Periodically log values (approx every 5 seconds)
                if int(now) % 5 == 0 and int(last_update) % 5 != 0:
                    log_message(f"Audio level: {level:.2f}, Low: {bands['low']:.2f}, Mid: {bands['mid']:.2f}, High: {bands['high']:.2f}")
                
                last_update = now
            
            # Sleep a tiny bit to reduce CPU usage
            time.sleep(0.001)
            
        except Exception as e:
            if running:  # Only print errors if we're still running
                log_message(f"Error processing audio: {e}")
                time.sleep(0.1)  # Brief pause before retry
    
    # Cleanup
    log_message("Closing audio stream")
    stream.stop_stream()
    stream.close()

def main():
    """Main entry point"""
    # Print program banner
    print("=" * 60)
    print("Audio Analyzer for AwesomeWM Glitch Effects")
    print("=" * 60)
    print_audio_info()
    
    # Start audio processing in a separate thread
    audio_thread = Thread(target=process_audio)
    audio_thread.daemon = True
    audio_thread.start()
    
    # Main thread just waits for program to terminate
    try:
        while running and audio_thread.is_alive():
            time.sleep(0.1)
    except KeyboardInterrupt:
        pass
    
    # Program exit
    p.terminate()
    print("\nAudio analyzer shutdown complete")

if __name__ == "__main__":
    main()