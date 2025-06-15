import 'package:flutter/material.dart';

enum DeviceStatus { 
  active('ACTIVE'), 
  inactive('INACTIVE'), 
  blocked('BLOCKED');
  
  const DeviceStatus(this.value);
  final String value;
  
  static DeviceStatus fromString(String value) {
    return DeviceStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => DeviceStatus.inactive,
    );
  }
}

enum ConnectionStatus { 
  online('ONLINE'), 
  offline('OFFLINE');
  
  const ConnectionStatus(this.value);
  final String value;
  
  static ConnectionStatus fromString(String value) {
    return ConnectionStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ConnectionStatus.offline,
    );
  }
}

class Device {
  final int id;
  final String deviceId;
  final String deviceName;
  final String? deviceIp;
  final String deviceType;
  final DeviceStatus status;
  final DateTime firstConnectedAt;
  final DateTime lastConnectedAt;
  final DateTime createdAt;
  final ConnectionStatus connectionStatus;
  final int secondsSinceLastConnection;
  final int totalReadings;
  final int? readingsToday;
  final int? totalConnections;
  final DateTime? lastDataReceived;
  final String? currentGasLevel;
  final int? currentGasValue;

  Device({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    this.deviceIp,
    required this.deviceType,
    required this.status,
    required this.firstConnectedAt,
    required this.lastConnectedAt,
    required this.createdAt,
    required this.connectionStatus,
    required this.secondsSinceLastConnection,
    required this.totalReadings,
    this.readingsToday,
    this.totalConnections,
    this.lastDataReceived,
    this.currentGasLevel,
    this.currentGasValue,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      deviceId: json['device_id'],
      deviceName: json['device_name'],
      deviceIp: json['device_ip'],
      deviceType: json['device_type'] ?? 'gas_sensor',
      status: DeviceStatus.fromString(json['status']),
      firstConnectedAt: DateTime.parse(json['first_connected_at']),
      lastConnectedAt: DateTime.parse(json['last_connected_at']),
      createdAt: DateTime.parse(json['created_at']),
      connectionStatus: ConnectionStatus.fromString(json['connection_status']),
      secondsSinceLastConnection: (json['seconds_since_last_connection'] ?? 0).round(),
      totalReadings: json['total_readings'] ?? 0,
      readingsToday: json['readings_today'],
      totalConnections: json['total_connections'],
      lastDataReceived: json['last_data_received'] != null 
          ? DateTime.parse(json['last_data_received']) 
          : null,
      currentGasLevel: json['current_gas_level'],
      currentGasValue: json['current_gas_value'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'device_name': deviceName,
      'device_ip': deviceIp,
      'device_type': deviceType,
      'status': status.value,
      'first_connected_at': firstConnectedAt.toIso8601String(),
      'last_connected_at': lastConnectedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'connection_status': connectionStatus.value,
      'seconds_since_last_connection': secondsSinceLastConnection,
      'total_readings': totalReadings,
      'readings_today': readingsToday,
      'total_connections': totalConnections,
      'last_data_received': lastDataReceived?.toIso8601String(),
      'current_gas_level': currentGasLevel,
      'current_gas_value': currentGasValue,
    };
  }

  // Helper methods for UI
  Color get statusColor {
    switch (status) {
      case DeviceStatus.active:
        return const Color(0xFF4CAF50); // Green
      case DeviceStatus.inactive:
        return const Color(0xFFFF9800); // Orange
      case DeviceStatus.blocked:
        return const Color(0xFFF44336); // Red
    }
  }

  Color get connectionStatusColor {
    switch (connectionStatus) {
      case ConnectionStatus.online:
        return const Color(0xFF4CAF50); // Green
      case ConnectionStatus.offline:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  IconData get statusIcon {
    switch (status) {
      case DeviceStatus.active:
        return Icons.check_circle;
      case DeviceStatus.inactive:
        return Icons.pause_circle;
      case DeviceStatus.blocked:
        return Icons.block;
    }
  }

  IconData get connectionStatusIcon {
    switch (connectionStatus) {
      case ConnectionStatus.online:
        return Icons.wifi;
      case ConnectionStatus.offline:
        return Icons.signal_wifi_off;
    }
  }

  String get displayConnectionStatus {
    switch (connectionStatus) {
      case ConnectionStatus.online:
        return 'Online';
      case ConnectionStatus.offline:
        return 'Offline';
    }
  }

  String get displayStatus {
    switch (status) {
      case DeviceStatus.active:
        return 'Allow';
      case DeviceStatus.inactive:
        return 'Inactive';
      case DeviceStatus.blocked:
        return 'Block';
    }
  }

  String get lastSeenText {
    if (secondsSinceLastConnection < 60) {
      return 'Just now';
    } else if (secondsSinceLastConnection < 3600) {
      final minutes = (secondsSinceLastConnection / 60).round();
      return '${minutes}m ago';
    } else if (secondsSinceLastConnection < 86400) {
      final hours = (secondsSinceLastConnection / 3600).round();
      return '${hours}h ago';
    } else {
      final days = (secondsSinceLastConnection / 86400).round();
      return '${days}d ago';
    }
  }

  Device copyWith({
    int? id,
    String? deviceId,
    String? deviceName,
    String? deviceIp,
    String? deviceType,
    DeviceStatus? status,
    DateTime? firstConnectedAt,
    DateTime? lastConnectedAt,
    DateTime? createdAt,
    ConnectionStatus? connectionStatus,
    int? secondsSinceLastConnection,
    int? totalReadings,
    int? readingsToday,
    int? totalConnections,
    DateTime? lastDataReceived,
    String? currentGasLevel,
    int? currentGasValue,
  }) {
    return Device(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceIp: deviceIp ?? this.deviceIp,
      deviceType: deviceType ?? this.deviceType,
      status: status ?? this.status,
      firstConnectedAt: firstConnectedAt ?? this.firstConnectedAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      createdAt: createdAt ?? this.createdAt,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      secondsSinceLastConnection: secondsSinceLastConnection ?? this.secondsSinceLastConnection,
      totalReadings: totalReadings ?? this.totalReadings,
      readingsToday: readingsToday ?? this.readingsToday,
      totalConnections: totalConnections ?? this.totalConnections,
      lastDataReceived: lastDataReceived ?? this.lastDataReceived,
      currentGasLevel: currentGasLevel ?? this.currentGasLevel,
      currentGasValue: currentGasValue ?? this.currentGasValue,
    );
  }
}

class DeviceConnection {
  final int id;
  final String deviceId;
  final String deviceName;
  final String? deviceIp;
  final String connectionType;
  final DateTime connectedAt;
  final DateTime? disconnectedAt;
  final bool isActive;
  final int dataCount;
  final String? registeredName;
  final DeviceStatus? deviceStatus;

  DeviceConnection({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    this.deviceIp,
    required this.connectionType,
    required this.connectedAt,
    this.disconnectedAt,
    required this.isActive,
    required this.dataCount,
    this.registeredName,
    this.deviceStatus,
  });

  factory DeviceConnection.fromJson(Map<String, dynamic> json) {
    return DeviceConnection(
      id: json['id'],
      deviceId: json['device_id'],
      deviceName: json['device_name'],
      deviceIp: json['device_ip'],
      connectionType: json['connection_type'] ?? 'data_upload',
      connectedAt: DateTime.parse(json['connected_at']),
      disconnectedAt: json['disconnected_at'] != null 
          ? DateTime.parse(json['disconnected_at']) 
          : null,
      isActive: json['is_active'] ?? false,
      dataCount: json['data_count'] ?? 0,
      registeredName: json['registered_name'],
      deviceStatus: json['device_status'] != null 
          ? DeviceStatus.fromString(json['device_status']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'device_name': deviceName,
      'device_ip': deviceIp,
      'connection_type': connectionType,
      'connected_at': connectedAt.toIso8601String(),
      'disconnected_at': disconnectedAt?.toIso8601String(),
      'is_active': isActive,
      'data_count': dataCount,
      'registered_name': registeredName,
      'device_status': deviceStatus?.value,
    };
  }

  Duration? get connectionDuration {
    if (disconnectedAt != null) {
      return disconnectedAt!.difference(connectedAt);
    }
    return null;
  }

  String get connectionDurationText {
    final duration = connectionDuration;
    if (duration == null) {
      if (isActive) {
        return 'Active now';
      } else {
        return 'Unknown duration';
      }
    }
    
    if (duration.inMinutes < 1) {
      return '${duration.inSeconds}s';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes}m';
    } else if (duration.inDays < 1) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    }
  }
} 