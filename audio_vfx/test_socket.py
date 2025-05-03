#!/usr/bin/env python3
"""
Test the Unix socket connection to AwesomeWM.
"""
import os
import sys
import time
import socket
import json
import argparse

def parse_args():
    parser = argparse.ArgumentParser(description='Test Unix socket communication with AwesomeWM')
    parser.add_argument('--socket', type=str, default='/tmp/audio_vfx.sock', help='Path to the Unix socket')
    parser.add_argument('--create', action='store_true', help='Create the socket if it doesn\'t exist')
    parser.add_argument('--send', type=str, help='Send a test message to the socket')
    return parser.parse_args()

def test_socket(socket_path, create=False, message=None):
    """Test if the socket exists and is working"""
    print(f"Testing Unix socket at: {socket_path}")
    
    # Check if socket file exists
    if os.path.exists(socket_path):
        print(f"✅ Socket file exists: {socket_path}")
        
        # Check permissions
        try:
            mode = os.stat(socket_path).st_mode
            perms = oct(mode & 0o777)
            print(f"Socket permissions: {perms}")
            if mode & 0o777 < 0o660:
                print(f"⚠️  Socket permissions might be too restrictive")
        except Exception as e:
            print(f"❌ Error checking socket permissions: {e}")
    else:
        print(f"❌ Socket file doesn't exist: {socket_path}")
        if create:
            print(f"Creating socket file...")
            try:
                server = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
                server.bind(socket_path)
                os.chmod(socket_path, 0o777)
                print(f"✅ Created socket: {socket_path}")
            except Exception as e:
                print(f"❌ Error creating socket: {e}")
                return False
        else:
            print("Use --create to create the socket")
            return False
    
    # Try to connect and send a message
    if message:
        print(f"\nSending test message: {message}")
        try:
            # Create client socket
            client = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
            
            # Bind to a temporary path
            temp_path = f"{socket_path}_test_{int(time.time())}"
            if os.path.exists(temp_path):
                os.unlink(temp_path)
            
            try:
                client.bind(temp_path)
                
                # Send message
                data = {
                    "type": "test",
                    "message": message,
                    "timestamp": time.time()
                }
                msg = json.dumps(data).encode('utf-8')
                client.sendto(msg, socket_path)
                print(f"✅ Message sent successfully")
                
                # Clean up
                client.close()
                os.unlink(temp_path)
                
            except Exception as e:
                print(f"❌ Error sending message: {e}")
                if "Connection refused" in str(e):
                    print("\nPossible causes:")
                    print("- AwesomeWM is not running")
                    print("- AwesomeWM hasn't loaded the audio_listener.lua module")
                    print("- The socket file exists but no process is listening on it")
                    print("\nSuggestions:")
                    print("1. Check if audio_listener is properly loaded in rc.lua")
                    print("2. Restart AwesomeWM (Mod+Ctrl+r)")
                    print("3. Delete the socket file and let AwesomeWM recreate it:")
                    print(f"   sudo rm {socket_path}")
                return False
                
        except Exception as e:
            print(f"❌ Error with socket connection: {e}")
            return False
    
    return True

def main():
    args = parse_args()
    test_socket(args.socket, args.create, args.send)

if __name__ == "__main__":
    main()