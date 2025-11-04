import 'package:flutter/material.dart';
import 'tts_manager.dart'; // ✅ IMPORT TTS MANAGER
import 'live_recording.dart';
import 'stethoscope_upload.dart';

class StethoscopeMainPage extends StatefulWidget {
  const StethoscopeMainPage({super.key});

  @override
  _StethoscopeMainPageState createState() => _StethoscopeMainPageState();
}

class _StethoscopeMainPageState extends State<StethoscopeMainPage> {
  // ✅ REPLACED: Using TtsManager instead of FlutterTts
  final TtsManager _tts = TtsManager();

  @override
  void initState() {
    super.initState();
    _initTtsAndSpeak();
  }

  // ✅ UPDATED: Initialize TtsManager and speak welcome message
  Future<void> _initTtsAndSpeak() async {
    try {
      await _tts.initialize();

      // Listen to TTS state changes to update UI
      _tts.addListener(() {
        if (mounted) setState(() {});
      });

      await Future.delayed(const Duration(milliseconds: 300));
      await _tts.speak(
        "Choose how to analyze your lung sounds. You can upload an audio file or record live",
      );
    } catch (e) {
      debugPrint("❌ TTS initialization error: $e");
    }
  }

  // ✅ Handle button navigation with TTS feedback
  void _navigateToUpload() {
    _tts.speak("Upload lung sounds");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StethoscopeUploadPage()),
    );
  }

  void _navigateToRecording() {
    _tts.speak("Record live audio");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LiveRecordingPage()),
    );
  }

  @override
  void dispose() {
    _tts.stop(); // ✅ UPDATED: Use TtsManager stop
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 Color options
    const mainTextColor = Color(0xFF0d3b66);
    const buttonColor = Color(0xFF4B0082); // dark purple
    const buttonTextColor = Colors.white;

    // 🖼 Image sizes & positions
    const lungsWidth = 120.0;
    const lungsHeight = 160.0;
    const lungsLeft = 0.0;
    const lungsTop = 0.0;

    const titleFontSize = 60.0;
    const titleLeft = 180.0;
    const titleTop = 30.0;

    const stethoscopeWidth = 430.0;
    const stethoscopeHeight = 600.0;
    const stethoscopeLeft = 50.0;
    const stethoscopeTop = 170.0;

    // 🔧 Buttons
    const buttonWidth = 600.0;
    const buttonHeight = 180.0;
    const buttonBorderRadius = 90.0;
    const iconSize = 130.0;
    const iconTextSpacing = 20.0;

    const btn1Left = 650.0;
    const btn1Top = 220.0;

    const btn2Left = 650.0;
    const btn2Top = 500.0;

    return Scaffold(
      body: Stack(
        children: [
          // 🌄 Full background image
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.cover),
          ),

          // Top-left lungs_ai.png image
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
              "Analyze Your Lung Sounds With AI",
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: mainTextColor,
              ),
            ),
          ),

          // Central stethoscope image
          Positioned(
            left: stethoscopeLeft,
            top: stethoscopeTop,
            width: stethoscopeWidth,
            height: stethoscopeHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.asset(
                'assets/stethoscope_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Button 1: Upload Your Lung Sounds
          Positioned(
            left: btn1Left,
            top: btn1Top,
            child: SizedBox(
              width: buttonWidth,
              height: buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(buttonBorderRadius),
                  ),
                  elevation: 6,
                ),
                onPressed: _navigateToUpload,
                child: Row(
                  children: [
                    SizedBox(width: 20),
                    SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: Image.asset('assets/upload_icon.png'),
                    ),
                    SizedBox(width: iconTextSpacing),
                    Expanded(
                      child: Text(
                        "Upload Your Lung Sounds for AI Analyzation",
                        style: TextStyle(
                          fontSize: 32,
                          color: buttonTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Button 2: Record Audio For Live AI Analyzation
          Positioned(
            left: btn2Left,
            top: btn2Top,
            child: SizedBox(
              width: buttonWidth,
              height: buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(buttonBorderRadius),
                  ),
                  elevation: 6,
                ),
                onPressed: _navigateToRecording,
                child: Row(
                  children: [
                    SizedBox(width: 20),
                    SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: Image.asset('assets/record_icon.png'),
                    ),
                    SizedBox(width: iconTextSpacing),
                    Expanded(
                      child: Text(
                        "Record Audio For Live AI Analyzation",
                        style: TextStyle(
                          fontSize: 32,
                          color: buttonTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ✅ UPDATED: Speaking indicator using TtsManager
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
