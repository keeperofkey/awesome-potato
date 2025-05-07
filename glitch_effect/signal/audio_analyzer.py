import sounddevice as sd
import numpy as np
import asyncio
import websockets

# WebSocket server configuration
HOST = "localhost"
PORT = 8765

# FFT configuration
SAMPLE_RATE = 44100
FFT_SIZE = 1024

async def audio_stream(websocket, path):
    def callback(indata, frames, time, status):
        if status:
            print(f"Stream status: {status}")
        # Perform FFT
        spectrum = np.abs(np.fft.rfft(indata[:, 0], n=FFT_SIZE))
        spectrum = spectrum[:FFT_SIZE // 2]
        # Normalize and split into bands
        low = np.mean(spectrum[:FFT_SIZE // 16])
        mid = np.mean(spectrum[FFT_SIZE // 16:FFT_SIZE // 8])
        high = np.mean(spectrum[FFT_SIZE // 8:FFT_SIZE // 4])
        # Send data over WebSocket
        asyncio.run(websocket.send(f"{low},{mid},{high}"))

    with sd.InputStream(channels=1, samplerate=SAMPLE_RATE, callback=callback):
        await websocket.recv()  # Keep the connection open

async def main():
    async with websockets.serve(audio_stream, HOST, PORT):
        print(f"WebSocket server running at ws://{HOST}:{PORT}")
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    asyncio.run(main())