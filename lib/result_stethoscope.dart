import 'package:flutter/material.dart';
import 'tts_manager.dart';
import 'arduino_service.dart'; // ✅ NEW: Import Arduino Service
import 'scale.dart';
import 'prediction_logs.dart';
import 'dart:math';

class ResultStethoscopePage extends StatefulWidget {
  final Map<String, double>
  percentages; // keys: 'normal','wheeze','crackle','both'
  final String mainLabel;
  final List<String>? logs;

  const ResultStethoscopePage({
    super.key,
    required this.percentages,
    required this.mainLabel,
    this.logs,
  });

  @override
  State<ResultStethoscopePage> createState() => _ResultStethoscopePageState();
}

class _ResultStethoscopePageState extends State<ResultStethoscopePage> {
  int _tapCount = 0;
  DateTime? _firstTapAt;

  final TtsManager _tts = TtsManager();
  final ArduinoService _arduino = ArduinoService(); // ✅ NEW: Arduino Service

  @override
  void initState() {
    super.initState();
    _initTts();
    _initArduino(); // ✅ NEW: Initialize Arduino
    _speakResults();
  }

  // ✅ NEW: Initialize Arduino with stethoscope result
  Future<void> _initArduino() async {
    await Future.delayed(const Duration(milliseconds: 200));

    final resultShort = widget.mainLabel.length > 8
        ? widget.mainLabel.substring(0, 8)
        : widget.mainLabel;

    // Display main result on LCD
    await _arduino.updateLCD('Lung Sound:', resultShort);

    // Bot gesture based on result
    final mainLower = widget.mainLabel.toLowerCase();

    if (mainLower == 'normal') {
      // Normal: Thumbs up (right hand)
      await _arduino.setBotPosition(head: 0, handL: 0, handR: 90);

      await Future.delayed(const Duration(milliseconds: 1500));

      final normalPercent = widget.percentages['normal']?.round() ?? 0;
      await _arduino.updateLCD('Normal Lungs', '$normalPercent% Sure');
    } else if (mainLower == 'crackle') {
      final crackleVal = widget.percentages['crackle'] ?? 0.0;

      if (crackleVal >= 70) {
        // High crackle: Both hands up (warning)
        await _arduino.setBotPosition(head: -20, handL: 85, handR: 0);

        await Future.delayed(const Duration(milliseconds: 1500));
        await _arduino.updateLCD('Crackles!', 'See Doctor');
      } else {
        // Moderate crackle: Left hand up
        await _arduino.setBotPosition(head: -15, handL: 70, handR: 0);

        await Future.delayed(const Duration(milliseconds: 1500));
        await _arduino.updateLCD('Crackles', 'Get Checked');
      }
    } else if (mainLower == 'wheeze') {
      final wheezeVal = widget.percentages['wheeze'] ?? 0.0;

      if (wheezeVal >= 70) {
        // High wheeze: Both hands up (warning)
        await _arduino.setBotPosition(head: 20, handL: 0, handR: 85);

        await Future.delayed(const Duration(milliseconds: 1500));
        await _arduino.updateLCD('Wheezes!', 'See Doctor');
      } else {
        // Moderate wheeze: Right hand up
        await _arduino.setBotPosition(head: 15, handL: 0, handR: 70);

        await Future.delayed(const Duration(milliseconds: 1500));
        await _arduino.updateLCD('Wheezes', 'Get Checked');
      }
    } else if (mainLower == 'both') {
      // Both detected: Maximum warning (both hands high)
      await _arduino.setBotPosition(head: 0, handL: 90, handR: 90);

      await Future.delayed(const Duration(milliseconds: 1500));
      await _arduino.updateLCD('Both Found!', 'See Doctor');
    }
  }

  Future<void> _initTts() async {
    try {
      await _tts.initialize();

      _tts.addListener(() {
        if (mounted) setState(() {});
      });
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

  // ✅ UPDATED: Speak results with Arduino animations
  Future<void> _speakResults() async {
    final order = ['normal', 'crackle', 'wheeze', 'both'];
    final entries = order
        .map((k) => MapEntry(k, widget.percentages[k] ?? 0.0))
        .toList();

    String announcement = "Lung sound analysis complete. ";
    announcement += "Main detection: ${widget.mainLabel}. ";

    // ✅ Cycle through percentages on LCD
    await Future.delayed(const Duration(milliseconds: 1000));
    for (var entry in entries) {
      if (!mounted) break;
      final label = entry.key.toUpperCase();
      final labelShort = label.length > 8 ? label.substring(0, 8) : label;
      final percent = entry.value.round();
      await _arduino.updateLCD(labelShort, '$percent%');
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    announcement += "Confidence levels: ";
    for (var entry in entries) {
      final rounded = entry.value.round();
      announcement += "${entry.key}, $rounded percent. ";
    }

    // Add medical interpretation
    final mainLower = widget.mainLabel.toLowerCase();

    if (mainLower == 'normal') {
      announcement += "Lung sounds appear normal. No abnormalities detected.";

      // ✅ Bot: Celebration
      await _arduino.setBotPosition(head: 0, handL: 90, handR: 90);
      await Future.delayed(const Duration(milliseconds: 800));
      await _arduino.setBotPosition(head: 0, handL: 0, handR: 90);

      await _arduino.updateLCD('All Clear!', 'Healthy Lungs');
    } else if (mainLower == 'crackle') {
      final crackleVal = widget.percentages['crackle'] ?? 0.0;

      if (crackleVal >= 70) {
        announcement +=
            "Significant crackles detected. These may indicate fluid in the lungs. Medical consultation recommended.";

        await _arduino.updateLCD('High Crackle', 'Urgent Care');
        await _arduino.setBotPosition(head: -25, handL: 90, handR: 0);
      } else {
        announcement +=
            "Crackles detected. Consider medical evaluation for proper diagnosis.";

        await _arduino.updateLCD('Crackles', 'Consult Doctor');
      }
    } else if (mainLower == 'wheeze') {
      final wheezeVal = widget.percentages['wheeze'] ?? 0.0;

      if (wheezeVal >= 70) {
        announcement +=
            "Significant wheezing detected. This may indicate airway obstruction. Medical consultation recommended.";

        await _arduino.updateLCD('High Wheeze', 'Urgent Care');
        await _arduino.setBotPosition(head: 25, handL: 0, handR: 90);
      } else {
        announcement +=
            "Wheezing detected. Consider medical evaluation for proper diagnosis.";

        await _arduino.updateLCD('Wheezes', 'Consult Doctor');
      }
    } else if (mainLower == 'both') {
      announcement +=
          "Both crackles and wheezes detected. This indicates possible respiratory complications. Medical consultation strongly recommended.";

      await _arduino.updateLCD('BOTH ISSUES!', 'See Doctor NOW');
      // Bot maintains both hands up warning
    }

    await _speak(announcement);
  }

  @override
  void dispose() {
    _tts.stop();
    _arduino.gestureReset(); // ✅ NEW: Reset bot on exit
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

      _speak("Opening prediction logs");

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PredictionLogsPage(logs: widget.logs ?? const <String>[]),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = 'assets/background.png';
    final lungs = 'assets/lungs_ai.png';

    final order = ['normal', 'crackle', 'wheeze', 'both'];
    final entries = order
        .map((k) => MapEntry(k, widget.percentages[k] ?? 0.0))
        .toList();

    final maxVal = entries.map((e) => e.value).fold<double>(0.0, max);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleGlobalTap,
        child: Stack(
          children: [
            Positioned.fill(child: Image.asset(bg, fit: BoxFit.cover)),
            Positioned(
              left: 0,
              top: 0,
              width: S.w(context, 120),
              height: S.h(context, 160),
              child: Image.asset(lungs, fit: BoxFit.contain),
            ),
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: Container(
                    width: min(
                      MediaQuery.of(context).size.width * 0.84,
                      S.w(context, 1200),
                    ),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.86),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Analysis Result',
                          style: TextStyle(
                            fontSize: S.fs(context, 28),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Detected: ${widget.mainLabel.toUpperCase()}',
                          style: TextStyle(
                            fontSize: S.fs(context, 20),
                            fontWeight: FontWeight.w700,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Bars
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: entries.map((e) {
                            final label = e.key;
                            final val = e.value;
                            final barHeight =
                                (val / (maxVal == 0 ? 1 : maxVal)) * 220;
                            final color = _colorFor(label);
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18.0,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${val.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: S.fs(context, 14),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 60,
                                    height: 220,
                                    alignment: Alignment.bottomCenter,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 600,
                                      ),
                                      width: 60,
                                      height: barHeight,
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    label.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: S.fs(context, 14),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 22),

                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Confidence breakdown',
                                style: TextStyle(
                                  fontSize: S.fs(context, 16),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: entries.map((e) {
                                  return Chip(
                                    backgroundColor: _colorFor(
                                      e.key,
                                    ).withOpacity(0.14),
                                    label: Text(
                                      '${e.key}: ${e.value.toStringAsFixed(1)}%',
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            // ✅ Arduino feedback before exit
                            await _arduino.updateLCD('Returning', 'Home...');
                            await _arduino.gestureReset();

                            _speak("Returning to home screen");

                            await Future.delayed(
                              const Duration(milliseconds: 500),
                            );

                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                          },
                          child: const Text('Done'),
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
      ),
    );
  }

  Color _colorFor(String k) {
    switch (k) {
      case 'normal':
        return Colors.greenAccent.shade700;
      case 'crackle':
        return Colors.orangeAccent;
      case 'wheeze':
        return Colors.blueAccent;
      case 'both':
        return Colors.purpleAccent;
      default:
        return Colors.grey;
    }
  }
}
