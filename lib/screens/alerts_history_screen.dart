import 'package:flutter/material.dart';
import '../models/gas_sensor_reading.dart';
import '../services/supabase_service.dart';
import '../utils/time_formatter.dart';

class AlertsHistoryScreen extends StatefulWidget {
  const AlertsHistoryScreen({super.key});

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
      final allReadings = await _supabaseService.getRecentReadingsFiltered(limit: 1000);
      
      // Filter for non-safe readings (WARNING, DANGER, CRITICAL) and get the 10 most recent
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
        return Colors.orange;
      case 'DANGER':
        return Colors.red;
      case 'CRITICAL':
        return Colors.red[800]!;
      default:
        return Colors.grey;
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
      appBar: AppBar(
        title: const Text('Alert History'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlertHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
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
                        onPressed: _loadAlertHistory,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _alertReadings.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 64,
                            color: Colors.green,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No Alerts Found',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'All gas levels are within safe ranges',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAlertHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _alertReadings.length,
                        itemBuilder: (context, index) {
                          final reading = _alertReadings[index];
                          final gasLevelColor = _getGasLevelColor(reading.gasLevel);
                          final gasLevelIcon = _getGasLevelIcon(reading.gasLevel);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 4,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: gasLevelColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  gasLevelIcon,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                'Gas Level: ${reading.gasLevel.toUpperCase()}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: gasLevelColor,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    'Device: ${reading.deviceName}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Value: ${reading.gasValue} ppm',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        TimeFormatter.formatDateTime(reading.createdAt),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: gasLevelColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${reading.gasValue}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
} 