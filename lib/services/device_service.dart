import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/device.dart';
import 'package:logger/logger.dart';

class DeviceService {
  static DeviceService? _instance;
  static DeviceService get instance => _instance ??= DeviceService._();

  DeviceService._();

  SupabaseClient get client => Supabase.instance.client;
  static final Logger _logger = Logger();

  // Get all active devices (not blocked, online status)
  Future<List<Device>> getActiveDevices() async {
    try {
      final response = await client
          .from('active_devices')
          .select()
          .order('last_data_received', ascending: false);

      return response
          .map<Device>((json) => Device.fromJson(json))
          .toList();
    } catch (e) {
      _logger.e('Error fetching active devices', e);
      return [];
    }
  }

  // Get all devices (for history/management)
  Future<List<Device>> getDeviceHistory() async {
    try {
      final response = await client
          .from('device_history')
          .select()
          .order('last_data_received', ascending: false);

      return response
          .map<Device>((json) => Device.fromJson(json))
          .toList();
    } catch (e) {
      _logger.e('Error fetching device history', e);
      return [];
    }
  }

  // Get device by ID
  Future<Device?> getDevice(String deviceId) async {
    try {
      final response = await client
          .from('device_history')
          .select()
          .eq('device_id', deviceId)
          .single();

      return Device.fromJson(response);
    } catch (e) {
      _logger.e('Error fetching device: $deviceId', e);
      return null;
    }
  }

  // Update device status (Allow/Block/Inactive)
  Future<bool> updateDeviceStatus(String deviceId, DeviceStatus status) async {
    try {
      await client
          .from('devices')
          .update({'status': status.value})
          .eq('device_id', deviceId);

      return true;
    } catch (e) {
      _logger.e('Error updating device status: $deviceId', e);
      return false;
    }
  }

  // Delete device
  Future<bool> deleteDevice(String deviceId) async {
    try {
      // Delete device (cascades to connections due to foreign key)
      await client
          .from('devices')
          .delete()
          .eq('device_id', deviceId);

      return true;
    } catch (e) {
      _logger.e('Error deleting device: $deviceId', e);
      return false;
    }
  }

  // Get recent device connections
  Future<List<DeviceConnection>> getRecentConnections({int limit = 50}) async {
    try {
      final response = await client
          .from('recent_device_connections')
          .select()
          .limit(limit)
          .order('connected_at', ascending: false);

      return response
          .map<DeviceConnection>((json) => DeviceConnection.fromJson(json))
          .toList();
    } catch (e) {
      _logger.e('Error fetching recent connections', e);
      return [];
    }
  }

  // Get connections for a specific device
  Future<List<DeviceConnection>> getDeviceConnections(String deviceId, {int limit = 20}) async {
    try {
      final response = await client
          .from('device_connections')
          .select()
          .eq('device_id', deviceId)
          .limit(limit)
          .order('connected_at', ascending: false);

      return response
          .map<DeviceConnection>((json) => DeviceConnection.fromJson(json))
          .toList();
    } catch (e) {
      _logger.e('Error fetching device connections: $deviceId', e);
      return [];
    }
  }

  // Register/update device connection
  Future<Map<String, dynamic>?> registerDeviceConnection({
    required String deviceId,
    required String deviceName,
    String? deviceIp,
  }) async {
    try {
      final response = await client
          .rpc('register_device_connection', params: {
            'p_device_id': deviceId,
            'p_device_name': deviceName,
            'p_device_ip': deviceIp,
          });

      return response.isNotEmpty ? response.first : null;
    } catch (e) {
      _logger.e('Error registering device connection: $deviceId', e);
      return null;
    }
  }

  // Subscribe to real-time device updates
  RealtimeChannel subscribeToDeviceUpdates({
    required Function(Device) onDeviceUpdate,
    required Function(DeviceConnection) onNewConnection,
  }) {
    final subscription = client
        .channel('device_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'devices',
          callback: (payload) {
            // Refetch device data for updates since views might have changed
            _fetchAndNotifyDevice(payload.newRecord['device_id'], onDeviceUpdate);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'device_connections',
          callback: (payload) {
            final connection = DeviceConnection.fromJson(payload.newRecord);
            onNewConnection(connection);
          },
        );

    subscription.subscribe();
    return subscription;
  }

  // Helper method to fetch and notify device updates
  Future<void> _fetchAndNotifyDevice(String deviceId, Function(Device) onUpdate) async {
    try {
      final device = await getDevice(deviceId);
      if (device != null) {
        onUpdate(device);
      }
    } catch (e) {
      _logger.e('Error fetching updated device: $deviceId', e);
    }
  }

  // Unsubscribe from real-time updates
  void unsubscribe(RealtimeChannel subscription) {
    subscription.unsubscribe();
  }

  // Get device statistics
  Future<Map<String, dynamic>> getDeviceStatistics() async {
    try {
      // Get actual data and count manually for compatibility
      final activeDevices = await client
          .from('active_devices')
          .select();

      final totalDevices = await client
          .from('devices')
          .select();

      final onlineDevices = activeDevices
          .where((device) => device['connection_status'] == 'ONLINE')
          .toList();

      final blockedDevices = totalDevices
          .where((device) => device['status'] == 'BLOCKED')
          .toList();

      return {
        'total_devices': totalDevices.length,
        'active_devices': activeDevices.length,
        'online_devices': onlineDevices.length,
        'blocked_devices': blockedDevices.length,
      };
    } catch (e) {
      _logger.e('Error fetching device statistics', e);
      return {
        'total_devices': 0,
        'active_devices': 0,
        'online_devices': 0,
        'blocked_devices': 0,
      };
    }
  }

  // Bulk update device statuses
  Future<bool> bulkUpdateDeviceStatus(List<String> deviceIds, DeviceStatus status) async {
    try {
      await client
          .from('devices')
          .update({'status': status.value})
          .inFilter('device_id', deviceIds);

      return true;
    } catch (e) {
      _logger.e('Error bulk updating device status', e);
      return false;
    }
  }

  // Bulk delete devices
  Future<bool> bulkDeleteDevices(List<String> deviceIds) async {
    try {
      await client
          .from('devices')
          .delete()
          .inFilter('device_id', deviceIds);

      return true;
    } catch (e) {
      _logger.e('Error bulk deleting devices', e);
      return false;
    }
  }
} 