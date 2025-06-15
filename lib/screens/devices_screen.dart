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
        return Colors.green;
      case 'WARNING':
        return Colors.orange;
      case 'DANGER':
        return Colors.red;
      case 'CRITICAL':
        return Colors.red[800]!;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSearchAndFilters() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search bar
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search devices...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 16),
            
            // Status filter (connection-based)
            DropdownButtonFormField<ConnectionStatus?>(
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              value: _statusFilter,
              items: [
                const DropdownMenuItem(value: null, child: Text('All Status')),
                DropdownMenuItem(
                  value: ConnectionStatus.online,
                  child: Row(
                    children: [
                      Icon(Icons.wifi, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      const Text('Online'),
                    ],
                  ),
                ),

                DropdownMenuItem(
                  value: ConnectionStatus.offline,
                  child: Row(
                    children: [
                      Icon(Icons.signal_wifi_off, color: Colors.grey, size: 16),
                      const SizedBox(width: 8),
                      const Text('Offline'),
                    ],
                  ),
                ),
              ],
              onChanged: _onStatusFilterChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    // Using TimeFormatter for consistent 12-hour format
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeviceDetailsScreen(device: device),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Device icon with status
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: device.statusColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      device.statusIcon,
                      color: device.statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
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
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          device.deviceId,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Connection status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: device.connectionStatusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          device.connectionStatusIcon,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          device.displayConnectionStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Status and gas level row
              Row(
                children: [
                  // Device status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: device.statusColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      device.displayStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  if (device.currentGasLevel != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getGasLevelColor(device.currentGasLevel!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sensors, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            device.currentGasLevel!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (device.currentGasValue != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${device.currentGasValue})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              
              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatChip(
                    Icons.sensors,
                    '${device.totalReadings} readings',
                    Colors.blue,
                  ),
                  if (device.readingsToday != null)
                    _buildStatChip(
                      Icons.today,
                      '${device.readingsToday} today',
                      Colors.green,
                    ),
                  _buildStatChip(
                    Icons.schedule,
                    device.lastSeenText,
                    Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDevices,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDevices,
                  child: Column(
                    children: [
                      _buildSearchAndFilters(),
                      Expanded(
                        child: _filteredDevices.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.device_unknown,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty || _statusFilter != null
                                          ? 'No devices match your filters'
                                          : 'No devices found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _searchQuery.isNotEmpty || _statusFilter != null
                                          ? 'Try adjusting your search or filters'
                                          : 'Devices will appear here once they connect',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
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