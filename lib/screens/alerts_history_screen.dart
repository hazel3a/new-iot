import 'package:flutter/material.dart';
import '../models/gas_sensor_reading.dart';
import '../models/device.dart';
import '../services/supabase_service.dart';
import '../utils/time_formatter.dart';

class AlertsHistoryScreen extends StatefulWidget {
  final Device? device;
  
  const AlertsHistoryScreen({super.key, this.device});

  @override
  State<AlertsHistoryScreen> createState() => _AlertsHistoryScreenState();
}

class _AlertsHistoryScreenState extends State<AlertsHistoryScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  List<GasSensorReading> _alertReadings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAlertHistory();
  }

  Future<void> _loadAlertHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get more readings to ensure we find warnings even if they're older
      // If device is specified, filter by device name, otherwise get all alerts
      final allReadings = await _supabaseService.getRecentReadingsFiltered(
        limit: 1000,
        deviceName: widget.device?.deviceName,
      );
      
      // Filter for non-safe readings (WARNING, DANGER, CRITICAL) and get at least 10 most recent
      final alertReadings = allReadings.where((reading) {
        final gasLevel = reading.gasLevel.toUpperCase();
        return gasLevel == 'WARNING' || gasLevel == 'DANGER' || gasLevel == 'CRITICAL';
      }).take(10).toList();

      setState(() {
        _alertReadings = alertReadings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load alert history: $e';
        _isLoading = false;
      });
    }
  }

  Color _getGasLevelColor(String gasLevel) {
    switch (gasLevel.toUpperCase()) {
      case 'WARNING':
        return const Color(0xFFFBBF24); // Yellow for warning
      case 'DANGER':
        return const Color(0xFFF87171); // Soft red for danger
      case 'CRITICAL':
        return const Color(0xFF8B0000); // Bloody red for critical
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  IconData _getGasLevelIcon(String gasLevel) {
    switch (gasLevel.toUpperCase()) {
      case 'WARNING':
        return Icons.warning_amber;
      case 'DANGER':
        return Icons.error;
      case 'CRITICAL':
        return Icons.dangerous;
      default:
        return Icons.sensors;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF4ADE80)),
            onPressed: () => Navigator.pop(context),
          ),
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
                Icons.warning_amber,
                color: Color(0xFFF87171),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.device != null 
                    ? '${widget.device!.deviceName} Alerts'
                    : 'Alert History',
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  fontFamily: 'Inter',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF4ADE80)),
              onPressed: _loadAlertHistory,
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  const Text(
                    'Loading alert history...',
                    style: TextStyle(
                      color: Color(0xFFE5E7EB),
                      fontSize: 16,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
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
                      mainAxisSize: MainAxisSize.min,
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
                        const Text(
                          'Connection Error',
                          style: TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                            fontFamily: 'Inter',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadAlertHistory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4ADE80),
                            foregroundColor: const Color(0xFF0F0F0F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Try Again',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _alertReadings.isEmpty
                  ? Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4ADE80).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                size: 48,
                                color: Color(0xFF4ADE80),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              widget.device != null 
                                  ? 'No Alerts Found'
                                  : 'All Clear!',
                              style: const TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.device != null
                                  ? 'All gas levels for this device are within safe ranges'
                                  : 'All gas levels are within safe ranges',
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 14,
                                fontFamily: 'Inter',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAlertHistory,
                      color: const Color(0xFF4ADE80),
                      backgroundColor: const Color(0xFF111827),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _alertReadings.length,
                        itemBuilder: (context, index) {
                          final reading = _alertReadings[index];
                          final gasLevelColor = _getGasLevelColor(reading.gasLevel);
                          final gasLevelIcon = _getGasLevelIcon(reading.gasLevel);
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: gasLevelColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  // Alert icon
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: gasLevelColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      gasLevelIcon,
                                      color: gasLevelColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Alert level badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: gasLevelColor,
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
                                        const SizedBox(height: 12),
                                        
                                        // Device name
                                        Text(
                                          reading.deviceName,
                                          style: const TextStyle(
                                            color: Color(0xFFFFFFFF),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        
                                        // Gas value
                                        Row(
                                          children: [
                                            Text(
                                              '${reading.gasValue}',
                                              style: TextStyle(
                                                color: gasLevelColor,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'PPM',
                                              style: TextStyle(
                                                color: gasLevelColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        
                                        // Timestamp
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time,
                                              size: 14,
                                              color: Color(0xFF6B7280),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              TimeFormatter.formatDateTime(reading.createdAt),
                                              style: const TextStyle(
                                                color: Color(0xFF6B7280),
                                                fontSize: 12,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Severity indicator
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F0F0F),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: gasLevelColor,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          reading.gasLevel.toLowerCase() == 'critical' ? '!!!' : 
                                          reading.gasLevel.toLowerCase() == 'danger' ? '!!' : '!',
                                          style: TextStyle(
                                            color: gasLevelColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
} 