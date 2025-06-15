import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/device_service.dart';
import '../utils/time_formatter.dart';
import 'dart:async';

class ActiveDevicesScreen extends StatefulWidget {
  const ActiveDevicesScreen({super.key});

  @override
  State<ActiveDevicesScreen> createState() => _ActiveDevicesScreenState();
}

class _ActiveDevicesScreenState extends State<ActiveDevicesScreen> {
  final DeviceService _deviceService = DeviceService.instance;
  List<Device> _activeDevices = [];
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _setupAutoRefresh() {
    // Refresh every 30 seconds for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadData(showLoading: false);
    });
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final devices = await _deviceService.getActiveDevices();
      final stats = await _deviceService.getDeviceStatistics();

      setState(() {
        _activeDevices = devices;
        _statistics = stats;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading devices: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildStatisticsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Device Statistics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Online',
                    '${_statistics['online_devices'] ?? 0}',
                    Colors.green,
                    Icons.wifi,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Active',
                    '${_statistics['active_devices'] ?? 0}',
                    Colors.blue,
                    Icons.devices,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Total',
                    '${_statistics['total_devices'] ?? 0}',
                    Colors.grey,
                    Icons.device_hub,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Blocked',
                    '${_statistics['blocked_devices'] ?? 0}',
                    Colors.red,
                    Icons.block,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(Device device) {
    // Using TimeFormatter for consistent 12-hour format
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with device name and connection status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.deviceName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        device.deviceId,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
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
                    const SizedBox(height: 4),
                    Text(
                      device.lastSeenText,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Device details row
            Row(
              children: [
                if (device.deviceIp != null) ...[
                  Icon(Icons.network_wifi, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    device.deviceIp!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Last: ${TimeFormatter.formatLastSeen(device.lastConnectedAt)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Statistics row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDeviceStatChip(
                  'Total Readings',
                  '${device.totalReadings}',
                  Icons.sensors,
                  Colors.blue,
                ),
                if (device.readingsToday != null)
                  _buildDeviceStatChip(
                    'Today',
                    '${device.readingsToday}',
                    Icons.today,
                    Colors.green,
                  ),
                if (device.currentGasLevel != null)
                  _buildDeviceStatChip(
                    'Gas Level',
                    device.currentGasLevel!,
                    Icons.warning,
                    _getGasLevelColor(device.currentGasLevel!),
                  ),
                _buildDeviceStatChip(
                  'Status',
                  device.displayStatus,
                  device.statusIcon,
                  device.statusColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

  Widget _buildDeviceStatChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Devices'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadData(),
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
                        onPressed: () => _loadData(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadData(),
                  child: Column(
                    children: [
                      // Statistics section
                      _buildStatisticsCard(),
                      
                      // Active devices list
                      Expanded(
                        child: _activeDevices.isEmpty
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
                                      'No Active Devices',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No devices are currently online or active',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _activeDevices.length,
                                itemBuilder: (context, index) {
                                  return _buildDeviceCard(_activeDevices[index]);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
} 