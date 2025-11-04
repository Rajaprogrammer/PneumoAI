import 'package:flutter/material.dart';
import 'package:pattern_lock/pattern_lock.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthMethod { face, fingerprint, pattern }

class AppAuth {
  static const _pinKey = 'app_pattern_v1';
  // Legacy reset PIN no longer used; retained for potential future flows
  // static const _resetPin = '1234';
  static const _methodKey = 'app_auth_method_v1';

  // ---------------- Storage helpers ----------------
  static Future<String?> _getStoredPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey);
  }

  static Future<void> _setStoredPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
  }

  static Future<AuthMethod?> _getStoredMethod() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_methodKey);
    if (s == 'face') return AuthMethod.face;
    if (s == 'fingerprint') return AuthMethod.fingerprint;
    if (s == 'pattern') return AuthMethod.pattern;
    return null;
  }

  static Future<void> _setStoredMethod(AuthMethod m) async {
    final prefs = await SharedPreferences.getInstance();
    final s = m == AuthMethod.face
        ? 'face'
        : (m == AuthMethod.fingerprint ? 'fingerprint' : 'pattern');
    await prefs.setString(_methodKey, s);
  }

  // ---------------- Biometrics ----------------
  static Future<bool> _tryBiometric(AuthMethod method) async {
    final auth = LocalAuthentication();
    final canCheck =
        await auth.canCheckBiometrics || await auth.isDeviceSupported();
    if (!canCheck) return false;

    final available = await auth.getAvailableBiometrics();
    // Prefer requested method, otherwise fail
    final wantsFace = method == AuthMethod.face;
    final wantsFp = method == AuthMethod.fingerprint;
    final hasFace =
        available.contains(BiometricType.face) ||
        available.contains(BiometricType.strong);
    final hasFp =
        available.contains(BiometricType.fingerprint) ||
        available.contains(BiometricType.weak);

    if ((wantsFace && !hasFace) || (wantsFp && !hasFp)) return false;

    return await auth.authenticate(
      localizedReason: wantsFace
          ? 'Authenticate with Face'
          : 'Authenticate with Fingerprint',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
        sensitiveTransaction: true,
      ),
    );
  }

  // ---------------- Pattern dialogs ----------------
  static Future<bool> _showPatternVerifyDialog(
    BuildContext context,
    String stored,
  ) async {
    bool authed = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Draw pattern to unlock'),
          content: SizedBox(
            width: 300,
            height: 360,
            child: PatternLock(
              selectedColor: Colors.blueAccent,
              pointRadius: 10,
              onInputComplete: (input) {
                final entered = input.join(',');
                if (entered == stored) {
                  authed = true;
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ),
        );
      },
    );
    return authed;
  }

  static Future<bool> _showPatternCreateDialog(BuildContext context) async {
    String pattern = '';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Set your pattern'),
          content: SizedBox(
            width: 300,
            height: 360,
            child: PatternLock(
              selectedColor: Colors.blueAccent,
              pointRadius: 10,
              onInputComplete: (input) {
                pattern = input.join(',');
                Navigator.of(ctx).pop();
              },
            ),
          ),
        );
      },
    );
    if (pattern.isEmpty) return false;
    await _setStoredPin(pattern);
    return true;
  }

  // ---------------- Method selection ----------------
  static Future<AuthMethod?> _selectInitialMethod(BuildContext context) async {
    final auth = LocalAuthentication();
    final available = await auth.getAvailableBiometrics();
    final hasFace =
        available.contains(BiometricType.face) ||
        available.contains(BiometricType.strong);
    final hasFp =
        available.contains(BiometricType.fingerprint) ||
        available.contains(BiometricType.weak);

    AuthMethod? chosen;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Choose unlock method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasFace)
                ListTile(
                  leading: const Icon(Icons.face_retouching_natural),
                  title: const Text('Face recognition'),
                  onTap: () {
                    chosen = AuthMethod.face;
                    Navigator.of(ctx).pop();
                  },
                ),
              if (hasFp)
                ListTile(
                  leading: const Icon(Icons.fingerprint),
                  title: const Text('Fingerprint'),
                  onTap: () {
                    chosen = AuthMethod.fingerprint;
                    Navigator.of(ctx).pop();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.pattern),
                title: const Text('Pattern'),
                onTap: () {
                  chosen = AuthMethod.pattern;
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        );
      },
    );
    return chosen;
  }

  // Public API: authenticate using stored method; on first run, choose and persist.
  static Future<bool> ensureAuthenticated(BuildContext context) async {
    AuthMethod? method = await _getStoredMethod();
    if (method == null) {
      method = await _selectInitialMethod(context);
      if (method == null) return false;
      await _setStoredMethod(method);
      if (method == AuthMethod.pattern) {
        final ok = await _showPatternCreateDialog(context);
        if (!ok) return false;
      }
    }

    // Execute chosen method
    if (method == AuthMethod.face || method == AuthMethod.fingerprint) {
      final ok = await _tryBiometric(method);
      if (ok) return true;
      // If preferred biometrics unavailable/fails, fallback order: other biometric -> pattern
      final other = method == AuthMethod.face
          ? AuthMethod.fingerprint
          : AuthMethod.face;
      if (await _tryBiometric(other)) return true;
      final stored = await _getStoredPin();
      if (stored != null)
        return await _showPatternVerifyDialog(context, stored);
      // If no pattern yet, ask to set and then unlock
      final created = await _showPatternCreateDialog(context);
      if (!created) return false;
      return await _showPatternVerifyDialog(context, (await _getStoredPin())!);
    } else {
      // Pattern flow
      final stored = await _getStoredPin();
      if (stored == null) {
        final ok = await _showPatternCreateDialog(context);
        if (!ok) return false;
        return await _showPatternVerifyDialog(
          context,
          (await _getStoredPin())!,
        );
      }
      return await _showPatternVerifyDialog(context, stored);
    }
  }

  // Expose a UI to change the default method anytime
  static Future<void> showChangeAuthMethodDialog(BuildContext context) async {
    final newMethod = await _selectInitialMethod(context);
    if (newMethod == null) return;
    await _setStoredMethod(newMethod);
    if (newMethod == AuthMethod.pattern) {
      // Ensure a pattern exists
      final stored = await _getStoredPin();
      if (stored == null || stored.isEmpty) {
        await _showPatternCreateDialog(context);
      }
    }
    // For biometrics, OS enrollment is assumed
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication method updated')),
      );
    }
  }
}
