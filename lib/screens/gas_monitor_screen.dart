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
  const GasMonitorScreen({super.key});

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
      
      // Filter out test devices AND blocked devices
      final filteredDevices = allDevices.where((device) => 
        !_isTestDevice(device.deviceName) && device.status != DeviceStatus.blocked).toList();
      
      // Load only devices with active gas readings for status indicator (also filtered)
      // Use gas reading activity for accurate online detection
      final onlineDevices = filteredDevices.where((device) => 
        device.hasActiveGasReadings).toList();
      
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
              // Update device in available devices list (only if not blocked)
              if (device.status != DeviceStatus.blocked) {
                final index = _availableDevices.indexWhere((d) => d.deviceId == device.deviceId);
                if (index != -1) {
                  _availableDevices[index] = device;
                } else {
                  _availableDevices.add(device);
                }
              } else {
                // Remove blocked device from the list if it exists
                _availableDevices.removeWhere((d) => d.deviceId == device.deviceId);
              }
              
              // Instantly update online devices list using gas reading activity (excluding blocked)
              _onlineDevices = _availableDevices.where((d) => 
                d.hasActiveGasReadings && d.status != DeviceStatus.blocked).toList();
            });
          }
          
          // Debug log for instant detection verification
          debugPrint('🔄 INSTANT UPDATE: Device ${device.deviceName} is now ${device.connectionStatus} (Status: ${device.status.value})');
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
    // Real-time refresh every 3 seconds to match gas reading activity
    _periodicTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _refreshDeviceStatusInstantly();
      
      // Force refresh of gas data provider for real-time data
      ref.read(gasDataProvider.notifier).refresh();
      
      // Trigger UI update for live time displays and device online/offline status
      if (mounted) {
        setState(() {
          // This forces rebuild of time-dependent widgets and online/offline status
          // Update online devices list based on real-time gas reading activity
          _onlineDevices = _availableDevices.where((d) => 
            d.hasActiveGasReadings).toList();
        });
      }
    });
  }

  Future<void> _refreshDeviceStatusInstantly() async {
    try {
      // Quick device status check without full reload
      final allDevices = await _deviceService.getDeviceHistory();
      
      // Filter out test devices AND blocked devices
      final filteredDevices = allDevices.where((device) => 
        !_isTestDevice(device.deviceName) && device.status != DeviceStatus.blocked).toList();
      
      final onlineDevices = filteredDevices.where((device) => 
        device.hasActiveGasReadings).toList();
      
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
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF87171).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.logout,
                  color: Color(0xFFF87171),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Sign Out',
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to sign out? Gas monitoring notifications will be stopped.',
            style: TextStyle(
              color: Color(0xFFE5E7EB),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF87171),
                foregroundColor: const Color(0xFFFFFFFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
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
                builder: (context) => const LoginScreen(),
              ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF87171).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Color(0xFFF87171),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Logout failed: $e',
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF111827),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Widget _buildDeviceFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF374151),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4ADE80).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.developer_board,
              color: Color(0xFF4ADE80),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedDeviceName,
                dropdownColor: const Color(0xFF111827),
                style: const TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontSize: 16,
                  fontFamily: 'Inter',
                ),
                hint: const Text(
                  'All Devices',
                  style: TextStyle(
                    color: Color(0xFFE5E7EB),
                    fontFamily: 'Inter',
                    fontSize: 16,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'All Devices',
                      style: TextStyle(
                        color: Color(0xFFE5E7EB),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  ..._availableDevices.map((device) {
                    final isOnline = device.hasActiveGasReadings;
                    return DropdownMenuItem<String>(
                      value: device.deviceName,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isOnline ? const Color(0xFF4ADE80) : const Color(0xFF6B7280),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              device.deviceName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFE5E7EB),
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOnline 
                                  ? const Color(0xFF4ADE80).withOpacity(0.1)
                                  : const Color(0xFF6B7280).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isOnline ? const Color(0xFF4ADE80) : const Color(0xFF6B7280),
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: _onDeviceFilterChanged,
                icon: const Icon(
                  Icons.expand_more,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestReadingCard(GasDataState gasDataState) {
    if (gasDataState.isLoading && gasDataState.latestReading == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF4ADE80).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ADE80)),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading real-time data...',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFFFFFFFF),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connecting to live sensors...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      );
    }

    if (gasDataState.error != null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFF87171).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 24),
            Text(
              'Connection Error',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFFFFFFFF),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              gasDataState.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref.read(gasDataProvider.notifier).refresh(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ADE80),
                foregroundColor: const Color(0xFF0F0F0F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Retry Connection',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (gasDataState.latestReading == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6B7280).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sensors_off,
                size: 48,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Data Available',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFFFFFFFF),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for real-time sensor data...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      );
    }

    final reading = gasDataState.latestReading!;
    
    // Determine colors based on gas levels using Bankout theme
    Color levelColor;
    if (reading.gasLevel.toLowerCase() == 'safe') {
      levelColor = const Color(0xFF4ADE80); // Mint green for safe
    } else if (reading.gasLevel.toLowerCase() == 'warning') {
      levelColor = const Color(0xFFFBBF24); // Yellow for warning
    } else if (reading.gasLevel.toLowerCase() == 'danger') {
      levelColor = const Color(0xFFF87171); // Soft red for danger
    } else if (reading.gasLevel.toLowerCase() == 'critical') {
      levelColor = const Color(0xFF8B0000); // Bloody red for critical
    } else {
      levelColor = const Color(0xFFF87171); // Default red for unknown
    }
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: levelColor.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  // Header with icon and title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: levelColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          reading.levelIcon,
                          size: 32,
                          color: levelColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Current Gas Level',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFFFFFFFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Gas Level Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      color: levelColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      reading.gasLevel.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF0F0F0F),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Gas Value Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${reading.gasValue}',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: levelColor,
                          fontSize: 48,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'PPM',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: levelColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Info Cards
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F0F0F),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 20,
                                color: const Color(0xFF4ADE80),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                TimeFormatter.formatDateTime(reading.createdAt),
                                style: const TextStyle(
                                  color: Color(0xFFE5E7EB),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
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
                            color: const Color(0xFF0F0F0F),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.device_hub,
                                size: 20,
                                color: const Color(0xFF4ADE80),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                reading.deviceName,
                                style: const TextStyle(
                                  color: Color(0xFFE5E7EB),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6B7280).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.timeline,
                size: 48,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Recent Readings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFFFFFFF),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time readings will appear here automatically',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF9CA3AF),
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
                  color: const Color(0xFF4ADE80).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.timeline,
                  color: Color(0xFF4ADE80),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Recent Readings',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFFFFF),
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
            
            // Determine colors based on gas levels using Bankout theme
            Color levelColor;
            if (reading.gasLevel.toLowerCase() == 'safe') {
              levelColor = const Color(0xFF4ADE80); // Mint green for safe
            } else if (reading.gasLevel.toLowerCase() == 'warning') {
              levelColor = const Color(0xFFFBBF24); // Yellow for warning
            } else if (reading.gasLevel.toLowerCase() == 'danger') {
              levelColor = const Color(0xFFF87171); // Soft red for danger
            } else if (reading.gasLevel.toLowerCase() == 'critical') {
              levelColor = const Color(0xFF8B0000); // Bloody red for critical
            } else {
              levelColor = const Color(0xFFF87171); // Default red for unknown
            }
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: levelColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Status indicator
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: levelColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        reading.levelIcon,
                        color: levelColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Gas level badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: levelColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              reading.gasLevel.toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF0F0F0F),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Device name
                          Text(
                            reading.deviceName,
                            style: const TextStyle(
                              color: Color(0xFFE5E7EB),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          
                          // Timestamp
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: const Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                TimeFormatter.getTimeAgo(reading.createdAt),
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Gas value display
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${reading.gasValue}',
                          style: TextStyle(
                            color: levelColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        Text(
                          'PPM',
                          style: TextStyle(
                            fontSize: 12,
                            color: levelColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
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
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4ADE80).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.gas_meter_rounded,
                color: Color(0xFF34BB8B),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Gas Leak Detector',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFFFFFFFF),
                fontFamily: 'SF Pro Display',
              ),
            ),
          ],
        ),
        actions: [
          // Online devices indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _onlineDevices.isNotEmpty 
                        ? const Color(0xFF4ADE80) 
                        : const Color(0xFF6B7280),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_onlineDevices.length}',
                  style: const TextStyle(
                    color: Color(0xFFE5E7EB),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          // Menu button
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: Color(0xFF4ADE80),
              ),
              color: const Color(0xFF111827),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
                  case 'settings':
                    Navigator.push(
                      context,
                                              MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                    );
                    break;
                  case 'logout':
                    _handleLogout();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'devices',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ADE80).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.devices,
                          color: Color(0xFF4ADE80),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Devices',
                        style: TextStyle(
                          color: Color(0xFFE5E7EB),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B7280).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: Color(0xFF6B7280),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Settings',
                        style: TextStyle(
                          color: Color(0xFFE5E7EB),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF87171).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.logout,
                          color: Color(0xFFF87171),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Sign Out',
                        style: TextStyle(
                          color: Color(0xFFF87171),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(gasDataProvider.notifier).refresh(),
        color: const Color(0xFF4ADE80),
        backgroundColor: const Color(0xFF111827),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              
              // Device Filter Section
              _buildDeviceFilter(),
              
              // Current Gas Level Section (Real-time)
              _buildLatestReadingCard(gasDataState),
              
              // Recent Readings Section (Real-time)
              const SizedBox(height: 16),
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