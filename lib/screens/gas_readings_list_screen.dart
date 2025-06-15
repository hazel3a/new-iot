import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gas_sensor_reading.dart';
import '../services/supabase_service.dart';
import '../utils/time_formatter.dart';

class GasReadingsListScreen extends StatefulWidget {
  const GasReadingsListScreen({super.key});

  @override
  State<GasReadingsListScreen> createState() => _GasReadingsListScreenState();
}

class _GasReadingsListScreenState extends State<GasReadingsListScreen> {
  List<GasSensorReading> _readings = [];
  List<String> _availableDevices = [];
  String? _selectedDevice;
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  RealtimeChannel? _subscription;
  final SupabaseService _supabaseService = SupabaseService.instance;

  /// Check if a device name is a test device that should be filtered out  
  /// This ensures NO test devices appear in gas readings lists
  bool _isTestDevice(String deviceName) {
    final lowercaseName = deviceName.toLowerCase().trim();
    
    // Comprehensive test device filtering - matches SupabaseService filtering
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

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtimeSubscription();
    _setupPeriodicRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (_subscription != null) {
      _supabaseService.unsubscribe(_subscription!);
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load available devices
      final devices = await _supabaseService.getAvailableDevices();
      
      // Load readings (filtered if device is selected)
      final readings = await _supabaseService.getRecentReadingsFiltered(
        limit: 50,
        deviceName: _selectedDevice,
      );

      setState(() {
        _availableDevices = ['All Devices', ...devices];
        _readings = readings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _onDeviceChanged(String? newDevice) async {
    setState(() {
      _selectedDevice = newDevice == 'All Devices' ? null : newDevice;
    });
    await _loadReadings();
  }

  Future<void> _loadReadings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final readings = await _supabaseService.getRecentReadingsFiltered(
        limit: 50,
        deviceName: _selectedDevice,
      );

      setState(() {
        _readings = readings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading readings: $e';
        _isLoading = false;
      });
    }
  }

  void _setupRealtimeSubscription() {
    try {
      _subscription = _supabaseService.subscribeToReadings(
        onInsert: (reading) {
          // Skip test devices
          if (_isTestDevice(reading.deviceName)) return;
          
          setState(() {
            _readings.insert(0, reading);
            // Update available devices immediately when new device appears
            if (!_availableDevices.contains(reading.deviceName)) {
              _availableDevices.add(reading.deviceName);
              _availableDevices.sort();
            }
          });
        },
        onUpdate: (reading) {
          // Skip test devices
          if (_isTestDevice(reading.deviceName)) return;
          
          setState(() {
            final index = _readings.indexWhere((r) => r.id == reading.id);
            if (index != -1) {
              _readings[index] = reading;
            }
            // Update available devices in case device name changed
            if (!_availableDevices.contains(reading.deviceName)) {
              _availableDevices.add(reading.deviceName);
              _availableDevices.sort();
            }
          });
        },
      );
    } catch (e) {
      debugPrint('Error setting up real-time subscription: $e');
    }
  }

  void _setupPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _refreshDeviceList();
    });
  }

  Future<void> _refreshDeviceList() async {
    try {
      final devices = await _supabaseService.getAvailableDevices();
      setState(() {
        _availableDevices = ['All Devices', ...devices];
      });
    } catch (e) {
      debugPrint('Error refreshing device list: $e');
    }
  }

  Widget _buildDeviceDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedDevice ?? 'All Devices',
                hint: const Text('Select Device'),
                items: _availableDevices.map((String device) {
                  return DropdownMenuItem<String>(
                    value: device,
                    child: Row(
                      children: [
                        Text(device),
                        if (device != 'All Devices') ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.sensors,
                            size: 16,
                            color: Colors.green[600],
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _onDeviceChanged,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _refreshDeviceList,
            tooltip: 'Refresh device list',
          ),
        ],
      ),
    );
  }

  Widget _buildReadingCard(GasSensorReading reading) {
    // Using TimeFormatter for consistent 12-hour format
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with device name and time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reading.deviceName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'ID: ${reading.deviceId}',
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
                    Text(
                      TimeFormatter.formatDate(reading.createdAt),
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      TimeFormatter.formatTime(reading.createdAt),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Gas level indicator
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: reading.levelColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        reading.levelIcon,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        reading.gasLevel.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Gas Value: ${reading.gasValue}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Additional details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Baseline: ${reading.baseline}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Deviation: ${reading.deviation}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  'ID: ${reading.id}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gas Sensor Readings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Device selection dropdown
          _buildDeviceDropdown(),
          
          // Readings list
          Expanded(
            child: _isLoading
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
                              onPressed: _loadData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _readings.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.sensors_off,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _selectedDevice != null
                                      ? 'No readings found for $_selectedDevice'
                                      : 'No readings found',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadData,
                                  child: const Text('Refresh'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadReadings,
                            child: ListView.builder(
                              itemCount: _readings.length,
                              itemBuilder: (context, index) {
                                return _buildReadingCard(_readings[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
} 