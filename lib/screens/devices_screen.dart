import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/device.dart';
import '../services/device_service.dart';
import 'device_details_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final DeviceService _deviceService = DeviceService.instance;
  
  List<Device> _devices = [];
  List<Device> _filteredDevices = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  ConnectionStatus? _statusFilter;
  Timer? _refreshTimer;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _setupRealtimeSubscription();
    _setupPeriodicRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (_subscription != null) {
      _deviceService.unsubscribe(_subscription!);
    }
    super.dispose();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allDevices = await _deviceService.getDeviceHistory();
      
      // Filter out test devices - only show real ESP32 devices
      final realDevices = allDevices.where((device) => !_isTestDevice(device.deviceName)).toList();
      
      setState(() {
        _devices = realDevices;
        _filterDevices();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load devices: $e';
        _isLoading = false;
      });
    }
  }

  /// Check if a device name is a test device that should be filtered out
  /// This ensures NO test devices appear in the devices screen
  bool _isTestDevice(String deviceName) {
    final lowercaseName = deviceName.toLowerCase().trim();
    
    // Comprehensive test device filtering
    return lowercaseName.contains('test') ||
           lowercaseName.contains('demo') ||
           lowercaseName.contains('sample') ||
           lowercaseName.contains('debug') ||
           lowercaseName.contains('notification_test') ||
           lowercaseName.contains('real time test') ||
           lowercaseName.contains('real-time test') ||
           lowercaseName.contains('realtime test') ||
           deviceName.startsWith('TEST_') ||
           deviceName.startsWith('DEMO_') ||
           deviceName.startsWith('NOTIFICATION_') ||
           deviceName == 'Real-Time Test Device' ||
           deviceName == 'REAL TIME TEST DEVICE' ||
           deviceName == 'Test Notification Device' ||
           deviceName == 'NOTIFICATION_TEST_DEVICE' ||
           deviceName == 'Test Device' ||
           deviceName == 'Test Arduino Sensor';
  }

  void _setupRealtimeSubscription() {
    try {
      _subscription = _deviceService.subscribeToDeviceUpdates(
        onDeviceUpdate: (device) {
          // Skip test devices in real-time updates
          if (_isTestDevice(device.deviceName)) return;
          
          setState(() {
            final index = _devices.indexWhere((d) => d.deviceId == device.deviceId);
            if (index != -1) {
              _devices[index] = device;
            } else {
              _devices.insert(0, device);
            }
            _filterDevices();
          });
        },
        onNewConnection: (connection) {
          // Refresh the device list when new connections are made
          _loadDevices();
        },
      );
    } catch (e) {
      debugPrint('Error setting up real-time subscription: $e');
    }
  }

  void _setupPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadDevices();
    });
  }

  void _filterDevices() {
    _filteredDevices = _devices.where((device) {
      final matchesSearch = _searchQuery.isEmpty ||
          device.deviceName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          device.deviceId.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesStatus = _statusFilter == null || device.connectionStatus == _statusFilter;
      
      return matchesSearch && matchesStatus;
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _filterDevices();
    });
  }

  void _onStatusFilterChanged(ConnectionStatus? status) {
    setState(() {
      _statusFilter = status;
      _filterDevices();
    });
  }

  Color _getGasLevelColor(String gasLevel) {
    switch (gasLevel) {
      case 'SAFE':
        return const Color(0xFF34BB8B);
      case 'WARNING':
        return const Color(0xFFFBBF24);
      case 'DANGER':
        return const Color(0xFFF87171);
      case 'CRITICAL':
        return const Color(0xFF8B0000); // Bloody red
      case 'UNKNOWN':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Widget _buildSearchAndFilters() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Search field
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF000000) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
              ),
            ),
            child: TextField(
              onChanged: _onSearchChanged,
              style: TextStyle(color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827)),
              decoration: InputDecoration(
                hintText: 'Search devices...',
                hintStyle: TextStyle(color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF34BB8B),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Status filter
          Row(
            children: [
              const Text(
                'Status',
                style: TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF000000),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF374151)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ConnectionStatus?>(
                      value: _statusFilter,
                      hint: const Text(
                        'All Status',
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                      dropdownColor: const Color(0xFF1A1A1A),
                      style: const TextStyle(color: Color(0xFFFFFFFF)),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6B7280)),
                      items: [
                        const DropdownMenuItem<ConnectionStatus?>(
                          value: null,
                          child: Text('All Status'),
                        ),
                        DropdownMenuItem<ConnectionStatus>(
                          value: ConnectionStatus.online,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF34BB8B),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Online'),
                            ],
                          ),
                        ),
                        DropdownMenuItem<ConnectionStatus>(
                          value: ConnectionStatus.offline,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF6B7280),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Offline'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: _onStatusFilterChanged,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
                  Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeviceDetailsScreen(
              device: device,
            ),
          ),
        );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Device icon with status
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34BB8B).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.gas_meter_rounded,
                      color: Color(0xFF34BB8B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Device name and ID
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.deviceName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFFFFF),
                            fontFamily: 'SF Pro Display',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          device.deviceId,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                            fontFamily: 'SF Pro Display',
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Connection status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: device.connectionStatus == ConnectionStatus.online 
                          ? const Color(0xFF34BB8B) 
                          : const Color(0xFF6B7280),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          device.connectionStatus == ConnectionStatus.online ? 'Online' : 'Offline',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'SF Pro Display',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Device details row
              Row(
                children: [
                  // Allow button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34BB8B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Allow',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'SF Pro Display',
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Gas level indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getGasLevelColor(device.currentGasLevel ?? 'UNKNOWN').withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getGasLevelColor(device.currentGasLevel ?? 'UNKNOWN'),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (device.currentGasLevel ?? 'UNKNOWN') == 'SAFE' ? Icons.check_circle : Icons.warning,
                          color: _getGasLevelColor(device.currentGasLevel ?? 'UNKNOWN'),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          device.currentGasLevel ?? 'UNKNOWN',
                          style: TextStyle(
                            color: _getGasLevelColor(device.currentGasLevel ?? 'UNKNOWN'),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'SF Pro Display',
                          ),
                        ),
                        if (device.currentGasValue != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${device.currentGasValue})',
                            style: TextStyle(
                              color: _getGasLevelColor(device.currentGasLevel ?? 'UNKNOWN'),
                              fontSize: 12,
                              fontFamily: 'SF Pro Display',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Readings count
                  if (device.totalReadings > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34BBAB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.analytics,
                            color: Color(0xFF34BBAB),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${device.totalReadings} readings',
                            style: const TextStyle(
                              color: Color(0xFF34BBAB),
                              fontSize: 11,
                              fontFamily: 'SF Pro Display',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Last reading time
              if (device.lastDataReceived != null)
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Color(0xFF9CA3AF),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      device.lastSeenText,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontFamily: 'SF Pro Display',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
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
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF374151)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'Devices',
          style: TextStyle(
            color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827),
            fontWeight: FontWeight.bold,
            fontFamily: 'SF Pro Display',
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF34BB8B)),
              onPressed: _loadDevices,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF34BB8B)),
            )
          : _error != null
              ? Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF87171).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Color(0xFFF87171),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFFE5E7EB),
                            fontFamily: 'SF Pro Display',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadDevices,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF34BB8B),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDevices,
                  color: const Color(0xFF34BB8B),
                  backgroundColor: const Color(0xFF1A1A1A),
                  child: Column(
                    children: [
                      _buildSearchAndFilters(),
                      Expanded(
                        child: _filteredDevices.isEmpty
                            ? Center(
                                child: Container(
                                  margin: const EdgeInsets.all(24),
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1A1A),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF34BB8B).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.devices,
                                          size: 48,
                                          color: Color(0xFF34BB8B),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchQuery.isNotEmpty || _statusFilter != null
                                            ? 'No devices match your filters'
                                            : 'No devices found',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFFFFFF),
                                          fontFamily: 'SF Pro Display',
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _searchQuery.isNotEmpty || _statusFilter != null
                                            ? 'Try adjusting your search or filters'
                                            : 'Devices will appear here once they connect',
                                        style: const TextStyle(
                                          color: Color(0xFF9CA3AF),
                                          fontFamily: 'SF Pro Display',
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredDevices.length,
                                itemBuilder: (context, index) {
                                  return _buildDeviceCard(_filteredDevices[index]);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
} 