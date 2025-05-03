#!/usr/bin/env python3
"""
Ultra-simple audio device monitor that uses a different approach to avoid crashes.
"""
import os
import sys
import time
import subprocess
import numpy as np
import argparse

def parse_args():
    parser = argparse.ArgumentParser(description='Simple audio device monitor')
    parser.add_argument('device', type=str, help='ALSA device (e.g., hw:0,0)')
    parser.add_argument('--rate', type=int, default=44100, help='Sample rate')
    parser.add_argument('--duration', type=int, default=10, help='Recording duration in seconds')
    return parser.parse_args()

def main():
    args = parse_args()
    
    print(f"Recording {args.duration} seconds from ALSA device {args.device} at {args.rate} Hz")
    print("Press Ctrl+C to stop")
    
    # Create a temporary filename
    temp_file = f"/tmp/audio_test_{int(time.time())}.raw"
    
    try:
        # Start recording to a file using arecord
        cmd = [
            "arecord", 
            "-D", args.device,
            "-r", str(args.rate),
            "-f", "S16_LE",
            "-c", "2",
            "-d", str(args.duration),
            temp_file
        ]
        
        print(f"Running: {' '.join(cmd)}")
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
        # Wait a bit to let recording start
        time.sleep(0.5)
        
        # Periodically check file size
        start_time = time.time()
        last_size = 0
        last_update = start_time
        
        while proc.poll() is None and time.time() - start_time < args.duration:
            try:
                # Check if file exists
                if os.path.exists(temp_file):
                    current_size = os.path.getsize(temp_file)
                    
                    # Calculate data rate
                    now = time.time()
                    elapsed = now - last_update
                    
                    if elapsed >= 0.5:  # Update every half second
                        data_rate = (current_size - last_size) / elapsed
                        last_size = current_size
                        last_update = now
                        
                        # Format sizes for display
                        if data_rate > 1024:
                            rate_str = f"{data_rate/1024:.2f} KB/s"
                        else:
                            rate_str = f"{data_rate:.2f} bytes/s"
                            
                        # Create a visual indicator based on data rate
                        # A working audio device should have a steady stream of data
                        if data_rate > 100:
                            indicator = "#" * min(int(data_rate / 1000), 50)
                            print(f"Data rate: {rate_str} {indicator}")
                        else:
                            print(f"Data rate: {rate_str} (very low/no audio detected)")
                
                time.sleep(0.1)
                
            except KeyboardInterrupt:
                print("\nStopping recording...")
                proc.terminate()
                break
                
        # Get final output
        stdout, stderr = proc.communicate(timeout=1)
        
        # Check if file exists and has data
        if os.path.exists(temp_file):
            final_size = os.path.getsize(temp_file)
            print(f"Recording completed. File size: {final_size} bytes")
            
            if final_size > 1000:
                print(f"✅ Device {args.device} IS recording audio")
                print(f"Run the main program with: python main.py --device-name '{args.device}' --samplerate {args.rate} --test-mode")
            else:
                print(f"❌ Device {args.device} is NOT recording audio or is recording silence")
        else:
            print("Error: Recording file was not created")
            
        # Clean up
        if os.path.exists(temp_file):
            os.unlink(temp_file)
            
    except Exception as e:
        print(f"Error: {e}")
    
    print("Done")

if __name__ == "__main__":
    main()