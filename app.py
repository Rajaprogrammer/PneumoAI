# app.py
from flask import Flask, request, render_template, jsonify
from tensorflow.keras.models import load_model
from sklearn.preprocessing import LabelEncoder
import numpy as np
import librosa
import os
import json
from pydub import AudioSegment
import uuid
import sys
import threading
import pyttsx3
import time
from serial_utils import SerialCommunicator # Ensure serial_utils.py is in the same directory

app = Flask(__name__, static_folder="static", template_folder="templates")

# Initialize Serial Communicator (adjust COM port and baudrate as needed)
# Set enabled=False if you don't have an Arduino connected or don't want serial communication
serial_comm = SerialCommunicator(port="COM4", baudrate=9600, enabled=True)

# 🎙 Voice engine setup
engine = pyttsx3.init()
voices = engine.getProperty('voices')
# Try to find an English voice
for v in voices:
    if "english" in v.name.lower():
        engine.setProperty('voice', v.id)
        break
engine.setProperty('rate', 180) # Set speech rate

voice_lock = threading.Lock() # To prevent overlapping speech

# ✅ Global default config for servo control
# Default reset positions for (DH DL DR) are now implicitly handled by Arduino or default 0,0,0
# Default hold time in milliseconds if not specified for a servo in the command
DEFAULT_HOLD_MS_COMMAND = 1500 # Minimum 1.5 seconds as requested

# Function to speak text
def speak(text):
    with voice_lock: # Ensure only one speech output at a time
        try:
            print(f"🗣️ Speaking: {text}")
            engine.say(text)
            engine.runAndWait()
        except Exception as e:
            print(f"❌ Voice output error: {e}", file=sys.stderr)

# ✅ Unified serial & voice interaction function with new servo format
def send_serial(lcd_message=None, voice_message=None,
                head_angle=None, head_hold_ms=None,
                handl_angle=None, handl_hold_ms=None,
                handr_angle=None, handr_hold_ms=None):
    """
    Sends commands to the Arduino via serial and/or triggers voice output.
    - lcd_message: Text to display on LCD.
    - voice_message: Text to speak.
    - head_angle, handl_angle, handr_angle: Target servo angles (0-180).
    - head_hold_ms, handl_hold_ms, handr_hold_ms: Time in milliseconds to hold position.
    """
    try:
        # Send LCD message
        if lcd_message is not None:
            serial_comm.send(f"lcd:{lcd_message.strip()}\n")
            time.sleep(0.08) # 80 ms gap after LCD command

        # Prepare servo command using the new format: servo:H,HT;L,LT;R,RT\n
        _head_angle = head_angle if head_angle is not None else 0
        _head_hold_ms = head_hold_ms if head_hold_ms is not None else DEFAULT_HOLD_MS_COMMAND

        _handl_angle = handl_angle if handl_angle is not None else 0
        _handl_hold_ms = handl_hold_ms if handl_hold_ms is not None else DEFAULT_HOLD_MS_COMMAND

        _handr_angle = handr_angle if handr_angle is not None else 0
        _handr_hold_ms = handr_hold_ms if handr_hold_ms is not None else DEFAULT_HOLD_MS_COMMAND

        full_servo_command = (
            f"servo:{_head_angle},{_head_hold_ms};"
            f"{_handl_angle},{_handl_hold_ms};"
            f"{_handr_angle},{_handr_hold_ms}\n"
        )
        
        # Send servo command
        serial_comm.send(full_servo_command)
        
        # Determine the longest hold time to sleep for
        max_hold_time_sec = max(_head_hold_ms, _handl_hold_ms, _handr_hold_ms) / 1000.0
        time.sleep(max_hold_time_sec + 0.08) # Wait for longest servo movement to complete + 80ms gap

        # Trigger voice output
        if voice_message:
            threading.Thread(target=speak, args=(voice_message,)).start()

    except Exception as e:
        print(f"❌ send_serial error: {e}", file=sys.stderr)


# --- Application Startup Actions ---
# Action when the model is loaded
try:
    model = load_model("models/respiratory_model.h5")
    # Initial model load action
    send_serial(lcd_message="Model Loaded", voice_message="Deep learning model is ready.",
                head_angle=90, head_hold_ms=2000,
                handl_angle=45, handl_hold_ms=2000,
                handr_angle=135, handr_hold_ms=2000)
except Exception as e:
    print(f"❌ Error loading Keras model: {e}", file=sys.stderr)
    # Model load error action
    send_serial(lcd_message="Model Error!", voice_message="Failed to load deep learning model. Please check model files.",
                head_angle=45, head_hold_ms=2000,
                handl_angle=90, handl_hold_ms=2000,
                handr_angle=23, handr_hold_ms=2000)
    sys.exit(1)

# Action when mean/std and label mapping are loaded
try:
    X_mean = np.load("models/X_mean.npy")
    with open("models/input_std.json") as f:
        input_std = np.array(json.load(f))
    with open("models/label_mapping.json") as f:
        label_mapping = json.load(f)
    ordered_labels = [k for k, v in sorted(label_mapping.items(), key=lambda item: item[1])]
    label_encoder = LabelEncoder()
    label_encoder.classes_ = np.array(ordered_labels)
    # Data loaded action
    send_serial(lcd_message="Data Loaded", voice_message="Preprocessing data loaded successfully.",
                head_angle=35, head_hold_ms=2000,
                handl_angle=20, handl_hold_ms=2000,
                handr_angle=360, handr_hold_ms=2000)
except Exception as e:
    print(f"❌ Error loading audio preprocessing data or label encoder: {e}", file=sys.stderr)
    # Data load error action
    send_serial(lcd_message="Data Error!", voice_message="Failed to load preprocessing data. Please check data files.",
                head_angle=90, head_hold_ms=2000,
                handl_angle=45, handl_hold_ms=2000,
                handr_angle=135, handr_hold_ms=2000)
    sys.exit(1)

# Directory for uploaded audio files
UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Function to convert MP3 to WAV
def convert_mp3_to_wav(mp3_path):
    wav_path = mp3_path.replace(".mp3", ".wav")
    try:
        # MP3 to WAV conversion start action
        send_serial(lcd_message="Converting...", voice_message="Converting MP3 to WAV.",
                    head_angle=80, head_hold_ms=1500, # Head slightly down
                    handl_angle=45, handl_hold_ms=1500,
                    handr_angle=135, handr_hold_ms=1500)
        sound = AudioSegment.from_mp3(mp3_path)
        sound.export(wav_path, format="wav")
        # MP3 to WAV conversion complete action
        send_serial(lcd_message="Converted!", voice_message="Conversion complete.",
                    head_angle=90, head_hold_ms=1800, # Head back to center
                    handl_angle=45, handl_hold_ms=1800,
                    handr_angle=135, handr_hold_ms=1800)
        return wav_path
    except Exception as e:
        # MP3 to WAV conversion error action
        send_serial(lcd_message="Conv. Error!", voice_message="Failed to convert audio file.",
                    head_angle=90, head_hold_ms=2000,
                    handl_angle=45, handl_hold_ms=2000,
                    handr_angle=135, handr_hold_ms=2000)
        print(f"❌ Error converting MP3 to WAV: {e}", file=sys.stderr)
        raise

# Function to preprocess audio for model prediction
def preprocess_audio(file_path):
    try:
        # Audio preprocessing start action
        send_serial(lcd_message="Preproc...", voice_message="Preprocessing audio features.",
                    head_angle=90, head_hold_ms=1500, # Head centered
                    handl_angle=45, handl_hold_ms=1500,
                    handr_angle=135, handr_hold_ms=1500)
        y, sr = librosa.load(file_path, sr=22050) # Load audio, resample to 22050 Hz
        mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=40) # Extract 40 MFCCs
        mfcc_mean = np.mean(mfcc.T, axis=0) # Get mean of MFCCs
        mfcc_scaled = (mfcc_mean - X_mean) / input_std # Scale using pre-calculated mean/std
        # Audio features extracted action
        send_serial(lcd_message="Features OK", voice_message="Audio features extracted.",
                    head_angle=90, head_hold_ms=1800, # Head centered
                    handl_angle=45, handl_hold_ms=1800,
                    handr_angle=135, handr_hold_ms=1800)
        return np.expand_dims(mfcc_scaled, axis=0) # Add batch dimension
    except Exception as e:
        # Audio preprocessing error action
        send_serial(lcd_message="Preproc Err!", voice_message="Failed to preprocess audio.",
                    head_angle=90, head_hold_ms=2000,
                    handl_angle=45, handl_hold_ms=2000,
                    handr_angle=135, handr_hold_ms=2000)
        print(f"❌ Error during audio preprocessing: {e}", file=sys.stderr)
        raise

@app.route("/")
def index():
    """Renders the main index.html page."""
    # Web UI ready action
    send_serial(lcd_message="Web UI Ready", voice_message="Web interface loaded. Ready for interaction.",
                head_angle=90, head_hold_ms=2000,
                handl_angle=45, handl_hold_ms=2000,
                handr_angle=135, handr_hold_ms=2000)
    return render_template("index.html")

@app.route("/predict", methods=["POST"])
def predict_route():
    """Handles audio file uploads, performs prediction, and returns results."""
    # This action is triggered by the frontend 'Analyze Audio' button submit
    # Prediction request received action
    send_serial(lcd_message="Predict Req", voice_message="Received prediction request.",
                head_angle=90, head_hold_ms=1500, # Head centered, preparing for analysis
                handl_angle=45, handl_hold_ms=1500,
                handr_angle=135, handr_hold_ms=1500)

    if "file" not in request.files:
        # No file part received action
        send_serial(lcd_message="No File!", voice_message="No audio file part received.",
                    head_angle=90, head_hold_ms=2000,
                    handl_angle=45, handl_hold_ms=2000,
                    handr_angle=135, handr_hold_ms=2000)
        return jsonify({"error": "No file part"}), 400

    file = request.files["file"]
    if file.filename == "":
        # No selected file action
        send_serial(lcd_message="No File!", voice_message="No selected audio file for upload.",
                    head_angle=90, head_hold_ms=2000,
                    handl_angle=45, handl_hold_ms=2000,
                    handr_angle=135, handr_hold_ms=2000)
        return jsonify({"error": "No selected file"}), 400

    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in [".wav", ".mp3"]:
        # Unsupported file format action
        send_serial(lcd_message="Bad Format!", voice_message="Unsupported audio file type. Please upload a WAV or MP3.",
                    head_angle=90, head_hold_ms=2000,
                    handl_angle=45, handl_hold_ms=2000,
                    handr_angle=135, handr_hold_ms=2000)
        return jsonify({"error": "Unsupported file type. Please upload .wav or .mp3"}), 400

    filename = f"{uuid.uuid4()}{ext}"
    path = os.path.join(UPLOAD_DIR, filename)
    file.save(path)
    # File saved action
    send_serial(lcd_message="File Saved", voice_message=f"Audio file '{os.path.basename(filename)}' saved.",
                head_angle=90, head_hold_ms=1500, # Head centered
                handl_angle=45, handl_hold_ms=1500,
                handr_angle=135, handr_hold_ms=1500)

    original_path = path # Keep track of the original path for cleanup

    try:
        if ext == ".mp3":
            path = convert_mp3_to_wav(path) # Convert to WAV if MP3

        features = preprocess_audio(path)
        # Prediction started action
        send_serial(lcd_message="Predicting...", voice_message="Making a prediction.",
                    head_angle=90, head_hold_ms=2000, # Head centered, focused
                    handl_angle=45, handl_hold_ms=2000,
                    handr_angle=135, handr_hold_ms=2000)
        preds = model.predict(features)[0]
        predicted_index = int(np.argmax(preds))
        label = label_encoder.inverse_transform([predicted_index])[0]
        # Prediction complete action
        send_serial(lcd_message="Prediction Done", voice_message="Prediction complete.",
                    head_angle=90, head_hold_ms=1500, # Head centered
                    handl_angle=45, handl_hold_ms=1500,
                    handr_angle=135, handr_hold_ms=1500)

        # Build confidences dict for all labels
        confidences = {
            label_encoder.inverse_transform([i])[0]: float(preds[i])
            for i in range(len(preds))
        }

        # Sort confidences by value in descending order
        sorted_confidences = dict(sorted(confidences.items(), key=lambda item: item[1], reverse=True))

        # Action based on prediction result
        lcd_msg = f"Pred: {label}"
        voice_msg = f"The predicted lung sound is {label}."

        if label == "normal":
            # Normal prediction action
            send_serial(lcd_message=lcd_msg, voice_message=voice_msg + " All clear!",
                        head_angle=90, head_hold_ms=2500, # Head straight, happy
                        handl_angle=60, handl_hold_ms=2500, # Hands slightly up
                        handr_angle=120, handr_hold_ms=2500)
        elif label == "crackle":
            # Crackle prediction action (hands out, head slightly down)
            send_serial(lcd_message=lcd_msg, voice_message=voice_msg + " Suggest further examination.",
                        head_angle=80, head_hold_ms=2000, # Head slightly down
                        handl_angle=10, handl_hold_ms=2000, # Left hand out
                        handr_angle=170, handr_hold_ms=2000) # Right hand fully out
            # Crackle prediction hand reset action
            send_serial(lcd_message="Hands Reset", voice_message="Hands reset.", # Optional LCD/voice for reset
                        head_angle=0, head_hold_ms=1000, # Use 0 for reset as per new format
                        handl_angle=0, handl_hold_ms=1000,
                        handr_angle=0, handr_hold_ms=1000)
        elif label == "wheeze":
            # Wheeze prediction action (head turn, hands slightly in)
            send_serial(lcd_message=lcd_msg, voice_message=voice_msg + " Consider checking airways.",
                        head_angle=120, head_hold_ms=2000,
                        handl_angle=30, handl_hold_ms=2000,
                        handr_angle=150, handr_hold_ms=2000)
            # Wheeze prediction head reset action
            send_serial(lcd_message="Head Reset", voice_message="Head reset.", # Optional LCD/voice for reset
                        head_angle=0, head_hold_ms=1000, # Use 0 for reset as per new format
                        handl_angle=0, handl_hold_ms=1000,
                        handr_angle=0, handr_hold_ms=1000)
        elif label == "both": # Assuming 'both' means crackle and wheeze
            # Both prediction action (hands out wide, head shaking)
            send_serial(lcd_message=lcd_msg, voice_message=voice_msg + " Significant findings detected.",
                        head_angle=70, head_hold_ms=2500,
                        handl_angle=0, handl_hold_ms=2500,
                        handr_angle=180, handr_hold_ms=2500) # Right hand fully out
            # Both prediction head reset action (quick shake then center)
            send_serial(lcd_message="Resetting", voice_message="Resetting position.",
                        head_angle=110, head_hold_ms=500,
                        handl_angle=0, handl_hold_ms=500, # Use 0 for reset as per new format
                        handr_angle=0, handr_hold_ms=500)
            send_serial(lcd_message="Resetting", voice_message="Resetting position.",
                        head_angle=0, head_hold_ms=1000, # Use 0 for reset as per new format
                        handl_angle=0, handl_hold_ms=1000,
                        handr_angle=0, handr_hold_ms=1000)
        else: # Default action for other labels
            # Other prediction action
            send_serial(lcd_message=lcd_msg, voice_message=voice_msg,
                        head_angle=90, head_hold_ms=2000,
                        handl_angle=45, handl_hold_ms=2000,
                        handr_angle=135, handr_hold_ms=2000)


        return jsonify({
            "prediction": label,
            "confidences": sorted_confidences
        })

    except Exception as e:
        print(f"❌ Prediction error: {e}", file=sys.stderr)
        # Prediction error action
        send_serial(lcd_message="Error!", voice_message="An error occurred during prediction.",
                    head_angle=90, head_hold_ms=2000,
                    handl_angle=45, handl_hold_ms=2000,
                    handr_angle=135, handr_hold_ms=2000)
        return jsonify({"error": str(e)}), 500
    finally:
        # Clean up uploaded files
        if os.path.exists(original_path):
            os.remove(original_path)
            # Temporary file cleaned action
            send_serial(lcd_message="File Cleaned", voice_message="Temporary file removed.",
                        head_angle=0, head_hold_ms=1000, # Use 0 for reset as per new format
                        handl_angle=0, handl_hold_ms=1000,
                        handr_angle=0, handr_hold_ms=1000)
        if ext == ".mp3" and os.path.exists(path) and path != original_path: # Remove converted WAV if applicable
            os.remove(path)
            # Converted WAV cleaned action
            send_serial(lcd_message="WAV Cleaned", voice_message="Converted WAV file removed.",
                        head_angle=0, head_hold_ms=1000, # Use 0 for reset as per new format
                        handl_angle=0, handl_hold_ms=1000,
                        handr_angle=0, handr_hold_ms=1000)

@app.route("/speak", methods=["POST"])
def speak_route():
    """API endpoint to trigger speech output."""
    data = request.get_json()
    message = data.get("message", "Hello from PneumoAI!")
    # The actual speak function itself calls send_serial, so no need for an extra send_serial here.
    print(f"Flask received request to speak: {message}")
    threading.Thread(target=speak, args=(message,)).start()
    return jsonify({"status": "speaking", "message": message})


@app.route("/servo_control", methods=["POST"])
def servo_control_route():
    """API endpoint to control servos."""
    data = request.get_json()
    head = data.get("head")
    handl = data.get("handl")
    handr = data.get("handr")
    head_hold = data.get("head_hold_ms")
    handl_hold = data.get("handl_hold_ms")
    handr_hold = data.get("handr_hold_ms")
    # Servo control action
    send_serial(lcd_message="Servo Cntrl", voice_message="Controlling servos.",
                head_angle=head, head_hold_ms=head_hold,
                handl_angle=handl, handl_hold_ms=handl_hold,
                handr_angle=handr, handr_hold_ms=handr_hold)
    return jsonify({"status": "servos controlled", "head": head, "handl": handl, "handr": handr})

@app.route("/reset_servos", methods=["POST"])
def reset_servos_route():
    """API endpoint to reset all servos to default positions."""
    # Servos reset action
    send_serial(lcd_message="Servos Reset", voice_message="Servos reset.",
                head_angle=0, head_hold_ms=1000, # Use 0 for reset as per new format
                handl_angle=0, handl_hold_ms=1000,
                handr_angle=0, handr_hold_ms=1000)
    return jsonify({"status": "servos reset to default"})

# --- Routes for specific UI actions (mapping to frontend buttons) ---
@app.route("/action/ui_loaded", methods=["POST"])
def action_ui_loaded():
    data = request.get_json()
    # UI loaded action
    send_serial(lcd_message=data.get("lcd_message"), voice_message=data.get("voice_message"),
                head_angle=data.get("head"), head_hold_ms=data.get("head_hold_ms"),
                handl_angle=data.get("handl"), handl_hold_ms=data.get("handl_hold_ms"),
                handr_angle=data.get("handr"), handr_hold_ms=data.get("handr_hold_ms"))
    return jsonify({"status": "success", "action": "ui_loaded"})

@app.route("/action/start_recording_clicked", methods=["POST"])
def action_start_recording_clicked():
    data = request.get_json()
    # Start recording button clicked action
    send_serial(lcd_message=data.get("lcd_message"), voice_message=data.get("voice_message"),
                head_angle=data.get("head"), head_hold_ms=data.get("head_hold_ms"),
                handl_angle=data.get("handl"), handl_hold_ms=data.get("handl_hold_ms"),
                handr_angle=data.get("handr"), handr_hold_ms=data.get("handr_hold_ms"))
    return jsonify({"status": "success", "action": "start_recording_clicked"})

@app.route("/action/stop_recording_clicked", methods=["POST"])
def action_stop_recording_clicked():
    data = request.get_json()
    # Stop recording button clicked action
    send_serial(lcd_message=data.get("lcd_message"), voice_message=data.get("voice_message"),
                head_angle=data.get("head"), head_hold_ms=data.get("head_hold_ms"),
                handl_angle=data.get("handl"), handl_hold_ms=data.get("handl_hold_ms"),
                handr_angle=data.get("handr"), handr_hold_ms=data.get("handr_hold_ms"))
    return jsonify({"status": "success", "action": "stop_recording_clicked"})

@app.route("/action/mic_access_error", methods=["POST"])
def action_mic_access_error():
    data = request.get_json()
    # Microphone access error action
    send_serial(lcd_message=data.get("lcd_message"), voice_message=data.get("voice_message"),
                head_angle=data.get("head"), head_hold_ms=data.get("head_hold_ms"),
                handl_angle=data.get("handl"), handl_hold_ms=data.get("handl_hold_ms"),
                handr_angle=data.get("handr"), handr_hold_ms=data.get("handr_hold_ms"))
    return jsonify({"status": "success", "action": "mic_access_error"})

@app.route("/action/file_input_changed", methods=["POST"])
def action_file_input_changed():
    data = request.get_json()
    # File input changed action
    send_serial(lcd_message=data.get("lcd_message"), voice_message=data.get("voice_message"),
                head_angle=data.get("head"), head_hold_ms=data.get("head_hold_ms"),
                handl_angle=data.get("handl"), handl_hold_ms=data.get("handl_hold_ms"),
                handr_angle=data.get("handr"), handr_hold_ms=data.get("handr_hold_ms"))
    return jsonify({"status": "success", "action": "file_input_changed"})

@app.route("/action/analyze_audio_button_clicked", methods=["POST"])
def action_analyze_audio_button_clicked():
    data = request.get_json()
    # Analyze audio button clicked action
    send_serial(lcd_message=data.get("lcd_message"), voice_message=data.get("voice_message"),
                head_angle=data.get("head"), head_hold_ms=data.get("head_hold_ms"),
                handl_angle=data.get("handl"), handl_hold_ms=data.get("handl_hold_ms"),
                handr_angle=data.get("handr"), handr_hold_ms=data.get("handr_hold_ms"))
    return jsonify({"status": "success", "action": "analyze_audio_button_clicked"})

@app.route("/action/no_file_for_analysis_alert", methods=["POST"])
def action_no_file_for_analysis_alert():
    data = request.get_json()
    # No file for analysis alert action
    send_serial(lcd_message=data.get("lcd_message"), voice_message=data.get("voice_message"),
                head_angle=data.get("head"), head_hold_ms=data.get("head_hold_ms"),
                handl_angle=data.get("handl"), handl_hold_ms=data.get("handl_hold_ms"),
                handr_angle=data.get("handr"), handr_hold_ms=data.get("handr_hold_ms"))
    return jsonify({"status": "success", "action": "no_file_for_analysis_alert"})

@app.route("/action/clear_results_clicked", methods=["POST"])
def action_clear_results_clicked():
    data = request.get_json()
    # Clear results button clicked action
    send_serial(lcd_message=data.get("lcd_message"), voice_message=data.get("voice_message"),
                head_angle=data.get("head"), head_hold_ms=data.get("head_hold_ms"),
                handl_angle=data.get("handl"), handl_hold_ms=data.get("handl_hold_ms"),
                handr_angle=data.get("handr"), handr_hold_ms=data.get("handr_hold_ms"))
    return jsonify({"status": "success", "action": "clear_results_clicked"})

@app.route("/action/network_error_frontend", methods=["POST"])
def action_network_error_frontend():
    data = request.get_json()
    # Frontend network error action
    send_serial(lcd_message=data.get("lcd_message"), voice_message=data.get("voice_message"),
                head_angle=data.get("head"), head_hold_ms=data.get("head_hold_ms"),
                handl_angle=data.get("handl"), handl_hold_ms=data.get("handl_hold_ms"),
                handr_angle=data.get("handr"), handr_hold_ms=data.get("handr_hold_ms"))
    return jsonify({"status": "success", "action": "network_error_frontend"})

@app.route("/action/simulated_prediction_result", methods=["POST"])
def action_simulated_prediction_result():
    """Triggers robot action based on a simulated prediction from frontend."""
    data = request.get_json()
    label = data.get("prediction", "unknown")
    
    # Re-use the prediction-based action logic
    lcd_msg = f"Sim Pred: {label}"
    voice_msg = f"Simulated prediction is {label}."

    if label == "normal":
        # Simulated normal prediction action
        send_serial(lcd_message=lcd_msg, voice_message=voice_msg + " All clear!",
                    head_angle=90, head_hold_ms=2500,
                    handl_angle=60, handl_hold_ms=2500,
                    handr_angle=120, handr_hold_ms=2500)
    elif label == "crackle":
        # Simulated crackle prediction action (hands out, head slightly down)
        send_serial(lcd_message=lcd_msg, voice_message=voice_msg + " Suggest further examination.",
                    head_angle=80, head_hold_ms=2000,
                    handl_angle=10, handl_hold_ms=2000,
                    handr_angle=170, handr_hold_ms=2000) # Right hand fully out
        # Simulated crackle prediction hand reset action
        send_serial(lcd_message="Hands Reset", voice_message="Hands reset.", # Optional LCD/voice for reset
                    head_angle=0, head_hold_ms=1000, # Use 0 for reset as per new format
                    handl_angle=0, handl_hold_ms=1000,
                    handr_angle=0, handr_hold_ms=1000)
    elif label == "wheeze":
        # Simulated wheeze prediction action (head turn, hands slightly in)
        send_serial(lcd_message=lcd_msg, voice_message=voice_msg + " Consider checking airways.",
                    head_angle=120, head_hold_ms=2000,
                    handl_angle=30, handl_hold_ms=2000,
                    handr_angle=150, handr_hold_ms=2000)
        # Simulated wheeze prediction head reset action
        send_serial(lcd_message="Head Reset", voice_message="Head reset.", # Optional LCD/voice for reset
                    head_angle=0, head_hold_ms=1000, # Use 0 for reset as per new format
                    handl_angle=0, handl_hold_ms=1000,
                    handr_angle=0, handr_hold_ms=1000)
    elif label == "both": # Assuming 'both' means crackle and wheeze
        # Simulated both prediction action (hands out wide, head shaking)
        send_serial(lcd_message=lcd_msg, voice_message=voice_msg + " Significant findings detected.",
                    head_angle=70, head_hold_ms=2500,
                    handl_angle=0, handl_hold_ms=2500,
                    handr_angle=180, handr_hold_ms=2500) # Right hand fully out
            # Simulated both prediction head reset action (quick shake then center)
        send_serial(lcd_message="Resetting", voice_message="Resetting position.",
                    head_angle=110, head_hold_ms=500,
                    handl_angle=0, handl_hold_ms=500, # Use 0 for reset as per new format
                    handr_angle=0, handr_hold_ms=500)
        send_serial(lcd_message="Resetting", voice_message="Resetting position.",
                    head_angle=0, head_hold_ms=1000, # Use 0 for reset as per new format
                    handl_angle=0, handl_hold_ms=1000,
                    handr_angle=0, handr_hold_ms=1000)
    else: # Default action for other labels
        # Simulated other prediction action
        send_serial(lcd_message=lcd_msg, voice_message=voice_msg,
                    head_angle=90, head_hold_ms=2000,
                    handl_angle=45, handl_hold_ms=2000,
                    handr_angle=135, handr_hold_ms=2000)

    return jsonify({"status": "success", "action": "simulated_prediction_result", "prediction": label})
# --- End of routes ---


@app.route("/shutdown", methods=["POST"])
def shutdown():
    """Shuts down the Flask server."""
    func = request.environ.get('werkzeug.server.shutdown')
    if func is None:
        raise RuntimeError('Not running with the Werkzeug Server')
    func()
    # Application shutdown action
    send_serial(lcd_message="Shutting Down", voice_message="Application is shutting down.",
                head_angle=0, head_hold_ms=1000, # Use 0 for reset as per new format
                handl_angle=0, handl_hold_ms=1000,
                handr_angle=0, handr_hold_ms=1000)
    print("✅ Flask server shutting down...")
    serial_comm.close() # Close serial port on shutdown
    return "Server shutting down..."

@app.route("/restart", methods=["POST"])
def restart():
    """Restarts the application (Flask server and Pywebview)."""
    # Application restart action
    send_serial(lcd_message="Restarting...", voice_message="Restarting application.",
                head_angle=0, head_hold_ms=1000, # Use 0 for reset as per new format
                handl_angle=0, handl_hold_ms=1000,
                handr_angle=0, handr_hold_ms=1000)
    print("🔄 Restarting application...")
    serial_comm.close() # Close serial port before restarting
    # This will restart the entire Python process
    python = sys.executable
    os.execl(python, python, *sys.argv)
    return "Restarting..."


if __name__ == "__main__":
    # This block is typically run when app.py is executed directly for testing
    # In the GUI setup, gui.py will run app.run()
    app.run(debug=True, port=5000)
