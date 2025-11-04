// lib/stethoscope_upload_loading.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'result_stethoscope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'auth.dart';
import 'tts_manager.dart'; // ✅ IMPORT TTS MANAGER

class StethoscopeUploadLoadingPage extends StatefulWidget {
  final String chosenSide;
  final int seedRandom;
  final String uploadedFileName;
  final String uploadedFilePath;

  const StethoscopeUploadLoadingPage({
    super.key,
    required this.chosenSide,
    required this.seedRandom,
    required this.uploadedFileName,
    required this.uploadedFilePath,
  });

  @override
  State<StethoscopeUploadLoadingPage> createState() =>
      _StethoscopeUploadLoadingPageState();
}

class _StethoscopeUploadLoadingPageState
    extends State<StethoscopeUploadLoadingPage>
    with TickerProviderStateMixin {
  static const String backgroundAsset = 'assets/background.png';
  static const String lungsAsset = 'assets/lungs_ai.png';

  SharedPreferences? _prefs;
  bool _patternVerified = false;

  // ✅ REPLACED: Using TtsManager instead of FlutterTts
  final TtsManager _tts = TtsManager();

  bool _loadingStarted = false;
  late final Random _rnd;
  late final int _delayMs;
  final List<String> _logs = [];

  final List<String> _messages = [
    'Filtering background noise...',
    'Normalizing spectral bands...',
    'Detecting crackles and wheezes...',
    'Running temporal envelope analysis...',
    'Calibrating AI model...',
    'Comparing against verified cases...',
    'Extracting spectral fingerprints...',
    'Applying denoise filter...',
    'Scoring probable events...',
    'Preparing final report...',
  ];
  int _msgIndex = 0;
  Timer? _msgTicker;

  late AnimationController _lungsController;
  late Animation<double> _lungsScale;

  static const _pythonChannel = MethodChannel('ai_inference');

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
    _rnd = Random(widget.seedRandom);
    _initTts(); // ✅ UPDATED: Initialize TtsManager
    _initAuth();

    _lungsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _lungsScale = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _lungsController, curve: Curves.easeInOut),
    );
  }

  // ✅ UPDATED: Initialize TtsManager
  Future<void> _initTts() async {
    try {
      await _tts.initialize();

      // Listen to TTS state changes to update UI
      _tts.addListener(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      debugPrint("❌ TTS initialization error: $e");
    }
  }

  Future<void> _initAuth() async {
    // ✅ UPDATED: Use TtsManager speak
    await _tts.speak("Authentication required to proceed");

    final ok = await AppAuth.ensureAuthenticated(context);
    if (!mounted) return;
    if (ok) {
      setState(() => _patternVerified = true);

      // ✅ UPDATED: Use TtsManager speak
      await _tts.speak("Authentication successful. Starting analysis");

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

    // ✅ UPDATED: Use TtsManager speak
    _tts.speak(text);
  }

  // ✅ Handle tap for responsive mode toggle
  void _handleTap() {
    _tapResetTimer?.cancel();

    setState(() {
      _tapCount++;

      if (_tapCount >= 15) {
        _responsiveMode = !_responsiveMode;
        _tapCount = 0;

        final message = _responsiveMode
            ? 'Responsive mode enabled'
            : 'Responsive mode disabled';

        // ✅ UPDATED: Use TtsManager speak
        _tts.speak(message);

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

  Future<void> _startLoadingSequence() async {
    if (!mounted) return;
    if (_loadingStarted) return;
    setState(() => _loadingStarted = true);

    _delayMs = 7000 + _rnd.nextInt(3001);
    _logs.add(
      'Stethoscope prediction started at: ${DateTime.now().toIso8601String()}',
    );
    _logs.add('File name: ${widget.uploadedFileName}');
    _logs.add('File path: ${widget.uploadedFilePath}');

    _msgIndex = 0;

    // ✅ UPDATED: Use TtsManager speak
    _tts.speak(_messages[_msgIndex]);

    _msgTicker?.cancel();
    _msgTicker = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!mounted) return;
      setState(() => _msgIndex = (_msgIndex + 1) % _messages.length);

      // ✅ UPDATED: Use TtsManager speak (every other message)
      if (_msgIndex % 2 == 0) {
        _tts.speak(_messages[_msgIndex]);
      }
    });

    await Future.delayed(Duration(milliseconds: _delayMs));

    _msgTicker?.cancel();

    Map<String, double> result = {};
    try {
      _logs.add('Invoking Python channel: ai_inference.predictStethoscope');

      final Map<dynamic, dynamic> pyResult = await _pythonChannel.invokeMethod(
        'predictStethoscope',
        {'audio': widget.uploadedFilePath},
      );

      _logs.add('Python inference successful: $pyResult');

      final confidenceMap = Map<String, dynamic>.from(pyResult['confidence']);
      result = {
        'normal': (confidenceMap['Normal'] ?? 0.0) * 100,
        'wheeze': (confidenceMap['Wheeze'] ?? 0.0) * 100,
        'crackle': (confidenceMap['Crackle'] ?? 0.0) * 100,
        'both': (confidenceMap['Both'] ?? 0.0) * 100,
      };

      _logs.add('Mapped UI percentages: $result');

      // ✅ UPDATED: Use TtsManager speak
      await _tts.speak("Analysis complete. Displaying results");
    } on PlatformException catch (e) {
      print('Python inference failed: $e');
      _showTemporaryMessage(
        'AI inference failed, showing random result',
        isError: true,
      );
      _logs.add('ERROR: Python inference failed: ${e.code} - ${e.message}');
      _logs.add('Details: ${e.details}');

      result = _generatePercentages(widget.chosenSide);
      _logs.add('Fallback random percentages: $result');
    } catch (e) {
      print('Unexpected error: $e');
      _logs.add('ERROR: Unexpected error: $e');

      result = _generatePercentages(widget.chosenSide);
      _logs.add('Fallback random percentages: $result');
    }

    final mainLabel = _determineMainLabel(result);
    _logs.add('Determined main label: $mainLabel');

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultStethoscopePage(
          percentages: result,
          mainLabel: mainLabel,
          logs: List<String>.from(_logs),
        ),
      ),
    );
  }

  Map<String, double> _generatePercentages(String chosen) {
    final r = Random();
    double normal = r.nextDouble() * 30;
    double wheeze = r.nextDouble() * 30;
    double crackle = r.nextDouble() * 30;
    double both = r.nextDouble() * 20;

    if (chosen == 'normal') {
      normal += 45 + r.nextDouble() * 15;
    } else if (chosen == 'wheeze') {
      wheeze += 40 + r.nextDouble() * 20;
    } else if (chosen == 'crackle') {
      crackle += 40 + r.nextDouble() * 20;
    } else if (chosen == 'both') {
      both += 40 + r.nextDouble() * 20;
    } else if (chosen == 'prediction') {
      normal += 20 + r.nextDouble() * 30;
    } else {
      normal += 20 + r.nextDouble() * 30;
    }

    final total = normal + wheeze + crackle + both;
    return {
      'normal': (normal / total) * 100,
      'wheeze': (wheeze / total) * 100,
      'crackle': (crackle / total) * 100,
      'both': (both / total) * 100,
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
    _tapResetTimer?.cancel();
    _lungsController.dispose();
    _tts.stop(); // ✅ UPDATED: Use TtsManager stop
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    // Hardcoded values
    const lungsWidth = 120.0;
    const lungsHeight = 160.0;
    const authFontSize = 22.0;
    const authVerticalPadding = 6.0;
    const authButtonHeight = 14.0;
    const authSpacing = 8.0;
    const loadingSpacing1 = 8.0;
    const loadingLungsSize = 160.0;
    const loadingSpacing2 = 18.0;
    const loadingMessageFontSize = 24.0;
    const loadingSpacing3 = 16.0;
    const loadingFileNameFontSize = 14.0;
    const loadingPathFontSize = 10.0;
    const loadingSpacing4 = 18.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        // ✅ Detect taps anywhere on screen
        onTap: _handleTap,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(backgroundAsset, fit: BoxFit.cover),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: _scale(lungsWidth, screenWidth, _referenceWidth),
              height: _scale(lungsHeight, screenHeight, _referenceHeight),
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: _scale(
                                    authVerticalPadding,
                                    screenHeight,
                                    _referenceHeight,
                                  ),
                                ),
                                child: Text(
                                  'Authentication required',
                                  style: TextStyle(
                                    fontSize: _scale(
                                      authFontSize,
                                      screenWidth,
                                      _referenceWidth,
                                    ),
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: _scale(
                                  authButtonHeight,
                                  screenHeight,
                                  _referenceHeight,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _initAuth,
                                child: const Text('Unlock'),
                              ),
                              SizedBox(
                                height: _scale(
                                  authSpacing,
                                  screenHeight,
                                  _referenceHeight,
                                ),
                              ),
                            ],
                          ),
                        if (_patternVerified)
                          Column(
                            children: [
                              SizedBox(
                                height: _scale(
                                  loadingSpacing1,
                                  screenHeight,
                                  _referenceHeight,
                                ),
                              ),
                              AnimatedOpacity(
                                opacity: 1.0,
                                duration: const Duration(milliseconds: 400),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: _scale(
                                        loadingLungsSize,
                                        screenWidth,
                                        _referenceWidth,
                                      ),
                                      height: _scale(
                                        loadingLungsSize,
                                        screenHeight,
                                        _referenceHeight,
                                      ),
                                      child: ScaleTransition(
                                        scale: _lungsScale,
                                        child: Image.asset(
                                          lungsAsset,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: _scale(
                                        loadingSpacing2,
                                        screenHeight,
                                        _referenceHeight,
                                      ),
                                    ),
                                    SizedBox(
                                      width: _responsiveMode
                                          ? screenWidth * 0.8
                                          : size.width * 0.8,
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 600,
                                        ),
                                        transitionBuilder: (child, anim) {
                                          final offsetAnim = Tween<Offset>(
                                            begin: const Offset(0, 0.2),
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
                                            fontSize: _scale(
                                              loadingMessageFontSize,
                                              screenWidth,
                                              _referenceWidth,
                                            ),
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: _scale(
                                        loadingSpacing3,
                                        screenHeight,
                                        _referenceHeight,
                                      ),
                                    ),
                                    Text(
                                      'Analyzing: ${widget.uploadedFileName}',
                                      style: TextStyle(
                                        fontSize: _scale(
                                          loadingFileNameFontSize,
                                          screenWidth,
                                          _referenceWidth,
                                        ),
                                        color: Colors.black54,
                                      ),
                                    ),
                                    if (kDebugMode)
                                      Padding(
                                        padding: EdgeInsets.all(
                                          _scale(
                                            8.0,
                                            screenWidth,
                                            _referenceWidth,
                                          ),
                                        ),
                                        child: Text(
                                          'Path: ${widget.uploadedFilePath}',
                                          style: TextStyle(
                                            fontSize: _scale(
                                              loadingPathFontSize,
                                              screenWidth,
                                              _referenceWidth,
                                            ),
                                            color: Colors.black38,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    SizedBox(
                                      height: _scale(
                                        loadingSpacing4,
                                        screenHeight,
                                        _referenceHeight,
                                      ),
                                    ),
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
                      ],
                    ),
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

// The rest of the file (Pattern lock widget & painter) remains unchanged...

// Pattern lock widget & painter (unchanged)
class _PatternLockWidget extends StatefulWidget {
  final double size;
  final double dotRadius;
  final List<int> selected;
  final ValueChanged<List<int>> onUpdateSelected;
  final VoidCallback onComplete;
  final bool isError;
  const _PatternLockWidget({
    required this.size,
    required this.dotRadius,
    required this.selected,
    required this.onUpdateSelected,
    required this.onComplete,
    this.isError = false,
  });

  @override
  State<_PatternLockWidget> createState() => _PatternLockWidgetState();
}

class _PatternLockWidgetState extends State<_PatternLockWidget> {
  final List<int> _sel = [];
  Offset? _current;

  @override
  void initState() {
    super.initState();
    _sel.addAll(widget.selected);
  }

  @override
  void didUpdateWidget(covariant _PatternLockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.selected, widget.selected)) {
      _sel
        ..clear()
        ..addAll(widget.selected);
    }
  }

  void _updateSelection(Offset localPos) {
    final centers = _computeCenters();
    for (int i = 0; i < centers.length; i++) {
      final d = (localPos - centers[i]).distance;
      if (d <= widget.dotRadius * 1.6 && !_sel.contains(i)) {
        setState(() => _sel.add(i));
        widget.onUpdateSelected(List<int>.from(_sel));
        break;
      }
    }
  }

  List<Offset> _computeCenters() {
    final step = widget.size / 3;
    final centers = <Offset>[];
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        final cx = (c + 0.5) * step;
        final cy = (r + 0.5) * step;
        centers.add(Offset(cx, cy));
      }
    }
    return centers;
  }

  @override
  Widget build(BuildContext context) {
    final centers = _computeCenters();
    return Listener(
      onPointerDown: (ev) {
        setState(() => _current = ev.localPosition);
        _updateSelection(ev.localPosition);
      },
      onPointerMove: (ev) {
        setState(() => _current = ev.localPosition);
        _updateSelection(ev.localPosition);
      },
      onPointerUp: (ev) {
        setState(() => _current = null);
        widget.onComplete();
      },
      child: CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _PatternPainter(
          centers: centers,
          dotRadius: widget.dotRadius,
          selected: _sel,
          current: _current,
          isError: widget.isError,
        ),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  final List<Offset> centers;
  final double dotRadius;
  final List<int> selected;
  final Offset? current;
  final bool isError;

  _PatternPainter({
    required this.centers,
    required this.dotRadius,
    required this.selected,
    this.current,
    this.isError = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = isError ? Colors.redAccent : Colors.blueAccent
      ..strokeWidth = dotRadius * 0.45
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintDot = Paint()..color = Colors.grey.shade300;
    final paintDotSel = Paint()
      ..color = isError ? Colors.redAccent : Colors.blueAccent;

    if (selected.isNotEmpty) {
      final path = Path();
      path.moveTo(centers[selected[0]].dx, centers[selected[0]].dy);
      for (int i = 1; i < selected.length; i++) {
        path.lineTo(centers[selected[i]].dx, centers[selected[i]].dy);
      }
      canvas.drawPath(path, paintLine);

      if (current != null) {
        final last = centers[selected.last];
        canvas.drawLine(last, current!, paintLine);
      }
    }

    for (int i = 0; i < centers.length; i++) {
      final c = centers[i];
      final bool sel = selected.contains(i);
      canvas.drawCircle(c, dotRadius * 1.15, paintDot);
      canvas.drawCircle(
        c,
        sel ? dotRadius * 0.9 : dotRadius * 0.6,
        sel ? paintDotSel : Paint()
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter old) => true;
}

class _PinAuthDialog extends StatefulWidget {
  @override
  State<_PinAuthDialog> createState() => _PinAuthDialogState();
}

class _PinAuthDialogState extends State<_PinAuthDialog> {
  String pin = '';
  String message = '';

  void _addDigit(String d) {
    if (pin.length >= 6) return;
    setState(() => pin += d);
  }

  void _backspace() {
    if (pin.isEmpty) return;
    setState(() => pin = pin.substring(0, pin.length - 1));
  }

  void _confirm() {
    if (pin == '1234') {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        message = 'Incorrect PIN';
        pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget key(String s) => GestureDetector(
      onTap: () => _addDigit(s),
      child: Container(
        margin: const EdgeInsets.all(6),
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text(s, style: const TextStyle(fontSize: 20))),
      ),
    );

    return AlertDialog(
      title: const Text('Enter PIN to change pattern'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '*' * pin.length,
              style: const TextStyle(fontSize: 24, letterSpacing: 6),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            children: [
              for (var r = 1; r <= 9; r++) key('$r'),
              key('0'),
              GestureDetector(
                onTap: _backspace,
                child: Container(
                  margin: const EdgeInsets.all(6),
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.backspace_outlined),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _confirm, child: const Text('Confirm')),
      ],
    );
  }
}
