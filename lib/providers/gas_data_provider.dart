import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gas_sensor_reading.dart';
import '../services/supabase_service.dart';

/// Real-time gas sensor data state
class GasDataState {
  final GasSensorReading? latestReading;
  final List<GasSensorReading> recentReadings;
  final bool isLoading;
  final String? error;
  final DateTime lastUpdated;

  const GasDataState({
    this.latestReading,
    this.recentReadings = const [],
    this.isLoading = false,
    this.error,
    required this.lastUpdated,
  });

  GasDataState copyWith({
    GasSensorReading? latestReading,
    List<GasSensorReading>? recentReadings,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return GasDataState(
      latestReading: latestReading ?? this.latestReading,
      recentReadings: recentReadings ?? this.recentReadings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }
}

/// Real-time gas data provider using streams
class GasDataNotifier extends StateNotifier<GasDataState> {
  final SupabaseService _supabaseService;
  RealtimeChannel? _subscription;
  Timer? _connectionHealthTimer;
  String? _deviceFilter;

  GasDataNotifier(this._supabaseService) : super(GasDataState(lastUpdated: DateTime.fromMillisecondsSinceEpoch(0))) {
    _initializeRealTimeData();
    _startConnectionHealthCheck();
  }

  /// Initialize real-time data subscription
  void _initializeRealTimeData() {
    _loadInitialData();
    _setupRealtimeSubscription();
  }

  /// Load initial data from database
  Future<void> _loadInitialData() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final results = await Future.wait([
        _supabaseService.getLatestReadingFiltered(deviceName: _deviceFilter),
        _supabaseService.getRecentReadingsFiltered(limit: 10, deviceName: _deviceFilter),
      ]);

      final latestReading = results[0] as GasSensorReading?;
      final recentReadings = results[1] as List<GasSensorReading>;

      state = state.copyWith(
        latestReading: latestReading,
        recentReadings: recentReadings,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      // Handle the case where no data is found gracefully
      state = state.copyWith(
        latestReading: null,
        recentReadings: [],
        isLoading: false,
        error: null, // Don't show error for empty data
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// Setup real-time subscription with enhanced error handling
  void _setupRealtimeSubscription() {
    try {
      _subscription?.unsubscribe();
      
      _subscription = _supabaseService.subscribeToReadings(
        onInsert: (reading) {
          // Only update if no filter is set or reading matches filter
          if (_deviceFilter == null || reading.deviceName == _deviceFilter) {
            _handleNewReading(reading);
          }
        },
        onUpdate: (reading) {
          if (_deviceFilter == null || reading.deviceName == _deviceFilter) {
            _handleUpdatedReading(reading);
          }
        },
      );
    } catch (e) {
      state = state.copyWith(error: 'Real-time connection failed: $e');
    }
  }

  /// Check if a device name is a test device that should be filtered out
  /// This ensures NO test devices appear in any real-time data streams
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

  /// Handle new gas sensor reading
  void _handleNewReading(GasSensorReading newReading) {
    // Skip test devices from appearing in real-time data
    if (_isTestDevice(newReading.deviceName)) {
      return;
    }
    
    final updatedRecentReadings = [newReading, ...state.recentReadings];
    
    // Keep only the latest 10 readings
    final limitedReadings = updatedRecentReadings.take(10).toList();
    
    state = state.copyWith(
      latestReading: newReading,
      recentReadings: limitedReadings,
      error: null,
      lastUpdated: DateTime.now(),
    );
  }

  /// Handle updated gas sensor reading
  void _handleUpdatedReading(GasSensorReading updatedReading) {
    // Skip test devices from appearing in real-time data
    if (_isTestDevice(updatedReading.deviceName)) {
      return;
    }
    
    final updatedRecentReadings = state.recentReadings.map((reading) {
      return reading.id == updatedReading.id ? updatedReading : reading;
    }).toList();

    // Update latest reading if it's the same ID
    final updatedLatestReading = state.latestReading?.id == updatedReading.id
        ? updatedReading
        : state.latestReading;

    state = state.copyWith(
      latestReading: updatedLatestReading,
      recentReadings: updatedRecentReadings,
      error: null,
      lastUpdated: DateTime.now(),
    );
  }

  /// Set device filter and refresh data
  Future<void> setDeviceFilter(String? deviceName) async {
    if (_deviceFilter != deviceName) {
      _deviceFilter = deviceName;
      await _loadInitialData();
      _setupRealtimeSubscription(); // Re-setup subscription with new filter
    }
  }

  /// Force refresh data (for manual refresh if needed)
  Future<void> refresh() async {
    await _loadInitialData();
  }

  /// Start connection health check with controlled monitoring
  void _startConnectionHealthCheck() {
    _connectionHealthTimer = Timer.periodic(
      const Duration(minutes: 2), // Check every 2 minutes to avoid spam
      (timer) {
        // Check if we've received data recently
        final timeSinceLastUpdate = DateTime.now().difference(state.lastUpdated);
        
        // Only reconnect if no update for 5 minutes AND subscription exists
        if (timeSinceLastUpdate.inMinutes >= 5 && _subscription != null) {
          if (kDebugMode) print('⚡ Real-time connection may be stale, reconnecting...');
          _setupRealtimeSubscription();
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _connectionHealthTimer?.cancel();
    super.dispose();
  }
}

/// Provider for real-time gas data
final gasDataProvider = StateNotifierProvider<GasDataNotifier, GasDataState>((ref) {
  return GasDataNotifier(SupabaseService.instance);
});

/// Stream provider for real-time updates (alternative approach)
final gasDataStreamProvider = StreamProvider<GasSensorReading?>((ref) {
  final completer = Completer<void>();
  GasSensorReading? latestReading;
  
  final subscription = SupabaseService.instance.subscribeToReadings(
    onInsert: (reading) {
      latestReading = reading;
      if (!completer.isCompleted) {
        completer.complete();
      }
    },
    onUpdate: (reading) {
      latestReading = reading;
    },
  );

  ref.onDispose(() {
    SupabaseService.instance.unsubscribe(subscription);
  });

  return Stream.periodic(const Duration(milliseconds: 100), (_) => latestReading)
      .where((reading) => reading != null)
      .distinct((previous, next) => previous?.id == next?.id);
});

/// Provider for available devices (real-time updated)
final availableDevicesProvider = StateNotifierProvider<AvailableDevicesNotifier, List<String>>((ref) {
  return AvailableDevicesNotifier();
});

class AvailableDevicesNotifier extends StateNotifier<List<String>> {
  Timer? _refreshTimer;
  
  AvailableDevicesNotifier() : super([]) {
    _loadDevices();
    _startPeriodicRefresh();
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await SupabaseService.instance.getAvailableDevices();
      state = devices;
    } catch (e) {
      // Keep current state on error
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadDevices();
    });
  }

  Future<void> refresh() async {
    await _loadDevices();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
} 