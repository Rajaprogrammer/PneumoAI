import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'loading_stethoscope.dart';
import 'scale.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: S.notifier,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/loadingStethoscope': (context) => const LoadingStethoscopePage(),
          },
          builder: (context, child) {
            final size = MediaQuery.of(context).size;
            // Lenovo Yoga Tab 11 baseline is 2000x1200 (already in S)
            final widthScale = size.width / S.designWidth;
            final heightScale = size.height / S.designHeight;
            final avgScale = (widthScale + heightScale) / 2.0;
            final textScale = S.enabled ? avgScale : 1.0;

            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                // For Flutter >= 3.16 use textScaler; for older, textScaleFactor is respected
                textScaler: TextScaler.linear(textScale),
                textScaleFactor: textScale,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
