// lib/xray_picture.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'loading_xray.dart';
import 'scale.dart';
import 'tts_manager.dart'; // ✅ NEW: Import TTS Manager

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

  // ✅ UPDATED: Use TTS Manager instead of FlutterTts
  final TtsManager _tts = TtsManager();

  @override
  void initState() {
    super.initState();
    _initTtsAndSpeak();
  }

  // ✅ UPDATED: Simplified TTS initialization
  Future<void> _initTtsAndSpeak() async {
    await _tts.initialize();

    // Listen to TTS state changes to update UI
    _tts.addListener(() {
      if (mounted) setState(() {});
    });

    await Future.delayed(const Duration(milliseconds: 300));
    await _tts.speak("Take a picture of your chest X-ray for AI analysis");
  }

  @override
  void dispose() {
    _tts.stop(); // ✅ UPDATED: Use TTS Manager stop
    super.dispose();
  }

  // Camera Capture
  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        setState(() {
          _takenPictureName = photo.name;
          _takenPicturePath = photo.path;
        });

        // ✅ UPDATED: Use TTS Manager speak
        await _tts.speak(
          "Picture captured successfully. You can now proceed to AI analysis",
        );
      }
    } on PlatformException catch (e) {
      debugPrint("Camera error: $e");

      // ✅ UPDATED: Use TTS Manager speak
      await _tts.speak("Failed to open camera. Please check permissions");
    }
  }

  // Navigate to Loading + Analysis
  void _analyzePicture(String resultType) {
    if (_takenPictureName == null || _takenPicturePath == null) {
      setState(() {
        _showError = true;
      });

      // ✅ UPDATED: Use TTS Manager speak
      _tts.speak("Please take a picture of your chest X-ray first");

      Timer(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _showError = false;
          });
        }
      });
      return;
    }

    // ✅ UPDATED: Use TTS Manager speak
    _tts.speak("Starting AI analysis of your chest X-ray");

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
                            onTap: () {
                              // Let the actual prediction determine the result type
                              _analyzePicture("prediction");
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ✅ UPDATED: Speaking indicator using TTS Manager
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
