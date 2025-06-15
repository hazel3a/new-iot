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
      // Load device details
      final device = await _deviceService.getDevice(_currentDevice.deviceId);
      if (device != null) {
        _currentDevice = device;
      }

      // Load recent connections
      _connections = await _deviceService.getDeviceConnections(_currentDevice.deviceId);

      // Load recent readings
      _recentReadings = await _supabaseService.getRecentReadingsFiltered(
        deviceName: _currentDevice.deviceName,
        limit: 10,
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load device data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Device',
          style: TextStyle(color: Color(0xFFFFFFFF), fontFamily: 'SF Pro Display'),
        ),
        content: Text(
          'Delete "${_currentDevice.deviceName}"? This will remove all device data and cannot be undone.',
          style: const TextStyle(color: Color(0xFFE5E7EB), fontFamily: 'SF Pro Display'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFF87171)),
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
            backgroundColor: const Color(0xFF34BB8B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete device'),
            backgroundColor: const Color(0xFFF87171),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
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
        builder: (context) => AlertsHistoryScreen(device: _currentDevice),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentDevice.deviceName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFFFFF),
                        fontFamily: 'SF Pro Display',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentDevice.deviceId,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                        fontFamily: 'SF Pro Display',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _currentDevice.connectionStatus == ConnectionStatus.online 
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
                      _currentDevice.connectionStatus == ConnectionStatus.online ? 'online' : 'offline',
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
          
          const SizedBox(height: 20),
          
          // Action buttons
          Row(
            children: [
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SF Pro Display',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getGasLevelColor(_currentDevice.currentGasLevel ?? 'UNKNOWN').withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getGasLevelColor(_currentDevice.currentGasLevel ?? 'UNKNOWN')),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      (_currentDevice.currentGasLevel ?? 'UNKNOWN') == 'SAFE' ? Icons.check_circle : Icons.warning,
                      color: _getGasLevelColor(_currentDevice.currentGasLevel ?? 'UNKNOWN'),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_currentDevice.currentGasLevel ?? 'UNKNOWN'} (${_currentDevice.currentGasValue ?? 'Unknown'})',
                      style: TextStyle(
                        color: _getGasLevelColor(_currentDevice.currentGasLevel ?? 'UNKNOWN'),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'SF Pro Display',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInformationCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                      Text(
              'Device Information',
             style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
               color: Color(0xFFFFFFFF),
                fontFamily: 'SF Pro Display',
              ),
          ),
          const SizedBox(height: 16),
          
          _buildInfoRow('Device Type', 'gas_sensor'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
              fontFamily: 'SF Pro Display',
            ),
          ),
        ),
        Expanded(
                      child: Text(
              value ?? 'Unknown',
             style: const TextStyle(
               color: Color(0xFFFFFFFF),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              fontFamily: 'SF Pro Display',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGasLevelThresholdsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gas Level Thresholds',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFFFFF),
              fontFamily: 'SF Pro Display',
            ),
          ),
          const SizedBox(height: 16),
          
          // Threshold cards in 2x2 grid
          Row(
            children: [
              Expanded(
                child: _buildThresholdCard(
                  'SAFE',
                  '0-100 ppm',
                  const Color(0xFF34BB8B),
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThresholdCard(
                  'WARNING',
                  '101-300 ppm',
                  const Color(0xFFFBBF24),
                  Icons.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildThresholdCard(
                  'DANGER',
                  '301-600 ppm',
                  const Color(0xFFF87171),
                  Icons.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThresholdCard(
                  'CRITICAL',
                  '601+ ppm',
                  const Color(0xFF8B0000), // Bloody red
                  Icons.dangerous,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdCard(String level, String range, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            level,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'SF Pro Display',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            range,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontFamily: 'SF Pro Display',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFFFFF),
              fontFamily: 'SF Pro Display',
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34BBAB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.analytics,
                        color: Color(0xFF34BBAB),
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_currentDevice.totalReadings}',
                        style: const TextStyle(
                          color: Color(0xFF34BBAB),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'SF Pro Display',
                        ),
                      ),
                      const Text(
                        'Total Readings',
                        style: TextStyle(
                          color: Color(0xFF34BBAB),
                          fontSize: 12,
                          fontFamily: 'SF Pro Display',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.history,
                        color: Color(0xFFFBBF24),
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _navigateToAlertHistory,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFBBF24),
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                        ),
                        child: const Text(
                          'View',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'SF Pro Display',
                          ),
                        ),
                      ),
                      const Text(
                        'Alert History',
                        style: TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 12,
                          fontFamily: 'SF Pro Display',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFFFFFFFF)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          _currentDevice.deviceName,
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
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
              onPressed: _loadDeviceData,
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
                          onPressed: _loadDeviceData,
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
                  onRefresh: _loadDeviceData,
                  color: const Color(0xFF34BB8B),
                  backgroundColor: const Color(0xFF1A1A1A),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildDeviceInfoCard(),
                        _buildDeviceInformationCard(),
                        _buildGasLevelThresholdsCard(),
                        _buildStatisticsCard(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }
} 