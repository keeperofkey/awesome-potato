#!/usr/bin/env python3
"""
Raw audio monitor to check the actual values coming from the audio device.
"""
import sys
import time
import numpy as np
import sounddevice as sd
import argparse

def parse_args():
    parser = argparse.ArgumentParser(description='Debug audio volume and data')
    parser.add_argument('--device', type=int, required=True, help='Audio device index')
    parser.add_argument('--samplerate', type=int, default=48000, help='Sample rate')
    parser.add_argument('--blocksize', type=int, default=1024, help='Block size')
    parser.add_argument('--channels', type=int, default=2, help='Number of channels')
    return parser.parse_args()

def main():
    args = parse_args()
    
    print(f"Raw Audio Data Monitor for Device {args.device}")
    print(f"Sample Rate: {args.samplerate} Hz, Block Size: {args.blocksize}, Channels: {args.channels}")
    print("Press Ctrl+C to stop\n")
    
    # Get detailed device info
    try:
        device_info = sd.query_devices(args.device)
        print(f"Device name: {device_info['name']}")
        print(f"Max input channels: {device_info['max_input_channels']}")
        print(f"Default samplerate: {device_info['default_samplerate']}")
        print(f"ALSA device: {args.device}\n")
        
        # Print audio constants
        print(f"Default input: {sd.query_devices(kind='input')['name']}")
    except Exception as e:
        print(f"Error getting device info: {e}")
        return
    
    # Callback to show detailed information about incoming audio
    def callback(indata, frames, time, status):
        if status:
            print(f"Status: {status}")
        
        # Convert to mono
        mono = np.mean(indata, axis=1) if indata.ndim > 1 else indata
        
        # Calculate various stats
        rms = np.sqrt(np.mean(mono**2))
        peak = np.max(np.abs(mono))
        mean = np.mean(mono)
        std = np.std(mono)
        
        # First 10 samples (raw values)
        first_samples = mono[:10]
        sample_str = ", ".join([f"{sample:.8f}" for sample in first_samples])
        
        # Detailed histogram
        hist, bins = np.histogram(mono, bins=10, range=(-1, 1))
        hist_str = " ".join([f"{count}" for count in hist])
        
        # Now print everything
        print(f"Volume RMS: {rms:.8f} Peak: {peak:.8f} Mean: {mean:.8f} StdDev: {std:.8f}")
        print(f"First few samples: [{sample_str}]")
        print(f"Histogram: {hist_str}")
        print(f"Is zero: {np.allclose(mono, 0, atol=1e-6)}")
        print("-" * 80)
    
    # Start stream
    try:
        with sd.InputStream(
            device=args.device,
            channels=args.channels,
            callback=callback,
            blocksize=args.blocksize,
            samplerate=args.samplerate,
            latency='high'
        ):
            print("Stream started...")
            while True:
                time.sleep(0.5)
    except KeyboardInterrupt:
        print("\nStream stopped.")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()