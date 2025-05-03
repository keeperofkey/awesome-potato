#!/usr/bin/env python3
"""
Simple audio debugging tool to identify which devices are receiving audio.
"""
import sys
import time
import numpy as np
import sounddevice as sd

def main():
    """Debug audio by testing each input device"""
    print("\nSimple Audio Device Tester")
    print("=========================")
    
    # List all devices
    print("\nAvailable audio devices:")
    devices = sd.query_devices()
    input_devices = []
    
    for i, dev in enumerate(devices):
        in_ch = dev['max_input_channels'] 
        if in_ch > 0:
            input_devices.append((i, dev['name'], in_ch))
            print(f"  Device {i}: {dev['name']} ({in_ch} input channels)")
    
    if not input_devices:
        print("No input devices found!")
        return
    
    # Interactive device testing
    while True:
        print("\nOptions:")
        print("1) Test all devices briefly")
        print("2) Monitor specific device")
        print("0) Exit")
        
        try:
            choice = input("\nEnter choice: ")
            
            if choice == "0":
                return
                
            elif choice == "1":
                # Test all devices
                print("\nTesting all input devices briefly...")
                
                for device_idx, name, channels in input_devices:
                    test_channels = min(channels, 2)  # Use max 2 channels
                    print(f"\nTesting device {device_idx}: {name} ({test_channels} channels)...")
                    
                    # Try different sample rates
                    success = False
                    for sr in [48000, 44100, 16000, 8000]:
                        try:
                            print(f"  Trying sample rate: {sr} Hz...", end="", flush=True)
                            
                            # Create a callback to detect volume
                            max_volume = [0.0]
                            def callback(indata, frames, time, status):
                                volume = np.sqrt(np.mean(indata**2))
                                max_volume[0] = max(max_volume[0], volume)
                            
                            # Record for a short period
                            with sd.InputStream(device=device_idx, channels=test_channels, 
                                              callback=callback, samplerate=sr,
                                              blocksize=1024, latency='high'):
                                time.sleep(1.5)  # Short test
                            
                            # Report result
                            print(f" OK (max volume: {max_volume[0]:.6f})")
                            
                            # Add visual indicator
                            bars = int(max_volume[0] * 200)
                            indicator = "#" * bars
                            
                            if max_volume[0] > 0.01:
                                print(f"  Status: ✅ GOOD [{indicator}]")
                                print(f"  FOUND WORKING DEVICE! Use: --device {device_idx} --samplerate {sr}")
                                success = True
                                break
                            elif max_volume[0] > 0.001:
                                print(f"  Status: ⚠️  LOW [{indicator}]")
                            else:
                                print(f"  Status: ❌ NONE (no audio detected)")
                            
                            success = True
                            break
                            
                        except Exception as e:
                            print(f" Failed: {e}")
                    
                    if not success:
                        print(f"  Could not test device {device_idx} with any sample rate")
                
                print("\nDevice testing completed!")
                print("For devices showing '✅ GOOD', use those device numbers in the main application")
                print("Example: python main.py --device X --samplerate Y --test-mode")
                    
            elif choice == "2":
                # Monitor specific device
                try:
                    device_idx = int(input("Enter device index to monitor: "))
                    
                    # Find device in our list
                    found = False
                    for idx, name, ch in input_devices:
                        if idx == device_idx:
                            found = True
                            test_channels = min(ch, 2)  # Use max 2 channels
                            print(f"\nMonitoring device {idx}: {name} ({test_channels} channels)")
                            break
                    
                    if not found:
                        print(f"Device {device_idx} not found or has no input channels")
                        continue
                    
                    # Try different sample rates
                    samplerate = None
                    for sr in [48000, 44100, 16000, 8000]:
                        try:
                            print(f"Trying sample rate: {sr} Hz...", end="", flush=True)
                            # Test that this sample rate works
                            with sd.InputStream(device=device_idx, channels=test_channels, 
                                                samplerate=sr, blocksize=1024):
                                time.sleep(0.1)
                            print(" OK")
                            samplerate = sr
                            break
                        except Exception as e:
                            print(f" Failed: {e}")
                    
                    if samplerate is None:
                        print("Could not find a working sample rate for this device.")
                        continue
                    
                    # Now monitor the volume
                    print(f"\nMonitoring device {device_idx} at {samplerate} Hz...")
                    print("Press Ctrl+C to stop monitoring")
                    
                    # Initialize metrics
                    max_vol = 0.0
                    last_print = time.time()
                    
                    # Monitoring callback
                    def monitor_callback(indata, frames, time, status):
                        nonlocal max_vol, last_print
                        
                        try:
                            if status:
                                print(f"Status: {status}")
                                
                            # Calculate volume
                            volume = np.sqrt(np.mean(indata**2))
                            max_vol = max(max_vol, volume)
                            
                            # Print updates once per second
                            now = time.time()
                            if now - last_print >= 0.2:  # Update 5 times per second
                                bars = int(volume * 500)  # More sensitive scale
                                print(f"Volume: {volume:.6f} Max: {max_vol:.6f} " + "#" * min(bars, 50))
                                last_print = now
                        except Exception as e:
                            print(f"Error in callback: {e}")
                    
                    # Start monitoring
                    try:
                        with sd.InputStream(device=device_idx, channels=test_channels,
                                          callback=monitor_callback, samplerate=samplerate,
                                          blocksize=1024, latency='high'):
                            try:
                                while True:
                                    time.sleep(0.1)
                            except KeyboardInterrupt:
                                print("\nMonitoring stopped.")
                    except Exception as e:
                        print(f"Error: {e}")
                    
                    # Report findings
                    if max_vol > 0.01:
                        print(f"\nResult: ✅ GOOD - Audio detected on device {device_idx}")
                        print(f"To use this device: python main.py --device {device_idx} --samplerate {samplerate} --test-mode")
                    elif max_vol > 0.001:
                        print(f"\nResult: ⚠️ LOW - Some audio detected on device {device_idx}")
                        print(f"To use this device: python main.py --device {device_idx} --samplerate {samplerate} --test-mode")
                    else:
                        print(f"\nResult: ❌ NONE - No significant audio detected on device {device_idx}")
                    
                except ValueError:
                    print("Invalid input - please enter a number")
            
            else:
                print("Invalid choice - please try again")
                
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nDebug tool exited by user.")
    except Exception as e:
        print(f"Global error: {e}")
    print("\nDebug tool completed.")