import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
// Import the persistence package
import 'package:shared_preferences/shared_preferences.dart';

class ArduinoService {
  static final ArduinoService _instance = ArduinoService._internal();
  factory ArduinoService() => _instance;

  // --- Persistence Keys ---
  static const String _ipKey = 'arduino_ip_address';
  static const String _portKey = 'arduino_port';

  // Configuration (made package-private for reading in NextPage's State initialization)
  String _ipAddress = '192.168.68.106'; // Default value
  String _port = '5000'; // Default value
  bool _serialEnabled = true;

  // Internal constructor now loads configuration
  ArduinoService._internal() {
    _loadConfig();
  }

  // --- Getters ---
  bool get isSerialEnabled => _serialEnabled;
  String get serverUrl => 'http://$_ipAddress:$_port';
  // Expose current configuration for the UI dialog
  String get currentIp => _ipAddress;
  String get currentPort => _port;
  // ------------------

  // --- Persistence Methods ---

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _ipAddress = prefs.getString(_ipKey) ?? _ipAddress;
      _port = prefs.getString(_portKey) ?? _port;
      debugPrint('🔧 Config loaded: $serverUrl');
    } catch (e) {
      debugPrint('❌ Failed to load config: $e');
    }
  }

  Future<void> _saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ipKey, _ipAddress);
      await prefs.setString(_portKey, _port);
      debugPrint('🔧 Config saved: $serverUrl');
    } catch (e) {
      debugPrint('❌ Failed to save config: $e');
    }
  }
  // ------------------

  // Update setConfig to be async and trigger saving
  Future<void> setConfig(String ip, String port) async {
    _ipAddress = ip;
    _port = port;
    await _saveConfig();
  }

  void toggleSerial() {
    _serialEnabled = !_serialEnabled;
    debugPrint(
      '🔧 Serial communication ${_serialEnabled ? "ENABLED" : "DISABLED"}',
    );
  }

  void enableSerial(bool enable) {
    _serialEnabled = enable;
  }

  // Send command to Arduino via Flask
  Future<void> sendCommand(String command) async {
    if (!_serialEnabled) {
      debugPrint('⚠️ Serial disabled, skipping: $command');
      return;
    }

    try {
      final url = Uri.parse('$serverUrl/send?cmd=$command');
      debugPrint('📡 Sending: $command');

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              debugPrint('⏱️ Timeout sending: $command');
              return http.Response('Timeout', 408);
            },
          );

      if (response.statusCode == 200) {
        debugPrint('✅ Sent: $command');
      } else {
        debugPrint('❌ Failed (${response.statusCode}): $command');
      }
    } catch (e) {
      debugPrint('❌ Error sending command: $e');
      // Silently fail - no GUI error
    }
  }

  // LCD Commands
  Future<void> updateLCD(String line1, [String? line2]) async {
    String message = line2 != null ? '$line1::$line2' : line1;
    await sendCommand('lcd:$message');
  }

  // Bot Commands (servo positions)
  Future<void> setBotPosition({int? head, int? handL, int? handR}) async {
    List<String> parts = [];
    if (head != null) parts.add('head=$head');
    if (handL != null) parts.add('handl=$handL');
    if (handR != null) parts.add('handr=$handR');

    if (parts.isNotEmpty) {
      await sendCommand('bot:${parts.join(' ')}');
    }
  }

  // Timed servo command with individual durations
  Future<void> setTimedServos({
    required int headAngle,
    required int headDuration,
    required int leftAngle,
    required int leftDuration,
    required int rightAngle,
    required int rightDuration,
    int defaultHead = 0,
    int defaultLeft = 0,
    int defaultRight = 0,
  }) async {
    String cmd =
        'servo:$headAngle $headDuration $leftAngle $leftDuration $rightAngle $rightDuration($defaultHead $defaultLeft $defaultRight)';
    await sendCommand(cmd);
  }

  // Preset gestures
  Future<void> gestureWave() async {
    await setBotPosition(head: 45, handL: 0, handR: 90);
    await Future.delayed(const Duration(milliseconds: 500));
    await setBotPosition(handR: 45);
    await Future.delayed(const Duration(milliseconds: 500));
    await setBotPosition(handR: 90);
    await Future.delayed(const Duration(milliseconds: 500));
    await setBotPosition(head: 0, handR: 0);
  }

  Future<void> gestureWelcome() async {
    await setBotPosition(head: 0, handL: 90, handR: 90);
    await Future.delayed(const Duration(milliseconds: 1500));
    await setBotPosition(handL: 0, handR: 0);
  }

  Future<void> gestureThinking() async {
    await setBotPosition(head: 30, handL: 60, handR: 0);
    await Future.delayed(const Duration(milliseconds: 1000));
    await setBotPosition(head: -30);
    await Future.delayed(const Duration(milliseconds: 1000));
    await setBotPosition(head: 0, handL: 0);
  }

  Future<void> gesturePointLeft() async {
    await setBotPosition(head: -45, handL: 90, handR: 0);
  }

  Future<void> gesturePointRight() async {
    await setBotPosition(head: 45, handL: 0, handR: 90);
  }

  Future<void> gestureReset() async {
    await setBotPosition(head: 0, handL: 0, handR: 0);
  }

  // RFID Auth
  Future<void> requestRFIDAuth() async {
    await sendCommand('rfid:auth');
  }
}
