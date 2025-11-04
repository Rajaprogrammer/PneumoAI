import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global TTS Manager - Singleton
/// Manages TTS state and preferences across the entire app
class TtsManager extends ChangeNotifier {
  static final TtsManager _instance = TtsManager._internal();
  factory TtsManager() => _instance;
  TtsManager._internal();

  static const String _ttsEnabledKey = 'tts_enabled_v1';

  late FlutterTts _flutterTts;
  bool _isEnabled = true; // Default: TTS ON
  bool _isSpeaking = false;
  bool _isInitialized = false;

  bool get isEnabled => _isEnabled;
  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _isInitialized;

  /// Initialize TTS and load saved preference
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load saved preference
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_ttsEnabledKey) ?? true;

    // Initialize TTS engine
    _flutterTts = FlutterTts();

    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Try to use Google's neural voice on Android
      await _flutterTts.setVoice({
        "name": "en-us-x-tpf-network",
        "locale": "en-US",
      });

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint("❌ TTS Error: $msg");
        _isSpeaking = false;
        notifyListeners();
      });

      _isInitialized = true;
      debugPrint("✅ TTS Manager initialized - Enabled: $_isEnabled");
    } catch (e) {
      debugPrint("❌ TTS initialization error: $e");
    }
  }

  /// Speak text (only if TTS is enabled)
  Future<void> speak(String text) async {
    if (!_isInitialized) await initialize();
    if (!_isEnabled) {
      debugPrint("🔇 TTS disabled, skipping: $text");
      return;
    }

    try {
      if (_isSpeaking) await _flutterTts.stop();
      debugPrint("🔊 Speaking: $text");
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("❌ TTS speak error: $e");
    }
  }

  /// Stop current speech
  Future<void> stop() async {
    if (!_isInitialized) return;
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      notifyListeners();
    } catch (e) {
      debugPrint("❌ TTS stop error: $e");
    }
  }

  /// Toggle TTS on/off and save preference
  Future<void> toggle() async {
    _isEnabled = !_isEnabled;

    // Save preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ttsEnabledKey, _isEnabled);

    // Stop any ongoing speech if disabling
    if (!_isEnabled && _isSpeaking) {
      await stop();
    }

    debugPrint("🔊 TTS toggled: $_isEnabled");
    notifyListeners();

    // Announce the change
    if (_isEnabled) {
      await speak("Voice announcements enabled");
    }
  }

  /// Set TTS state explicitly
  Future<void> setEnabled(bool enabled) async {
    if (_isEnabled == enabled) return;

    _isEnabled = enabled;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ttsEnabledKey, enabled);

    if (!enabled && _isSpeaking) {
      await stop();
    }

    debugPrint("🔊 TTS set to: $enabled");
    notifyListeners();
  }
}
