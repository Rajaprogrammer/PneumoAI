// lib/stethoscope_upload.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'dart:math';
import 'stethoscope_upload_loading.dart';
import 'tts_manager.dart';
import 'arduino_service.dart'; // ✅ NEW: Import Arduino Service

class StethoscopeUploadPage extends StatefulWidget {
  const StethoscopeUploadPage({super.key});

  @override
  _StethoscopeUploadPageState createState() => _StethoscopeUploadPageState();
}

class _StethoscopeUploadPageState extends State<StethoscopeUploadPage> {
  String? _uploadedFileName;
  String? _uploadedFilePath;
  bool _showError = false;
  final _random = Random();

  final TtsManager _tts = TtsManager();
  final ArduinoService _arduino = ArduinoService(); // ✅ NEW: Arduino Service

  // ✅ Responsive mode tracking
  int _tapCount = 0;
  bool _responsiveMode = false;
  Timer? _tapResetTimer;

  // ✅ Reference screen size (Lenovo Yoga Tab 11: 2000 x 1200)
  static const double _referenceWidth = 2000.0;
  static const double _referenceHeight = 1200.0;

  @override
  void initState() {
    super.initState();
    _initTtsAndSpeak();
    _initArduino(); // ✅ NEW: Initialize Arduino
  }

  // ✅ NEW: Initialize Arduino on page load
  Future<void> _initArduino() async {
    await Future.delayed(const Duration(milliseconds: 200));

    // Update LCD
    await _arduino.updateLCD('Lung Sound', 'Upload Ready');

    // Bot gesture: Listening pose
    await _arduino.setBotPosition(head: 10, handL: 50, handR: 50);

    await Future.delayed(const Duration(milliseconds: 1000));
    await _arduino.gestureReset();
  }

  Future<void> _initTtsAndSpeak() async {
    await _tts.initialize();

    _tts.addListener(() {
      if (mounted) setState(() {});
    });

    await Future.delayed(const Duration(milliseconds: 300));
    await _tts.speak("Upload your lung sounds for AI analysis");
  }

  // ✅ UPDATED: Upload with Arduino feedback
  Future<void> _uploadFile() async {
    try {
      // LCD: Waiting for file selection
      await _arduino.updateLCD('Select Audio', 'File...');

      // Bot: Attentive gesture
      await _arduino.setBotPosition(head: 15, handL: 60, handR: 0);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _uploadedFileName = result.files.single.name;
          _uploadedFilePath = result.files.single.path;
        });

        debugPrint("Selected file: $_uploadedFileName");
        debugPrint("Full path: $_uploadedFilePath");

        // ✅ LCD: File uploaded
        await _arduino.updateLCD('Audio Uploaded', 'Successfully!');

        // ✅ Bot: Success - right hand up
        await _arduino.setBotPosition(head: 0, handL: 0, handR: 90);

        await Future.delayed(const Duration(milliseconds: 800));
        await _arduino.gestureReset();

        await _tts.speak(
          "Audio file uploaded successfully. You can now proceed to AI analysis",
        );

        // Update LCD after speech
        await Future.delayed(const Duration(seconds: 2));
        await _arduino.updateLCD('Audio Ready', 'Tap Analyze');
      } else {
        // User cancelled
        await _arduino.updateLCD('Upload', 'Cancelled');
        await _arduino.gestureReset();

        await Future.delayed(const Duration(seconds: 1));
        await _arduino.updateLCD('Lung Sound', 'Upload Ready');
      }
    } catch (e) {
      debugPrint("File picker error: $e");

      // ✅ LCD: Error
      await _arduino.updateLCD('Upload Error', 'Try Again');
      await _arduino.setBotPosition(head: -30, handL: 0, handR: 0);

      await Future.delayed(const Duration(seconds: 1));
      await _arduino.updateLCD('Lung Sound', 'Upload Ready');
      await _arduino.gestureReset();
    }
  }

  // ✅ UPDATED: Error with Arduino feedback
  void _showTransientError() async {
    setState(() => _showError = true);

    // ✅ LCD: Error message
    await _arduino.updateLCD('ERROR!', 'Upload Audio');

    // ✅ Bot: Shake head (disapproval)
    await _arduino.setBotPosition(head: -40, handL: 0, handR: 0);
    await Future.delayed(const Duration(milliseconds: 250));
    await _arduino.setBotPosition(head: 40);
    await Future.delayed(const Duration(milliseconds: 250));
    await _arduino.setBotPosition(head: 0);

    _tts.speak("Please upload a lung sound audio file first");

    Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _showError = false);
        _arduino.updateLCD('Lung Sound', 'Upload Ready');
      }
    });
  }

  // ✅ UPDATED: Analysis with Arduino feedback
  void _startAnalysisByHalfTap(bool leftHalf) async {
    if (_uploadedFilePath == null) {
      _showTransientError();
      return;
    }

    // ✅ LCD: Starting analysis
    await _arduino.updateLCD('Analyzing', 'Lung Sounds...');

    // ✅ Bot: Processing gesture (both hands mid-height)
    await _arduino.setBotPosition(head: 20, handL: 75, handR: 75);

    await Future.delayed(const Duration(milliseconds: 600));
    await _arduino.gestureReset();

    _tts.speak("Starting AI analysis of your lung sounds");

    // Small delay for effect
    await Future.delayed(const Duration(milliseconds: 400));

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StethoscopeUploadLoadingPage(
          chosenSide: 'prediction',
          seedRandom: _random.nextInt(100000),
          uploadedFilePath: _uploadedFilePath!,
          uploadedFileName: _uploadedFileName!,
        ),
      ),
    );
  }

  // ✅ Handle tap for responsive mode toggle
  void _handleTap() {
    _tapResetTimer?.cancel();

    setState(() {
      _tapCount++;

      if (_tapCount >= 15) {
        _responsiveMode = !_responsiveMode;
        _tapCount = 0;

        _tts.speak(
          _responsiveMode
              ? 'Responsive mode enabled'
              : 'Responsive mode disabled',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _responsiveMode
                  ? '✅ Responsive mode ENABLED'
                  : '❌ Responsive mode DISABLED',
            ),
            duration: Duration(seconds: 1),
            backgroundColor: _responsiveMode ? Colors.green : Colors.orange,
          ),
        );
      }
    });

    // Reset tap count after 2 seconds of inactivity
    _tapResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _tapCount = 0);
      }
    });
  }

  // ✅ Calculate scaled value based on screen size
  double _scale(
    double value,
    double screenDimension,
    double referenceDimension,
  ) {
    if (!_responsiveMode) return value;
    return value * (screenDimension / referenceDimension);
  }

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    _tts.stop();
    _arduino.gestureReset(); // ✅ NEW: Reset bot on exit
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Get current screen size
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Layout constants (hardcoded for Lenovo Yoga Tab 11: 2000x1200)
    const lungsWidth = 120.0;
    const lungsHeight = 160.0;
    const lungsLeft = 0.0;
    const lungsTop = 0.0;

    const titleFontSize = 60.0;
    const titleLeft = 180.0;
    const titleTop = 30.0;
    const titleColor = Color(0xFF0d3b66);

    const stethoscopeWidth = 430.0;
    const stethoscopeHeight = 600.0;
    const stethoscopeLeft = 50.0;
    const stethoscopeTop = 180.0;
    const stethoscopeBorderRadius = 40.0;

    const buttonWidth = 600.0;
    const buttonHeight = 180.0;
    const buttonBorderRadius = 90.0;
    const buttonColor = Color(0xFF4B0082);
    const buttonTextColor = Colors.white;
    const buttonTextSize = 32.0;
    const iconSize = 130.0;
    const iconTextSpacing = 24.0;

    const btn1Left = 650.0;
    const btn1Top = 220.0;

    const uploadedTextLeft = 650.0;
    const uploadedTextTop = 460.0;
    const uploadedTextSize = 32.0;
    const uploadedTextColor = Colors.black87;

    const btn2Left = 650.0;
    const btn2Top = 500.0;

    return Scaffold(
      body: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Image.asset('assets/background.png', fit: BoxFit.cover),
            ),

            // Error overlay
            if (_showError)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: _showError ? 50 : 0,
                  color: Colors.red.withOpacity(0.7),
                  alignment: Alignment.center,
                  child: const Text(
                    'No file uploaded!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Lungs logo
            Positioned(
              left: _scale(lungsLeft, screenWidth, _referenceWidth),
              top: _scale(lungsTop, screenHeight, _referenceHeight),
              width: _scale(lungsWidth, screenWidth, _referenceWidth),
              height: _scale(lungsHeight, screenHeight, _referenceHeight),
              child: Image.asset('assets/lungs_ai.png', fit: BoxFit.contain),
            ),

            // Title
            Positioned(
              left: _scale(titleLeft, screenWidth, _referenceWidth),
              top: _scale(titleTop, screenHeight, _referenceHeight),
              child: Text(
                "Analyze Your Lung Sounds With AI",
                style: TextStyle(
                  fontSize: _scale(titleFontSize, screenWidth, _referenceWidth),
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
            ),

            // Main stethoscope placeholder
            Positioned(
              left: _scale(stethoscopeLeft, screenWidth, _referenceWidth),
              top: _scale(stethoscopeTop, screenHeight, _referenceHeight),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  _scale(stethoscopeBorderRadius, screenWidth, _referenceWidth),
                ),
                child: SizedBox(
                  width: _scale(stethoscopeWidth, screenWidth, _referenceWidth),
                  height: _scale(
                    stethoscopeHeight,
                    screenHeight,
                    _referenceHeight,
                  ),
                  child: Image.asset(
                    'assets/stethoscope_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            // Upload button
            Positioned(
              left: _scale(btn1Left, screenWidth, _referenceWidth),
              top: _scale(btn1Top, screenHeight, _referenceHeight),
              child: SizedBox(
                width: _scale(buttonWidth, screenWidth, _referenceWidth),
                height: _scale(buttonHeight, screenHeight, _referenceHeight),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        _scale(
                          buttonBorderRadius,
                          screenWidth,
                          _referenceWidth,
                        ),
                      ),
                    ),
                    elevation: 8,
                  ),
                  onPressed: _uploadFile,
                  child: Row(
                    children: [
                      SizedBox(
                        width: _scale(iconSize, screenWidth, _referenceWidth),
                        height: _scale(iconSize, screenWidth, _referenceWidth),
                        child: Image.asset('assets/upload_icon.png'),
                      ),
                      SizedBox(
                        width: _scale(
                          iconTextSpacing,
                          screenWidth,
                          _referenceWidth,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Upload Your Lung Sounds for AI Analysis",
                          style: TextStyle(
                            fontSize: _scale(
                              buttonTextSize,
                              screenWidth,
                              _referenceWidth,
                            ),
                            fontWeight: FontWeight.bold,
                            color: buttonTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Uploaded file text
            Positioned(
              left: _scale(uploadedTextLeft, screenWidth, _referenceWidth),
              top: _scale(uploadedTextTop, screenHeight, _referenceHeight),
              child: Text(
                "Uploaded File: ${_uploadedFileName ?? 'None'}",
                style: TextStyle(
                  fontSize: _scale(
                    uploadedTextSize,
                    screenWidth,
                    _referenceWidth,
                  ),
                  color: uploadedTextColor,
                ),
              ),
            ),

            // Analyze button
            Positioned(
              left: _scale(btn2Left, screenWidth, _referenceWidth),
              top: _scale(btn2Top, screenHeight, _referenceHeight),
              child: SizedBox(
                width: _scale(buttonWidth, screenWidth, _referenceWidth),
                height: _scale(buttonHeight, screenHeight, _referenceHeight),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final dx = details.localPosition.dx;
                    if (_uploadedFilePath == null) {
                      _showTransientError();
                      return;
                    }
                    final scaledButtonWidth = _scale(
                      buttonWidth,
                      screenWidth,
                      _referenceWidth,
                    );
                    if (dx < scaledButtonWidth / 2) {
                      _startAnalysisByHalfTap(true);
                    } else {
                      _startAnalysisByHalfTap(false);
                    }
                  },
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          _scale(
                            buttonBorderRadius,
                            screenWidth,
                            _referenceWidth,
                          ),
                        ),
                      ),
                      elevation: 8,
                    ),
                    onPressed: () {
                      if (_uploadedFilePath == null) {
                        _showTransientError();
                        return;
                      }
                      _startAnalysisByHalfTap(true);
                    },
                    child: Row(
                      children: [
                        SizedBox(
                          width: _scale(iconSize, screenWidth, _referenceWidth),
                          height: _scale(
                            iconSize,
                            screenWidth,
                            _referenceWidth,
                          ),
                          child: Image.asset('assets/ai_icon.png'),
                        ),
                        SizedBox(
                          width: _scale(
                            iconTextSpacing,
                            screenWidth,
                            _referenceWidth,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "Proceed To AI Analyzation",
                            style: TextStyle(
                              fontSize: _scale(
                                buttonTextSize,
                                screenWidth,
                                _referenceWidth,
                              ),
                              fontWeight: FontWeight.bold,
                              color: buttonTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ✅ Speaking indicator using TTS Manager
            if (_tts.isSpeaking)
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade400.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.volume_up, color: Colors.white, size: 16),
                      SizedBox(width: 5),
                      Text(
                        'Speaking',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ✅ Tap counter indicator (appears while tapping)
            if (_tapCount > 0)
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Taps: $_tapCount/15 ${_responsiveMode ? "(Responsive ON)" : ""}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
