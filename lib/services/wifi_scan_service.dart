// WiFi Scan Service (2025 Flutter Best Practices)
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart' as wifi_scan;
import '../models/wifi_access_point.dart' as models;

/// Stream-based WiFi scanning service with smart filtering
class WiFiScanService {
  static final WiFiScanService _instance = WiFiScanService._internal();
  factory WiFiScanService() => _instance;
  WiFiScanService._internal();

  // Stream controllers
  final StreamController<List<models.WiFiAccessPoint>> _networkStreamController =
      StreamController<List<models.WiFiAccessPoint>>.broadcast();
  
  final StreamController<bool> _scanningController =
      StreamController<bool>.broadcast();
  
  final StreamController<String?> _errorController =
      StreamController<String?>.broadcast();

  // Configuration
  static const Duration _scanInterval = Duration(seconds: 3);
  static const int _minSignalLevel = -80; // dBm threshold
  
  // State
  Timer? _scanTimer;
  bool _isScanning = false;
  bool _hasPermissions = false;
  List<models.WiFiAccessPoint> _lastResults = [];

  // Getters for streams
  Stream<List<models.WiFiAccessPoint>> get networkStream => _networkStreamController.stream;
  Stream<bool> get scanningStream => _scanningController.stream;
  Stream<String?> get errorStream => _errorController.stream;
  
  // Getters for state
  bool get isScanning => _isScanning;
  bool get hasPermissions => _hasPermissions;
  List<models.WiFiAccessPoint> get lastResults => List.unmodifiable(_lastResults);

  /// Initialize the service and request permissions
  Future<bool> initialize() async {
    try {
      _hasPermissions = await _requestPermissions();
      if (!_hasPermissions) {
        _errorController.add('WiFi scanning permissions not granted');
        return false;
      }

      // Check if WiFi scanning is supported
      final canScan = await wifi_scan.WiFiScan.instance.canGetScannedResults();
      if (canScan != wifi_scan.CanGetScannedResults.yes) {
        _errorController.add('WiFi scanning not supported on this device');
        return false;
      }

      _errorController.add(null); // Clear any previous errors
      return true;
    } catch (e) {
      _errorController.add('Failed to initialize WiFi scanning: $e');
      return false;
    }
  }

  /// Start continuous WiFi scanning
  Future<void> startScanning() async {
    if (_isScanning) return;

    if (!_hasPermissions) {
      final initialized = await initialize();
      if (!initialized) return;
    }

    _isScanning = true;
    _scanningController.add(true);

    // Initial scan
    await _performScan();

    // Start continuous scanning
    _scanTimer = Timer.periodic(_scanInterval, (_) async {
      await _performScan();
    });

    if (kDebugMode) {
      print('WiFi scanning started with ${_scanInterval.inSeconds}s interval');
    }
  }

  /// Stop WiFi scanning
  void stopScanning() {
    if (!_isScanning) return;

    _scanTimer?.cancel();
    _scanTimer = null;
    _isScanning = false;
    _scanningController.add(false);

    if (kDebugMode) {
      print('WiFi scanning stopped');
    }
  }

  /// Perform a single scan
  Future<void> _performScan() async {
    try {
      // Start scan
      await wifi_scan.WiFiScan.instance.startScan();
      
      // Wait a moment for scan to complete
      await Future.delayed(const Duration(milliseconds: 2000));
      
      // Get results
      final results = await wifi_scan.WiFiScan.instance.getScannedResults();
      
      // Convert and filter results
      final networks = results
          .map((result) => models.WiFiAccessPoint.fromWiFiScanResult(result))
          .where(_shouldIncludeNetwork)
          .toList();

      // Remove duplicates and sort by signal strength
      final filteredNetworks = _removeDuplicatesAndSort(networks);
      
      // Always update results, even if empty (this clears "No networks found" when refreshing)
      _lastResults = filteredNetworks;
      _networkStreamController.add(filteredNetworks);

      // Clear errors if scan was successful
      _errorController.add(null);

      if (kDebugMode) {
        print('WiFi scan completed - found ${filteredNetworks.length} networks');
        if (filteredNetworks.isEmpty) {
          print('No networks found - this might be due to permissions or no nearby networks');
        }
      }
    } catch (e) {
      _errorController.add('Scan failed: $e');
      // Don't clear results on error, keep last known good results
      if (kDebugMode) {
        print('WiFi scan error: $e');
      }
    }
  }

  /// Smart filtering logic
  bool _shouldIncludeNetwork(models.WiFiAccessPoint network) {
    // Filter out networks with empty SSID
    if (network.ssid.isEmpty) return false;
    
    // Filter out networks with very weak signal
    if (network.level < _minSignalLevel) return false;
    
    // Filter out hidden networks (SSID starting with special characters)
    if (network.ssid.startsWith('\x00')) return false;
    
    return true;
  }

  /// Remove duplicates and sort by signal strength
  List<models.WiFiAccessPoint> _removeDuplicatesAndSort(List<models.WiFiAccessPoint> networks) {
    // Group by SSID and keep the one with strongest signal
    final Map<String, models.WiFiAccessPoint> uniqueNetworks = {};
    
    for (final network in networks) {
      final existing = uniqueNetworks[network.ssid];
      if (existing == null || network.level > existing.level) {
        uniqueNetworks[network.ssid] = network;
      }
    }
    
    // Sort by signal strength (descending)
    final sortedNetworks = uniqueNetworks.values.toList();
    sortedNetworks.sort((a, b) => b.level.compareTo(a.level));
    
    return sortedNetworks;
  }

  /// Request necessary permissions with smart handling
  Future<bool> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Android 13+ permissions - request one by one for better UX
        final locationStatus = await Permission.locationWhenInUse.request();
        
        if (locationStatus == PermissionStatus.granted) {
          // Only request WiFi permission if location is granted
          final wifiStatus = await Permission.nearbyWifiDevices.request();
          
          if (wifiStatus == PermissionStatus.granted || 
              wifiStatus == PermissionStatus.limited) {
            return true;
          }
        }
        
        // Provide helpful error message
        _errorController.add('WiFi scanning requires location access. Please enable location permission in Settings > Apps > Breadwinners Mobile > Permissions.');
        return false;
        
      } else if (Platform.isIOS) {
        // iOS requires location permission for WiFi scanning
        final status = await Permission.locationWhenInUse.request();
        
        if (status == PermissionStatus.granted) {
          return true;
        }
        
        _errorController.add('WiFi scanning requires location access. Please enable location permission in Settings > Privacy & Security > Location Services.');
        return false;
      }

      return true; // Other platforms
    } catch (e) {
      // Fallback: try to work without permissions
      if (kDebugMode) {
        print('Permission request failed: $e. Attempting fallback mode.');
      }
      return false;
    }
  }

  /// Get permission status for UI feedback
  Future<Map<String, PermissionStatus>> getPermissionStatuses() async {
    if (Platform.isAndroid) {
      return {
        'nearbyWifiDevices': await Permission.nearbyWifiDevices.status,
        'location': await Permission.locationWhenInUse.status,
      };
    } else if (Platform.isIOS) {
      return {
        'location': await Permission.locationWhenInUse.status,
      };
    }
    return {};
  }

  /// Open app settings for permission management
  Future<void> openAppSettings() async {
    await openAppSettings();
  }

  /// Refresh scan results immediately
  Future<void> refresh() async {
    try {
      // Clear any previous errors
      _errorController.add(null);
      
      // Check permissions first
      if (!_hasPermissions) {
        final initialized = await initialize();
        if (!initialized) {
          return;
        }
      }

      // Clear previous results to show fresh scan
      _lastResults = [];
      _networkStreamController.add([]);
      
      // Indicate scanning is active
      _scanningController.add(true);
      
      // Wait a bit to ensure previous scan operations complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Perform fresh scan
      await _performScan();
      
      if (kDebugMode) {
        print('WiFi refresh completed - found ${_lastResults.length} networks');
      }
    } catch (e) {
      _errorController.add('Refresh failed: $e');
      if (kDebugMode) {
        print('WiFi refresh error: $e');
      }
    } finally {
      // Restore scanning state based on whether continuous scanning is active
      _scanningController.add(_isScanning);
    }
  }

  /// Get network by SSID
  models.WiFiAccessPoint? getNetworkBySSID(String ssid) {
    try {
      return _lastResults.firstWhere((network) => network.ssid == ssid);
    } catch (e) {
      return null;
    }
  }

  /// Dispose of resources
  void dispose() {
    stopScanning();
    _networkStreamController.close();
    _scanningController.close();
    _errorController.close();
  }
} 