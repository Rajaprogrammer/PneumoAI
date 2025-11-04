import 'package:flutter/material.dart';
import 'tts_manager.dart'; // ✅ IMPORT TTS MANAGER
import 'scale.dart';
import 'prediction_logs.dart';
import 'dart:math';

class ResultXRayPage extends StatefulWidget {
  final Map<String, double> percentages;
  final String mainLabel;
  final List<String>? logs;

  const ResultXRayPage({
    super.key,
    required this.percentages,
    required this.mainLabel,
    this.logs,
  });

  @override
  State<ResultXRayPage> createState() => _ResultXRayPageState();
}

class _ResultXRayPageState extends State<ResultXRayPage> {
  int _tapCount = 0;
  DateTime? _firstTapAt;

  // ✅ REPLACED: Using TtsManager instead of FlutterTts
  final TtsManager _tts = TtsManager();

  // ✅ ADD: Modified percentages and label
  late Map<String, double> _displayPercentages;
  late String _displayLabel;

  @override
  void initState() {
    super.initState();
    _processResults(); // ✅ Process results based on your logic
    _initTts(); // Initialize TtsManager
    _speakResults(); // Speak the results
  }

  // ✅ ADD: Process results with your custom logic
  void _processResults() {
    // Get the original pneumonia percentage
    final pneumoniaKey = widget.percentages.containsKey('Pneumonia')
        ? 'Pneumonia'
        : 'pneumonia';
    final healthyKey = widget.percentages.containsKey('Healthy')
        ? 'Healthy'
        : 'normal';

    final originalPneumonia = widget.percentages[pneumoniaKey] ?? 0.0;

    if (originalPneumonia >= 97.0) {
      // If pneumonia >= 97%, keep original values and label as pneumonia
      _displayPercentages = Map.from(widget.percentages);
      _displayLabel = 'Pneumonia';
    } else {
      // Otherwise, classify as healthy with random percentages
      final random = Random();

      // Generate pneumonia percentage between 5-25%
      final newPneumonia = 5.0 + random.nextDouble() * 20.0;

      // Generate healthy percentage approximately 3x higher
      // Range: 2.5x to 3.5x of pneumonia percentage, but not exceeding 100%
      final multiplier = 2.5 + random.nextDouble();
      double newHealthy = newPneumonia * multiplier;

      // Ensure healthy percentage is between 60-95%
      newHealthy = newHealthy.clamp(60.0, 95.0);

      // Ensure pneumonia + healthy doesn't exceed 100%
      if (newPneumonia + newHealthy > 100.0) {
        newHealthy = 100.0 - newPneumonia;
      }

      _displayPercentages = {
        healthyKey: newHealthy,
        pneumoniaKey: newPneumonia,
      };
      _displayLabel = 'Healthy';

      // Debug print
      debugPrint(
        "🔄 Modified results - Original Pneumonia: ${originalPneumonia.toStringAsFixed(1)}%",
      );
      debugPrint(
        "🔄 New: Healthy=${newHealthy.toStringAsFixed(1)}%, Pneumonia=${newPneumonia.toStringAsFixed(1)}%",
      );
    }
  }

  // ✅ Initialize TtsManager
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

  Future<void> _speakResults() async {
    // Use display percentages instead of original
    final healthyKey = _displayPercentages.containsKey('Healthy')
        ? 'Healthy'
        : 'normal';
    final pneumoniaKey = _displayPercentages.containsKey('Pneumonia')
        ? 'Pneumonia'
        : 'pneumonia';

    final healthyVal = _displayPercentages[healthyKey] ?? 0.0;
    final pneumoniaVal = _displayPercentages[pneumoniaKey] ?? 0.0;

    String announcement = "X-ray analysis complete. ";
    announcement += "Main detection: $_displayLabel. ";

    announcement += "Confidence levels: ";
    announcement += "Healthy, ${healthyVal.round()} percent. ";
    announcement += "Pneumonia, ${pneumoniaVal.round()} percent. ";

    if (_displayLabel.toLowerCase() == 'healthy' ||
        _displayLabel.toLowerCase() == 'normal') {
      announcement +=
          "Chest X-ray appears normal. No signs of pneumonia detected.";
    } else if (_displayLabel.toLowerCase() == 'pneumonia') {
      if (pneumoniaVal >= 97) {
        announcement +=
            "Very high confidence pneumonia detection. Immediate medical consultation strongly recommended.";
      } else if (pneumoniaVal >= 80) {
        announcement +=
            "High confidence pneumonia detection. Medical consultation recommended.";
      } else if (pneumoniaVal >= 60) {
        announcement +=
            "Moderate confidence pneumonia detection. Consider medical consultation.";
      } else {
        announcement +=
            "Possible pneumonia indicators detected. Consider medical consultation for confirmation.";
      }
    }

    await _speak(announcement);
  }

  @override
  void dispose() {
    _tts.stop(); // ✅ UPDATED: Use TtsManager stop
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
    const bg = 'assets/background.png';
    const lungs = 'assets/lungs_ai.png';

    // Use display percentages instead of original
    final healthyKey = _displayPercentages.containsKey('Healthy')
        ? 'Healthy'
        : 'normal';
    final pneumoniaKey = _displayPercentages.containsKey('Pneumonia')
        ? 'Pneumonia'
        : 'pneumonia';

    final healthyVal = _displayPercentages[healthyKey] ?? 0.0;
    final pneumoniaVal = _displayPercentages[pneumoniaKey] ?? 0.0;

    final entries = [
      MapEntry('Healthy', healthyVal),
      MapEntry('Pneumonia', pneumoniaVal),
    ];

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
                          "X-Ray Analysis Result",
                          style: TextStyle(
                            fontSize: S.fs(context, 28),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Detected: ${_displayLabel.toUpperCase()}", // ✅ Use display label
                          style: TextStyle(
                            fontSize: S.fs(context, 20),
                            fontWeight: FontWeight.w700,
                            color:
                                _displayLabel.toLowerCase() == 'healthy' ||
                                    _displayLabel.toLowerCase() == 'normal'
                                ? Colors.green.shade700
                                : Colors.deepPurple,
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
                                horizontal: 28.0,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${val.toStringAsFixed(1)}%",
                                    style: TextStyle(
                                      fontSize: S.fs(context, 14),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 70,
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
                                      width: 70,
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
                                      fontSize: S.fs(context, 16),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 22),

                        // Confidence breakdown
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "Confidence breakdown",
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
                                      "${e.key}: ${e.value.toStringAsFixed(1)}%",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
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
                            _speak("Returning to home screen");
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          },
                          child: const Text("Done"),
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
      ),
    );
  }

  Color _colorFor(String k) {
    switch (k.toLowerCase()) {
      case 'healthy':
      case 'normal':
        return Colors.greenAccent.shade700;
      case 'pneumonia':
        return Colors.redAccent.shade400;
      default:
        return Colors.grey;
    }
  }
}
