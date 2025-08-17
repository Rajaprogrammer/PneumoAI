# rfid_reader.py
import serial
import time
import sys

def send_and_receive_rfid_data(port, baud_rate, signal):
    """
    Connects to serial port, sends RFID signal, reads incoming data,
    and prints it to stdout for the parent process to capture.
    Exits after finding a definitive RFID status line or timeout.
    """
    ser = None # Initialize ser to None
    try:
        ser = serial.Serial(port, baud_rate, timeout=1) # Set a timeout for read operations
        time.sleep(2) # Give time for the serial connection to establish
        print(f"Connected to {port} at {baud_rate} baud.")

        # rishon: Send the RFID signal
        ser.write(signal.encode('utf-8'))
        print(f"Sent signal: {repr(signal)}") # Use repr() to show exact string sent

        print("\n--- Incoming Serial Data (Raw Bytes) ---")
        buffer = ""
        start_time = time.time()
        timeout_duration = 10 # rishon: Timeout for receiving RFID response (10 seconds)

        while (time.time() - start_time) < timeout_duration:
            if ser.in_waiting > 0:
                raw_byte = ser.read(1)
                sys.stdout.write(f"\\x{raw_byte.hex()}") # Print raw byte representation
                sys.stdout.flush() # Ensure it prints immediately

                try:
                    char = raw_byte.decode('ascii') # Attempt to decode as ASCII
                except UnicodeDecodeError:
                    char = f"\\x{raw_byte.hex()}" # Fallback to hex representation for non-ASCII

                if char == '\n':
                    line = buffer.strip()
                    print(f"\n[RFID READER RECEIVED LINE] '{line}'") # Print the full processed line
                    # rishon: Check if this line contains a definitive RFID status
                    if line.startswith("rfid:success") or \
                       line.startswith("rfid:failed") or \
                       line.startswith("rfid:timeout"):
                        print(f"RFID_READER_FINAL_STATUS: {line}") # rishon: Explicitly print final status for subprocess capture
                        return # Exit function, as definitive status found
                    buffer = "" # Reset buffer for the next line
                    sys.stdout.write("--- Incoming Serial Data (Raw Bytes) ---\n") # Reset raw byte output line
                    sys.stdout.flush()
                elif char == '\r':
                    pass # Ignore carriage return
                else:
                    buffer += char
            time.sleep(0.01) # Small delay to prevent busy-waiting

        print(f"\n[RFID READER TIMEOUT] No definitive RFID response received within {timeout_duration} seconds.")
        print("RFID_READER_FINAL_STATUS: rfid:timeout") # rishon: Explicitly print timeout status
    except serial.SerialException as e:
        print(f"❌ RFID Serial error: {e}", file=sys.stderr)
        print("RFID_READER_FINAL_STATUS: rfid:error") # rishon: Explicitly print error status
    except Exception as e:
        print(f"❌ An unexpected error occurred in rfid_reader.py: {e}", file=sys.stderr)
        print("RFID_READER_FINAL_STATUS: rfid:error") # rishon: Explicitly print error status
    finally:
        if ser and ser.is_open:
            ser.close()
            print(f"Serial port {port} closed by rfid_reader.py.")

if __name__ == "__main__":
    # rishon: Configuration for rfid_reader.py
    SERIAL_PORT = 'COM4'
    BAUD_RATE = 9600
    SIGNAL_TO_SEND = "rfid:auth\n" # Ensure this includes the newline

    send_and_receive_rfid_data(SERIAL_PORT, BAUD_RATE, SIGNAL_TO_SEND)
