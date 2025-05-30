import sys
import os
import numpy as np
import librosa
import subprocess
import pyaudio
import signal
import time


def extract_features(y, sr):
    features = {}
    # Precompute reusable values
    mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
    chroma = librosa.feature.chroma_stft(y=y, sr=sr)
    contrast = librosa.feature.spectral_contrast(y=y, sr=sr)
    zcr = librosa.feature.zero_crossing_rate(y)
    rms = librosa.feature.rms(y=y)
    centroid = librosa.feature.spectral_centroid(y=y, sr=sr)
    bandwidth = librosa.feature.spectral_bandwidth(y=y, sr=sr)
    # New features
    melspec = librosa.feature.melspectrogram(y=y, sr=sr)
    poly = librosa.feature.poly_features(y=y, sr=sr)

    # Compute features
    features.update(
        {
            "mfccs_mean": np.mean(mfccs, axis=1),
            "mfccs_std": np.std(mfccs, axis=1),
            "chroma_mean": np.mean(chroma, axis=1),
            "chroma_std": np.std(chroma, axis=1),
            "contrast_mean": np.mean(contrast, axis=1),
            "contrast_std": np.std(contrast, axis=1),
            "zcr_mean": np.mean(zcr),
            "zcr_std": np.std(zcr),
            "rms_mean": np.mean(rms),
            "rms_std": np.std(rms),
            "centroid_mean": np.mean(centroid),
            "centroid_std": np.std(centroid),
            "bandwidth_mean": np.mean(bandwidth),
            "bandwidth_std": np.std(bandwidth),
            # Added features
            "melspec_mean": np.mean(melspec, axis=1),
            "melspec_std": np.std(melspec, axis=1),
            "poly_mean": np.mean(poly, axis=1),
            "poly_std": np.std(poly, axis=1),
        }
    )

    # Beat detection
    try:
        tempo, beat_frames = librosa.beat.beat_track(y=y, sr=sr)
        features["tempo"] = tempo
        features["beats"] = librosa.frames_to_time(beat_frames, sr=sr)
    except Exception:
        features["tempo"] = None
        features["beats"] = np.array([])

    # Tonnetz (only for harmonic signals)
    try:
        y_harmonic = librosa.effects.harmonic(y)
        tonnetz = librosa.feature.tonnetz(y=y_harmonic, sr=sr)
        features["tonnetz_mean"] = np.mean(tonnetz, axis=1)
        features["tonnetz_std"] = np.std(tonnetz, axis=1)
    except Exception:
        pass

    return features


def send_to_awesome(signal_name, value):
    try:
        val_str = (
            f"{float(value):.6f}" if isinstance(value, (int, float)) else str(value)
        )
        lua_cmd = f'awesome.emit_signal("{signal_name}", {val_str})'
        subprocess.run(
            ["awesome-client", lua_cmd],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass


def live_audio_loop(rate=44100, chunk=22050, n_mfcc=13):
    print("Starting live audio feature extraction (Ctrl+C to stop)...")
    FORMAT = pyaudio.paInt16
    CHANNELS = 1
    p = pyaudio.PyAudio()
    stream = p.open(
        format=FORMAT, channels=CHANNELS, rate=rate, input=True, frames_per_buffer=chunk
    )

    running = True

    def signal_handler(sig, frame):
        nonlocal running
        running = False

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    while running:
        try:
            data = stream.read(chunk, exception_on_overflow=False)
            audio = np.frombuffer(data, dtype=np.int16).astype(np.float32) / 32768.0

            # Extract features
            rms = float(librosa.feature.rms(y=audio).mean())
            mfcc0 = float(
                librosa.feature.mfcc(y=audio, sr=rate, n_mfcc=n_mfcc)[0].mean()
            )
            zcr = float(librosa.feature.zero_crossing_rate(y=audio).mean())
            contrast = float(librosa.feature.spectral_contrast(y=audio, sr=rate).mean())
            # New features
            melspec = librosa.feature.melspectrogram(y=audio, sr=rate)
            melspec_mean = float(np.mean(melspec))
            poly = librosa.feature.poly_features(y=audio, sr=rate)
            poly_mean_arr = np.mean(poly, axis=1)
            poly_mean_str = ",".join([f"{v:.6f}" for v in poly_mean_arr])

            # Emit individual signals for each feature
            send_to_awesome("glitch::rms", rms)
            send_to_awesome("glitch::mfcc0", mfcc0)
            send_to_awesome("glitch::zcr", zcr)
            send_to_awesome("glitch::contrast", contrast)
            send_to_awesome("glitch::melspec_mean", melspec_mean)
            send_to_awesome("glitch::poly_mean", poly_mean_str)

            # Beat detection for live audio
            try:
                tempo, beat_frames = librosa.beat.beat_track(y=audio, sr=rate)
                send_to_awesome("glitch::bpm", tempo)
                # Optionally, emit a signal if a beat is detected in this chunk
                if len(beat_frames) > 0:
                    send_to_awesome("glitch::beat", 1)
                else:
                    send_to_awesome("glitch::beat", 0)
            except Exception:
                tempo = None  # Ensure tempo is defined

            # Print summary
            if tempo is not None:
                if isinstance(tempo, (float, int, np.floating, np.integer)):
                    tempo_str = f"{tempo:.1f}"
                elif hasattr(tempo, 'item'):
                    tempo_str = f"{tempo.item():.1f}"
                else:
                    tempo_str = str(tempo)
            else:
                tempo_str = "N/A"
            sys.stdout.write(
                f"\rRMS: {rms:.3f}, MFCC[0]: {mfcc0:.1f}, ZCR: {zcr:.3f}, Contrast: {contrast:.3f}, MelSpec: {melspec_mean:.3f}, Poly: {poly_mean_str}, BPM: {tempo_str}"
            )
            sys.stdout.flush()
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
    if "--live" in sys.argv:
        live_audio_loop()
        return
    audio_path = sys.argv[1]
    if not os.path.isfile(audio_path):
        print(f"File not found: {audio_path}")
        sys.exit(1)
    y, sr = librosa.load(audio_path, sr=None, mono=True)
    features = extract_features(y, sr)
    # Print all features
    for k, v in features.items():
        print(f"{k}: {v}")
    # If beat info is present, print BPM and beat times
    if "tempo" in features and features["tempo"] is not None:
        tempo_val = features["tempo"]
        if isinstance(tempo_val, (float, int, np.floating, np.integer)):
            print(f"Detected BPM: {tempo_val:.2f}")
        elif hasattr(tempo_val, 'item'):
            print(f"Detected BPM: {tempo_val.item():.2f}")
        else:
            print(f"Detected BPM: {tempo_val}")
    if "beats" in features and features["beats"] is not None and len(features["beats"]) > 0:
        print(f"Beat times (s): {features['beats'].tolist() if hasattr(features['beats'], 'tolist') else features['beats']}")


if __name__ == "__main__":
    main()
