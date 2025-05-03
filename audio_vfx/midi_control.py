import threading
import mido
import time

class MidiController:
    def __init__(self, device_name=None):
        self.state = {}
        self.running = False
        self.thread = None
        self.device_name = device_name
        self._connected = False
        self._reconnect_delay = 5  # seconds

    def start(self):
        self.running = True
        self.thread = threading.Thread(target=self.listen)
        self.thread.daemon = True
        self.thread.start()
        
    def stop(self):
        self.running = False
        if self.thread:
            self.thread.join(timeout=1.0)
            
    def listen(self):
        while self.running:
            try:
                # List available devices and try to find a suitable one
                available_ports = mido.get_input_names()
                if not available_ports:
                    print("No MIDI devices found. Retrying in 5 seconds...")
                    time.sleep(self._reconnect_delay)
                    continue
                    
                # Use specified device name or first available
                port_name = self.device_name
                if not port_name or port_name not in available_ports:
                    port_name = available_ports[0]
                    print(f"Using MIDI device: {port_name}")
                
                with mido.open_input(port_name) as port:
                    self._connected = True
                    print(f"Connected to MIDI device: {port_name}")
                    
                    while self.running:
                        # Use non-blocking receive with timeout
                        for msg in port.iter_pending():
                            # Example: store CC values
                            if msg.type == 'control_change':
                                self.state[msg.control] = msg.value
                        time.sleep(0.01)  # Small sleep to prevent CPU hogging
                        
            except Exception as e:
                self._connected = False
                print(f"MIDI error: {e}. Reconnecting in {self._reconnect_delay} seconds...")
                time.sleep(self._reconnect_delay)

    def get_state(self):
        return self.state.copy()  # Return a copy to prevent race conditions
        
    def is_connected(self):
        return self._connected
