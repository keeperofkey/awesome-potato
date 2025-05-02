import threading
import mido

class MidiController:
    def __init__(self):
        self.state = {}
        self.running = False
        self.thread = None

    def start(self):
        self.running = True
        self.thread = threading.Thread(target=self.listen)
        self.thread.daemon = True
        self.thread.start()

    def listen(self):
        try:
            with mido.open_input() as port:
                for msg in port:
                    # Example: store CC values
                    if msg.type == 'control_change':
                        self.state[msg.control] = msg.value
        except Exception as e:
            print("MIDI error:", e)

    def get_state(self):
        return self.state
