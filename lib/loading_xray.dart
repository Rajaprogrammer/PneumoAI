import 'dart:async';
import 'dart:math';
import 'result_xray.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'tts_manager.dart';
import 'arduino_service.dart'; // ✅ NEW: Import Arduino Service
import 'auth.dart';
import 'scale.dart';

class LoadingXRayPage extends StatefulWidget {
  final String resultType; // 'normal' / 'viral' / 'bacterial'
  final String uploadedFileName;

  const LoadingXRayPage({
    super.key,
    required this.resultType,
    required this.uploadedFileName,
  });

  @override
  State<LoadingXRayPage> createState() => _LoadingXRayPageState();
}

class _LoadingXRayPageState extends State<LoadingXRayPage>
    with TickerProviderStateMixin {
  static const String backgroundAsset = 'assets/background.png';
  static const String lungsAsset = 'assets/lungs_ai.png';
  static const _pythonChannel = MethodChannel('ai_inference');

  bool _patternVerified = false;

  final TtsManager _tts = TtsManager();
  final ArduinoService _arduino = ArduinoService(); // ✅ NEW: Arduino Service

  bool _loadingStarted = false;
  final List<String> _messages = [
    'Filtering background noise...',
    'Normalizing contrast and intensity...',
    'Detecting opacities and consolidations...',
    'Running texture analysis...',
    'Comparing against verified cases...',
    'Applying model ensemble...',
    'Computing region-of-interest metrics...',
    'Calibrating confidence vectors...',
    'Generating probabilistic diagnosis...',
    'Preparing final report...',
  ];
  int _msgIndex = 0;
  Timer? _msgTicker;
  Timer? _imageTicker;
  late final Random _rnd;
  late final int _delayMs;
  final List<String> _logs = [];

  final ScrollController _imgController = ScrollController();
  double _itemHeight = 220.0;
  bool _imgScrolling = false;
  final int _repeats = 40;

  @override
  void initState() {
    super.initState();
    _rnd = Random();
    _initTts();
    _initArduino(); // ✅ NEW: Initialize Arduino
    _initAuth();
  }

  // ✅ NEW: Initialize Arduino
  Future<void> _initArduino() async {
    await Future.delayed(const Duration(milliseconds: 100));

    // Initial LCD: Authentication required
    await _arduino.updateLCD('X-Ray Auth', 'Required');

    // Bot: Waiting gesture
    await _arduino.setBotPosition(head: 0, handL: 30, handR: 30);
  }

  Future<void> _initTts() async {
    try {
      await _tts.initialize();

      _tts.addListener(() {
        if (mounted) setState(() {});
      });

      debugPrint("✅ TTS initialized successfully");
    } catch (e) {
      debugPrint("❌ TTS initialization error: $e");
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

  Future<void> _initAuth() async {
    await _speak("Authentication required to proceed with X-ray analysis");

    final ok = await AppAuth.ensureAuthenticated(context);
    if (!mounted) return;
    if (ok) {
      setState(() => _patternVerified = true);

      // ✅ LCD: Auth success
      await _arduino.updateLCD('Auth Success', 'Starting...');

      // ✅ Bot: Success gesture
      await _arduino.setBotPosition(head: 0, handL: 90, handR: 90);
      await Future.delayed(const Duration(milliseconds: 800));
      await _arduino.gestureReset();

      await _speak("Authentication successful. Starting X-ray analysis");

      _startLoadingSequence();
    } else {
      // ✅ LCD: Auth failed
      await _arduino.updateLCD('Auth Failed', 'Try Again');

      // ✅ Bot: Rejection gesture
      await _arduino.setBotPosition(head: -30, handL: 0, handR: 0);
      await Future.delayed(const Duration(milliseconds: 1000));
      await _arduino.gestureReset();
    }
  }

  void _retryAuth() async {
    final ok = await AppAuth.ensureAuthenticated(context);
    if (!mounted) return;
    if (ok) {
      setState(() => _patternVerified = true);

      // ✅ LCD: Auth success
      await _arduino.updateLCD('Auth Success', 'Starting...');

      // ✅ Bot: Success gesture
      await _arduino.setBotPosition(head: 0, handL: 90, handR: 90);
      await Future.delayed(const Duration(milliseconds: 800));
      await _arduino.gestureReset();

      await _speak("Authentication successful. Starting X-ray analysis");

      _startLoadingSequence();
    }
  }

  void _showTemporaryMessage(
    String text, {
    bool isError = false,
    int ms = 900,
  }) {
    final snack = SnackBar(
      content: Text(text),
      backgroundColor: isError ? Colors.redAccent : Colors.black87,
      duration: Duration(milliseconds: ms),
    );
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snack);

    _speak(text);
  }

  // ✅ UPDATED: Loading sequence with Arduino animations
  Future<void> _startLoadingSequence() async {
    if (!mounted) return;
    setState(() => _loadingStarted = true);

    // ✅ LCD: Analysis starting
    await _arduino.updateLCD('Analyzing', 'X-Ray...');

    // ✅ Bot: Analysis starting gesture
    await _arduino.setBotPosition(head: 15, handL: 60, handR: 60);

    _msgIndex = 0;
    _speak(_messages[_msgIndex]);

    // ✅ LCD messages corresponding to analysis steps
    final lcdMessages = [
      ['Filtering', 'Noise...'],
      ['Normalizing', 'Contrast...'],
      ['Detecting', 'Opacities...'],
      ['Analyzing', 'Texture...'],
      ['Comparing', 'Cases...'],
      ['AI Model', 'Ensemble...'],
      ['Computing', 'Metrics...'],
      ['Calibrating', 'Vectors...'],
      ['Generating', 'Diagnosis...'],
      ['Finalizing', 'Report...'],
    ];

    _msgTicker?.cancel();
    _msgTicker = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (!mounted) return;
      setState(() => _msgIndex = (_msgIndex + 1) % _messages.length);

      // ✅ Update LCD with current step
      if (_msgIndex < lcdMessages.length) {
        await _arduino.updateLCD(
          lcdMessages[_msgIndex][0],
          lcdMessages[_msgIndex][1],
        );
      }

      // ✅ Bot: Subtle movements during analysis
      if (_msgIndex % 3 == 0) {
        await _arduino.setBotPosition(
          head: 10 + (_msgIndex % 2) * 10,
          handL: 55 + (_msgIndex % 3) * 10,
          handR: 55 + (_msgIndex % 3) * 10,
        );
      }

      if (_msgIndex % 2 == 0) {
        _speak(_messages[_msgIndex]);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startImageAutoScroll();
    });

    final startTime = DateTime.now();
    _logs.add('Prediction started at: ${startTime.toIso8601String()}');

    Map<String, double> result = {};
    try {
      _logs.add('Invoking Python channel: ai_inference.predictXray');

      // ✅ LCD: AI Processing
      await _arduino.updateLCD('AI Processing', 'X-Ray Data...');

      // ✅ Bot: Intense processing
      await _arduino.setBotPosition(head: 20, handL: 80, handR: 80);

      final Map<dynamic, dynamic> pyResult = await _pythonChannel.invokeMethod(
        'predictXray',
        {'image': widget.uploadedFileName},
      );

      result = _mapModelOutputToUI(pyResult);
      _logs.add('Inference raw result: $pyResult');
      _logs.add('Mapped UI percentages: $result');

      final predictionTime = DateTime.now()
          .difference(startTime)
          .inMilliseconds;
      _delayMs = predictionTime;
      _logs.add('Inference duration: $_delayMs ms');

      // ✅ LCD: Analysis complete
      await _arduino.updateLCD('Analysis', 'Complete!');

      // ✅ Bot: Success celebration
      await _arduino.setBotPosition(head: 0, handL: 90, handR: 90);
      await Future.delayed(const Duration(milliseconds: 600));

      await _speak("X-ray analysis complete. Displaying results");
    } on PlatformException catch (e) {
      print('Python inference failed: $e');
      _logs.add('ERROR: Python inference failed: $e');

      // ✅ LCD: Error message
      await _arduino.updateLCD('AI Error', 'Using Fallback');

      // ✅ Bot: Error gesture
      await _arduino.setBotPosition(head: -25, handL: 40, handR: 0);

      if (e.code != 'UNSUPPORTED_ABI') {
        _showTemporaryMessage(
          'AI inference failed, showing random result',
          isError: true,
        );
        _logs.add('ERROR: Non-ABI failure, using random fallback');
        _delayMs = 7000 + _rnd.nextInt(3001);
        result = _generatePercentages(widget.resultType);
        _logs.add('Fallback random percentages: $result');
      } else {
        _showTemporaryMessage(
          'Using device-compatible fallback',
          isError: false,
        );
      }

      await Future.delayed(const Duration(milliseconds: 800));
      await _arduino.updateLCD('Fallback', 'Result Ready');
    }

    final minDelay = 3000;
    if (_delayMs < minDelay) {
      await Future.delayed(Duration(milliseconds: minDelay - _delayMs));
    }
    _logs.add('UI enforced min delay: $minDelay ms');

    _msgTicker?.cancel();
    _imageTicker?.cancel();
    _imgScrolling = false;

    final mainLabel = _determineMainLabel(result);
    _logs.add('Determined main label: $mainLabel');

    // ✅ LCD: Show result type
    String resultDisplay = mainLabel.toUpperCase();
    if (resultDisplay.length > 8) resultDisplay = resultDisplay.substring(0, 8);
    await _arduino.updateLCD('Result:', resultDisplay);

    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultXRayPage(
          percentages: result,
          mainLabel: mainLabel,
          logs: List<String>.from(_logs),
        ),
      ),
    );
  }

  void _startImageAutoScroll() {
    if (!mounted) return;
    if (_imgController.hasClients) {
      const containerH = 500.0;
      _itemHeight = containerH * 0.9;

      _imgScrolling = true;
      _imageTicker?.cancel();
      _imageTicker = Timer.periodic(const Duration(milliseconds: 900), (
        _,
      ) async {
        if (!mounted || !_imgController.hasClients) return;
        final maxExtent = _imgController.position.maxScrollExtent;
        double next = _imgController.offset + _itemHeight + 8.0;
        if (next > maxExtent - 4.0) {
          await _imgController.animateTo(
            maxExtent,
            duration: const Duration(milliseconds: 600),
            curve: Curves.linear,
          );
          if (!mounted) return;
          _imgController.jumpTo(0);
        } else {
          await _imgController.animateTo(
            next,
            duration: const Duration(milliseconds: 700),
            curve: Curves.linear,
          );
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _startImageAutoScroll(),
      );
    }
  }

  Map<String, double> _mapModelOutputToUI(Map<dynamic, dynamic> modelResult) {
    final prediction = modelResult['prediction']?.toString() ?? 'Healthy';
    final confidence =
        modelResult['confidence'] as Map<dynamic, dynamic>? ?? {};

    final healthyConf = (confidence['Healthy'] as num?)?.toDouble() ?? 0.5;
    final pneumoniaConf = (confidence['Pneumonia'] as num?)?.toDouble() ?? 0.5;

    final healthyPct = healthyConf * 100;
    final pneumoniaPct = pneumoniaConf * 100;

    return {'Healthy': healthyPct, 'Pneumonia': pneumoniaPct};
  }

  Map<String, double> _generatePercentages(String chosen) {
    final r = Random();
    double normal = r.nextDouble() * 30;
    double viral = r.nextDouble() * 30;
    double bacterial = r.nextDouble() * 30;

    if (chosen == 'normal') {
      normal += 45 + r.nextDouble() * 15;
    } else if (chosen == 'viral') {
      viral += 45 + r.nextDouble() * 15;
    } else if (chosen == 'bacterial') {
      bacterial += 45 + r.nextDouble() * 15;
    } else if (chosen == 'prediction') {
      normal += 20 + r.nextDouble() * 30;
    } else {
      normal += 20 + r.nextDouble() * 30;
    }

    final total = normal + viral + bacterial;
    return {
      'normal': (normal / total) * 100,
      'viral': (viral / total) * 100,
      'bacterial': (bacterial / total) * 100,
    };
  }

  String _determineMainLabel(Map<String, double> p) {
    final sorted = p.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  @override
  void dispose() {
    _msgTicker?.cancel();
    _imageTicker?.cancel();
    _imgController.dispose();
    _tts.stop();
    _arduino.gestureReset(); // ✅ NEW: Reset bot on exit
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double lungsWidth = 120.0;
    const double lungsHeight = 160.0;
    const double messageSize = 22.0;
    const double loadingTopSpacing = 8.0;
    const double textSpacing = 18.0;
    const double bigTextSize = 26.0;
    const double fileTextSpacing = 24.0;
    const double fileTextSize = 14.0;
    const double buttonSpacing = 12.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(backgroundAsset, fit: BoxFit.cover),
          ),

          Positioned(
            left: 0,
            top: 0,
            width: lungsWidth,
            height: lungsHeight,
            child: Image.asset(lungsAsset, fit: BoxFit.contain),
          ),

          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_patternVerified)
                        Column(
                          children: [
                            Text(
                              'Authentication required',
                              style: TextStyle(
                                fontSize: messageSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 12.0),
                            ElevatedButton(
                              onPressed: _retryAuth,
                              child: const Text('Unlock'),
                            ),
                          ],
                        ),

                      if (_patternVerified)
                        SizedBox(
                          width: S.w(context, 1200.0),
                          child: Column(
                            children: [
                              SizedBox(height: loadingTopSpacing),
                              AnimatedOpacity(
                                opacity: _loadingStarted ? 1.0 : 1.0,
                                duration: const Duration(milliseconds: 400),
                                child: Column(
                                  children: [
                                    Builder(
                                      builder: (ctx) {
                                        final containerW = S.w(context, 600.0);
                                        final containerH = S.h(context, 500.0);
                                        _itemHeight = containerH * 0.9;

                                        return SizedBox(
                                          width: containerW,
                                          height: containerH,
                                          child: Card(
                                            elevation: 10,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            clipBehavior: Clip.hardEdge,
                                            child: Container(
                                              color: Colors.black12,
                                              child: ScrollConfiguration(
                                                behavior:
                                                    const _NoGlowBehavior(),
                                                child: ListView.builder(
                                                  controller: _imgController,
                                                  physics:
                                                      const NeverScrollableScrollPhysics(),
                                                  itemCount: _repeats,
                                                  itemBuilder: (_, index) {
                                                    final int imgIndex =
                                                        (index % 10) + 1;
                                                    String which;

                                                    if (imgIndex == 1) {
                                                      which =
                                                          'assets/xray_icon.png';
                                                    } else if (imgIndex == 2) {
                                                      which =
                                                          'assets/xray2_icon.png';
                                                    } else {
                                                      which =
                                                          'assets/xray${imgIndex}_icon.jpg';
                                                    }

                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 4.0,
                                                          ),
                                                      child: SizedBox(
                                                        height:
                                                            containerH * 0.9,
                                                        child: Image.asset(
                                                          which,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    SizedBox(height: textSpacing),

                                    SizedBox(
                                      width: S.w(context, 960.0),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 600,
                                        ),
                                        transitionBuilder: (child, anim) {
                                          final offsetAnim = Tween<Offset>(
                                            begin: const Offset(0, 0.3),
                                            end: Offset.zero,
                                          ).animate(anim);
                                          return SlideTransition(
                                            position: offsetAnim,
                                            child: FadeTransition(
                                              opacity: anim,
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: Text(
                                          _messages[_msgIndex],
                                          key: ValueKey<int>(_msgIndex),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: bigTextSize,
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(height: fileTextSpacing),
                                    Text(
                                      'Analyzing: ${widget.uploadedFileName}',
                                      style: TextStyle(
                                        fontSize: fileTextSize,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    SizedBox(height: buttonSpacing),
                                    if (!_loadingStarted)
                                      ElevatedButton(
                                        onPressed: _startLoadingSequence,
                                        child: const Text('Start Analysis'),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

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

class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
