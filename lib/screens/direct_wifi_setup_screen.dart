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

class DirectWiFiSetupScreen extends StatefulWidget {
  const DirectWiFiSetupScreen({super.key});

  @override
  State<DirectWiFiSetupScreen> createState() => _DirectWiFiSetupScreenState();
}

class _DirectWiFiSetupScreenState extends State<DirectWiFiSetupScreen> {
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
      
      if (mounted) {
        setState(() {
          isHotspotEnabled = hotspotStatus;
          hotspotName = apName;
        });
      }
      
      print('Hotspot enabled: $hotspotStatus, Name: $apName');
    } catch (e) {
      print('Error checking hotspot status: $e');
    }
  }

  Future<void> _checkPermissionsAndScan() async {
    if (!mounted) return;
    
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
    if (!mounted) return;
    
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
        
        if (mounted) {
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
        }

        // If no networks found, try a second scan
        if (availableNetworks.length <= (isHotspotEnabled ? 1 : 0)) {
          await Future.delayed(const Duration(seconds: 2));
          _performSecondScan();
        }
      } else {
        throw Exception('Failed to start WiFi scan');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isScanning = false;
          statusMessage = 'Error scanning: $e. Try enabling WiFi and location services.';
        });
      }
      print('WiFi scan error: $e');
    }
  }

  Future<void> _performSecondScan() async {
    if (!mounted || isScanning) return;
    
    if (kDebugMode) print('Performing second scan to detect more networks...');
    
    if (mounted) {
      setState(() {
        statusMessage = 'Performing deeper scan for hotspots...';
        isScanning = true;
      });
    }

    try {
      await Future.delayed(const Duration(seconds: 2));
      final results = await wifi_scan.WiFiScan.instance.getScannedResults();
      
      final networks = results
          .map((result) => WiFiAccessPoint.fromWiFiScanResult(result))
          .where((network) => 
              network.ssid.isNotEmpty && 
              network.ssid.trim().isNotEmpty &&
              !network.ssid.startsWith('\x00')
          )
          .toList();
      
      final uniqueNetworks = <String, WiFiAccessPoint>{};
      for (final network in networks) {
        final key = '${network.ssid}_${network.bssid}';
        if (!uniqueNetworks.containsKey(key) || 
            uniqueNetworks[key]!.level < network.level) {
          uniqueNetworks[key] = network;
        }
      }
      
      if (mounted) {
        setState(() {
          availableNetworks = uniqueNetworks.values.toList();
          availableNetworks.sort((a, b) => b.level.compareTo(a.level));
          isScanning = false;
          statusMessage = availableNetworks.isEmpty 
              ? 'No networks found - check your WiFi settings' 
              : '${availableNetworks.length} networks found';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isScanning = false;
          statusMessage = 'Second scan failed: $e';
        });
      }
      print('Second scan error: $e');
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WiFi Permissions Required'),
        content: const Text('This app needs location permissions to scan for WiFi networks. Please enable location permissions in your device settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPasswordDialog(WiFiAccessPoint network) {
    passwordController.clear();
    
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF),
          title: Text(
            'Connect to ${network.ssid}',
            style: TextStyle(
              color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827),
              fontFamily: 'SF Pro Display',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (network.isSecure) ...[
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: TextStyle(
                    color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF34BB8B)),
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  'This is an open network. No password required.',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34BB8B),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                _connectToNetwork(network, passwordController.text);
              },
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _connectToNetwork(WiFiAccessPoint network, String password) async {
    setState(() {
      isConnecting = true;
      selectedNetwork = network;
      statusMessage = 'Connecting to ${network.ssid}...';
    });

    try {
      bool success = false;
      
      if (network.bssid == 'LOCAL_HOTSPOT') {
        // Handle local hotspot connection differently
        statusMessage = 'Cannot connect to your own hotspot';
        success = false;
      } else {
        // Try to connect to the network
        success = await WiFiForIoTPlugin.connect(
          network.ssid,
          password: network.isSecure ? password : '',
          security: network.securityType == WiFiSecurity.wpa2 
              ? NetworkSecurity.WPA 
              : NetworkSecurity.NONE,
          joinOnce: true,
        );
      }

      if (success) {
        setState(() {
          statusMessage = 'Successfully connected to ${network.ssid}';
          currentSSID = network.ssid;
        });
        
        // Show success and navigate back after delay
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          statusMessage = 'Failed to connect to ${network.ssid}. Check password.';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = 'Error connecting: $e';
      });
      print('Connection error: $e');
    } finally {
      setState(() {
        isConnecting = false;
        selectedNetwork = null;
      });
    }
  }

  Future<void> _refreshNetworks() async {
    if (isScanning || isConnecting) return;
    
    setState(() {
      availableNetworks.clear();
    });
    
    await _scanNetworks();
  }

  String _getSignalStrength(int level) {
    if (level >= -50) return 'Excellent';
    if (level >= -60) return 'Good';
    if (level >= -70) return 'Fair';
    return 'Weak';
  }

  Color _getSignalColor(int level) {
    if (level >= -50) return Colors.green;
    if (level >= -60) return Colors.lightGreen;
    if (level >= -70) return Colors.orange;
    return Colors.red;
  }

  IconData _getSignalIcon(int signalStrength) {
    if (signalStrength >= -50) {
      return Icons.wifi;
    } else if (signalStrength >= -60) {
      return Icons.wifi;
    } else if (signalStrength >= -70) {
      return Icons.wifi_1_bar;
    } else {
      return Icons.wifi_1_bar;
    }
  }

  bool _isCurrentNetwork(WiFiAccessPoint network) {
    if (currentSSID == null) return false;
    String cleanCurrentSSID = currentSSID!.replaceAll('"', '');
    return cleanCurrentSSID == network.ssid;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF9FAFB),
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF374151)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF34BB8B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.wifi_rounded,
                color: Color(0xFF34BB8B),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'WiFi',
              style: TextStyle(
                color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827),
                fontWeight: FontWeight.w600,
                fontSize: 20,
                fontFamily: 'SF Pro Display',
              ),
            ),
          ],
        ),
        actions: [
          if (isScanning)
            Container(
              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF34BB8B),
                ),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: (isScanning || isConnecting) ? null : _refreshNetworks,
                icon: Icon(
                  Icons.refresh,
                  color: (isScanning || isConnecting) 
                      ? const Color(0xFF6B7280)
                      : const Color(0xFF34BB8B),
                ),
                tooltip: (isScanning || isConnecting) 
                    ? 'Please wait...' 
                    : 'Refresh Networks',
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Connection Status
            if (currentSSID != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34BB8B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.wifi,
                        color: Color(0xFF34BB8B),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Connected',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              fontFamily: 'SF Pro Display',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentSSID!.replaceAll('"', ''),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827),
                              fontFamily: 'SF Pro Display',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34BB8B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF34BB8B),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Hotspot Status Banner
            if (isHotspotEnabled)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF34BBAB).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34BBAB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.wifi_tethering,
                        color: Color(0xFF34BBAB),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your hotspot is active',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827),
                              fontFamily: 'SF Pro Display',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Name: ${hotspotName ?? 'Unknown'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              fontFamily: 'SF Pro Display',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34BBAB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.wifi_tethering,
                        color: Color(0xFF34BBAB),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

            if (isHotspotEnabled) const SizedBox(height: 24),

            // Status Message
            if (statusMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    if (isScanning)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF34BB8B),
                        ),
                      )
                    else
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFF34BB8B),
                        size: 18,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        statusMessage,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          fontFamily: 'SF Pro Display',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (statusMessage.isNotEmpty) const SizedBox(height: 24),

            // Available Networks Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34BB8B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.wifi_find,
                    color: Color(0xFF34BB8B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Available Networks',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827),
                    fontFamily: 'SF Pro Display',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Networks List
            availableNetworks.isEmpty && !isScanning
                ? Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6B7280).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.wifi_off,
                              size: 48,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No networks found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827),
                              fontFamily: 'SF Pro Display',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pull down to refresh or check WiFi settings',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              fontFamily: 'SF Pro Display',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: availableNetworks.length,
                    itemBuilder: (context, index) {
                      final network = availableNetworks[index];
                      final isConnected = _isCurrentNetwork(network);
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isConnected 
                                ? const Color(0xFF34BB8B)
                                : isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: isConnected ? null : () => _showPasswordDialog(network),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _getSignalColor(network.level).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _getSignalIcon(network.level),
                                      color: _getSignalColor(network.level),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                network.ssid,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827),
                                                  fontFamily: 'SF Pro Display',
                                                ),
                                              ),
                                            ),
                                            if (network.isSecure)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF6B7280).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Icon(
                                                  Icons.lock,
                                                  size: 16,
                                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_getSignalStrength(network.level)} • ${network.securityType.name.toUpperCase()}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                            fontFamily: 'SF Pro Display',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isConnected)
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF34BB8B).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF34BB8B),
                                        size: 20,
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward_ios,
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }
} 