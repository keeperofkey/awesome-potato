import sys
from PyQt5.QtWidgets import QApplication
from audio_input import AudioInput
from signal_analysis import SignalAnalyzer
from effects.glitch import GlitchEffectWindow
from midi_control import MidiController
from awesome_ipc import AwesomeIPC


def main():
    app = QApplication(sys.argv)
    audio = AudioInput()
    analyzer = SignalAnalyzer()
    midi = MidiController()
    ipc = AwesomeIPC()
    effect_win = GlitchEffectWindow(analyzer, midi)
    effect_win.show()

    def audio_callback(indata):
        volume, fft, peak, beat = analyzer.process_audio(indata)
        # Send to AwesomeWM (glitch_effect)
        ipc.send_analysis(volume, peak, beat, fft)
        # The analyzer object is updated, so the window will reflect new values on next timer tick

    audio.start(audio_callback)
    midi.start()
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()
