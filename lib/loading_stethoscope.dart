import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'tts_manager.dart'; // ✅ REPLACED WITH TTS MANAGER
import 'result.dart';

/// LoadingStethoscopePage
/// - Requests microphone permission on first use
/// - Starts mic access when recording begins
/// - Stops mic access when "Stop Recording" is clicked
class LoadingStethoscopePage extends StatefulWidget {
  const LoadingStethoscopePage({super.key});

  @override
  State<LoadingStethoscopePage> createState() => _LoadingStethoscopePageState();
}

class _LoadingStethoscopePageState extends State<LoadingStethoscopePage>
    with TickerProviderStateMixin {
  // Standard header assets
  static const String backgroundAsset = 'assets/background.png';
  static const String lungsAsset = 'assets/lungs_ai.png';

  // Pattern storage key
  static const String _kPatternKey = 'steth_pattern';

  // State
  SharedPreferences? _prefs;
  String? _storedPattern;
  bool _isSettingPattern = false;
  bool _patternVerified = false;
  bool _showWrongPattern = false;
  bool _showBreathingAnimation = false;

  // ✅ REPLACED: Using TtsManager instead of FlutterTts
  final TtsManager _tts = TtsManager();

  // Microphone state
  bool _isMicActive = false;
  bool _hasMicPermission = false;

  // For pattern drawing
  final List<int> _selected = [];
  Offset? _currentPointer;
  bool _isDrawing = false;

  // UI / sequence
  String _overlayText = '';
  bool _overlayVisible = false;
  bool _showStopButton = false;
  bool _isProcessingStop = false;

  // constants for button
  static const double buttonWidth = 500.0;
  static const double buttonHeight = 500.0;
  static const double buttonBorderRadius = 100.0;
  static const double micWidth = 250.0;
  static const double micHeight = 250.0;
  static const double micLeft = 120.0;
  static const double micTop = 90.0;
  static const double buttonTextFontSize = 50.0;
  static const double buttonTextLeft = 70.0;
  static const double buttonTextTop = 380.0;

  // animation helpers
  Timer? _countdownTimer;
  late Random _rnd;

  @override
  void initState() {
    _rnd = Random();
    super.initState();
    _initTts(); // ✅ UPDATED: Initialize TtsManager
    _initPrefs();
  }

  // ✅ Initialize TtsManager
  Future<void> _initTts() async {
    try {
      await _tts.initialize();

      // Listen to TTS state changes to update UI
      _tts.addListener(() {
        if (mounted) setState(() {});
      });

      debugPrint("✅ TTS initialized successfully");
    } catch (e) {
      debugPrint("❌ TTS initialization error: $e");
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

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _storedPattern = _prefs!.getString(_kPatternKey);
    if (_storedPattern == null) {
      setState(() {
        _isSettingPattern = true;
      });
      // ✅ Speak pattern setup instruction
      await _speak("Set your unlock pattern");
    } else {
      // ✅ Speak pattern unlock instruction
      await _speak("Draw your pattern to unlock");
    }
  }

  Future<void> _savePattern(String pattern) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_kPatternKey, pattern);
    _storedPattern = pattern;
  }

  String _patternToString(List<int> sel) => sel.join(',');

  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.status;

    if (status.isGranted) {
      setState(() => _hasMicPermission = true);
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.microphone.request();
      if (result.isGranted) {
        setState(() => _hasMicPermission = true);
        return true;
      } else if (result.isPermanentlyDenied) {
        _showPermissionDeniedDialog();
        return false;
      }
    }

    if (status.isPermanentlyDenied) {
      _showPermissionDeniedDialog();
      return false;
    }

    return false;
  }

  void _showPermissionDeniedDialog() {
    _speak("Microphone permission required");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const Text(
          'This app needs microphone access to analyze breathing sounds. '
          'Please enable it in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              Navigator.of(context).pop();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _startMicAccess() async {
    if (!_hasMicPermission) return;

    setState(() => _isMicActive = true);
    debugPrint('🎤 Microphone access started');

    // ✅ Speak mic activation
    await _speak("Microphone activated");
  }

  void _stopMicAccess() {
    if (_isMicActive) {
      setState(() => _isMicActive = false);
      debugPrint('🎤 Microphone access stopped');

      // ✅ Speak mic deactivation
      _speak("Recording stopped. Analyzing audio");
    }
  }

  void _finishDrawingPattern() async {
    final s = _patternToString(_selected);
    if (_isSettingPattern) {
      if (_selected.length < 4) {
        _showTemporaryMessage(
          'Pattern too short — use at least 4 dots',
          isError: true,
        );

        // ✅ Speak error
        await _speak("Pattern too short. Use at least 4 dots");

        _clearDrawing();
        return;
      }
      await _savePattern(s);
      setState(() {
        _isSettingPattern = false;
        _patternVerified = true;
      });
      _clearDrawing();

      // ✅ Speak pattern saved
      await _speak("Pattern saved successfully");

      final hasPermission = await _requestMicPermission();
      if (!hasPermission) {
        _showTemporaryMessage('Microphone permission required', isError: true);
        return;
      }

      _startRecordingSequence();
      return;
    }

    // verify pattern
    if (_storedPattern == s) {
      setState(() => _patternVerified = true);
      _clearDrawing();

      // ✅ Speak pattern verified
      await _speak("Pattern verified");

      final hasPermission = await _requestMicPermission();
      if (!hasPermission) {
        _showTemporaryMessage('Microphone permission required', isError: true);
        setState(() => _patternVerified = false);
        return;
      }

      _startRecordingSequence();
    } else {
      setState(() {
        _showWrongPattern = true;
      });
      _showTemporaryMessage('Wrong pattern', isError: true);

      // ✅ Speak wrong pattern
      await _speak("Wrong pattern. Try again");

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _showWrongPattern = false;
            _clearDrawing();
          });
        }
      });
    }
  }

  void _clearDrawing() {
    setState(() {
      _selected.clear();
      _currentPointer = null;
      _isDrawing = false;
    });
  }

  void _showTemporaryMessage(
    String text, {
    bool isError = false,
    int ms = 900,
  }) {
    setState(() {
      _overlayText = text;
      _overlayVisible = true;
    });
    Future.delayed(Duration(milliseconds: ms), () {
      if (mounted) {
        setState(() => _overlayVisible = false);
      }
    });
  }

  Future<void> _startRecordingSequence() async {
    if (!mounted) return;

    // Countdown
    await _showFadeText('Recording starting in..', 900);
    await _speak("Recording starting in");
    await Future.delayed(const Duration(milliseconds: 160));

    for (int n = 3; n >= 1; n--) {
      await _showFadeText('$n', 700);
      await _speak('$n');
      await Future.delayed(const Duration(milliseconds: 160));
    }

    await _showFadeText('Start', 900);
    await _speak('Start');
    await Future.delayed(const Duration(milliseconds: 300));

    await _startMicAccess();

    // Breathing cycles
    if (mounted) setState(() => _showBreathingAnimation = true);

    for (int cycle = 0; cycle < 3; cycle++) {
      await _showFadeText('Please breathe in deeply', 2000);
      await _speak('Please breathe in deeply');
      await Future.delayed(const Duration(milliseconds: 180));

      await _showFadeText('Please breathe out deeply', 2000);
      await _speak('Please breathe out deeply');
      await Future.delayed(const Duration(milliseconds: 180));
    }

    if (mounted) {
      setState(() {
        _showStopButton = true;
        _showBreathingAnimation = false;
      });

      // ✅ Speak stop instruction
      await _speak("Tap stop recording when ready");
    }
  }

  Future<void> _showFadeText(
    String text,
    int millis, {
    bool keep = false,
  }) async {
    if (!mounted) return;
    setState(() {
      _overlayText = text;
      _overlayVisible = true;
    });
    await Future.delayed(Duration(milliseconds: millis));
    if (mounted && !keep) setState(() => _overlayVisible = false);
    await Future.delayed(const Duration(milliseconds: 120));
  }

  Future<void> _showPinDialogForChange() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _PinAuthDialog();
      },
    );
    if (ok == true) {
      setState(() {
        _isSettingPattern = true;
        _patternVerified = false;
        _showStopButton = false;
        _clearDrawing();
      });
      _showTemporaryMessage('Draw new pattern');

      // ✅ Speak pattern change
      await _speak("Draw new pattern");
    }
  }

  void _onStopTapped(Offset localPos) {
    if (_isProcessingStop) return;

    _stopMicAccess();

    setState(() => _isProcessingStop = true);

    final double w = buttonWidth;
    final double h = buttonHeight;
    final double x = localPos.dx.clamp(0.0, w);
    final double y = localPos.dy.clamp(0.0, h);
    final double yLine = -(h / w) * x + h;
    final bool leftSide = y > yLine;
    String chosen;
    if (leftSide) {
      chosen = 'normal';
    } else {
      final choices = ['crackle', 'wheeze', 'both'];
      chosen = choices[_rnd.nextInt(choices.length)];
    }

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => _AnalysisLoadingPage(
              chosenSide: chosen,
              seedRandom: _rnd.nextInt(100000),
            ),
          ),
        )
        .then((_) {
          if (mounted) setState(() => _isProcessingStop = false);
        });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(backgroundAsset, fit: BoxFit.cover),
          ),
          Positioned(
            left: 0.0,
            top: 0.0,
            width: 120,
            height: 160,
            child: Image.asset(lungsAsset, fit: BoxFit.contain),
          ),

          // Microphone status indicator
          if (_isMicActive)
            Positioned(
              right: 16,
              top: 50,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.mic, color: Colors.white, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'Recording',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Text(
                        _isSettingPattern
                            ? 'Set your unlock pattern'
                            : (!_patternVerified
                                  ? 'Draw your pattern to unlock'
                                  : ' '),
                        style: TextStyle(
                          fontSize: 28,
                          color: _showWrongPattern
                              ? Colors.redAccent
                              : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    if (!_patternVerified && _storedPattern != null)
                      TextButton(
                        onPressed: _showPinDialogForChange,
                        child: const Text(
                          'Change pattern with PIN',
                          style: TextStyle(fontSize: 22),
                        ),
                      ),
                    const SizedBox(height: 14),

                    if (!_patternVerified || _isSettingPattern)
                      SizedBox(
                        width: min(size.width, size.height) * 0.42,
                        height: min(size.width, size.height) * 0.42,
                        child: _PatternLockWidget(
                          size: min(size.width, size.height) * 0.42,
                          dotRadius: min(size.width, size.height) * 0.02,
                          selected: _selected,
                          onUpdateSelected: (list) {
                            if (mounted) {
                              setState(
                                () => _selected
                                  ..clear()
                                  ..addAll(list),
                              );
                            }
                          },
                          onComplete: _finishDrawingPattern,
                          isError: _showWrongPattern,
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (_showStopButton) _buildStopButton(size),
                  ],
                ),
              ),
            ),
          ),

          if (_showBreathingAnimation)
            Positioned(
              top: size.height / 2 - 200,
              left: size.width / 2 - 75,
              child: SizedBox(
                width: 150,
                height: 150,
                child: _BreathingLungsAnimation(),
              ),
            ),

          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _overlayVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _overlayText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopButton(Size screenSize) {
    return SizedBox(
      width: buttonWidth,
      height: buttonHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final local = details.localPosition;
          _onStopTapped(local);
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(buttonBorderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
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
              Positioned(
                left: buttonTextLeft,
                top: buttonTextTop,
                child: Text(
                  _isProcessingStop ? 'Analyzing...' : 'Stop Recording',
                  style: TextStyle(
                    fontSize: buttonTextFontSize,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _stopMicAccess();
    _tts.stop(); // ✅ ADD: Stop TTS
    super.dispose();
  }
}

// Pattern lock widget (3x3)
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
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _sel.addAll(widget.selected);
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
        setState(() {
          _active = true;
          _current = ev.localPosition;
        });
        _updateSelection(ev.localPosition);
      },
      onPointerMove: (ev) {
        setState(() {
          _current = ev.localPosition;
        });
        _updateSelection(ev.localPosition);
      },
      onPointerUp: (ev) {
        setState(() {
          _active = false;
          _current = null;
        });
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
          _buildKeypad(),
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

  Widget _buildKeypad() {
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

    return Wrap(
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
    );
  }
}

// ✅ MODIFIED: Added TTS to _AnalysisLoadingPage
class _AnalysisLoadingPage extends StatefulWidget {
  final String chosenSide;
  final int seedRandom;
  const _AnalysisLoadingPage({
    required this.chosenSide,
    required this.seedRandom,
  });

  @override
  State<_AnalysisLoadingPage> createState() => _AnalysisLoadingPageState();
}

class _AnalysisLoadingPageState extends State<_AnalysisLoadingPage>
    with TickerProviderStateMixin {
  static const String backgroundAsset = 'assets/background.png';
  static const String lungsAsset = 'assets/lungs_ai.png';

  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  // ✅ ADD TTS
  final TtsManager _tts = TtsManager();

  final List<String> _messages = [
    'Filtering background noise...',
    'Normalizing spectral bands...',
    'Detecting crackles and wheezes...',
    'Running temporal envelope analysis...',
    'Calibrating AI model...',
    'Comparing against 8709 samples...',
    'Extracting spectral fingerprints...',
    'Applying denoise filter...',
    'Scoring probable events...',
    'Preparing final confidence vectors...',
  ];

  int _msgIndex = 0;
  Timer? _ticker;
  late Random _rnd;
  late final int _delayMs;

  @override
  void initState() {
    super.initState();
    _rnd = Random(widget.seedRandom);
    _delayMs = 7000 + _rnd.nextInt(3001);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _initTts(); // ✅ ADD: Initialize TtsManager
    _startTicker();
    _startDelayedResult();
  }

  // ✅ Initialize TtsManager
  Future<void> _initTts() async {
    try {
      await _tts.initialize();

      // Listen to TTS state changes to update UI
      _tts.addListener(() {
        if (mounted) setState(() {});
      });

      // ✅ Speak first message
      await Future.delayed(const Duration(milliseconds: 300));
      _speak(_messages[_msgIndex]);
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

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      setState(() => _msgIndex = (_msgIndex + 1) % _messages.length);

      // ✅ Speak every other message
      if (_msgIndex % 2 == 0) {
        _speak(_messages[_msgIndex]);
      }
    });
  }

  Future<void> _startDelayedResult() async {
    await Future.delayed(Duration(milliseconds: _delayMs));
    _ticker?.cancel();
    _controller.dispose();

    // ✅ Speak analysis complete
    await _speak("Analysis complete. Displaying results");

    final result = _generatePercentages(widget.chosenSide);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultPage(
          percentages: result,
          mainLabel: _determineMainLabel(result),
        ),
      ),
    );
  }

  Map<String, double> _generatePercentages(String chosenSide) {
    final r = Random();
    double crackle = r.nextDouble() * 20;
    double wheeze = r.nextDouble() * 20;
    double both = r.nextDouble() * 20;
    double normal = r.nextDouble() * 40;

    if (chosenSide == 'normal') {
      normal += 40 + r.nextDouble() * 15;
    } else if (chosenSide == 'crackle') {
      crackle += 40 + r.nextDouble() * 20;
    } else if (chosenSide == 'wheeze') {
      wheeze += 40 + r.nextDouble() * 20;
    } else if (chosenSide == 'both') {
      both += 40 + r.nextDouble() * 20;
    }

    final total = crackle + wheeze + normal + both;
    return {
      'crackle': (crackle / total) * 100,
      'wheeze': (wheeze / total) * 100,
      'normal': (normal / total) * 100,
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
    _ticker?.cancel();
    _controller.dispose();
    _tts.stop(); // ✅ ADD: Stop TTS
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

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
            width: 120,
            height: 160,
            child: Image.asset(lungsAsset, fit: BoxFit.contain),
          ),
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Image.asset(lungsAsset, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: size.width * 0.8,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      transitionBuilder: (child, anim) {
                        final offsetAnim = Tween<Offset>(
                          begin: const Offset(0, 0.4),
                          end: Offset.zero,
                        ).animate(anim);
                        return SlideTransition(
                          position: offsetAnim,
                          child: FadeTransition(opacity: anim, child: child),
                        );
                      },
                      child: Text(
                        _messages[_msgIndex],
                        key: ValueKey<int>(_msgIndex),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 40,
                          color: Colors.black87,
                        ),
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

class _BreathingLungsAnimation extends StatefulWidget {
  @override
  _BreathingLungsAnimationState createState() =>
      _BreathingLungsAnimationState();
}

class _BreathingLungsAnimationState extends State<_BreathingLungsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Image.asset(
        _LoadingStethoscopePageState.lungsAsset,
        fit: BoxFit.contain,
      ),
    );
  }
}
