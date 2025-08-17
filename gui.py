# gui.py
import threading
import webview
from app import app  # This imports your Flask app
import time          # Import time for sleep
import sys           # Import sys for error logging

print(">> Flask App Loaded From:", app.root_path)

def run_flask():
    """Starts the Flask server in a separate thread."""
    print("✅ Flask server starting...")
    try:
        # It's good practice to log any Flask startup errors here
        # use_reloader=False is crucial when running with pywebview to avoid issues
        app.run(debug=False, port=5000, use_reloader=False)
    except Exception as e:
        print(f"❌ Flask server failed to start: {e}", file=sys.stderr) # Use sys.stderr for errors
        # You might want to signal the main thread to exit or show a message box here
        # For simplicity, we'll just print the error.

if __name__ == '__main__':
    # Start Flask server in background thread
    flask_thread = threading.Thread(target=run_flask)
    flask_thread.daemon = True # Daemon threads exit when the main program exits
    flask_thread.start()

    # Give Flask a moment to start up before pywebview tries to load the URL
    # Increased sleep for robustness, adjust if needed based on your system's startup time
    time.sleep(3) # Increased from 2 to 3 seconds for more robust startup

    # Start the native webview GUI pointing to the local Flask app
    try:
        print("🌍 Attempting to create webview window...")
        webview.create_window("PneumoAI - Lung Sound Classifier", "http://127.0.0.1:5000")
        webview.start()
        print("✅ Webview window closed.")
    except Exception as e:
        print(f"❌ Pywebview failed to start or encountered an error: {e}", file=sys.stderr)
        # Optionally, you could show a message box here if webview fails
        # webview.create_window("Error", html=f"<h1>Pywebview Error</h1><p>{e}</p>")
        # webview.start()

    # Ensure Flask thread is cleaned up if it's still running
    if flask_thread.is_alive():
        print("ℹ️ Flask thread still alive, attempting to join (may block briefly).")
        # You might need a more sophisticated shutdown mechanism for Flask if it doesn't exit cleanly
        # For now, relying on daemon thread will eventually terminate it.
