import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/gas_data_provider.dart';
import '../utils/time_formatter.dart';
import 'settings_screen.dart';
import 'devices_screen.dart';
import 'alerts_history_screen.dart';

class RealTimeGasMonitorScreen extends ConsumerStatefulWidget {
  const RealTimeGasMonitorScreen({super.key});

  @override
  ConsumerState<RealTimeGasMonitorScreen> createState() => _RealTimeGasMonitorScreenState();
}

class _RealTimeGasMonitorScreenState extends ConsumerState<RealTimeGasMonitorScreen>
    with TickerProviderStateMixin {
  String? _selectedDeviceName;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onDeviceFilterChanged(String? deviceName) {
    setState(() {
      _selectedDeviceName = deviceName;
    });
    ref.read(gasDataProvider.notifier).setDeviceFilter(deviceName);
  }

  void _startPulseAnimation() {
    _pulseController.forward().then((_) {
      _pulseController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final gasDataState = ref.watch(gasDataProvider);
    final availableDevices = ref.watch(availableDevicesProvider);

    // Trigger pulse animation when new data arrives
    ref.listen<GasDataState>(gasDataProvider, (previous, next) {
      if (previous?.latestReading?.id != next.latestReading?.id && 
          next.latestReading != null) {
        _startPulseAnimation();
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Gas Leak Monitor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'devices':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DevicesScreen(),
                    ),
                  );
                  break;
                case 'alerts_history':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AlertsHistoryScreen(),
                    ),
                  );
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                                          MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'devices',
                child: Row(
                  children: [
                    Icon(Icons.devices, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text('Devices'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'alerts_history',
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.deepOrange),
                    SizedBox(width: 8),
                    Text('Alerts & History'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(gasDataProvider.notifier).refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(gasDataProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Real-time status indicator
              _buildRealTimeStatusIndicator(gasDataState),
              
              // Device Filter Section
              _buildDeviceFilter(availableDevices),
              
              // Current Gas Level Section (Real-time)
              _buildRealTimeLatestReadingCard(gasDataState),
              
              // Recent Readings Section (Real-time)
              const SizedBox(height: 8),
              _buildRealTimeRecentReadingsSection(gasDataState),
              
              // Bottom padding for better scrolling
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRealTimeStatusIndicator(GasDataState gasDataState) {
    final timeSinceUpdate = DateTime.now().difference(gasDataState.lastUpdated);
    final isRealTime = timeSinceUpdate.inSeconds < 10;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isRealTime ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRealTime ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isRealTime ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                    boxShadow: isRealTime ? [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ] : null,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRealTime ? '🔴 LIVE' : '⚡ Real-time',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  isRealTime 
                      ? 'Receiving live data' 
                      : 'Last update: ${timeSinceUpdate.inSeconds}s ago',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (gasDataState.isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceFilter(List<String> availableDevices) {
    // Filter out test devices from the dropdown
    final filteredDevices = availableDevices.where((device) => !_isTestDevice(device)).toList();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_list, color: Colors.teal[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedDeviceName,
                hint: const Text('All Devices'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Devices'),
                  ),
                  ...filteredDevices.map((String device) {
                    return DropdownMenuItem<String>(
                      value: device,
                      child: Row(
                        children: [
                          Icon(Icons.sensors, color: Colors.green[600], size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(device)),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: _onDeviceFilterChanged,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: () => ref.read(availableDevicesProvider.notifier).refresh(),
            tooltip: 'Refresh devices',
          ),
        ],
      ),
    );
  }

  /// Check if a device name is a test device that should be filtered out
  /// This ensures NO test devices appear in device dropdowns
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

  Widget _buildRealTimeLatestReadingCard(GasDataState gasDataState) {
    if (gasDataState.isLoading && gasDataState.latestReading == null) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading real-time data...',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      );
    }

    if (gasDataState.error != null) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text('Error', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(gasDataState.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(gasDataProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (gasDataState.latestReading == null) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.sensors_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('No Data Available', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Waiting for real-time sensor data...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final reading = gasDataState.latestReading!;
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 4,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    reading.levelColor.withValues(alpha: 0.1),
                    reading.levelColor.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(reading.levelIcon, size: 40, color: reading.levelColor),
                        const SizedBox(width: 12),
                        Text('Live Gas Level', style: Theme.of(context).textTheme.headlineSmall),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Gas Level Display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: reading.levelColor,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        reading.gasLevel.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Gas Value
                    Text(
                      '${reading.gasValue} PPM',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: reading.levelColor,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Timestamp and Device Info
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              TimeFormatter.formatDateTime(reading.createdAt),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.device_hub, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              reading.deviceName,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRealTimeRecentReadingsSection(GasDataState gasDataState) {
    if (gasDataState.recentReadings.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.timeline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No Recent Readings', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Real-time readings will appear here automatically',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.timeline, color: Colors.teal, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Recent Readings (Live)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${gasDataState.recentReadings.length} readings',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: gasDataState.recentReadings.length,
          itemBuilder: (context, index) {
            final reading = gasDataState.recentReadings[index];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Card(
                elevation: 2,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: reading.levelColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(reading.levelIcon, color: reading.levelColor, size: 20),
                  ),
                  title: Text(
                    'Gas Level: ${reading.gasLevel.toUpperCase()} - ${reading.gasValue} PPM',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: reading.levelColor,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Device: ${reading.deviceName}'),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            TimeFormatter.getTimeAgo(reading.createdAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: reading.levelColor,
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
                      const SizedBox(height: 4),
                      Text(
                        'ppm',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
} 