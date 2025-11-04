import 'package:flutter/material.dart';
import 'tts_manager.dart';
import 'arduino_service.dart'; // ✅ IMPORT ARDUINO
import 'scale.dart';
import 'xray_upload.dart';
import 'xray_picture.dart';

class ChestXRayPage extends StatefulWidget {
  const ChestXRayPage({super.key});

  @override
  _ChestXRayPageState createState() => _ChestXRayPageState();
}

class _ChestXRayPageState extends State<ChestXRayPage> {
  final TtsManager _tts = TtsManager();
  final ArduinoService _arduino = ArduinoService(); // ✅ ARDUINO

  @override
  void initState() {
    super.initState();
    _initTts();
    _initArduino(); // ✅ ARDUINO INIT
  }

  // ✅ ARDUINO INITIALIZATION
  Future<void> _initArduino() async {
    await Future.delayed(const Duration(milliseconds: 200));

    // Update LCD
    await _arduino.updateLCD('X-Ray Mode', 'Select Option');

    // Bot: Presenting options gesture (both hands partially raised)
    await _arduino.setBotPosition(head: 0, handL: 60, handR: 60);

    await Future.delayed(const Duration(milliseconds: 1200));
    await _arduino.gestureReset();
  }

  Future<void> _initTts() async {
    try {
      await _tts.initialize();

      _tts.addListener(() {
        if (mounted) setState(() {});
      });

      await Future.delayed(const Duration(milliseconds: 300));
      await _speak(
        "Choose how to analyze your chest X-ray. You can upload an image or take a picture",
      );
    } catch (e) {
      debugPrint("❌ TTS error: $e");
    }
  }

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
    _tts.stop();
    _arduino.gestureReset(); // ✅ ARDUINO CLEANUP
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Screen-specific constants
    const lungsWidth = 120.0;
    const lungsHeight = 160.0;
    const lungsLeft = 0.0;
    const lungsTop = 0.0;

    const titleFontSize = 60.0;
    const titleLeft = 180.0;
    const titleTop = 30.0;
    const titleColor = Color(0xFF0d3b66);

    const xrayWidth = 400.0;
    const xrayHeight = 500.0;
    const xrayLeft = 50.0;
    const xrayTop = 200.0;
    const xrayBorderRadius = 40.0;

    const buttonWidth = 600.0;
    const buttonHeight = 180.0;
    const buttonBorderRadius = 90.0;
    const buttonBackgroundColor = Color(0xFF4B0082);
    const buttonTextSize = 32.0;
    const buttonTextColor = Colors.white;
    const iconSize = 130.0;
    const iconTextSpacing = 24.0;

    const btn1Left = 650.0;
    const btn1Top = 220.0;
    const btn1Icon = 'assets/upload_icon.png';
    const btn1Text = "Upload Your Chest X-Ray for AI Analyzation";

    const btn2Left = 650.0;
    const btn2Top = 500.0;
    const btn2Icon = 'assets/camera_icon.png';
    const btn2Text = "Take a Picture Of Your Chest X-Ray";

    return Scaffold(
      body: Stack(
        children: [
          // Full background image
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.cover),
          ),

          // Lungs AI image (top-left)
          Positioned(
            left: S.w(context, lungsLeft),
            top: S.h(context, lungsTop),
            child: SizedBox(
              width: S.w(context, lungsWidth),
              height: S.h(context, lungsHeight),
              child: Image.asset('assets/lungs_ai.png', fit: BoxFit.contain),
            ),
          ),

          // Title text
          Positioned(
            left: S.w(context, titleLeft),
            top: S.h(context, titleTop),
            child: Text(
              "Analyze Your Chest X-Ray With AI",
              style: TextStyle(
                fontSize: S.fs(context, titleFontSize),
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ),

          // Main X-ray image
          Positioned(
            left: S.w(context, xrayLeft),
            top: S.h(context, xrayTop),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                S.w(context, xrayBorderRadius),
              ),
              child: SizedBox(
                width: S.w(context, xrayWidth),
                height: S.h(context, xrayHeight),
                child: Image.asset('assets/xray_icon.png', fit: BoxFit.cover),
              ),
            ),
          ),

          // Button 1: Upload
          Positioned(
            left: S.w(context, btn1Left),
            top: S.h(context, btn1Top),
            child: SizedBox(
              width: S.w(context, buttonWidth),
              height: S.h(context, buttonHeight),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonBackgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      S.w(context, buttonBorderRadius),
                    ),
                  ),
                  elevation: 8,
                ),
                onPressed: () async {
                  // ✅ ARDUINO: Upload selected
                  await _arduino.updateLCD('Upload Mode', 'Selected');

                  // ✅ Bot: Point to upload option (left)
                  await _arduino.setBotPosition(head: -30, handL: 90, handR: 0);

                  await Future.delayed(const Duration(milliseconds: 600));

                  _speak("Upload chest X-ray");

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const XRayUploadPage(),
                    ),
                  );
                },
                child: Row(
                  children: [
                    SizedBox(
                      width: S.w(context, iconSize),
                      height: S.h(context, iconSize),
                      child: Image.asset(btn1Icon),
                    ),
                    SizedBox(width: S.w(context, iconTextSpacing)),
                    Expanded(
                      child: Text(
                        btn1Text,
                        style: TextStyle(
                          fontSize: S.fs(context, buttonTextSize),
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

          // Button 2: Take Picture
          Positioned(
            left: S.w(context, btn2Left),
            top: S.h(context, btn2Top),
            child: SizedBox(
              width: S.w(context, buttonWidth),
              height: S.h(context, buttonHeight),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonBackgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      S.w(context, buttonBorderRadius),
                    ),
                  ),
                  elevation: 8,
                ),
                onPressed: () async {
                  // ✅ ARDUINO: Picture mode selected
                  await _arduino.updateLCD('Camera Mode', 'Selected');

                  // ✅ Bot: Point to picture option (right)
                  await _arduino.setBotPosition(head: 30, handL: 0, handR: 90);

                  await Future.delayed(const Duration(milliseconds: 600));

                  _speak("Take a picture of chest X-ray");

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const XRayPicturePage(),
                    ),
                  );
                },
                child: Row(
                  children: [
                    SizedBox(
                      width: S.w(context, iconSize),
                      height: S.h(context, iconSize),
                      child: Image.asset(btn2Icon),
                    ),
                    SizedBox(width: S.w(context, iconTextSpacing)),
                    Expanded(
                      child: Text(
                        btn2Text,
                        style: TextStyle(
                          fontSize: S.fs(context, buttonTextSize),
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

          // Speaking indicator
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
