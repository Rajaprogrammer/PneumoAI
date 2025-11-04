// lib/splash_screen.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'tts_manager.dart'; // ✅ IMPORT TTS MANAGER
import 'next_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Controllers
  late final AnimationController _rocketController;
  late final AnimationController _shakeController;
  late final AnimationController _waveController;
  late final AnimationController _logoDropController;
  late final AnimationController _finalParticlesController;
  late final AnimationController _checkScaleController;

  // ✅ TTS Engine (using TtsManager)
  final TtsManager _tts = TtsManager();

  final Random _random = Random();

  // Stage state
  int _stage = 0;
  bool _engineInitializedTextShown = false;

  // Rockets and particles
  final List<_Rocket> _rockets = [];
  final int _numRockets = 9;
  final List<_Particle> _particles = [];

  @override
  @override
  void initState() {
    super.initState();

    _initTts();

    _rocketController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _logoDropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _finalParticlesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _checkScaleController = AnimationController(
      // 🧩 FIXED
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _finalParticlesController.addListener(() {
      if (mounted) setState(() {});
    });

    _tts.addListener(() {
      if (mounted) setState(() {});
    });

    _startSequence();
  }

  // ✅ Initialize TtsManager
  Future<void> _initTts() async {
    try {
      await _tts.initialize();
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

  Future<void> _startSequence() async {
    if (!mounted) return;

    // ✅ Stage 0: Activation (10s)
    setState(() {
      _stage = 0;
      _engineInitializedTextShown = false;
    });

    // ✅ Speak: "Activating AI Engine"
    await _speak("Activating AI Engine");
    await Future.delayed(const Duration(milliseconds: 500));

    _shakeController.repeat(reverse: true);
    await Future.delayed(const Duration(seconds: 10));
    if (!mounted) return;

    // Show AI initialized text
    setState(() {
      _engineInitializedTextShown = true;
    });
    _shakeController.stop(canceled: false);

    // ✅ Speak: "AI Engine Initialized Successfully"
    await _speak("AI Engine Initialized Successfully");

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // ✅ Stage 1: Comparing audio samples (10s)
    setState(() {
      _stage = 1;
      _engineInitializedTextShown = false;
    });

    // ✅ Speak: "Comparing Audio Samples"
    await _speak("Comparing Audio Samples");
    await Future.delayed(const Duration(milliseconds: 800));

    // ✅ Speak analysis phrases during stage 1
    _speakAnalysisPhrases();

    await Future.delayed(const Duration(seconds: 10));
    if (!mounted) return;

    // ✅ Stage 2: Final PneumoAI initialized
    setState(() {
      _stage = 2;
    });

    _createParticles();
    _logoDropController.forward(from: 0.0);
    _finalParticlesController.repeat();
    _checkScaleController.forward(from: 0.0);

    // ✅ Speak: "PneumoAI Initialized Successfully"
    await Future.delayed(const Duration(milliseconds: 600));
    await _speak(
      "PneumoAI Initialized Successfully. Systems nominal. Ready to analyze.",
    );

    await Future.delayed(const Duration(seconds: 10));
    if (!mounted) return;

    // Stop animations
    _finalParticlesController.stop(canceled: false);
    _logoDropController.reset();
    _checkScaleController.reset();
    _particles.clear();

    // Stop any ongoing speech
    await _tts.stop();

    // Navigate
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => NextPage()),
    );
  }

  // ✅ Speak analysis phrases during stage 1
  Future<void> _speakAnalysisPhrases() async {
    final phrases = [
      "Detecting crackles and wheezes",
      "Filtering background noise",
      "Analyzing spectral fingerprints",
    ];

    for (int i = 0; i < phrases.length && _stage == 1; i++) {
      await Future.delayed(const Duration(milliseconds: 2500));
      if (_stage == 1 && mounted) {
        await _speak(phrases[i]);
      }
    }
  }

  @override
  void dispose() {
    _rocketController.dispose();
    _shakeController.dispose();
    _waveController.dispose();
    _logoDropController.dispose();
    _finalParticlesController.dispose();
    _checkScaleController.dispose();

    // ✅ Clean up TTS
    _tts.stop();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final botSize = min(size.width, size.height) * 0.34;
    final logoSize = min(size.width, size.height) * 0.24;
    final titleFont = (min(size.width, size.height) * 0.045).clamp(20.0, 40.0);
    final subtitleFont = (min(size.width, size.height) * 0.032).clamp(
      16.0,
      30.0,
    );

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.cover),
          ),

          // ✅ Speaking indicator (using TtsManager)
          if (_tts.isSpeaking)
            Positioned(
              top: 50,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade400.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.volume_up, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Speaking',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Foreground animations
          AnimatedBuilder(
            animation: _shakeController,
            builder: (context, child) {
              double vibrate = 0.0;
              if (_stage == 0 && !_engineInitializedTextShown) {
                vibrate = 6.0 * sin(_shakeController.value * pi * 2);
              }
              return Transform.translate(
                offset: Offset(vibrate, 0),
                child: child,
              );
            },
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: _buildStageContent(
                      size,
                      botSize,
                      logoSize,
                      titleFont,
                      subtitleFont,
                    ),
                  ),
                ),
                if (_stage == 2 && _particles.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ParticlePainter(
                          _particles,
                          _finalParticlesController.value,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageContent(
    Size size,
    double botSize,
    double logoSize,
    double titleFont,
    double subtitleFont,
  ) {
    switch (_stage) {
      case 0:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: botSize,
                height: botSize,
                child: Image.asset('assets/ai_bot.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 28),
              Text(
                !_engineInitializedTextShown
                    ? "Activating AI Engine..."
                    : "AI Engine Initialized Successfully",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: titleFont,
                  fontWeight: FontWeight.w800,
                  shadows: !_engineInitializedTextShown
                      ? [
                          Shadow(
                            color: Colors.blue.withOpacity(0.12),
                            blurRadius: 12,
                          ),
                        ]
                      : [
                          Shadow(
                            color: Colors.green.withOpacity(0.15),
                            blurRadius: 18,
                          ),
                        ],
                ),
              ),
              const SizedBox(height: 16),
              Opacity(
                opacity: _engineInitializedTextShown ? 0.0 : 1.0,
                child: Text(
                  "Booting neural modules · calibrating sensors",
                  style: TextStyle(
                    fontSize: subtitleFont * 0.8,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        );

      case 1:
        final List<String> phrases = [
          "Detecting crackles and wheezes....",
          "Filtering background noise...",
          "Detecting wheezes and crackles...",
          "Analyzing spectral fingerprints...",
        ];
        return StatefulBuilder(
          builder: (context, setState) {
            int currentPhrase = 0;
            Timer.periodic(const Duration(milliseconds: 2500), (timer) {
              if (!mounted || _stage != 1) {
                timer.cancel();
                return;
              }
              setState(() {
                currentPhrase = (currentPhrase + 1) % phrases.length;
              });
            });

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Comparing Audio Samples...",
                    style: TextStyle(
                      color: Colors.blueAccent.shade700,
                      fontSize: titleFont,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: size.width * 0.78,
                    height: size.height * 0.26,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _waveController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _waveController.value * pi * 2,
                              child: Container(
                                width: size.width * 0.48,
                                height: size.width * 0.48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.blueAccent.withOpacity(0.12),
                                    width: 8,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 8,
                          bottom: 8,
                          child: Center(
                            child: SizedBox(
                              height: size.height * 0.12,
                              child: WaveformAnimation(
                                controller: _waveController,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 6,
                          left: 12,
                          right: 12,
                          child: SizedBox(
                            height: size.height * 0.10,
                            child: SpectrumBars(controller: _waveController),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    phrases[currentPhrase],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: subtitleFont * 0.95,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            );
          },
        );

      case 2:
        return Stack(
          children: [
            AnimatedBuilder(
              animation: _logoDropController,
              builder: (context, child) {
                final t = Curves.easeOutBack.transform(
                  _logoDropController.value,
                );
                final top = lerpDouble(-logoSize, size.height * 0.18, t)!;
                return Positioned(
                  top: top,
                  left: (size.width - logoSize) / 2,
                  child: SizedBox(
                    width: logoSize,
                    height: logoSize,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(
                              0.28 * t + 0.1,
                            ),
                            blurRadius: 30 * t + 8,
                            spreadRadius: 8 * t,
                          ),
                        ],
                      ),
                      child: Image.asset('assets/logo.png'),
                    ),
                  ),
                );
              },
            ),
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.6, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _checkScaleController,
                        curve: Curves.elasticOut,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.greenAccent.shade400.withOpacity(0.95),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.shade200.withOpacity(0.6),
                            blurRadius: 18,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(18),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "PneumoAI Initialized Successfully",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w900,
                      fontSize: titleFont * 0.95,
                      shadows: [
                        Shadow(
                          color: Colors.green.withOpacity(0.12),
                          blurRadius: 22,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Systems nominal · Ready to analyze",
                    style: TextStyle(
                      fontSize: subtitleFont * 0.9,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  void _createParticles() {
    _particles.clear();
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    for (int i = 0; i < 26; i++) {
      final angle = _random.nextDouble() * pi * 2;
      final speed = 120.0 + _random.nextDouble() * 200.0;
      final radius = 4.0 + _random.nextDouble() * 6.0;
      final color = _colors[_random.nextInt(_colors.length)];
      _particles.add(
        _Particle(
          origin: Offset(w / 2, h * 0.25),
          vx: cos(angle) * speed,
          vy: sin(angle) * speed - 60,
          radius: radius,
          color: color,
          life: 1.6 + _random.nextDouble() * 1.0,
        ),
      );
    }
  }

  static const List<Color> _colors = [
    Colors.redAccent,
    Colors.orangeAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.purpleAccent,
    Colors.yellowAccent,
  ];
}

// ==================== Helper Classes ====================

class WaveformAnimation extends StatelessWidget {
  final AnimationController controller;
  const WaveformAnimation({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(painter: WaveformPainter(controller.value));
      },
    );
  }
}

class WaveformPainter extends CustomPainter {
  final double progress;
  WaveformPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..shader = LinearGradient(
        colors: [Colors.blueAccent, Colors.lightBlueAccent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path path = Path();
    for (double x = 0; x <= size.width; x++) {
      final t = (x / size.width) * 4 * pi;
      final y =
          size.height / 2 + (size.height / 2.5) * sin(t + progress * 6.28);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) => true;
}

class SpectrumBars extends StatelessWidget {
  final AnimationController controller;
  const SpectrumBars({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(painter: SpectrumPainter(controller.value));
      },
    );
  }
}

class SpectrumPainter extends CustomPainter {
  final double progress;
  SpectrumPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final int bars = 20;
    final double gap = 6.0;
    final double barW = (size.width - (bars - 1) * gap) / bars;
    final centerY = size.height / 2;

    for (int i = 0; i < bars; i++) {
      final double phase = (i / bars) * pi * 2;
      final double h =
          (size.height * 0.9) *
          (0.2 + 0.8 * (0.5 + 0.5 * sin(progress * 2 * pi + phase * 1.3)));
      final rect = Rect.fromLTWH(i * (barW + gap), centerY - h / 2, barW, h);

      paint.shader = LinearGradient(
        colors: [
          Colors.blueAccent.withOpacity(0.95 - i * 0.02),
          Colors.lightBlueAccent.withOpacity(0.6),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SpectrumPainter oldDelegate) => true;
}

class _Rocket {
  double x;
  double y;
  double vx;
  double vy;
  double angle;
  double size;
  final Random random;

  _Rocket(this.random)
    : x = random.nextDouble() * 900,
      y = -20.0 - random.nextDouble() * 600.0,
      vx = -10 + random.nextDouble() * 20,
      vy = 60 + random.nextDouble() * 180,
      angle = random.nextDouble() * pi * 2,
      size = 28 + random.nextDouble() * 40;

  void update(Size screen, {bool falling = false}) {
    if (falling) {
      vy += 4 * (0.7 + random.nextDouble() * 0.6);
      y += vy * 0.016;
      x += vx * 0.016;
      angle += 0.04;
    } else {
      x += (vx * 0.004);
      y += (vy * 0.004);
      angle += 0.01;
    }

    if (y > screen.height + 100 || x < -120 || x > screen.width + 120) {
      x = random.nextDouble() * screen.width;
      y = -40 - random.nextDouble() * 200;
      vx = -30 + random.nextDouble() * 60;
      vy = 80 + random.nextDouble() * 160;
      size = 24 + random.nextDouble() * 46;
      angle = random.nextDouble() * pi * 2;
    }
  }

  void reset(Random r) {
    x = r.nextDouble() * 900;
    y = -20.0 - r.nextDouble() * 600.0;
    vx = -10 + r.nextDouble() * 20;
    vy = 60 + r.nextDouble() * 180;
    angle = r.nextDouble() * pi * 2;
    size = 24 + r.nextDouble() * 46;
  }
}

class _Particle {
  final Offset origin;
  final double vx;
  final double vy;
  final double radius;
  final Color color;
  final double life;

  _Particle({
    required this.origin,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.color,
    required this.life,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;

  _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var p in particles) {
      final life = p.life;
      final f = Curves.easeOut.transform(
        min(1.0, t * (1.0 + 0.6 * (1.0 / life))),
      );
      final dx = p.vx * f;
      final dy = p.vy * f + (50.0 * f * f);
      final pos = Offset(p.origin.dx + dx, p.origin.dy + dy);
      paint.color = p.color.withOpacity((1.0 - f).clamp(0.0, 1.0));
      canvas.drawCircle(pos, p.radius * (1.0 - 0.2 * f), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
