#!/bin/bash
# Install script for PyAudio dependencies

echo "=== Installing PyAudio and dependencies ==="

# Detect the distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    DISTRO=$DISTRIB_ID
else
    echo "Could not determine Linux distribution"
    DISTRO="unknown"
fi

echo "Detected distribution: $DISTRO"

# Install packages based on distribution
case "$DISTRO" in
    "arch"|"manjaro"|"endeavouros")
        echo "Installing for Arch-based system..."
        sudo pacman -S --needed python-pyaudio python-numpy
        ;;
    "ubuntu"|"debian"|"linuxmint"|"pop")
        echo "Installing for Debian/Ubuntu-based system..."
        sudo apt-get update
        sudo apt-get install -y python3-pyaudio python3-numpy
        ;;
    "fedora")
        echo "Installing for Fedora..."
        sudo dnf install -y python3-pyaudio python3-numpy
        ;;
    *)
        echo "Unsupported distribution, trying with pip..."
        # Try to install with pip for unsupported distributions
        pip install --user pyaudio numpy
        ;;
esac

# Test if installation was successful
echo "Testing PyAudio installation..."
python3 -c "import pyaudio; print('PyAudio version:', pyaudio.__version__)"
python3 -c "import numpy; print('NumPy version:', numpy.__version__)"

if [ $? -eq 0 ]; then
    echo "Installation successful!"
    echo "You can now run the audio analyzer with:"
    echo "python3 audio_analyzer.py"
else
    echo "Installation may have failed. Please install PyAudio and NumPy manually."
    echo "For most systems, you need to install portaudio development headers first:"
    echo "  Arch: sudo pacman -S portaudio"
    echo "  Ubuntu/Debian: sudo apt-get install portaudio19-dev"
    echo "  Fedora: sudo dnf install portaudio-devel"
    echo "Then install PyAudio:"
    echo "  pip install --user pyaudio numpy"
fi