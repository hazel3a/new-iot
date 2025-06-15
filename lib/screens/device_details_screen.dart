import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/gas_sensor_reading.dart';
import '../services/device_service.dart';
import '../services/supabase_service.dart';
import '../utils/time_formatter.dart';
import '../test_data_fetch.dart';

class DeviceDetailsScreen extends StatefulWidget {
  final Device device;

  const DeviceDetailsScreen({super.key, required this.device});

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> with TickerProviderStateMixin {
  final DeviceService _deviceService = DeviceService.instance;
  final SupabaseService _supabaseService = SupabaseService.instance;
  
  late TabController _tabController;
  late Device _currentDevice;
  List<DeviceConnection> _connections = [];
  List<GasSensorReading> _recentReadings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentDevice = widget.device;
    _tabController = TabController(length: 3, vsync: this);
    _loadDeviceData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load updated device info
      final updatedDevice = await _deviceService.getDevice(_currentDevice.deviceId);
      if (updatedDevice != null) {
        _currentDevice = updatedDevice;
      }

      // Load connections and readings in parallel
      final results = await Future.wait([
        _deviceService.getDeviceConnections(_currentDevice.deviceId),
        _supabaseService.getRecentReadingsFiltered(deviceName: _currentDevice.deviceName, limit: 50),
      ]);

      setState(() {
        _connections = results[0] as List<DeviceConnection>;
        _recentReadings = results[1] as List<GasSensorReading>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load device data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateDeviceStatus(DeviceStatus status) async {
    final success = await _deviceService.updateDeviceStatus(_currentDevice.deviceId, status);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device status updated to ${status.value}'),
          backgroundColor: Colors.green,
        ),
      );
      _loadDeviceData();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update device status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text('Delete "${_currentDevice.deviceName}"? This will remove all device data and cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _deviceService.deleteDevice(_currentDevice.deviceId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device "${_currentDevice.deviceName}" deleted'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete device'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _testConnection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TestDataFetch(deviceFilter: _currentDevice.deviceName),
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

  Widget _buildDeviceOverview() {
    // Using TimeFormatter for consistent 12-hour format
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _currentDevice.statusColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _currentDevice.statusIcon,
                          color: _currentDevice.statusColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentDevice.deviceName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentDevice.deviceId,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _currentDevice.connectionStatusColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _currentDevice.connectionStatusIcon,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _currentDevice.displayConnectionStatus,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Status badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _currentDevice.statusColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _currentDevice.displayStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_currentDevice.currentGasLevel != null) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getGasLevelColor(_currentDevice.currentGasLevel!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sensors, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                _currentDevice.currentGasLevel!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_currentDevice.currentGasValue != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(${_currentDevice.currentGasValue})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Device Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Device Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Device Type', _currentDevice.deviceType),
                  if (_currentDevice.deviceIp != null)
                    _buildInfoRow('IP Address', _currentDevice.deviceIp!),
                  _buildInfoRow('First Seen', TimeFormatter.formatDateTime(_currentDevice.firstConnectedAt)),
                  _buildInfoRow('Last Seen', TimeFormatter.formatDateTime(_currentDevice.lastConnectedAt)),
                  if (_currentDevice.lastDataReceived != null)
                    _buildInfoRow('Last Data', TimeFormatter.formatDateTime(_currentDevice.lastDataReceived!)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Statistics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Readings',
                          '${_currentDevice.totalReadings}',
                          Icons.sensors,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Today',
                          '${_currentDevice.readingsToday ?? 0}',
                          Icons.today,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Connections',
                          '${_currentDevice.totalConnections ?? 0}',
                          Icons.link,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Last Activity',
                          _currentDevice.lastSeenText,
                          Icons.schedule,
                          Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Action buttons
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _testConnection,
                          icon: const Icon(Icons.bug_report),
                          label: const Text('Test Connection'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _loadDeviceData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _currentDevice.status == DeviceStatus.active
                              ? () => _updateDeviceStatus(DeviceStatus.blocked)
                              : () => _updateDeviceStatus(DeviceStatus.active),
                          icon: Icon(_currentDevice.status == DeviceStatus.active ? Icons.block : Icons.check_circle),
                          label: Text(_currentDevice.status == DeviceStatus.active ? 'Block Device' : 'Allow Device'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _currentDevice.status == DeviceStatus.active ? Colors.red : Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _deleteDevice,
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionsTab() {
    if (_connections.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No connection history',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _connections.length,
      itemBuilder: (context, index) {
        final connection = _connections[index];
        // Using TimeFormatter for consistent 12-hour format
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: connection.isActive ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
              child: Icon(
                connection.isActive ? Icons.link : Icons.link_off,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text('${connection.connectionType} Connection'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connected: ${TimeFormatter.formatCompactDateTime(connection.connectedAt)}'),
                if (connection.disconnectedAt != null)
                  Text('Disconnected: ${TimeFormatter.formatCompactDateTime(connection.disconnectedAt!)}'),
                Text('Data points: ${connection.dataCount}'),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: connection.isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    connection.isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!connection.isActive)
                  Text(
                    connection.connectionDurationText,
                    style: const TextStyle(fontSize: 10),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReadingsTab() {
    if (_recentReadings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sensors_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No readings found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _recentReadings.length,
      itemBuilder: (context, index) {
        final reading = _recentReadings[index];
        // Using TimeFormatter for consistent 12-hour format
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getGasLevelColor(reading.gasLevel),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sensors,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text('Gas Level: ${reading.gasLevel}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Value: ${reading.gasValue} ppm'),
                Text('Deviation: ${reading.deviation}'),
                Text(TimeFormatter.formatCompactDateTime(reading.createdAt)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getGasLevelColor(reading.gasLevel),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${reading.gasValue}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentDevice.deviceName),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.info)),
            Tab(text: 'Connections', icon: Icon(Icons.link)),
            Tab(text: 'Readings', icon: Icon(Icons.sensors)),
          ],
        ),
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
                        onPressed: _loadDeviceData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDeviceOverview(),
                    _buildConnectionsTab(),
                    _buildReadingsTab(),
                  ],
                ),
    );
  }
} 