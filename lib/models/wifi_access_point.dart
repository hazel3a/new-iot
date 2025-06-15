// WiFi Access Point Model (2025 Flutter Best Practices)
class WiFiAccessPoint {
  final String ssid;
  final String bssid;
  final int level; // Signal strength in dBm
  final int frequency;
  final String capabilities;
  final bool isSecure;
  final WiFiSecurity securityType;
  final DateTime timestamp;

  const WiFiAccessPoint({
    required this.ssid,
    required this.bssid,
    required this.level,
    required this.frequency,
    required this.capabilities,
    required this.isSecure,
    required this.securityType,
    required this.timestamp,
  });

  /// Signal strength as percentage (0-100)
  int get signalStrengthPercentage {
    // Convert dBm to percentage
    // -30 dBm = 100%, -90 dBm = 0%
    if (level >= -30) return 100;
    if (level <= -90) return 0;
    return ((level + 90) * 100 / 60).round();
  }

  /// Get WiFi band (2.4GHz or 5GHz)
  String get band {
    if (frequency >= 2400 && frequency <= 2500) return '2.4GHz';
    if (frequency >= 5000 && frequency <= 6000) return '5GHz';
    return 'Unknown';
  }

  /// Human-readable signal quality
  String get signalQuality {
    if (level >= -50) return 'Excellent';
    if (level >= -60) return 'Good';
    if (level >= -70) return 'Fair';
    if (level >= -80) return 'Weak';
    return 'Very Weak';
  }

  /// Create from wifi_scan package result
  factory WiFiAccessPoint.fromWiFiScanResult(dynamic result) {
    return WiFiAccessPoint(
      ssid: result.ssid ?? '',
      bssid: result.bssid ?? '',
      level: result.level ?? -100,
      frequency: result.frequency ?? 0,
      capabilities: result.capabilities ?? '',
      isSecure: _isSecureNetwork(result.capabilities ?? ''),
      securityType: _getSecurityType(result.capabilities ?? ''),
      timestamp: DateTime.now(),
    );
  }

  /// Determine if network is secure based on capabilities
  static bool _isSecureNetwork(String capabilities) {
    return capabilities.contains('WPA') || 
           capabilities.contains('WEP') || 
           capabilities.contains('PSK');
  }

  /// Determine security type from capabilities string
  static WiFiSecurity _getSecurityType(String capabilities) {
    if (capabilities.contains('WPA3')) return WiFiSecurity.wpa3;
    if (capabilities.contains('WPA2')) return WiFiSecurity.wpa2;
    if (capabilities.contains('WPA')) return WiFiSecurity.wpa;
    if (capabilities.contains('WEP')) return WiFiSecurity.wep;
    return WiFiSecurity.open;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WiFiAccessPoint &&
          runtimeType == other.runtimeType &&
          ssid == other.ssid &&
          bssid == other.bssid;

  @override
  int get hashCode => ssid.hashCode ^ bssid.hashCode;

  @override
  String toString() => 'WiFiAccessPoint(ssid: $ssid, level: $level dBm)';
}

/// WiFi Security Types
enum WiFiSecurity {
  open('Open'),
  wep('WEP'),
  wpa('WPA'),
  wpa2('WPA2'),
  wpa3('WPA3');

  const WiFiSecurity(this.displayName);
  final String displayName;
}

/// WiFi Provisioning State
enum WiFiProvisioningState {
  idle,
  scanning,
  connecting,
  sendingCredentials,
  success,
  error
}

/// WiFi Provisioning Result
class WiFiProvisioningResult {
  final bool success;
  final String? error;
  final String? deviceResponse;
  final DateTime timestamp;

  const WiFiProvisioningResult({
    required this.success,
    this.error,
    this.deviceResponse,
    required this.timestamp,
  });

  factory WiFiProvisioningResult.success([String? response]) {
    return WiFiProvisioningResult(
      success: true,
      deviceResponse: response,
      timestamp: DateTime.now(),
    );
  }

  factory WiFiProvisioningResult.error(String error) {
    return WiFiProvisioningResult(
      success: false,
      error: error,
      timestamp: DateTime.now(),
    );
  }
} 