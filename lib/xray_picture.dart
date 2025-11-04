// lib/xray_picture.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'loading_xray.dart';
import 'scale.dart';
import 'tts_manager.dart';
import 'arduino_service.dart'; // ✅ NEW: Import Arduino Service

class XRayPicturePage extends StatefulWidget {
  const XRayPicturePage({super.key});

  @override
  _XRayPicturePageState createState() => _XRayPicturePageState();
}

class _XRayPicturePageState extends State<XRayPicturePage> {
  String? _takenPictureName;
  String? _takenPicturePath;
  bool _showError = false;

  final ImagePicker _picker = ImagePicker();
  final TtsManager _tts = TtsManager();
  final ArduinoService _arduino = ArduinoService(); // ✅ NEW: Arduino Service

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
    await _arduino.updateLCD('Camera Mode', 'Ready');

    // Bot points to camera icon
    await _arduino.setBotPosition(head: 15, handL: 70, handR: 0);

    await Future.delayed(const Duration(milliseconds: 1000));
    await _arduino.gestureReset();
  }

  Future<void> _initTtsAndSpeak() async {
    await _tts.initialize();

    _tts.addListener(() {
      if (mounted) setState(() {});
    });

    await Future.delayed(const Duration(milliseconds: 300));
    await _tts.speak("Take a picture of your chest X-ray for AI analysis");
  }

  @override
  void dispose() {
    _tts.stop();
    _arduino.gestureReset(); // ✅ NEW: Reset bot on exit
    super.dispose();
  }

  // ✅ UPDATED: Camera Capture with Arduino feedback
  Future<void> _takePicture() async {
    try {
      // LCD: Opening camera
      await _arduino.updateLCD('Opening', 'Camera...');

      // Bot: Ready to photograph gesture
      await _arduino.setBotPosition(head: 0, handL: 45, handR: 45);

      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        setState(() {
          _takenPictureName = photo.name;
          _takenPicturePath = photo.path;
        });

        // ✅ LCD: Picture captured
        await _arduino.updateLCD('Photo Captured', 'Successfully!');

        // ✅ Bot: Success celebration
        await _arduino.setBotPosition(head: 0, handL: 90, handR: 90);

        await Future.delayed(const Duration(milliseconds: 1000));
        await _arduino.gestureReset();

        await _tts.speak(
          "Picture captured successfully. You can now proceed to AI analysis",
        );

        // Update LCD after speech
        await Future.delayed(const Duration(seconds: 2));
        await _arduino.updateLCD('Photo Ready', 'Tap Analyze');
      } else {
        // User cancelled camera
        await _arduino.updateLCD('Camera', 'Cancelled');
        await _arduino.gestureReset();

        await Future.delayed(const Duration(seconds: 1));
        await _arduino.updateLCD('Camera Mode', 'Ready');
      }
    } on PlatformException catch (e) {
      debugPrint("Camera error: $e");

      // ✅ LCD: Camera error
      await _arduino.updateLCD('Camera Error', 'Check Permissions');

      // ✅ Bot: Concerned gesture
      await _arduino.setBotPosition(head: -35, handL: 0, handR: 0);

      await _tts.speak("Failed to open camera. Please check permissions");

      await Future.delayed(const Duration(seconds: 2));
      await _arduino.updateLCD('Camera Mode', 'Ready');
      await _arduino.gestureReset();
    }
  }

  // ✅ UPDATED: Navigate to Loading + Analysis with Arduino feedback
  void _analyzePicture(String resultType) async {
    if (_takenPictureName == null || _takenPicturePath == null) {
      setState(() {
        _showError = true;
      });

      // ✅ LCD: Error - No picture
      await _arduino.updateLCD('ERROR!', 'Take Photo First');

      // ✅ Bot: Shake head gesture (disapproval)
      await _arduino.setBotPosition(head: -45, handL: 0, handR: 0);
      await Future.delayed(const Duration(milliseconds: 300));
      await _arduino.setBotPosition(head: 45);
      await Future.delayed(const Duration(milliseconds: 300));
      await _arduino.setBotPosition(head: 0);

      _tts.speak("Please take a picture of your chest X-ray first");

      Timer(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _showError = false;
          });
          _arduino.updateLCD('Camera Mode', 'Ready');
        }
      });
      return;
    }

    // ✅ LCD: Starting analysis
    await _arduino.updateLCD('Analyzing', 'X-Ray Photo...');

    // ✅ Bot: Processing gesture
    await _arduino.setBotPosition(head: 25, handL: 80, handR: 80);

    await Future.delayed(const Duration(milliseconds: 700));
    await _arduino.gestureReset();

    _tts.speak("Starting AI analysis of your chest X-ray");

    // Small delay for effect
    await Future.delayed(const Duration(milliseconds: 400));

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LoadingXRayPage(
          resultType: resultType,
          uploadedFileName: _takenPicturePath!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- Layout constants ---
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
    const btn1Icon = 'assets/camera_icon.png';
    const btn1Text = "Take a Picture of Your Chest X-Ray for AI Analyzation";

    const takenTextLeft = 650.0;
    const takenTextTop = 460.0;
    const takenTextSize = 32.0;
    const takenTextColor = Colors.black87;

    const btn2Left = 650.0;
    const btn2Top = 500.0;
    const btn2Icon = 'assets/ai_icon.png';
    const btn2Text = "Proceed To AI Analyzation";

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.cover),
          ),

          // 🔴 Error message
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
                  'No picture taken!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // 🫁 Top-left lungs logo
          Positioned(
            left: S.w(context, lungsLeft),
            top: S.h(context, lungsTop),
            child: SizedBox(
              width: S.w(context, lungsWidth),
              height: S.h(context, lungsHeight),
              child: Image.asset('assets/lungs_ai.png', fit: BoxFit.contain),
            ),
          ),

          // 📝 Title text
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

          // 🩻 Main X-ray placeholder
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

          // 📷 Camera button
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
                onPressed: _takePicture,
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

          // 📄 Picture taken text
          Positioned(
            left: S.w(context, takenTextLeft),
            top: S.h(context, takenTextTop),
            child: Text(
              "Picture Taken: ${_takenPictureName ?? 'None'}",
              style: TextStyle(
                fontSize: S.fs(context, takenTextSize),
                color: takenTextColor,
              ),
            ),
          ),

          // 🤖 Analyze button (same style as above, with split)
          Positioned(
            left: S.w(context, btn2Left),
            top: S.h(context, btn2Top),
            child: SizedBox(
              width: S.w(context, buttonWidth),
              height: S.h(context, buttonHeight),
              child: Stack(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonBackgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          S.w(context, buttonBorderRadius),
                        ),
                      ),
                      elevation: 8,
                    ),
                    onPressed: () {},
                    child: Row(
                      children: [
                        SizedBox(
                          width: S.w(context, iconSize),
                          height: S.h(context, buttonHeight),
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
                  // Invisible split tap zones
                  Positioned.fill(
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => _analyzePicture("prediction"),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => _analyzePicture("prediction"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
        ],
      ),
    );
  }
}
