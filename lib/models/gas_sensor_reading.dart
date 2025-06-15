import 'package:flutter/material.dart';

class GasSensorReading {
  final int id;
  final DateTime createdAt;
  final int gasValue;
  final String gasLevel;
  final int deviation;
  final int baseline;
  final String deviceId;
  final String deviceName;

  GasSensorReading({
    required this.id,
    required this.createdAt,
    required this.gasValue,
    required this.gasLevel,
    required this.deviation,
    required this.baseline,
    required this.deviceId,
    required this.deviceName,
  });

  factory GasSensorReading.fromJson(Map<String, dynamic> json) {
    return GasSensorReading(
      id: json['id'],
      createdAt: DateTime.parse(json['created_at']),
      gasValue: json['gas_value'],
      gasLevel: json['gas_level'],
      deviation: json['deviation'] ?? 0,
      baseline: json['baseline'] ?? 0,
      deviceId: json['device_id'] ?? 'Unknown',
      deviceName: json['device_name'] ?? 'Unknown Device',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'gas_value': gasValue,
      'gas_level': gasLevel,
      'deviation': deviation,
      'baseline': baseline,
      'device_id': deviceId,
      'device_name': deviceName,
    };
  }

  // Helper method to get color based on gas level
  Color get levelColor {
    switch (gasLevel.toLowerCase()) {
      case 'safe':
        return const Color(0xFF4CAF50); // Green
      case 'warning':
        return const Color(0xFFFF9800); // Orange
      case 'danger':
        return const Color(0xFFFF5722); // Deep Orange
      case 'critical':
        return const Color(0xFFF44336); // Red
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  // Helper method to get icon based on gas level
  IconData get levelIcon {
    switch (gasLevel.toLowerCase()) {
      case 'safe':
        return Icons.check_circle;
      case 'warning':
        return Icons.warning;
      case 'danger':
        return Icons.error_outline;
      case 'critical':
        return Icons.emergency;
      default:
        return Icons.help_outline;
    }
  }
} 