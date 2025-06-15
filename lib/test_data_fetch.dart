import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'models/gas_sensor_reading.dart';

class TestDataFetch extends StatefulWidget {
  final String? deviceFilter;
  
  const TestDataFetch({super.key, this.deviceFilter});

  @override
  State<TestDataFetch> createState() => _TestDataFetchState();
}

class _TestDataFetchState extends State<TestDataFetch> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  List<GasSensorReading> _readings = [];
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceFilter != null 
            ? 'Test Connection - ${widget.deviceFilter}'
            : 'Test Data Fetch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _testFetch,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _testFetch,
              child: const Text('Test Fetch Data'),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error: $_error',
                  style: const TextStyle(color: Colors.red),
                ),
              )
            else if (_readings.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Successfully fetched ${_readings.length} readings!',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sample Data:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _readings.length,
                        itemBuilder: (context, index) {
                          final reading = _readings[index];
                          return Card(
                            child: ListTile(
                              title: Text('${reading.deviceName} (${reading.deviceId})'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Gas Value: ${reading.gasValue}'),
                                  Text('Level: ${reading.gasLevel}'),
                                  Text('Deviation: ${reading.deviation}'),
                                  Text('Baseline: ${reading.baseline}'),
                                  Text('Time: ${reading.createdAt}'),
                                ],
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: reading.levelColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  reading.levelIcon,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            else
              const Center(
                child: Text('No data fetched yet. Click the button to test.'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _testFetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _readings = [];
    });

    try {
      // Test connection with optional device filter
      final readings = widget.deviceFilter != null
          ? await _supabaseService.getRecentReadingsFiltered(
              deviceName: widget.deviceFilter, 
              limit: 10
            )
          : await _supabaseService.getRecentReadings(limit: 10);
      
      setState(() {
        _readings = readings;
        _isLoading = false;
      });
      
      if (readings.isEmpty) {
        setState(() {
          _error = 'Connected successfully but no data found. Make sure to run the SQL setup and ESP32 is uploading data.';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
} 