import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'scale.dart';
import 'chest_xray.dart';
import 'stethoscope_main.dart';
import 'tts_manager.dart';
import 'arduino_service.dart';

class NextPage extends StatefulWidget {
  const NextPage({super.key});

  @override
  State<NextPage> createState() => _NextPageState();
}

class _NextPageState extends State<NextPage> {
  int _tapCount = 0;
  DateTime? _firstTapAt;

  final TtsManager _tts = TtsManager();
  final ArduinoService _arduino = ArduinoService();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTts();
      _initializeArduino();
    });
  }

  Future<void> _initializeArduino() async {
    // Update LCD
    await _arduino.updateLCD('PneumoAI', 'System Ready');
    
    // Welcome gesture
    await Future.delayed(const Duration(milliseconds: 500));
    await _arduino.gestureWelcome();
  }

  Future<void> _initializeTts() async {
    try {
      await _tts.initialize();

      _tts.addListener(() {
        if (mounted) setState(() {});
      });

      _speakWelcomeMessage();
    } catch (e) {
      debugPrint('❌ TTS initialization error: $e');
    }
  }

  void _speakWelcomeMessage() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      
      // LCD update
      await _arduino.updateLCD('Welcome to', 'PneumoAI');
      
      await _tts.speak("Welcome to PneumoAI");
      await Future.delayed(const Duration(seconds: 2));
      
      // LCD update
      await _arduino.updateLCD('AI Detection', 'System');
      
      await _tts.speak(
        "Detects pneumonia by analyzing chest X-rays and lung sounds",
      );
      
      // Reset LCD
      await Future.delayed(const Duration(seconds: 3));
      await _arduino.updateLCD('PneumoAI', 'Ready');
    } catch (e) {
      debugPrint('❌ TTS speaking error: $e');
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _arduino.gestureReset();
    super.dispose();
  }

  void _handleGlobalTap() {
    final now = DateTime.now();
    if (_firstTapAt == null || now.difference(_firstTapAt!).inSeconds > 5) {
      _firstTapAt = now;
      _tapCount = 0;
    }
    _tapCount += 1;
    if (_tapCount >= 15) {
      _tapCount = 0;
      _firstTapAt = null;
      S.toggle();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.enabled
                ? 'Responsive scaling ENABLED (2000x1200 baseline)'
                : 'Responsive scaling DISABLED',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onStethoscopePressed() async {
    // Update LCD
    await _arduino.updateLCD('Lung Sound', 'Detection Mode');
    
    // Point to stethoscope option
    await _arduino.gesturePointLeft();
    
    await Future.delayed(const Duration(milliseconds: 800));
    
    _tts.stop();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const StethoscopeMainPage(),
      ),
    );
  }

  Future<void> _onXRayPressed() async {
    // Update LCD
    await _arduino.updateLCD('X-Ray Analysis', 'Mode');
    
    // Point to X-ray option
    await _arduino.gesturePointRight();
    
    await Future.delayed(const Duration(milliseconds: 800));
    
    _tts.stop();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChestXRayPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const mainTextColor = Color(0xFF0d3b66);
    const hindiTextColor = Color(0xFF7f9db1);
    const button1Color = Color(0xFFfecad5);
    const button2Color = Color(0xFFfecad5);
    const overlayColor = Colors.black54;
    const overlayOpacity = 0.0;

    const lungsWidth = 600.0;
    const lungsHeight = 800.0;
    const lungsLeft = 00.0;
    const lungsTop = -100.0;

    const pneumoFontSize = 100.0;
    const pneumoLeft = 90.0;
    const pneumoTop = 520.0;

    const hindiFontSize = 60.0;
    const hindiLeft = 150.0;
    const hindiTop = 640.0;

    const buttonWidth = 550.0;
    const buttonHeight = 200.0;
    const buttonBorderRadius = 50.0;

    const iconSize = 150.0;
    const iconBorderRadius = 40.0;

    const buttonTextSize = 40.0;
    const iconTextSpacing = 30.0;

    const btn1Left = 710.0;
    const btn1Top = 150.0;

    const btn2Left = 710.0;
    const btn2Top = 450.0;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleGlobalTap,
        child: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Image.asset(
                'assets/background.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('❌ Background image error: $error');
                  return Container(color: Colors.grey[300]);
                },
              ),
            ),

            // Overlay
            Positioned.fill(
              child: Container(color: overlayColor.withOpacity(overlayOpacity)),
            ),

            // Lungs image
            Positioned(
              left: S.w(context, lungsLeft),
              top: S.h(context, lungsTop),
              child: SizedBox(
                width: S.w(context, lungsWidth),
                height: S.h(context, lungsHeight),
                child: Image.asset(
                  'assets/lungs_ai.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('❌ Lungs image error: $error');
                    return const SizedBox();
                  },
                ),
              ),
            ),

            // "PneumoAI" Text
            Positioned(
              left: S.w(context, pneumoLeft),
              top: S.h(context, pneumoTop),
              child: Text(
                "PneumoAI",
                style: TextStyle(
                  fontSize: S.fs(context, pneumoFontSize),
                  fontWeight: FontWeight.bold,
                  color: mainTextColor,
                ),
              ),
            ),

            // Hindi text
            Positioned(
              left: S.w(context, hindiLeft),
              top: S.h(context, hindiTop),
              child: Text(
                "साँस की सुरक्षा",
                style: TextStyle(
                  fontSize: S.fs(context, hindiFontSize),
                  fontWeight: FontWeight.w600,
                  color: hindiTextColor,
                ),
              ),
            ),

            // Button 1: Detect Pneumonia
            Positioned(
              left: S.w(context, btn1Left),
              top: S.h(context, btn1Top),
              child: SizedBox(
                width: S.w(context, buttonWidth),
                height: S.h(context, buttonHeight),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: button1Color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        S.w(context, buttonBorderRadius),
                      ),
                    ),
                  ),
                  onPressed: _onStethoscopePressed,
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          S.w(context, iconBorderRadius),
                        ),
                        child: SizedBox(
                          width: S.w(context, iconSize),
                          height: S.h(context, iconSize),
                          child: Image.asset(
                            'assets/stethoscope_icon.png',
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('❌ Stethoscope icon error: $error');
                              return Container(
                                color: Colors.blue[100],
                                child: const Icon(Icons.mic, size: 50),
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: S.w(context, iconTextSpacing)),
                      Expanded(
                        child: Text(
                          "Detect Pneumonia with Lung Sounds",
                          style: TextStyle(
                            fontSize: S.fs(context, buttonTextSize),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF000080),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Button 2: Analyze Chest X-Ray
            Positioned(
              left: S.w(context, btn2Left),
              top: S.h(context, btn2Top),
              child: SizedBox(
                width: S.w(context, buttonWidth),
                height: S.h(context, buttonHeight),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: button2Color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        S.w(context, buttonBorderRadius),
                      ),
                    ),
                  ),
                  onPressed: _onXRayPressed,
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          S.w(context, iconBorderRadius),
                        ),
                        child: SizedBox(
                          width: S.w(context, iconSize),
                          height: S.h(context, iconSize),
                          child: Image.asset(
                            'assets/xray_icon.png',
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('❌ X-ray icon error: $error');
                              return Container(
                                color: Colors.blue[100],
                                child: const Icon(Icons.camera_alt, size: 50),
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: S.w(context, iconTextSpacing)),
                      Expanded(
                        child: Text(
                          "Analyze your Chest X-Ray with AI",
                          style: TextStyle(
                            fontSize: S.fs(context, buttonTextSize),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF000080),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ✅ TTS TOGGLE BUTTON (Top Right)
            Positioned(
              top: 20,
              right: 20,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    await _tts.toggle();
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _tts.isEnabled
                          ? Colors.blue.shade500
                          : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _tts.isEnabled ? Icons.volume_up : Icons.volume_off,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _tts.isEnabled ? 'Voice ON' : 'Voice OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ✅ SERIAL TOGGLE BUTTON (Top Right, below TTS)
            Positioned(
              top: 80,
              right: 20,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _arduino.toggleSerial();
                    });
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _arduino.isSerialEnabled
                          ? Colors.green.shade500
                          : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _arduino.isSerialEnabled
                              ? Icons.cable
                              : Icons.cable_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _arduino.isSerialEnabled ? 'Serial ON' : 'Serial OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ✅ Speaking indicator (when TTS is active)
            if (_tts.isSpeaking)
              Positioned(
                top: 140,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade400.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.graphic_eq, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Speaking...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}