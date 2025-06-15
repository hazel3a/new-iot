import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wifi_scan/wifi_scan.dart' as wifi_scan;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:wifi_iot/wifi_iot.dart';
import 'dart:convert';
import 'dart:async';
import '../models/wifi_access_point.dart';
import '../services/wifi_scan_service.dart';

class DirectWiFiSetupScreen extends ConsumerStatefulWidget {
  const DirectWiFiSetupScreen({super.key});

  @override
  ConsumerState<DirectWiFiSetupScreen> createState() => _DirectWiFiSetupScreenState();
}

class _DirectWiFiSetupScreenState extends ConsumerState<DirectWiFiSetupScreen> {
  List<WiFiAccessPoint> availableNetworks = [];
  bool isScanning = false;
  bool isConnecting = false;
  String statusMessage = '';
  WiFiAccessPoint? selectedNetwork;
  String? currentSSID;
  bool isHotspotEnabled = false;
  String? hotspotName;
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentNetwork();
    _checkHotspotStatus();
    _checkPermissionsAndScan();
  }

  Future<void> _getCurrentNetwork() async {
    try {
      currentSSID = await WiFiForIoTPlugin.getSSID();
      if (mounted) setState(() {});
    } catch (e) {
      print('Error getting current SSID: $e');
    }
  }

  Future<void> _checkHotspotStatus() async {
    try {
      // Check if hotspot is enabled
      bool hotspotStatus = await WiFiForIoTPlugin.isWiFiAPEnabled();
      String? apName = await WiFiForIoTPlugin.getWiFiAPSSID();
      
      setState(() {
        isHotspotEnabled = hotspotStatus;
        hotspotName = apName;
      });
      
      print('Hotspot enabled: $hotspotStatus, Name: $apName');
    } catch (e) {
      print('Error checking hotspot status: $e');
    }
  }

  Future<void> _checkPermissionsAndScan() async {
    setState(() {
      statusMessage = 'Requesting permissions...';
    });

    // Request all necessary permissions for WiFi scanning
    Map<Permission, PermissionStatus> permissions = await [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ].request();

    bool hasPermissions = permissions[Permission.location]?.isGranted == true ||
                         permissions[Permission.locationWhenInUse]?.isGranted == true ||
                         permissions[Permission.nearbyWifiDevices]?.isGranted == true;

    if (hasPermissions) {
      await _scanNetworks();
    } else {
      setState(() {
        statusMessage = 'WiFi scanning permissions required. Please enable in settings.';
      });
      
      // Show permission dialog
      _showPermissionDialog();
    }
  }

  Future<void> _scanNetworks() async {
    setState(() {
      isScanning = true;
      statusMessage = 'Scanning for WiFi networks and hotspots...';
    });

    try {
      // Check hotspot status before scanning
      await _checkHotspotStatus();
      
      // Check if WiFi scanning is available
      final canScan = await wifi_scan.WiFiScan.instance.canStartScan();
      if (canScan != wifi_scan.CanStartScan.yes) {
        throw Exception('WiFi scanning not available: $canScan');
      }

      // Start scanning
      final scanResults = await wifi_scan.WiFiScan.instance.startScan();
      if (scanResults) {
        // Wait longer for thorough scan to catch all networks including hotspots
        await Future.delayed(const Duration(seconds: 5));
        
        // Get scan results multiple times to catch all networks
        final results = await wifi_scan.WiFiScan.instance.getScannedResults();
        
        // Process results and filter
        final networks = results
            .map((result) => WiFiAccessPoint.fromWiFiScanResult(result))
            .where((network) => 
                network.ssid.isNotEmpty && 
                network.ssid.trim().isNotEmpty &&
                !network.ssid.startsWith('\x00') // Filter out null SSIDs
            )
            .toList();
        
        // Remove duplicates based on SSID + BSSID
        final uniqueNetworks = <String, WiFiAccessPoint>{};
        for (final network in networks) {
          final key = '${network.ssid}_${network.bssid}';
          if (!uniqueNetworks.containsKey(key) || 
              uniqueNetworks[key]!.level < network.level) {
            uniqueNetworks[key] = network;
          }
        }
        
        // Add current device's hotspot if enabled (since it won't appear in scan)
        if (isHotspotEnabled && hotspotName != null && hotspotName!.isNotEmpty) {
          final hotspotNetwork = WiFiAccessPoint(
            ssid: hotspotName!,
            bssid: 'LOCAL_HOTSPOT',
            level: -30, // Strong signal since it's local
            frequency: 2400,
            capabilities: 'WPA2',
            isSecure: true,
            securityType: WiFiSecurity.wpa2,
            timestamp: DateTime.now(),
          );
          uniqueNetworks['${hotspotName}_LOCAL'] = hotspotNetwork;
        }
        
        setState(() {
          availableNetworks = uniqueNetworks.values.toList();
          
          // Sort by signal strength (best first)
          availableNetworks.sort((a, b) => b.level.compareTo(a.level));
          
          isScanning = false;
          
          String message = '${availableNetworks.length} networks found';
          if (isHotspotEnabled) {
            message += ' (including your hotspot: $hotspotName)';
          } else {
            message += ' (including hotspots)';
          }
          statusMessage = availableNetworks.isEmpty 
              ? 'No networks found - try moving closer to WiFi sources' 
              : message;
        });

        // If no networks found, try a second scan
        if (availableNetworks.length <= (isHotspotEnabled ? 1 : 0)) {
          await Future.delayed(const Duration(seconds: 2));
          _performSecondScan();
        }
      } else {
        throw Exception('Failed to start WiFi scan');
      }
    } catch (e) {
      setState(() {
        isScanning = false;
        statusMessage = 'Error scanning: $e. Try enabling WiFi and location services.';
      });
      print('WiFi scan error: $e');
    }
  }

  Future<void> _performSecondScan() async {
    if (!mounted || isScanning) return;
    
    if (kDebugMode) print('Performing second scan to detect more networks...');
    setState(() {
      statusMessage = 'Performing deeper scan for hotspots...';
      isScanning = true;
    });

    try {
      await Future.delayed(const Duration(seconds: 1));
      final scanResults = await wifi_scan.WiFiScan.instance.startScan();
      if (scanResults) {
        await Future.delayed(const Duration(seconds: 4));
        final results = await wifi_scan.WiFiScan.instance.getScannedResults();
        
        final newNetworks = results
            .map((result) => WiFiAccessPoint.fromWiFiScanResult(result))
            .where((network) => 
                network.ssid.isNotEmpty && 
                network.ssid.trim().isNotEmpty &&
                !availableNetworks.any((existing) => 
                    existing.ssid == network.ssid && existing.bssid == network.bssid)
            )
            .toList();

        if (newNetworks.isNotEmpty && mounted) {
          setState(() {
            availableNetworks.addAll(newNetworks);
            availableNetworks.sort((a, b) => b.level.compareTo(a.level));
            
            String message = '${availableNetworks.length} networks found';
            if (isHotspotEnabled) {
              message += ' (including your hotspot: $hotspotName)';
            } else {
              message += ' (including hotspots)';
            }
            statusMessage = message;
          });
        }
      }
    } catch (e) {
      print('Second scan error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isScanning = false;
          if (availableNetworks.isEmpty || (availableNetworks.length == 1 && isHotspotEnabled)) {
            statusMessage = 'No other networks detected. ${isHotspotEnabled ? "Your hotspot ($hotspotName) is available." : "Ensure WiFi is enabled and try refresh."}';
          }
        });
      }
    }
  }

  Future<void> _connectToNetwork(WiFiAccessPoint network, String password) async {
    setState(() {
      isConnecting = true;
      selectedNetwork = network;
      statusMessage = 'Connecting to ${network.ssid}...';
    });

    try {
      // Special handling for local hotspot
      if (network.bssid == 'LOCAL_HOTSPOT') {
        setState(() {
          statusMessage = 'Cannot connect to your own hotspot. Please turn off hotspot and connect to a different network.';
          isConnecting = false;
          selectedNetwork = null;
        });
        
        _showHotspotWarningDialog(network.ssid);
        return;
      }

      // Connect phone to the selected network
      bool phoneConnected = await _connectPhoneToNetwork(network.ssid, password);
      
      if (!phoneConnected) {
        throw Exception('Failed to connect to ${network.ssid}');
      }

      setState(() {
        statusMessage = 'Connected! Automatically configuring ESP32 gas detector...';
      });

      // Automatically configure ESP32 with the same credentials
      bool esp32Configured = await _configureESP32(network.ssid, password);

      setState(() {
        statusMessage = esp32Configured 
            ? 'Setup complete! Both phone and ESP32 connected to WiFi.' 
            : 'Phone connected. ESP32 setup will happen automatically when detected.';
        isConnecting = false;
        currentSSID = network.ssid;
      });

      _showSuccessDialog(network.ssid, esp32Configured);

    } catch (e) {
      setState(() {
        statusMessage = 'Connection failed: $e';
        isConnecting = false;
        selectedNetwork = null;
      });
      
      _showErrorDialog(e.toString());
    }
  }

  Future<bool> _connectPhoneToNetwork(String ssid, String password) async {
    try {
      // Ensure WiFi is enabled
      bool isWifiEnabled = await WiFiForIoTPlugin.isEnabled();
      if (!isWifiEnabled) {
        await WiFiForIoTPlugin.setEnabled(true, shouldOpenSettings: false);
        await Future.delayed(const Duration(seconds: 2));
      }

      // Determine security type
      NetworkSecurity security = password.isEmpty 
          ? NetworkSecurity.NONE 
          : NetworkSecurity.WPA;

      // Connect to the network
      bool connected = await WiFiForIoTPlugin.connect(
        ssid,
        password: password,
        security: security,
        withInternet: true,
      );

      if (connected) {
        // Wait and verify connection
        await Future.delayed(const Duration(seconds: 3));
        String? connectedSSID = await WiFiForIoTPlugin.getSSID();
        return connectedSSID != null && connectedSSID.contains(ssid);
      }

      return false;

    } catch (e) {
      print('Phone connection error: $e');
      return false;
    }
  }

  Future<bool> _configureESP32(String ssid, String password) async {
    try {
      setState(() {
        statusMessage = 'Looking for ESP32 Gas Detector in background...';
      });

      // Try to connect to ESP32's access point in background
      bool esp32Connected = await WiFiForIoTPlugin.connect(
        "GasDetector_Setup", // Matches AP_SSID in your Arduino code
        password: "gasdetector123", // Matches AP_PASSWORD in your Arduino code
        security: NetworkSecurity.WPA,
        withInternet: false,
      ).timeout(const Duration(seconds: 10));

      if (!esp32Connected) {
        print('ESP32 "GasDetector_Setup" network not found - will retry in background');
        _scheduleESP32BackgroundConfig(ssid, password);
        return false;
      }

      setState(() {
        statusMessage = 'ESP32 detected! Configuring automatically...';
      });

      // Wait for connection to stabilize
      await Future.delayed(const Duration(seconds: 2));

      // Send credentials to ESP32 using exact format from your Arduino handleSave() function
      final response = await http.post(
        Uri.parse('http://192.168.4.1/save'), // Matches your Arduino web server IP
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'ssid=${Uri.encodeComponent(ssid)}&pass=${Uri.encodeComponent(password)}',
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          statusMessage = 'ESP32 configured successfully! Device connecting to WiFi...';
        });
        
        // Wait for ESP32 to restart and connect
        await Future.delayed(const Duration(seconds: 5));
        
        print('✅ ESP32 successfully configured with WiFi credentials');
        return true;
      } else {
        throw Exception('ESP32 configuration failed with status: ${response.statusCode}');
      }

    } catch (e) {
      print('ESP32 configuration error: $e');
      
      // Schedule background retry
      _scheduleESP32BackgroundConfig(ssid, password);
      
      return false; // Phone is connected, ESP32 will be configured later
    }
  }

  void _scheduleESP32BackgroundConfig(String ssid, String password) {
    // Schedule background ESP32 configuration
    Future.delayed(const Duration(seconds: 30), () async {
      if (mounted) {
        print('🔄 Retrying ESP32 configuration in background...');
        try {
          bool success = await _configureESP32(ssid, password);
          if (success && mounted) {
            // Show a subtle notification that ESP32 is now configured
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('ESP32 Gas Detector connected to WiFi!'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } catch (e) {
          print('Background ESP32 config failed: $e');
        }
      }
    });
  }

  void _showPasswordDialog(WiFiAccessPoint network) {
    passwordController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(_getSignalIcon(network.level), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                network.ssid,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            if (network.bssid == 'LOCAL_HOTSPOT')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Your Hotspot',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  network.securityType.displayName,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const Spacer(),
                Text(
                  _getSignalStrength(network.level),
                  style: TextStyle(
                    color: _getSignalColor(network.level),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (network.bssid == 'LOCAL_HOTSPOT') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is your own hotspot. Turn off hotspot to connect to other networks.',
                        style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (network.securityType != WiFiSecurity.open) ...[
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.visibility),
                    onPressed: () {
                      // Toggle password visibility
                    },
                  ),
                ),
                obscureText: true,
                autofocus: true,
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Open network - No password required',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (network.bssid != 'LOCAL_HOTSPOT')
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _connectToNetwork(network, passwordController.text);
              },
              child: const Text('Connect'),
            ),
        ],
      ),
    );
  }

  void _showHotspotWarningDialog(String hotspotName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Your Hotspot Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_tethering,
              color: Colors.blue,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'We found your hotspot "$hotspotName"',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const Text(
              'To connect your ESP32 gas detector to WiFi, you need to:\n\n'
              '1. Turn OFF your hotspot\n'
              '2. Connect to a WiFi network\n'
              '3. Use that network for ESP32 setup',
              textAlign: TextAlign.left,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String networkName, bool esp32Configured) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('WiFi Setup Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              esp32Configured ? Icons.check_circle : Icons.check_circle_outline,
              color: esp32Configured ? Colors.green : Colors.orange,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Phone connected to "$networkName"',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: esp32Configured ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: esp32Configured ? Colors.green.shade200 : Colors.orange.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    esp32Configured ? Icons.router : Icons.schedule,
                    color: esp32Configured ? Colors.green.shade600 : Colors.orange.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      esp32Configured
                          ? 'ESP32 gas detector automatically configured and connected!'
                          : 'ESP32 gas detector will connect automatically when detected.',
                      style: TextStyle(
                        color: esp32Configured ? Colors.green.shade700 : Colors.orange.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              esp32Configured
                  ? 'Your gas monitoring system is now fully online.'
                  : 'Your phone is connected. Gas detector setup will complete automatically.',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Connection Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Please check your password and try again.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showManualNetworkDialog() {
    final TextEditingController ssidController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.wifi_password, color: Colors.blue),
            SizedBox(width: 12),
            Text('Add Network Manually'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ssidController,
              decoration: InputDecoration(
                labelText: 'Network Name (SSID)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.wifi),
                hintText: 'Enter WiFi network name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.lock),
                hintText: 'Enter network password (leave empty for open networks)',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your ESP32 gas detector will automatically connect to the same network.',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (ssidController.text.isNotEmpty) {
                Navigator.pop(context);
                
                // Create a manual network entry
                final manualNetwork = WiFiAccessPoint(
                  ssid: ssidController.text,
                  bssid: 'MANUAL_ENTRY',
                  level: -50, // Medium signal as placeholder
                  frequency: 2400,
                  capabilities: passwordController.text.isEmpty ? 'OPEN' : 'WPA2',
                  isSecure: passwordController.text.isNotEmpty,
                  securityType: passwordController.text.isEmpty ? WiFiSecurity.open : WiFiSecurity.wpa2,
                  timestamp: DateTime.now(),
                );
                
                _connectToNetwork(manualNetwork, passwordController.text);
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('WiFi Scanning Permission'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on,
              color: Colors.orange,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'WiFi scanning requires location permission to detect nearby networks and hotspots.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'This is required by Android to scan for WiFi networks.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _checkPermissionsAndScan();
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  String _getSignalStrength(int level) {
    if (level >= -50) return 'Excellent';
    if (level >= -60) return 'Good';
    if (level >= -70) return 'Fair';
    if (level >= -80) return 'Weak';
    return 'Very Weak';
  }

  Color _getSignalColor(int level) {
    if (level >= -50) return Colors.green;
    if (level >= -60) return Colors.lightGreen;
    if (level >= -70) return Colors.orange;
    if (level >= -80) return Colors.deepOrange;
    return Colors.red;
  }

  IconData _getSignalIcon(int signalStrength) {
    if (signalStrength >= -50) return Icons.wifi;
    if (signalStrength >= -60) return Icons.wifi;
    if (signalStrength >= -70) return Icons.wifi;
    if (signalStrength >= -80) return Icons.network_wifi_1_bar;
    return Icons.wifi_off;
  }

  Color _getSecurityColor(WiFiSecurity securityType) {
    switch (securityType) {
      case WiFiSecurity.wpa3: return Colors.green.shade100;
      case WiFiSecurity.wpa2: return Colors.blue.shade100;
      case WiFiSecurity.wpa: return Colors.orange.shade100;
      case WiFiSecurity.wep: return Colors.red.shade100;
      case WiFiSecurity.open: return Colors.grey.shade100;
    }
  }

  bool _isCurrentNetwork(WiFiAccessPoint network) {
    return currentSSID != null && 
           currentSSID!.replaceAll('"', '') == network.ssid;
  }

  Future<void> _refreshNetworks() async {
    if (isScanning || isConnecting) return; // Prevent multiple simultaneous refreshes
    
    print('🔄 Manual refresh triggered');
    
    setState(() {
      availableNetworks.clear();
      statusMessage = 'Refreshing networks...';
    });

    try {
      // Get current network status first
      await _getCurrentNetwork();
      
      // Check hotspot status
      await _checkHotspotStatus();
      
      // Perform fresh network scan
      await _scanNetworks();
      
      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_find, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Found ${availableNetworks.length} networks'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      
    } catch (e) {
      print('Error during refresh: $e');
      
      if (mounted) {
        setState(() {
          statusMessage = 'Refresh failed. Please try again.';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Failed to refresh networks'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('WiFi'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          if (isScanning)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: (isScanning || isConnecting) ? null : _refreshNetworks,
              icon: Icon(
                Icons.refresh,
                color: (isScanning || isConnecting) ? Colors.grey : null,
              ),
              tooltip: (isScanning || isConnecting) 
                  ? 'Please wait...' 
                  : 'Refresh Networks',
            ),
        ],
      ),
      body: Column(
        children: [
          // Current Connection Status
          if (currentSSID != null)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.wifi, color: Colors.blue.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Connected',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          currentSSID!.replaceAll('"', ''),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                ],
              ),
            ),

          // Hotspot Status Banner
          if (isHotspotEnabled)
            Container(
              width: double.infinity,
              color: Colors.blue.shade50,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.wifi_tethering, color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your hotspot "$hotspotName" is active',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Divider
          Container(height: 1, color: Colors.grey.shade200),

          // Status Message
          if (statusMessage.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.blue.shade50,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (isScanning || isConnecting)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blue.shade600,
                      ),
                    )
                  else
                    Icon(Icons.info, size: 16, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusMessage,
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Available Networks Section
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available networks',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showManualNetworkDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Network'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

          // Networks List
          Expanded(
            child: availableNetworks.isEmpty && !isScanning
                ? Container(
                    color: Colors.white,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.wifi_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No networks found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isHotspotEnabled 
                                ? 'Turn off hotspot to see other networks'
                                : 'Pull down to refresh',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(
                    color: Colors.white,
                    child: RefreshIndicator(
                      onRefresh: _refreshNetworks,
                      child: ListView.separated(
                        itemCount: availableNetworks.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: Colors.grey.shade200,
                          indent: 60,
                        ),
                        itemBuilder: (context, index) {
                          final network = availableNetworks[index];
                          final isConnecting = selectedNetwork == network && this.isConnecting;
                          final isCurrent = _isCurrentNetwork(network);
                          final isLocalHotspot = network.bssid == 'LOCAL_HOTSPOT';
                          final isManualEntry = network.bssid == 'MANUAL_ENTRY';
                          
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                          leading: Stack(
                                children: [
                                  Icon(
                                    isLocalHotspot 
                                        ? Icons.wifi_tethering 
                                        : isManualEntry 
                                            ? Icons.edit_location_alt
                                            : _getSignalIcon(network.level),
                                    color: isLocalHotspot 
                                        ? Colors.blue.shade600 
                                        : isManualEntry 
                                            ? Colors.purple.shade600
                                            : _getSignalColor(network.level),
                                    size: 24,
                                  ),
                                  if (network.securityType != WiFiSecurity.open && !isLocalHotspot && !isManualEntry)
                                    Positioned(
                                      bottom: -2,
                                      right: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.lock,
                                          size: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    network.ssid,
                                    style: TextStyle(
                                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                                      color: isCurrent ? Colors.blue.shade700 : Colors.black,
                                    ),
                                  ),
                                ),
                                if (isCurrent)
                                  Icon(
                                    Icons.check,
                                    color: Colors.blue.shade600,
                                    size: 20,
                                  ),
                                if (isLocalHotspot)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Your Hotspot',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                if (isManualEntry)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Manual Entry',
                                      style: TextStyle(
                                        color: Colors.purple.shade700,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Row(
                              children: [
                                Text(
                                  isManualEntry ? 'Manually added network' : _getSignalStrength(network.level),
                                  style: TextStyle(
                                    color: isManualEntry ? Colors.purple.shade600 : _getSignalColor(network.level),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (network.securityType != WiFiSecurity.open) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.security,
                                    size: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    network.securityType.displayName,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: isConnecting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : isCurrent
                                    ? null
                                    : const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: (isConnecting || isCurrent) ? null : () => _showPasswordDialog(network),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }
}