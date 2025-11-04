import 'package:flutter/material.dart';

class S extends ChangeNotifier {
  static bool enabled = false;
  static const double designWidth = 2000.0;
  static const double designHeight = 1200.0;

  // Expose a singleton notifier so widgets like MaterialApp can listen
  static final S notifier = S._();

  S._();
  S();

  static void toggle() {
    enabled = !enabled;
    notifier.notifyListeners();
  }

  static void setEnabled(bool value) {
    if (enabled == value) return;
    enabled = value;
    notifier.notifyListeners();
  }

  static double w(BuildContext context, double x) {
    if (!enabled) return x;
    final size = MediaQuery.of(context).size;
    return (size.width / designWidth) * x;
  }

  static double h(BuildContext context, double y) {
    if (!enabled) return y;
    final size = MediaQuery.of(context).size;
    return (size.height / designHeight) * y;
  }

  static double fs(BuildContext context, double s) {
    if (!enabled) return s;
    final size = MediaQuery.of(context).size;
    final scale = (size.width / designWidth + size.height / designHeight) / 2.0;
    return s * scale;
  }

  // Padding helpers to scale spacing when enabled
  static EdgeInsets pAll(BuildContext context, double value) {
    final v = enabled ? w(context, value) : value;
    return EdgeInsets.all(v);
  }

  static EdgeInsets pSymmetric(
    BuildContext context, {
    double horizontal = 0,
    double vertical = 0,
  }) {
    final horizontalScaled = enabled ? w(context, horizontal) : horizontal;
    final verticalScaled = enabled ? S.h(context, vertical) : vertical;
    return EdgeInsets.symmetric(
      horizontal: horizontalScaled,
      vertical: verticalScaled,
    );
  }

  static EdgeInsets pLTRB(
    BuildContext context,
    double left,
    double top,
    double right,
    double bottom,
  ) {
    final l = enabled ? w(context, left) : left;
    final t = enabled ? h(context, top) : top;
    final r = enabled ? w(context, right) : right;
    final b = enabled ? h(context, bottom) : bottom;
    return EdgeInsets.fromLTRB(l, t, r, b);
  }

  // Corner radius helper
  static BorderRadius brAll(BuildContext context, double radius) {
    final r = enabled ? w(context, radius) : radius;
    return BorderRadius.circular(r);
  }
}
