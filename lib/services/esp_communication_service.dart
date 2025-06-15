// ESP Communication Service (2025 Flutter Best Practices)
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/wifi_access_point.dart';

/// Secure ESP32 communication service with retry logic and error handling
class ESPCommunicationService {
  static final ESPCommunicationService _instance = ESPCommunicationService._internal();
  factory ESPCommunicationService() => _instance;
  ESPCommunicationService._internal();

  // Configuration
  static const String _baseUrl = 'http://192.168.4.1';
  static const Duration _timeout = Duration(seconds: 10);
  static const int _maxRetries = 3;
  static const List<Duration> _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  // Device identification
  static const String _deviceId = 'FLUTTER_MOBILE_APP';

  /// Send WiFi credentials to ESP32 device
  Future<WiFiProvisioningResult> sendWiFiCredentials({
    required String ssid,
    required String password,
    String? deviceName,
  }) async {
    if (kDebugMode) {
      print('Sending WiFi credentials to ESP32...');
      print('SSID: $ssid');
      print('Password: ${password.isNotEmpty ? "****" : "Empty"}');
    }

    // Validate inputs
    if (ssid.trim().isEmpty) {
      return WiFiProvisioningResult.error('SSID cannot be empty');
    }

    // Retry logic with exponential backoff
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final result = await _sendCredentialsWithTimeout(
          ssid: ssid.trim(),
          password: password,
          deviceName: deviceName,
          attempt: attempt + 1,
        );

        if (result.success) {
          if (kDebugMode) {
            print('✓ WiFi credentials sent successfully on attempt ${attempt + 1}');
          }
          return result;
        }

        // If not the last attempt, wait before retrying
        if (attempt < _maxRetries - 1) {
          final delay = _retryDelays[attempt];
          if (kDebugMode) {
            print('⚠ Attempt ${attempt + 1} failed, retrying in ${delay.inSeconds}s...');
          }
          await Future.delayed(delay);
        }
      } catch (e) {
        if (kDebugMode) {
          print('✗ Attempt ${attempt + 1} error: $e');
        }
        
        // If last attempt, return error
        if (attempt == _maxRetries - 1) {
          return WiFiProvisioningResult.error('Failed after $_maxRetries attempts: $e');
        }
        
        // Wait before next attempt
        await Future.delayed(_retryDelays[attempt]);
      }
    }

    return WiFiProvisioningResult.error('All retry attempts failed');
  }

  /// Send credentials with timeout and secure transmission
  Future<WiFiProvisioningResult> _sendCredentialsWithTimeout({
    required String ssid,
    required String password,
    String? deviceName,
    required int attempt,
  }) async {
    final client = http.Client();
    
    try {
      // Prepare secure payload
      final payload = _createSecurePayload(
        ssid: ssid,
        password: password,
        deviceName: deviceName,
      );

      // Create request with secure headers
      final request = http.Request('POST', Uri.parse('$_baseUrl/save'))
        ..headers.addAll(_createSecureHeaders())
        ..body = payload;

      if (kDebugMode) {
        print('Sending request (attempt $attempt): ${request.url}');
      }

      // Send request with timeout
      final streamedResponse = await client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (kDebugMode) {
        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');
      }

      // Validate response
      return _validateResponse(response);
    } on TimeoutException {
      throw 'Request timed out after ${_timeout.inSeconds} seconds';
    } on SocketException catch (e) {
      throw 'Network error: ${e.message}';
    } on FormatException catch (e) {
      throw 'Invalid response format: ${e.message}';
    } catch (e) {
      throw 'Unexpected error: $e';
    } finally {
      client.close();
    }
  }

  /// Create secure payload with validation
  String _createSecurePayload({
    required String ssid,
    required String password,
    String? deviceName,
  }) {
    // URL encode values to prevent injection attacks
    final encodedSSID = Uri.encodeComponent(ssid);
    final encodedPassword = Uri.encodeComponent(password);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Build form data
    final formData = <String, String>{
      'ssid': encodedSSID,
      'pass': encodedPassword,
      'timestamp': timestamp.toString(),
    };

    if (deviceName != null && deviceName.isNotEmpty) {
      formData['device_name'] = Uri.encodeComponent(deviceName);
    }

    // Convert to URL-encoded string
    return formData.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('&');
  }

  /// Create secure headers for ESP32 communication
  Map<String, String> _createSecureHeaders() {
    return {
      'Content-Type': 'application/x-www-form-urlencoded',
      'X-Device-ID': _deviceId,
      'X-Timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      'User-Agent': 'BreadwinnersMobile/1.0',
      'Accept': 'text/html,application/json',
    };
  }

  /// Validate ESP32 response
  WiFiProvisioningResult _validateResponse(http.Response response) {
    // Check status code
    if (response.statusCode != 200) {
      return WiFiProvisioningResult.error(
        'HTTP ${response.statusCode}: ${response.reasonPhrase}'
      );
    }

    final body = response.body.toLowerCase();
    
    // Check for success indicators in response
    if (body.contains('settings saved') ||
        body.contains('saved successfully') ||
        body.contains('success')) {
      return WiFiProvisioningResult.success(response.body);
    }

    // Check for error indicators
    if (body.contains('error') || body.contains('failed')) {
      final errorMatch = RegExp(r'error[:\s]*([^<\n]*)', caseSensitive: false)
          .firstMatch(response.body);
      final errorMessage = errorMatch?.group(1)?.trim() ?? 'Unknown error from device';
      return WiFiProvisioningResult.error(errorMessage);
    }

    // If response doesn't contain clear success/error indicators
    if (response.body.length < 10) {
      return WiFiProvisioningResult.error('Invalid response from device');
    }

    // Assume success if we got a reasonable response
    return WiFiProvisioningResult.success(response.body);
  }

  /// Check ESP32 device status
  Future<Map<String, dynamic>?> getDeviceStatus() async {
    final client = http.Client();
    
    try {
      final response = await client
          .get(
            Uri.parse('$_baseUrl/status'),
            headers: _createSecureHeaders(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        try {
          return json.decode(response.body) as Map<String, dynamic>;
        } catch (e) {
          if (kDebugMode) {
            print('Failed to parse device status JSON: $e');
          }
          return null;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get device status: $e');
      }
    } finally {
      client.close();
    }
    
    return null;
  }

  /// Test connection to ESP32 device
  Future<bool> testConnection() async {
    final client = http.Client();
    
    try {
      final response = await client
          .get(
            Uri.parse(_baseUrl),
            headers: {'User-Agent': 'BreadwinnersMobile/1.0'},
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('ESP32 connection test failed: $e');
      }
      return false;
    } finally {
      client.close();
    }
  }

  /// Validate network connectivity to ESP32 AP
  Future<bool> isConnectedToESPAP() async {
    try {
      // Try to connect to the ESP32's common IP
      final socket = await Socket.connect('192.168.4.1', 80, timeout: const Duration(seconds: 3));
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get connection instructions for user
  String getConnectionInstructions() {
    return '''
To set up your gas detector WiFi:

1. Go to your phone's WiFi settings
2. Connect to network: "GasDetector_Setup"
3. Password: "gasdetector123"
4. Return to this app once connected
5. Select your home WiFi network from the list

The device will automatically restart and connect to your WiFi network after setup.
''';
  }
} 