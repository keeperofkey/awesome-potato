"""
Audio Feature Extraction with Librosa

This script loads an audio file, extracts a variety of features using librosa,
and prints/saves the results. Optionally, it can visualize the features.

Usage:
    python librosa_audio_features.py path/to/audio.wav

Dependencies:
    pip install librosa matplotlib numpy
"""
import sys
import os
import numpy as np
import librosa
import librosa.display
import matplotlib.pyplot as plt
import csv
import pyaudio
import signal
import time
import subprocess

def extract_features(y, sr):
    features = {}
    # MFCCs
    mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
    features['mfccs_mean'] = np.mean(mfccs, axis=1)
    features['mfccs_std'] = np.std(mfccs, axis=1)
    # Chroma
    chroma = librosa.feature.chroma_stft(y=y, sr=sr)
    features['chroma_mean'] = np.mean(chroma, axis=1)
    features['chroma_std'] = np.std(chroma, axis=1)
    # Spectral Contrast
    contrast = librosa.feature.spectral_contrast(y=y, sr=sr)
    features['contrast_mean'] = np.mean(contrast, axis=1)
    features['contrast_std'] = np.std(contrast, axis=1)
    # Zero Crossing Rate
    zcr = librosa.feature.zero_crossing_rate(y)
    features['zcr_mean'] = np.mean(zcr)
    features['zcr_std'] = np.std(zcr)
    # RMS Energy
    rms = librosa.feature.rms(y=y)
    features['rms_mean'] = np.mean(rms)
    features['rms_std'] = np.std(rms)
    # Spectral Centroid
    centroid = librosa.feature.spectral_centroid(y=y, sr=sr)
    features['centroid_mean'] = np.mean(centroid)
    features['centroid_std'] = np.std(centroid)
    # Spectral Bandwidth
    bandwidth = librosa.feature.spectral_bandwidth(y=y, sr=sr)
    features['bandwidth_mean'] = np.mean(bandwidth)
    features['bandwidth_std'] = np.std(bandwidth)
    # Tonnetz (only for harmonic signals)
    try:
        y_harmonic = librosa.effects.harmonic(y)
        tonnetz = librosa.feature.tonnetz(y=y_harmonic, sr=sr)
        features['tonnetz_mean'] = np.mean(tonnetz, axis=1)
        features['tonnetz_std'] = np.std(tonnetz, axis=1)
    except Exception:
        pass
    return features


def send_to_awesome(signal_name, value):
    # Format value as float with reasonable precision
    try:
        v = float(value)
        val_str = f"{v:.6f}"
    except Exception:
        val_str = str(value)
    # Compose Lua command
    lua_cmd = f'awesome.emit_signal("{signal_name}", {val_str})'
    try:
        subprocess.run(["awesome-client", lua_cmd], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def save_features_csv(features, out_path):
    # CSV export disabled in favor of signal emission
    pass

def visualize(y, sr, features):
    plt.figure(figsize=(12, 8))
    plt.subplot(3, 1, 1)
    librosa.display.waveshow(y, sr=sr)
    plt.title('Waveform')
    plt.subplot(3, 1, 2)
    S = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=128)
    S_dB = librosa.power_to_db(S, ref=np.max)
    librosa.display.specshow(S_dB, sr=sr, x_axis='time', y_axis='mel')
    plt.title('Mel Spectrogram')
    plt.colorbar(format='%+2.0f dB')
    plt.subplot(3, 1, 3)
    mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
    librosa.display.specshow(mfccs, x_axis='time')
    plt.title('MFCC')
    plt.colorbar()
    plt.tight_layout()
    plt.show()

def live_audio_loop(rate=44100, chunk=22050, n_mfcc=13, mel_bins=128):
    print("Starting live audio feature extraction with visualization (Ctrl+C to stop)...")
    FORMAT = pyaudio.paInt16
    CHANNELS = 1
    p = pyaudio.PyAudio()
    stream = p.open(format=FORMAT,
                    channels=CHANNELS,
                    rate=rate,
                    input=True,
                    frames_per_buffer=chunk)
    running = True
    def signal_handler(sig, frame):
        nonlocal running
        print("\nStopping live audio...")
        running = False
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Helper: ASCII bar
    def bar(val, minval, maxval, width=30, fillchar='█', emptychar=' '):
        norm = (val - minval) / (maxval - minval) if maxval > minval else 0
        n = int(norm * width)
        return fillchar * n + emptychar * (width - n)

    # Helper: Sparkline for waveform
    def sparkline(arr, width=60):
        arr = arr[::max(1, len(arr)//width)]  # Downsample
        chars = ' ▁▂▃▄▅▆▇█'  # Unicode sparkline chars
        minv, maxv = -1, 1
        scaled = np.clip((arr - minv) / (maxv - minv), 0, 1)
        idxs = (scaled * (len(chars)-1)).astype(int)
        return ''.join(chars[i] for i in idxs)

    # For RMS/MFCC normalization
    rms_min, rms_max = 0, 0.5
    mfcc0_min, mfcc0_max = -300, 300

    while running:
        try:
            data = stream.read(chunk, exception_on_overflow=False)
            audio = np.frombuffer(data, dtype=np.int16).astype(np.float32) / 32768.0
            rms = float(librosa.feature.rms(y=audio).mean())
            mfccs = librosa.feature.mfcc(y=audio, sr=rate, n_mfcc=n_mfcc)
            mfcc0 = float(mfccs[0].mean())
            # Emit signals to AwesomeWM
            send_to_awesome("glitch::rms", rms)
            send_to_awesome("glitch::mfcc0", mfcc0)
            # Zero-crossing rate
            zcr = float(librosa.feature.zero_crossing_rate(y=audio).mean())
            send_to_awesome("glitch::zcr", zcr)
            # Spectral contrast
            contrast = librosa.feature.spectral_contrast(y=audio, sr=rate)
            send_to_awesome("glitch::spectral_contrast", float(contrast.mean()))
            # Waveform sparkline
            wave_str = sparkline(audio, width=60)
            # RMS bar
            rms_str = bar(rms, rms_min, rms_max, width=30)
            # MFCC[0] bar
            mfcc_str = bar(mfcc0, mfcc0_min, mfcc0_max, width=30)
            # Print all on one screen (overwrite)
            sys.stdout.write(f"\rWaveform: {wave_str}\nRMS:   |{rms_str}| {rms:.3f}    MFCC[0]: |{mfcc_str}| {mfcc0:.1f}   ")
            sys.stdout.flush()
            time.sleep(0.01)
        except Exception as e:
            sys.stdout.write(f"\nError: {e}\n")
            sys.stdout.flush()
            time.sleep(0.1)
    stream.stop_stream()
    stream.close()
    p.terminate()
    print("\nLive audio feature extraction stopped.")

def main():
    if len(sys.argv) < 2:
        print("Usage: python librosa_audio_features.py path/to/audio.wav [--live]")
        sys.exit(1)
    if '--live' in sys.argv:
        live_audio_loop()
        return
    audio_path = sys.argv[1]
    if not os.path.isfile(audio_path):
        print(f"File not found: {audio_path}")
        sys.exit(1)
    y, sr = librosa.load(audio_path, sr=None, mono=True)
    print(f"Loaded {audio_path} (duration: {len(y)/sr:.2f}s, sr: {sr})")
    features = extract_features(y, sr)
    print("Feature summary:")
    for k, v in features.items():
        print(f"{k}: {v}")
    # Emit signals for rms and mfcc0
    rms = features.get('rms_mean', 0.0)
    mfcc0 = features.get('mfccs_mean', [0.0])[0] if 'mfccs_mean' in features else 0.0
    send_to_awesome("glitch::rms", rms)
    send_to_awesome("glitch::mfcc0", mfcc0)
    # Zero-crossing rate
    zcr = float(librosa.feature.zero_crossing_rate(y=y).mean())
    send_to_awesome("glitch::zcr", zcr)
    # Spectral contrast
    contrast = librosa.feature.spectral_contrast(y=y, sr=sr)
    send_to_awesome("glitch::spectral_contrast", float(contrast.mean()))
    # Optional: visualize
    visualize(y, sr, features)

if __name__ == "__main__":
    main()
