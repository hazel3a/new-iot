import 'dart:async';
// import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gas_sensor_reading.dart';
import 'package:logger/logger.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;

  static final Logger _logger = Logger();

  /// Check if a device name is a test device that should be filtered out
  /// This ensures NO test devices appear in any device lists
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

  // Initialize Supabase
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  // Fetch the latest gas sensor reading
  Future<GasSensorReading?> getLatestReading() async {
    try {
      final response = await client
          .from('gas_sensor_readings')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .single();

      return GasSensorReading.fromJson(response);
    } catch (e) {
      _logger.e('Error fetching latest reading', e);
      return null;
    }
  }

  // Fetch recent gas sensor readings (last N readings) - User-specific
  Future<List<GasSensorReading>> getRecentReadings({int limit = 10}) async {
    try {
      var query = client
          .from('gas_sensor_readings')
          .select();

      // Add user filter if user is authenticated
      final user = client.auth.currentUser;
      if (user != null) {
        query = query.eq('user_id', user.id);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return response
          .map<GasSensorReading>((json) => GasSensorReading.fromJson(json))
          .toList();
    } catch (e) {
      _logger.e('Error fetching recent readings', e);
      return [];
    }
  }

  // Subscribe to real-time updates for gas sensor readings with ultra-fast response - User-specific
  RealtimeChannel subscribeToReadings({
    required Function(GasSensorReading) onInsert,
    required Function(GasSensorReading) onUpdate,
    Function(Map<String, dynamic>)? onDelete,
  }) {
    final user = client.auth.currentUser;
    final subscription = client
        .channel('ultra_fast_gas_readings_${DateTime.now().millisecondsSinceEpoch}') // Unique channel name
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'gas_sensor_readings',
          filter: user != null ? PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ) : null,
          callback: (payload) {
            try {
              final reading = GasSensorReading.fromJson(payload.newRecord);
              // Only process readings from real ESP32 devices (not test devices)
              if (!_isTestDevice(reading.deviceName)) {
                _logger.i('⚡ INSTANT ESP32 reading: ${reading.gasValue} PPM from ${reading.deviceName}');
                onInsert(reading);
              }
            } catch (e) {
              _logger.e('Error processing real-time insert: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'gas_sensor_readings',
          filter: user != null ? PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ) : null,
          callback: (payload) {
            try {
              final reading = GasSensorReading.fromJson(payload.newRecord);
              if (!_isTestDevice(reading.deviceName)) {
                _logger.i('⚡ INSTANT ESP32 update: ${reading.gasValue} PPM from ${reading.deviceName}');
                onUpdate(reading);
              }
            } catch (e) {
              _logger.e('Error processing real-time update: $e');
            }
          },
        );

    if (onDelete != null) {
      subscription.onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'gas_sensor_readings',
        callback: (payload) {
          onDelete(payload.oldRecord);
        },
      );
    }

    subscription.subscribe();
    _logger.i('🚀 Ultra-fast real-time subscription activated for ESP32 gas sensors');
    return subscription;
  }

  // Unsubscribe from real-time updates
  void unsubscribe(RealtimeChannel subscription) {
    subscription.unsubscribe();
  }

  // Get readings by device
  Future<List<GasSensorReading>> getReadingsByDevice(
    String deviceId, {
    int limit = 50,
  }) async {
    try {
      final response = await client
          .from('gas_sensor_readings')
          .select()
          .eq('device_id', deviceId)
          .order('created_at', ascending: false)
          .limit(limit);

      return response
          .map<GasSensorReading>((json) => GasSensorReading.fromJson(json))
          .toList();
    } catch (e) {
      _logger.e('Error fetching readings by device', e);
      return [];
    }
  }

  // Get readings within a date range
  Future<List<GasSensorReading>> getReadingsInRange({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 100,
  }) async {
    try {
      final response = await client
          .from('gas_sensor_readings')
          .select()
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);

      return response
          .map<GasSensorReading>((json) => GasSensorReading.fromJson(json))
          .toList();
    } catch (e) {
      _logger.e('Error fetching readings in range', e);
      return [];
    }
  }

  // Get all available devices from gas_sensor_readings table (excluding test devices) - User-specific
  Future<List<String>> getAvailableDevices() async {
    try {
      var query = client
          .from('gas_sensor_readings')
          .select('device_name')
          .not('device_name', 'is', null);

      // Add user filter if user is authenticated
      final user = client.auth.currentUser;
      if (user != null) {
        query = query.eq('user_id', user.id);
      }

      final response = await query;

      // Get unique device names, excluding ALL test devices
      final Set<String> uniqueDevices = {};
      for (final row in response) {
        final deviceName = row['device_name'] as String?;
        if (deviceName != null && 
            deviceName.isNotEmpty && 
            !_isTestDevice(deviceName)) {
          uniqueDevices.add(deviceName);
        }
      }

      return uniqueDevices.toList()..sort();
    } catch (e) {
      _logger.e('Error fetching available devices', e);
      // Return sample devices for testing if no real devices found
      return [
        'Kitchen Gas Detector',
        'Living Room Monitor',
        'Basement Gas Sensor',
      ];
    }
  }

  // Get recent readings filtered by device name (EXCLUDING ALL TEST DEVICES)
  Future<List<GasSensorReading>> getRecentReadingsFiltered({
    int limit = 10,
    String? deviceName,
  }) async {
    try {
      var query = client
          .from('gas_sensor_readings')
          .select();

      if (deviceName != null && deviceName.isNotEmpty) {
        query = query.eq('device_name', deviceName);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit * 3); // Get more to account for filtering

      // Filter out ALL test devices from the results
      final filteredReadings = response
          .map<GasSensorReading>((json) => GasSensorReading.fromJson(json))
          .where((reading) => !_isTestDevice(reading.deviceName))
          .take(limit)
          .toList();

      return filteredReadings;
    } catch (e) {
      _logger.e('Error fetching filtered recent readings', e);
      return [];
    }
  }

  // Get latest reading filtered by device name (EXCLUDING ALL TEST DEVICES)
  Future<GasSensorReading?> getLatestReadingFiltered({String? deviceName}) async {
    try {
      var query = client
          .from('gas_sensor_readings')
          .select();

      if (deviceName != null && deviceName.isNotEmpty) {
        query = query.eq('device_name', deviceName);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(50); // Get more records to find non-test devices

      // Filter out ALL test devices and get the latest real reading
      final readings = response
          .map<GasSensorReading>((json) => GasSensorReading.fromJson(json))
          .where((reading) => !_isTestDevice(reading.deviceName))
          .toList();

      return readings.isNotEmpty ? readings.first : null;
    } catch (e) {
      _logger.e('Error fetching filtered latest reading', e);
      return null;
    }
  }


}
