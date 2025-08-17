# serial_utils.py
import serial
import time
import threading
import sys

class SerialCommunicator:
    def __init__(self, port, baudrate, enabled=True):
        self.port = port
        self.baudrate = baudrate
        self.enabled = enabled
        self.ser = None
        self.lock = threading.Lock() # To ensure thread-safe serial access

        if self.enabled:
            try:
                self.ser = serial.Serial(self.port, self.baudrate, timeout=0.05)
                time.sleep(2) # Give time for connection to establish
                print(f"✅ Serial port {self.port} opened successfully.")
            except serial.SerialException as e:
                self.enabled = False # Disable if connection fails
                print(f"❌ Could not open serial port {self.port}: {e}", file=sys.stderr)
                print("Serial communication disabled. Running in simulation mode.", file=sys.stderr)

    def send(self, data):
        """
        Sends data over the serial port exactly as provided.
        Prints exact string sent for debugging.
        """
        if not self.enabled:
            # Use repr() to show exact string including newlines in simulated output
            print(f"[SERIAL SIMULATED SEND] {repr(data)}")
            return

        with self.lock:
            try:
                if self.ser and self.ser.is_open:
                    self.ser.write(data.encode('utf-8'))
                    # Use repr() to show exact string including newlines in actual sent output
                    print(f"[SERIAL SENT] {repr(data)}")
                else:
                    print(f"❌ Serial port is not open. Cannot send data: {repr(data)}", file=sys.stderr)
            except serial.SerialException as e:
                print(f"❌ Error sending data over serial: {e}", file=sys.stderr)
                self.enabled = False # Disable if send fails
                print("Serial communication disabled due to error.", file=sys.stderr)

    def read_response(self, timeout_sec=5, expected_end_char='\n'):
        """
        Reads data from the serial port until an expected end character is found
        or a timeout occurs. Prints all incoming raw bytes for debugging.
        Returns the decoded line or None on timeout/error.
        """
        if not self.enabled:
            print(f"[SERIAL SIMULATED READ] Waiting for response (timeout {timeout_sec}s)...")
            return None

        start_time = time.time()
        current_line_buffer = ""
        print("\n--- Incoming Serial Data (Raw Bytes) ---")

        with self.lock: # Lock during read operation
            while (time.time() - start_time) < timeout_sec:
                if self.ser and self.ser.in_waiting > 0:
                    raw_byte = self.ser.read(1)  # Read one byte at a time
                    sys.stdout.write(f"\\x{raw_byte.hex()}")
                    sys.stdout.flush() # Ensure it prints immediately

                    try:
                        char = raw_byte.decode('ascii')
                        if char == expected_end_char:
                            processed_line = current_line_buffer.strip()
                            print(f"\n[SERIAL RECEIVED LINE] '{processed_line}'")
                            return processed_line
                        elif char == '\r': # Ignore carriage return
                            pass
                        else:
                            current_line_buffer += char
                    except UnicodeDecodeError:
                        current_line_buffer += f"\\x{raw_byte.hex()}"
                    except serial.SerialException as e:
                        print(f"\n❌ Error reading from serial: {e}", file=sys.stderr)
                        self.enabled = False
                        return None
                time.sleep(0.01) # Small delay

        print(f"\n[SERIAL TIMEOUT] No full response line received within {timeout_sec} seconds.")
        return None

    def close(self):
        if self.ser and self.ser.is_open:
            print(f"Closing serial port {self.port}.")
            self.ser.close()
