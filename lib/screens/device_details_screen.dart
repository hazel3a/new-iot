import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/gas_sensor_reading.dart';
import '../services/device_service.dart';
import '../services/supabase_service.dart';
import '../utils/time_formatter.dart';
import '../test_data_fetch.dart';
import 'alerts_history_screen.dart';

class DeviceDetailsScreen extends StatefulWidget {
  final Device device;

  const DeviceDetailsScreen({super.key, required this.device});

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  final DeviceService _deviceService = DeviceService.instance;
  final SupabaseService _supabaseService = SupabaseService.instance;
  
  late Device _currentDevice;
  List<DeviceConnection> _connections = [];
  List<GasSensorReading> _recentReadings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentDevice = widget.device;
    _loadDeviceData();
  }

  @override
  void dispose() {
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

  void _navigateToAlertHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AlertsHistoryScreen(),
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
                  const SizedBox(height: 16),
                  _buildThresholdIndicators(),
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
                        child: GestureDetector(
                          onTap: _navigateToAlertHistory,
                          child: _buildStatCard(
                            'Alert History',
                            'View',
                            Icons.warning_amber,
                            Colors.orange,
                            isClickable: true,
                          ),
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool isClickable = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: isClickable ? [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ] : null,
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
          if (isClickable) ...[
            const SizedBox(height: 4),
            Icon(
              Icons.touch_app,
              color: color.withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThresholdIndicators() {
    const int safeThreshold = 100;
    const int warningThreshold = 300;
    const int dangerThreshold = 600;
    const int criticalThreshold = 1000;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gas Level Thresholds',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildThresholdCard(
                'SAFE',
                '0-${safeThreshold}',
                Icons.check_circle,
                Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildThresholdCard(
                'WARNING',
                '${safeThreshold + 1}-${warningThreshold}',
                Icons.warning_amber,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildThresholdCard(
                'DANGER',
                '${warningThreshold + 1}-${dangerThreshold}',
                Icons.error,
                Colors.red,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildThresholdCard(
                'CRITICAL',
                '${dangerThreshold + 1}+',
                Icons.dangerous,
                Colors.red[800]!,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThresholdCard(String level, String range, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            level,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${range} ppm',
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentDevice.deviceName),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDeviceData,
            tooltip: 'Refresh',
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
                        onPressed: _loadDeviceData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildDeviceOverview(),
    );
  }
} 