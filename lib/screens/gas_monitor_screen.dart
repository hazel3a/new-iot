import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/device.dart';
import '../services/supabase_service.dart';
import '../services/device_service.dart';
import '../services/auth_service.dart';
import '../services/gas_notification_service.dart';
import '../providers/gas_data_provider.dart';
import '../utils/time_formatter.dart';
import 'settings_screen.dart';
import 'devices_screen.dart';
import 'alerts_history_screen.dart';
import 'login_screen.dart';
import '../utils/wifi_provisioning_navigation.dart';


class GasMonitorScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;
  
  const GasMonitorScreen({
    super.key,
    this.isDarkMode = false,
    required this.onDarkModeChanged,
  });

  @override
  ConsumerState<GasMonitorScreen> createState() => _GasMonitorScreenState();
}

class _GasMonitorScreenState extends ConsumerState<GasMonitorScreen>
    with TickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final DeviceService _deviceService = DeviceService.instance;
  
  List<Device> _availableDevices = [];
  List<Device> _onlineDevices = [];
  String? _selectedDeviceName;
  RealtimeChannel? _subscription;
  RealtimeChannel? _deviceSubscription;
  Timer? _periodicTimer;
  Timer? _liveTimeTimer;
  
  // Animation for real-time updates
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupLiveTimeUpdates();
    _loadDevices();
    _setupRealtimeSubscription();
    _setupDeviceSubscription();
    _setupPeriodicRefresh();
    
    // Additional instant device check after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _refreshDeviceStatusInstantly();
    });
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _setupLiveTimeUpdates() {
    // Update current time every second for live time display
    _liveTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Live time updates for UI refresh
        });
      }
    });
  }

  @override
  void dispose() {
    if (_subscription != null) {
      _supabaseService.unsubscribe(_subscription!);
    }
    if (_deviceSubscription != null) {
      _deviceService.unsubscribe(_deviceSubscription!);
    }
    _periodicTimer?.cancel();
    _liveTimeTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    try {
      // Load all devices but filter out test devices using SupabaseService filtering
      final allDevices = await _deviceService.getDeviceHistory();
      
      // Filter out test devices using the same logic as SupabaseService
      final filteredDevices = allDevices.where((device) => 
        !_isTestDevice(device.deviceName)).toList();
      
      // Load only online devices for status indicator (also filtered)
      final onlineDevices = filteredDevices.where((device) => 
        device.connectionStatus == ConnectionStatus.online).toList();
      
      if (mounted) {
        setState(() {
          _availableDevices = filteredDevices;
          _onlineDevices = onlineDevices;
        });
      }
    } catch (e) {
      debugPrint('Error loading devices: $e');
    }
  }

  /// Check if a device name is a test device that should be filtered out
  /// This ensures NO test devices appear in main screen device dropdown
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

  void _onDeviceFilterChanged(String? deviceName) {
    setState(() {
      _selectedDeviceName = deviceName;
    });
    // Update the Riverpod provider with the new filter
    ref.read(gasDataProvider.notifier).setDeviceFilter(deviceName);
  }

  void _setupRealtimeSubscription() {
    try {
      _subscription = _supabaseService.subscribeToReadings(
        onInsert: (reading) {
          // Trigger pulse animation for new data
          _triggerPulseAnimation();
          
          // INSTANT device status update when new reading arrives
          debugPrint('📊 NEW READING DETECTED: ${reading.deviceName} - triggering instant device update');
          _refreshDeviceStatusInstantly();
        },
        onUpdate: (reading) {
          // Also trigger instant device update on reading updates
          _refreshDeviceStatusInstantly();
        },
      );
    } catch (e) {
      debugPrint('Error setting up real-time subscription: $e');
    }
  }

  void _setupDeviceSubscription() {
    try {
      // Enhanced device subscription for instant updates
      _deviceSubscription = _deviceService.subscribeToDeviceUpdates(
        onDeviceUpdate: (device) {
          // Immediate state update for instant UI reflection
          if (mounted) {
            setState(() {
              // Update device in available devices list
              final index = _availableDevices.indexWhere((d) => d.deviceId == device.deviceId);
              if (index != -1) {
                _availableDevices[index] = device;
              } else {
                _availableDevices.add(device);
              }
              
              // Instantly update online devices list
              _onlineDevices = _availableDevices.where((d) => 
                d.connectionStatus == ConnectionStatus.online).toList();
            });
          }
          
          // Debug log for instant detection verification
          debugPrint('🔄 INSTANT UPDATE: Device ${device.deviceName} is now ${device.connectionStatus}');
        },
        onNewConnection: (connection) {
          // Immediate refresh when new connections are made
          debugPrint('🔌 NEW CONNECTION: ${connection.deviceName}');
          _refreshDeviceStatusInstantly();
        },
      );
    } catch (e) {
      debugPrint('Error setting up device subscription: $e');
    }
  }

  void _setupPeriodicRefresh() {
    // Real-time refresh every 2 seconds for continuous updates
    _periodicTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _refreshDeviceStatusInstantly();
      
      // Force refresh of gas data provider for real-time data
      ref.read(gasDataProvider.notifier).refresh();
      
      // Trigger UI update for live time displays in readings
      if (mounted) {
        setState(() {
          // This forces rebuild of time-dependent widgets for real-time updates
        });
      }
    });
  }

  Future<void> _refreshDeviceStatusInstantly() async {
    try {
      // Quick device status check without full reload
      final allDevices = await _deviceService.getDeviceHistory();
      
      // Filter out test devices using the same logic as SupabaseService
      final filteredDevices = allDevices.where((device) => 
        !_isTestDevice(device.deviceName)).toList();
      
      final onlineDevices = filteredDevices.where((device) => 
        device.connectionStatus == ConnectionStatus.online).toList();
      
      // Only update if there's a change to avoid unnecessary rebuilds
      if (mounted && (_availableDevices.length != filteredDevices.length || 
          _onlineDevices.length != onlineDevices.length)) {
        setState(() {
          _availableDevices = filteredDevices;
          _onlineDevices = onlineDevices;
        });
      }
    } catch (e) {
      debugPrint('Error in instant device status refresh: $e');
    }
  }

  void _triggerPulseAnimation() {
    if (mounted) {
      _pulseController.forward().then((_) {
        _pulseController.reverse();
      });
    }
  }

  Future<void> _handleLogout() async {
    try {
      // Show confirmation dialog
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Logout'),
            ),
          ],
        ),
      );

      if (shouldLogout == true) {
        // 🔔 STOP NOTIFICATIONS: User is logging out
        try {
          GasNotificationService.instance.stopMonitoring();
          print('🔒 NOTIFICATIONS STOPPED: User logged out');
        } catch (e) {
          print('⚠️ Failed to stop notifications: $e');
        }

        // Sign out from Supabase
        await AuthService.instance.signOut();

        // Navigate to login screen and clear navigation stack
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => LoginScreen(
                isDarkMode: widget.isDarkMode,
                onDarkModeChanged: widget.onDarkModeChanged,
              ),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  Widget _buildDeviceFilter() {
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
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedDeviceName,
                hint: const Row(
                  children: [
                    Icon(Icons.developer_board, size: 18, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('All Devices', style: TextStyle(fontFamily: 'Roboto')),
                  ],
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(Icons.developer_board, size: 18, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('All Devices', style: TextStyle(fontFamily: 'Roboto')),
                      ],
                    ),
                  ),
                  ..._availableDevices.map((device) {
                    final isOnline = device.connectionStatus == ConnectionStatus.online;
                    return DropdownMenuItem<String>(
                      value: device.deviceName,
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            color: isOnline ? Colors.green : Colors.grey,
                            size: 8,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              device.deviceName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'Roboto'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isOnline ? Colors.green[700] : Colors.grey[600],
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: _onDeviceFilterChanged,
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildLatestReadingCard(GasDataState gasDataState) {
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
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontFamily: 'Roboto',
                        ),
                      ),
              const SizedBox(height: 8),
                                    Text(
                        'Connecting to live sensors...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                          fontFamily: 'Roboto',
                        ),
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
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Connection Error',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                gasDataState.error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(gasDataProvider.notifier).refresh(),
                child: const Text(
                  'Retry Connection',
                  style: TextStyle(fontFamily: 'Roboto'),
                ),
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
              Icon(
                Icons.sensors_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No Data Available',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Waiting for real-time sensor data...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  fontFamily: 'Roboto',
                ),
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
                        Icon(
                          reading.levelIcon,
                          size: 40,
                          color: reading.levelColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Current Gas Level',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
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
                          fontFamily: 'Roboto',
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
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
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
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
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

  Widget _buildRecentReadingsSection(GasDataState gasDataState) {
    if (gasDataState.recentReadings.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.timeline,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Recent Readings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Real-time readings will appear here automatically',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
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
          child: Text(
            'Recent Readings',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
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
                    child: Icon(
                      reading.levelIcon,
                      color: reading.levelColor,
                      size: 20,
                    ),
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
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
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
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
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

  @override
  Widget build(BuildContext context) {
    // Watch the real-time gas data from Riverpod
    final gasDataState = ref.watch(gasDataProvider);
    
    // Listen for changes and trigger animations
    ref.listen<GasDataState>(gasDataProvider, (previous, next) {
      if (previous?.latestReading?.id != next.latestReading?.id && 
          next.latestReading != null) {
        _triggerPulseAnimation();
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'GAS LEAK MONITOR',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 1.2,
              fontFamily: 'Roboto',
            ),
          ),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
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
                case 'wifi_setup':
                  WiFiProvisioningNavigation.navigateToWiFiSetup(context);
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsScreen(
                        isDarkMode: widget.isDarkMode,
                        onDarkModeChanged: widget.onDarkModeChanged,
                      ),
                    ),
                  );
                  break;
                case 'logout':
                  _handleLogout();
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
              const PopupMenuItem(
                value: 'wifi_setup',
                child: Row(
                  children: [
                    Icon(Icons.wifi_rounded, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('WiFi Setup'),
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
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
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
              // Device Filter Section (removed real-time status indicator)
              _buildDeviceFilter(),
              
              // Current Gas Level Section (Real-time)
              _buildLatestReadingCard(gasDataState),
              
              // Recent Readings Section (Real-time)
              const SizedBox(height: 8),
              _buildRecentReadingsSection(gasDataState),
              
              // Bottom padding for better scrolling
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
} 