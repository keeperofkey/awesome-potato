import socket
import json
import os
import logging
import time
import sys
import threading
from threading import Lock

logger = logging.getLogger(__name__)

class AwesomeIPC:
    def __init__(self, sock_path="/tmp/audio_vfx.sock", test_mode=False):
        self.sock_path = sock_path
        self.sock = None
        self.lock = Lock()
        self.temp_path = None
        self.test_mode = test_mode
        self.running = True
        self.listener_thread = None
        
        # Connect and start listener if in test mode
        self.connect()
        if test_mode:
            self.start_test_listener()
        
    def connect(self):
        """Connect to the socket, creating a new socket if needed"""
        try:
            with self.lock:
                if self.sock:
                    self.sock.close()
                
                # Create the socket file if it doesn't exist
                if not os.path.exists(os.path.dirname(self.sock_path)):
                    os.makedirs(os.path.dirname(self.sock_path))
                
                # Create the socket
                self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
                
                # If we're in test mode, bind directly to the main socket
                if self.test_mode:
                    try:
                        if os.path.exists(self.sock_path):
                            os.unlink(self.sock_path)
                        self.sock.bind(self.sock_path)
                        os.chmod(self.sock_path, 0o777)
                        self.temp_path = self.sock_path
                        logger.info(f"Testing mode: Bound directly to {self.sock_path}")
                    except Exception as e:
                        logger.error(f"Failed to bind to main socket in test mode: {e}")
                        raise
                else:
                    # Normal client mode: Create the server socket if it doesn't exist
                    self._create_server_socket()
                    
                    # Bind to a temporary path on the client side (required for DGRAM Unix sockets)
                    self.temp_path = f"{self.sock_path}_client_{os.getpid()}"
                    if os.path.exists(self.temp_path):
                        os.unlink(self.temp_path)
                    
                    try:
                        self.sock.bind(self.temp_path)
                        os.chmod(self.temp_path, 0o777)  # Ensure permissions
                    except OSError as e:
                        logger.warning(f"Could not bind to {self.temp_path}: {e}")
                        # Try an alternative path
                        self.temp_path = f"/tmp/audio_vfx_client_{os.getpid()}"
                        if os.path.exists(self.temp_path):
                            os.unlink(self.temp_path)
                        self.sock.bind(self.temp_path)
                        os.chmod(self.temp_path, 0o777)
                
                logger.info(f"Connected to socket: {self.sock_path} (via {self.temp_path})")
                return True
                
        except Exception as e:
            logger.error(f"Failed to connect to socket: {e}")
            return False
            
    def start_test_listener(self):
        """Start a test listener that echoes received messages back"""
        if self.listener_thread is not None:
            return
            
        self.running = True
        self.listener_thread = threading.Thread(target=self._listen_loop)
        self.listener_thread.daemon = True
        self.listener_thread.start()
        logger.info("Started test listener thread")
        
    def _listen_loop(self):
        """Background thread that listens for messages and echoes them"""
        if not self.test_mode:
            return
            
        logger.info("Test listener thread started")
        self.sock.settimeout(0.5)  # Short timeout for responsive shutdown
        
        while self.running:
            try:
                try:
                    data, addr = self.sock.recvfrom(8192)
                    if data:
                        logger.info(f"Test listener received data: {data[:50]}...")
                        
                        # Echo data back
                        try:
                            # Parse the data for debugging
                            parsed = json.loads(data.decode('utf-8'))
                            vol = parsed.get('volume', 0)
                            beat = parsed.get('beat', False)
                            
                            # Log meaningful debug info
                            if beat:
                                logger.info(f"BEAT detected! Volume: {vol:.3f}")
                            elif vol > 0.01:  # Only log meaningful volumes
                                logger.info(f"Volume: {vol:.3f}")
                                
                        except Exception as e:
                            logger.warning(f"Error parsing data: {e}")
                            
                except socket.timeout:
                    # Just a timeout, continue loop
                    continue
                    
            except Exception as e:
                if self.running:  # Only log if we're still meant to be running
                    logger.error(f"Error in test listener: {e}")
                    time.sleep(1)
        
        logger.info("Test listener thread stopped")
            
    def _create_server_socket(self):
        """Create the server socket if it doesn't exist"""
        try:
            # If the socket file doesn't exist, create it with a quick server socket
            if not os.path.exists(self.sock_path):
                logger.info(f"Server socket {self.sock_path} doesn't exist, creating it")
                srv_sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
                
                # Remove file if it exists (shouldn't, but just in case)
                try:
                    os.unlink(self.sock_path)
                except OSError:
                    pass
                    
                # Bind and set permissions
                srv_sock.bind(self.sock_path)
                os.chmod(self.sock_path, 0o777)
                logger.info(f"Created server socket: {self.sock_path}")
                
                # Close it - we just needed to create the file
                srv_sock.close()
        except Exception as e:
            logger.warning(f"Could not create server socket: {e}")
            # This is not fatal, as the server may create it later

    def send_analysis(self, volume, peak, beat, fft):
        """Send audio analysis data to AwesomeWM"""
        try:
            # Create a compact message with just necessary data
            data = {
                "volume": float(volume),  # Ensure it's a float
                "peak": bool(peak),       # Ensure it's a boolean
                "beat": bool(beat),       # Ensure it's a boolean
                "fft": fft[:32].tolist()  # Send first 32 bins for brevity
            }
            
            # Send data to socket
            with self.lock:
                if not self.sock:
                    if not self.connect():
                        return False
                
                msg = json.dumps(data).encode("utf-8")
                
                if self.test_mode:
                    # In test mode, we're already bound to the socket
                    # Just log that we would have sent data
                    logger.debug(f"Would send data: vol={volume:.3f}, peak={peak}, beat={beat}")
                    return True
                else:
                    # In normal mode, send to the server socket
                    self.sock.sendto(msg, self.sock_path)
                    return True
                
        except socket.error as e:
            logger.warning(f"Socket error: {e}. Attempting to reconnect...")
            time.sleep(1)  # Add delay to prevent rapid reconnection attempts
            self.connect()
            return False
        except Exception as e:
            logger.error(f"Error sending analysis: {e}")
            return False

    def cleanup(self):
        """Clean up resources"""
        # Stop the listener thread
        self.running = False
        if self.listener_thread:
            try:
                self.listener_thread.join(timeout=2.0)
            except:
                pass
            self.listener_thread = None
        
        # Clean up the socket
        with self.lock:
            if self.sock:
                try:
                    self.sock.close()
                    logger.info("Socket closed")
                    
                    # Clean up the temporary socket file
                    if self.temp_path and os.path.exists(self.temp_path):
                        os.unlink(self.temp_path)
                        logger.info(f"Removed temporary socket file: {self.temp_path}")
                except Exception as e:
                    logger.error(f"Error closing socket: {e}")
                finally:
                    self.sock = None
