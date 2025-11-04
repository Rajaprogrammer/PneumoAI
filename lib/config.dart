class AppConfig {
  static String arduinoIP = '192.168.68.106';
  static String arduinoPort = '5000';
  
  static void updateIP(String ip) {
    arduinoIP = ip;
  }
  
  static void updatePort(String port) {
    arduinoPort = port;
  }
}