import socket
import json
import os

class AwesomeIPC:
    def __init__(self, sock_path="/tmp/audio_vfx.sock"):
        self.sock_path = sock_path
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        # No need to bind for client, just connect/sendto
        # Clean up any old socket file if we ever act as a server

    def send_analysis(self, volume, peak, beat, fft):
        try:
            data = {
                "volume": volume,
                "peak": peak,
                "beat": beat,
                "fft": fft[:32].tolist()  # send first 32 bins for brevity
            }
            msg = json.dumps(data).encode("utf-8")
            self.sock.sendto(msg, self.sock_path)
        except Exception as e:
            print("[AwesomeIPC] Error sending analysis:", e)

    def cleanup(self):
        self.sock.close()
