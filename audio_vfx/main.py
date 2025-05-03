#!/usr/bin/env python3
"""
Audio VFX - Audio analysis and effects system for AwesomeWM

This system captures audio, analyzes it for volume, frequency content, peaks and beats,
and sends the data to AwesomeWM via a socket for real-time visual effects.
"""
import sys
import signal
import argparse
import logging
import time
import numpy as np
import sounddevice as sd
from PyQt5.QtCore import QTimer, QCoreApplication

from audio_input import AudioInput
from signal_analysis import SignalAnalyzer
from midi_control import MidiController
from awesome_ipc import AwesomeIPC
from config import AUDIO_SETTINGS, MIDI_SETTINGS, IPC_SETTINGS

logger = logging.getLogger(__name__)

def parse_args():
    parser = argparse.ArgumentParser(description='Audio VFX - Analysis system for AwesomeWM')
    parser.add_argument('--device', type=int, help='Audio device index to use')
    parser.add_argument('--device-name', type=str, help='Audio device name (partial match) to use')
    parser.add_argument('--samplerate', type=int, help='Audio samplerate to use (e.g., 16000, 44100, 48000)')
    parser.add_argument('--blocksize', type=int, help='Audio blocksize to use (e.g., 1024, 2048, 4096)')
    parser.add_argument('--midi-device', type=str, help='MIDI device name to use')
    parser.add_argument('--list-devices', action='store_true', help='List available audio and MIDI devices then exit')
    parser.add_argument('--socket', type=str, help='Socket path for AwesomeWM communication')
    parser.add_argument('--debug', action='store_true', help='Enable debug logging')
    parser.add_argument('--test-mode', action='store_true', help='Run in test mode with built-in socket server')
    parser.add_argument('--debug-audio', action='store_true', help='Run audio debugging tool')
    return parser.parse_args()

def list_devices():
    """List available audio and MIDI devices"""
    import sounddevice as sd
    import mido
    
    print("\n=== Audio Devices ===")
    devices = sd.query_devices()
    for i, dev in enumerate(devices):
        host_api = sd.query_hostapis(dev['hostapi'])['name']
        in_ch = dev['max_input_channels']
        out_ch = dev['max_output_channels']
        if dev['name'] == sd.query_devices(kind='input')['name']:  # Mark default input
            default_mark = " (DEFAULT INPUT) "
        elif dev['name'] == sd.query_devices(kind='output')['name']:  # Mark default output
            default_mark = " (DEFAULT OUTPUT)"
        else:
            default_mark = ""
        print(f"  {i}: {dev['name']}{default_mark}, {host_api} ({in_ch} in, {out_ch} out)")
        
    print("\n=== MIDI Devices ===")
    try:
        midi_inputs = mido.get_input_names()
        if midi_inputs:
            for i, name in enumerate(midi_inputs):
                print(f"  {i}: {name}")
        else:
            print("  No MIDI input devices found")
    except Exception as e:
        print(f"  Error listing MIDI devices: {e}")
        
    print("\nUsage examples:")
    print("  By index:    --device 2")
    print("  By name:     --device-name \"HDMI\" (partial match)")
    print("  With params: --device 1 --samplerate 16000 --blocksize 2048")
    print("  Debug audio: --debug-audio")
    
    sys.exit(0)

def debug_audio_detection():
    """Debug audio detection by directly monitoring audio devices"""
    print("\nAudio Detection Debugging Tool")
    print("==============================")
    print("This tool will help identify which audio device is receiving input.")
    print("It will try each input device and show volume levels.")
    
    devices = sd.query_devices()
    input_devices = []
    
    # Find all devices with input channels
    for i, dev in enumerate(devices):
        if dev['max_input_channels'] > 0:
            input_devices.append((i, dev['name'], dev['max_input_channels']))
    
    if not input_devices:
        print("No input devices found!")
        return
    
    print(f"\nFound {len(input_devices)} input devices.")
    print("Testing each device for 5 seconds...\n")
    
    # Test each input device
    for idx, name, channels in input_devices:
        print(f"Testing device {idx}: {name} ({channels} channels)")
        
        try:
            # Create a short recording to check volume
            duration = 3  # seconds
            samplerate = 16000
            data = sd.rec(
                int(duration * samplerate),
                samplerate=samplerate,
                channels=min(channels, 2),
                device=idx,
                blocking=True
            )
            
            # Calculate volume
            mono_data = np.mean(data, axis=1) if data.ndim > 1 else data
            rms = np.sqrt(np.mean(mono_data**2))
            peak = np.max(np.abs(mono_data))
            
            # Print results with a visual meter
            meter_width = 50
            meter_val = int(min(rms * 2000, 1.0) * meter_width)
            meter = '[' + '#' * meter_val + ' ' * (meter_width - meter_val) + ']'
            
            print(f"  Volume: {rms:.6f} RMS, {peak:.6f} peak")
            print(f"  Level:  {meter} {rms*100:.1f}%")
            
            # Recommendation based on volume
            if rms > 0.01:
                print(f"  Status: ✅ GOOD - Audio detected on this device")
                print(f"  Use with: --device {idx}")
            elif rms > 0.001:
                print(f"  Status: ⚠️  LOW - Some audio detected but level is low")
                print(f"  Use with: --device {idx}")
            else:
                print(f"  Status: ❌ NONE - No significant audio detected")
            
            print()
            
        except Exception as e:
            print(f"  Error testing device: {e}")
            print()
    
    print("Testing complete!")
    print("For devices with detected audio, use the --device option when running the application.")
    print("Example: python main.py --device 24 --test-mode")
    
    sys.exit(0)

def main():
    """Main entry point"""
    args = parse_args()
    
    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)
    
    if args.list_devices:
        list_devices()
        
    if args.debug_audio:
        debug_audio_detection()
        return
    
    # Use CLI args or config defaults
    audio_device = args.device if args.device is not None else AUDIO_SETTINGS['device']
    audio_device_name = args.device_name if args.device_name else None
    samplerate = args.samplerate if args.samplerate else AUDIO_SETTINGS['samplerate']
    blocksize = args.blocksize if args.blocksize else AUDIO_SETTINGS['blocksize']
    midi_device = args.midi_device if args.midi_device else MIDI_SETTINGS['device']
    socket_path = args.socket if args.socket else IPC_SETTINGS['socket_path']
    test_mode = args.test_mode
    
    # Configure logging based on debug flag
    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)
        
    # Print test mode status
    if test_mode:
        logger.info("Running in TEST MODE - audio data will be self-contained and socket will act as both client and server")
    
    # Initialize core components
    app = QCoreApplication(sys.argv)  # Using QCoreApplication instead of QApplication (no GUI needed)
    audio = AudioInput(
        device=audio_device,
        device_name=audio_device_name,
        samplerate=samplerate,
        blocksize=blocksize,
        channels=AUDIO_SETTINGS['channels']
    )
    analyzer = SignalAnalyzer(
        samplerate=samplerate,
        blocksize=blocksize
    )
    midi = MidiController(device_name=midi_device)
    ipc = AwesomeIPC(sock_path=socket_path, test_mode=test_mode)
    
    # Create a status reporting timer
    status_timer = QTimer()
    last_status_time = 0
    
    # Register signal handlers for graceful shutdown
    def signal_handler(sig, frame):
        logger.info("Shutting down...")
        try:
            status_timer.stop()
        except:
            pass
            
        try:
            audio.stop()
        except:
            pass
            
        try:
            midi.stop()
        except:
            pass
            
        try:
            ipc.cleanup()
        except:
            pass
            
        try:
            app.quit()
        except:
            pass
            
        # Force exit if needed
        sys.exit(0)
        
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    def audio_callback(indata):
        """Process audio data and send to AwesomeWM"""
        volume, fft, peak, beat = analyzer.process_audio(indata)
        ipc.send_analysis(volume, peak, beat, fft)
    
    def show_status():
        """Periodically show status"""
        nonlocal last_status_time
        
        # Get MIDI controller state for any active controls
        midi_state = midi.get_state()
        midi_active = []
        for cc, value in midi_state.items():
            if cc < 128:  # Valid CC range
                midi_active.append(f"CC{cc}:{value}")
        
        volume = getattr(analyzer, 'last_volume', 0)
        beat = getattr(analyzer, 'last_beat', False)
        peak = getattr(analyzer, 'last_peak', False)
        
        # Show volume meter if volume is significant
        if volume > 0.0001:
            meter_width = 30
            meter_val = int(min(volume * 1000, 1.0) * meter_width)
            meter = '[' + '#' * meter_val + ' ' * (meter_width - meter_val) + ']'
            logger.info(f"Status: vol={volume:.3f} {meter} peak={peak} beat={beat} midi=[{', '.join(midi_active[:5])}]")
        else:
            logger.info(f"Status: vol={volume:.3f} peak={peak} beat={beat} midi=[{', '.join(midi_active[:5])}]")
        
    # Set up periodic status reporting
    status_timer.timeout.connect(show_status)
    status_timer.start(5000)  # Show status every 5 seconds

    logger.info("Starting audio analysis... Press Ctrl+C to exit")
    audio.start(audio_callback)
    midi.start()
    
    try:
        sys.exit(app.exec_())
    except KeyboardInterrupt:
        signal_handler(None, None)

if __name__ == "__main__":
    main()