// lib/result.dart
import 'package:flutter/material.dart';
import 'tts_manager.dart'; // ✅ UPDATED: Use TtsManager
import 'arduino_service.dart'; // ✅ NEW: Import Arduino Service
import 'scale.dart';
import 'dart:math';

class ResultPage extends StatefulWidget {
  final Map<String, double>
  percentages; // keys: 'crackle','wheeze','normal','both'
  final String mainLabel; // which label is highest

  const ResultPage({
    super.key,
    required this.percentages,
    required this.mainLabel,
  });

  @override
  _ResultPageState createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  final TtsManager _tts = TtsManager(); // ✅ UPDATED: Use TtsManager
  final ArduinoService _arduino = ArduinoService(); // ✅ NEW: Arduino Service

  @override
  void initState() {
    super.initState();
    _initTtsAndSpeak();
    _initArduino(); // ✅ NEW: Initialize Arduino
  }

  // ✅ NEW: Initialize Arduino with result
  Future<void> _initArduino() async {
    await Future.delayed(const Duration(milliseconds: 200));

    final result = widget.mainLabel.toUpperCase();
    final resultShort = result.length > 8 ? result.substring(0, 8) : result;

    // Update LCD with result
    await _arduino.updateLCD('Result:', resultShort);

    // Bot gesture based on result
    if (widget.mainLabel.toLowerCase() == 'normal') {
      // Normal: Thumbs up (right hand)
      await _arduino.setBotPosition(head: 0, handL: 0, handR: 90);
    } else if (widget.mainLabel.toLowerCase() == 'crackle') {
      // Crackle: Concerned (left hand up)
      await _arduino.setBotPosition(head: -20, handL: 70, handR: 0);
    } else if (widget.mainLabel.toLowerCase() == 'wheeze') {
      // Wheeze: Alert (right hand up)
      await _arduino.setBotPosition(head: 20, handL: 0, handR: 70);
    } else if (widget.mainLabel.toLowerCase() == 'both') {
      // Both: Warning (both hands up)
      await _arduino.setBotPosition(head: 0, handL: 80, handR: 80);
    }

    await Future.delayed(const Duration(milliseconds: 2000));

    // Update LCD to show confidence
    final mainPercentage = widget.percentages[widget.mainLabel]?.round() ?? 0;
    await _arduino.updateLCD(resultShort, '$mainPercentage% Confidence');
  }

  // ✅ UPDATED: Initialize TtsManager and speak results
  Future<void> _initTtsAndSpeak() async {
    try {
      await _tts.initialize();

      _tts.addListener(() {
        if (mounted) setState(() {});
      });

      await Future.delayed(const Duration(milliseconds: 500));
      await _speakResults();
    } catch (e) {
      debugPrint("❌ TTS error: $e");
    }
  }

  // ✅ UPDATED: Speak method using TtsManager
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

  // ✅ UPDATED: Speak the analysis results with Arduino animations
  Future<void> _speakResults() async {
    final order = ['normal', 'crackle', 'wheeze', 'both'];
    final entries = order
        .map((k) => MapEntry(k, widget.percentages[k] ?? 0.0))
        .toList();

    // Build result announcement
    String announcement = "Analysis complete. ";
    announcement += "Main detection: ${widget.mainLabel}. ";

    // Add percentages
    announcement += "Confidence levels: ";
    for (var entry in entries) {
      final rounded = entry.value.round();
      announcement += "${entry.key}, $rounded percent. ";
    }

    // ✅ LCD: Show all percentages (cycle through)
    for (var entry in entries) {
      if (!mounted) break;
      final label = entry.key.toUpperCase();
      final labelShort = label.length > 8 ? label.substring(0, 8) : label;
      final percent = entry.value.round();
      await _arduino.updateLCD(labelShort, '$percent%');
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    // Add interpretation
    if (widget.mainLabel.toLowerCase() == 'normal') {
      announcement += "Lung sounds appear normal.";

      // ✅ LCD: Normal result
      await _arduino.updateLCD('Normal Lungs', 'All Clear!');

      // ✅ Bot: Happy gesture (both hands up briefly)
      await _arduino.setBotPosition(head: 0, handL: 90, handR: 90);
      await Future.delayed(const Duration(milliseconds: 800));
      await _arduino.setBotPosition(head: 0, handL: 0, handR: 90);
    } else if (widget.mainLabel.toLowerCase() == 'crackle') {
      announcement += "Crackles detected. Consider medical consultation.";

      // ✅ LCD: Crackle warning
      await _arduino.updateLCD('Crackles Found', 'See Doctor');

      // ✅ Bot: Concerned gesture
      await _arduino.setBotPosition(head: -25, handL: 80, handR: 0);
    } else if (widget.mainLabel.toLowerCase() == 'wheeze') {
      announcement += "Wheezes detected. Consider medical consultation.";

      // ✅ LCD: Wheeze warning
      await _arduino.updateLCD('Wheezes Found', 'See Doctor');

      // ✅ Bot: Alert gesture
      await _arduino.setBotPosition(head: 25, handL: 0, handR: 80);
    } else if (widget.mainLabel.toLowerCase() == 'both') {
      announcement +=
          "Both crackles and wheezes detected. Medical consultation recommended.";

      // ✅ LCD: Both warning
      await _arduino.updateLCD('Both Detected!', 'Urgent Care');

      // ✅ Bot: Warning gesture (both hands high)
      await _arduino.setBotPosition(head: 0, handL: 90, handR: 90);
    }

    await _speak(announcement);
  }

  @override
  void dispose() {
    _tts.stop();
    _arduino.gestureReset(); // ✅ NEW: Reset bot on exit
    super.dispose();
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
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(bg, fit: BoxFit.cover)),
          Positioned(
            left: 0,
            top: 0,
            width: S.w(context, 120),
            height: S.h(context, 160),
            child: Image.asset(lungs, fit: BoxFit.contain),
          ),

          // main content
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
                                    duration: const Duration(milliseconds: 600),
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

                      // Detailed card
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
                          // ✅ UPDATED: Arduino feedback before navigation
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
