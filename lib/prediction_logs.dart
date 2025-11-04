// lib/prediction_logs.dart
import 'package:flutter/material.dart';
import 'scale.dart';

class PredictionLogsPage extends StatelessWidget {
  final List<String> logs;

  const PredictionLogsPage({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.cover),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: S.w(context, 120),
            height: S.h(context, 160),
            child: Image.asset('assets/lungs_ai.png', fit: BoxFit.contain),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: S.w(context, 1200)),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Prediction Logs',
                        style: TextStyle(
                          fontSize: S.fs(context, 28),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: logs.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No logs available',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: logs.length,
                                  separatorBuilder: (_, __) => const Divider(
                                    height: 12,
                                    color: Colors.black12,
                                  ),
                                  itemBuilder: (_, i) {
                                    return Text(
                                      logs[i],
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 14,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
