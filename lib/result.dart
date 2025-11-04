// lib/result.dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart'; // ✅ ADD THIS
import 'scale.dart';
import 'dart:math';

class ResultPage extends StatefulWidget {
  // ✅ Changed to StatefulWidget
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
  // ✅ ADD TTS
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initTtsAndSpeak();
  }

  // ✅ ADD: Initialize TTS and speak results
  Future<void> _initTtsAndSpeak() async {
    _flutterTts = FlutterTts();

    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      if (Theme.of(context).platform == TargetPlatform.android) {
        await _flutterTts.setVoice({
          "name": "en-us-x-tpf-network",
          "locale": "en-US",
        });
      }

      _flutterTts.setStartHandler(() {
        if (mounted) setState(() => _isSpeaking = true);
      });

      _flutterTts.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint("TTS Error: $msg");
        if (mounted) setState(() => _isSpeaking = false);
      });

      // ✅ Speak results
      await Future.delayed(const Duration(milliseconds: 500));
      await _speakResults();
    } catch (e) {
      debugPrint("❌ TTS error: $e");
    }
  }

  // ✅ ADD: Speak method
  Future<void> _speak(String text) async {
    try {
      if (_isSpeaking) {
        await _flutterTts.stop();
      }
      debugPrint("🔊 Speaking: $text");
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("❌ TTS speak error: $e");
    }
  }

  // ✅ ADD: Speak the analysis results
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

    // Add interpretation
    if (widget.mainLabel.toLowerCase() == 'normal') {
      announcement += "Lung sounds appear normal.";
    } else if (widget.mainLabel.toLowerCase() == 'crackle') {
      announcement += "Crackles detected. Consider medical consultation.";
    } else if (widget.mainLabel.toLowerCase() == 'wheeze') {
      announcement += "Wheezes detected. Consider medical consultation.";
    } else if (widget.mainLabel.toLowerCase() == 'both') {
      announcement +=
          "Both crackles and wheezes detected. Medical consultation recommended.";
    }

    await _speak(announcement);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = 'assets/background.png';
    final lungs = 'assets/lungs_ai.png';

    // clamp and sort for display order
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

                      // Add a small detailed card
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
                        onPressed: () {
                          // ✅ Speak before navigating back
                          _speak("Returning to home screen");
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

          // ✅ ADD: Speaking indicator
          if (_isSpeaking)
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
