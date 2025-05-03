#!/usr/bin/env python3
"""
Audio configuration utility for audio_vfx.
"""
import os
import sys
import time
import argparse
import subprocess
import json

def parse_args():
    parser = argparse.ArgumentParser(description='Audio VFX configuration utility')
    parser.add_argument('--setup-loopback', action='store_true', help='Set up ALSA loopback device')
    parser.add_argument('--test-recording', action='store_true', help='Test audio recording')
    parser.add_argument('--config-device', action='store_true', help='Update config with working device')
    parser.add_argument('--help-pulseaudio', action='store_true', help='Show PulseAudio setup instructions')
    return parser.parse_args()

def setup_loopback():
    """Setup ALSA loopback device"""
    print("\n=== Setting up ALSA loopback device ===")
    
    # Check if module is loaded
    result = subprocess.run(['lsmod'], capture_output=True, text=True)
    if 'snd_aloop' not in result.stdout:
        print("Loopback module not loaded. Loading snd_aloop...")
        try:
            subprocess.run(['sudo', 'modprobe', 'snd_aloop'], check=True)
            print("✅ Loopback module loaded successfully")
        except subprocess.CalledProcessError:
            print("❌ Failed to load loopback module. Try running: sudo modprobe snd_aloop")
            return False
    else:
        print("✅ Loopback module already loaded")
    
    # Check loopback devices
    try:
        result = subprocess.run(['arecord', '-l'], capture_output=True, text=True)
        if 'Loopback' in result.stdout:
            print("✅ Loopback devices are available:")
            
            # Extract card numbers
            for line in result.stdout.splitlines():
                if 'Loopback' in line:
                    print(f"  - {line}")
        else:
            print("❌ No loopback devices found")
            return False
    except Exception as e:
        print(f"Error checking loopback devices: {e}")
        return False
    
    return True

def test_recording():
    """Test audio recording with loopback"""
    print("\n=== Testing Audio Recording ===")
    
    # Find available capture devices
    try:
        result = subprocess.run(['arecord', '-l'], capture_output=True, text=True)
        print("Available capture devices:")
        print(result.stdout)
    except Exception as e:
        print(f"Error listing devices: {e}")
        return
    
    # Ask user which device to test
    device = input("\nEnter ALSA device to test (e.g., hw:0,0): ")
    duration = 5
    
    print(f"\nRecording {duration} seconds from {device}...")
    try:
        # Record to a temp file
        temp_file = f"/tmp/audio_test_{int(time.time())}.wav"
        proc = subprocess.run([
            'arecord',
            '-D', device,
            '-f', 'S16_LE',
            '-r', '44100',
            '-c', '2',
            '-d', str(duration),
            temp_file
        ], capture_output=True, text=True)
        
        print("Recording completed.")
        print(f"Command output: {proc.stdout}")
        
        if proc.stderr:
            print(f"Errors: {proc.stderr}")
        
        # Check file exists and has content
        if os.path.exists(temp_file):
            size = os.path.getsize(temp_file)
            if size > 1000:
                print(f"✅ Successfully recorded {size} bytes to {temp_file}")
                print(f"To play the recording: aplay {temp_file}")
                print("If you hear sound, your recording is working!")
                
                # Suggest using this device
                print(f"\nTo use this device with audio_vfx:")
                print(f"python main.py --device-name {device} --test-mode")
                return device
            else:
                print(f"⚠️ Recording file is very small ({size} bytes)")
        else:
            print("❌ Failed to create recording file")
    except Exception as e:
        print(f"Error during recording: {e}")
    
    return None

def config_device(device):
    """Update config file with working device"""
    if not device:
        device = input("Enter the working ALSA device (e.g., hw:0,0): ")
    
    config_file = os.path.join(os.path.dirname(__file__), 'config.py')
    if not os.path.exists(config_file):
        print(f"Config file not found: {config_file}")
        return
    
    # Read current config
    with open(config_file, 'r') as f:
        config_content = f.read()
    
    # Find the AUDIO_SETTINGS section
    import re
    settings_pattern = r"AUDIO_SETTINGS\s*=\s*\{[^}]*\}"
    settings_match = re.search(settings_pattern, config_content, re.DOTALL)
    
    if settings_match:
        old_settings = settings_match.group(0)
        
        # Add the device name
        device_str = f"    'device_name': '{device}',"
        
        # Check if device_name already exists
        if "'device_name'" in old_settings:
            # Replace existing device_name
            new_settings = re.sub(
                r"'device_name'\s*:\s*'[^']*'", 
                f"'device_name': '{device}'", 
                old_settings
            )
        else:
            # Add new device_name line after opening brace
            new_settings = old_settings.replace(
                "AUDIO_SETTINGS = {",
                f"AUDIO_SETTINGS = {{\n{device_str}"
            )
        
        # Update the file
        new_content = config_content.replace(old_settings, new_settings)
        
        with open(config_file, 'w') as f:
            f.write(new_content)
        
        print(f"✅ Updated config file with device: {device}")
        print(f"Now you can run: python main.py --test-mode")
    else:
        print("❌ Could not find AUDIO_SETTINGS in config file")

def help_pulseaudio():
    """Show PulseAudio setup instructions"""
    print("\n=== PulseAudio Setup Guide ===")
    print("""
To route system audio to the loopback device:

1. Install PulseAudio Volume Control (pavucontrol) if not already installed:
   sudo apt install pavucontrol    # Debian/Ubuntu
   sudo pacman -S pavucontrol      # Arch Linux

2. Open pavucontrol:
   pavucontrol

3. Go to the "Recording" tab

4. Look for the "Monitor of" entries - these are what capture system audio

5. Look for the ALSA plugin entries - these represent your loopback device

6. To route audio to a loopback device:
   a. Play some audio (e.g., YouTube video)
   b. In pavucontrol, find the application playing audio
   c. Change its output to the loopback device

7. Configure audio_vfx to use the loopback device:
   python fix_audio.py --config-device

For more detailed instructions, see:
https://wiki.archlinux.org/title/PulseAudio/Examples#ALSA_monitor_source
""")

def main():
    args = parse_args()
    
    if args.setup_loopback:
        setup_loopback()
    
    if args.test_recording:
        device = test_recording()
        if device and args.config_device:
            config_device(device)
    
    if args.config_device and not args.test_recording:
        config_device(None)
    
    if args.help_pulseaudio:
        help_pulseaudio()
    
    # If no args specified, show help
    if not any(vars(args).values()):
        print("Audio VFX Configuration Utility")
        print("Usage examples:")
        print("  --setup-loopback   : Set up ALSA loopback device")
        print("  --test-recording   : Test audio recording")
        print("  --config-device    : Update config with working device")
        print("  --help-pulseaudio  : Show PulseAudio setup instructions")
        print("\nFor full documentation, run: python fix_audio.py --help")

if __name__ == "__main__":
    main()