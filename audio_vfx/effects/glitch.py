from PyQt5.QtWidgets import QWidget, QLabel, QVBoxLayout
from PyQt5.QtCore import QTimer
from PyQt5.QtGui import QColor, QPainter
import numpy as np

class GlitchEffectWindow(QWidget):
    def __init__(self, analyzer):
        super().__init__()
        self.analyzer = analyzer
        self.setWindowTitle("Audio Debug/Visualizer")
        self.resize(600, 400)
        self.label = QLabel("Audio Visualizer", self)
        layout = QVBoxLayout()
        layout.addWidget(self.label)
        self.setLayout(layout)
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_effect)
        self.timer.start(30)
        self.flash = False
        self.flash_timer = 0

    def update_effect(self):
        vol = self.analyzer.last_volume
        peak = getattr(self.analyzer, 'last_peak', False)
        beat = getattr(self.analyzer, 'last_beat', False)
        self.label.setText(f"Volume: {vol:.3f} | Peak: {peak}")
        # Flash background briefly on beat
        if beat:
            self.flash = True
            self.flash_timer = 5
        if self.flash:
            self.flash_timer -= 1
            if self.flash_timer <= 0:
                self.flash = False
        self.update()

    def paintEvent(self, event):
        qp = QPainter(self)
        # Flash background if beat triggered
        if self.flash:
            qp.setBrush(QColor(0, 180, 255))
        else:
            qp.setBrush(QColor(0, 0, 0))
        qp.drawRect(self.rect())
        # Draw FFT bars
        fft = self.analyzer.last_fft
        if fft is not None:
            n_bins = 64
            bins = np.array_split(fft, n_bins)
            heights = [np.mean(b) for b in bins]
            max_height = max(heights) if heights else 1
            w = self.width() / n_bins
            for i, h in enumerate(heights):
                bar_height = int((h / max_height) * self.height() * 0.9)
                x = int(i * w)
                y = self.height() - bar_height
                color = QColor(100, 220, 200)
                qp.setBrush(color)
                qp.drawRect(x, y, int(w)-2, bar_height)

