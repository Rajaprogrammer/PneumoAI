import 'package:flutter/material.dart';
import 'tts_manager.dart'; // ✅ REPLACED WITH TTS MANAGER

class LiveRecordingPage extends StatefulWidget {
  const LiveRecordingPage({super.key});

  @override
  _LiveRecordingPageState createState() => _LiveRecordingPageState();
}

class _LiveRecordingPageState extends State<LiveRecordingPage> {
  // ✅ REPLACED: Using TtsManager instead of FlutterTts
  final TtsManager _tts = TtsManager();

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  // ✅ Initialize TtsManager
  Future<void> _initTts() async {
    try {
      await _tts.initialize();

      // Listen to TTS state changes to update UI
      _tts.addListener(() {
        if (mounted) setState(() {});
      });

      // ✅ Speak welcome message
      await Future.delayed(const Duration(milliseconds: 300));
      await _speak(
        "Tap start recording to record your lung sounds for AI analysis",
      );
    } catch (e) {
      debugPrint("❌ TTS error: $e");
    }
  }

  // ✅ Speak text with TtsManager
  Future<void> _speak(String text) async {
    try {
      if (_tts.isSpeaking) {
        await _tts.stop();
      }
      debugPrint("🔊 Speaking: $text");
      await _tts.speak(text);
    } catch (e) {
      debugPrint("❌ TTS speak error: $e");
    }
  }

  @override
  void dispose() {
    _tts.stop(); // ✅ STOP TTS WHEN PAGE DISPOSES
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 Color options
    const backgroundColor = Colors.white;
    const mainTextColor = Color(0xFF0d3b66);
    const buttonColor = Color(0xFF4B0082); // dark purple
    const buttonTextColor = Colors.white;

    // 🖼 Top-left lungs_ai.png
    const lungsWidth = 120.0;
    const lungsHeight = 160.0;
    const lungsLeft = 0.0;
    const lungsTop = 0.0;

    const titleFontSize = 60.0;
    const titleLeft = 180.0;
    const titleTop = 30.0;

    // 🖼 Lung illustration
    const lungWidth = 800.0;
    const lungHeight = 700.0;
    const lungLeft = -140.0;
    const lungTop = 130.0;

    // 🔘 Recording button
    const buttonWidth = 500.0;
    const buttonHeight = 500.0;
    const buttonBorderRadius = 100.0;

    // 🎤 Microphone inside button
    const micWidth = 250.0;
    const micHeight = 250.0;
    const micLeft = 90.0; // relative to button
    const micTop = 90.0;

    const buttonTextFontSize = 50.0;
    const buttonTextLeft = 55.0; // relative to button
    const buttonTextTop = 380.0;

    const buttonLeft = 700.0;
    const buttonTop = 220.0;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // 🌄 Full background
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.cover),
          ),

          // Top-left lungs_ai.png
          Positioned(
            left: lungsLeft,
            top: lungsTop,
            width: lungsWidth,
            height: lungsHeight,
            child: Image.asset('assets/lungs_ai.png', fit: BoxFit.contain),
          ),

          // Title text
          Positioned(
            left: titleLeft,
            top: titleTop,
            child: Text(
              "Record Your Lung Sounds With AI",
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: mainTextColor,
              ),
            ),
          ),

          // Lung illustration image
          Positioned(
            left: lungLeft,
            top: lungTop,
            width: lungWidth,
            height: lungHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.asset('assets/lungs_icon.png', fit: BoxFit.cover),
            ),
          ),

          // Recording button
          Positioned(
            left: buttonLeft,
            top: buttonTop,
            width: buttonWidth,
            height: buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(buttonBorderRadius),
                ),
                elevation: 8,
              ),
              onPressed: () {
                // ✅ Speak before navigating
                _speak("Starting live recording");

                Navigator.pushNamed(context, '/loadingStethoscope');
              },
              child: Stack(
                children: [
                  // Microphone icon
                  Positioned(
                    left: micLeft,
                    top: micTop,
                    width: micWidth,
                    height: micHeight,
                    child: Image.asset(
                      'assets/record_icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  // Start Recording text
                  Positioned(
                    left: buttonTextLeft,
                    top: buttonTextTop,
                    child: Text(
                      "Start Recording",
                      style: TextStyle(
                        fontSize: buttonTextFontSize,
                        fontWeight: FontWeight.bold,
                        color: buttonTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ✅ ADD: Speaking indicator
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
        ],
      ),
    );
  }
}
