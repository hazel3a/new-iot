import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/device_service.dart';

class DeviceHistoryScreen extends StatefulWidget {
  const DeviceHistoryScreen({super.key});

  @override
  State<DeviceHistoryScreen> createState() => _DeviceHistoryScreenState();
}

class _DeviceHistoryScreenState extends State<DeviceHistoryScreen> {
  final DeviceService _deviceService = DeviceService.instance;
  List<Device> _devices = [];
  List<Device> _filteredDevices = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  DeviceStatus? _statusFilter;
  final Set<String> _selectedDevices = {};
  bool _isMultiSelectMode = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final devices = await _deviceService.getDeviceHistory();
      setState(() {
        _devices = devices;
        _filteredDevices = devices;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _error = 'Error loading device history: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredDevices = _devices.where((device) {
        final matchesSearch = device.deviceName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                              device.deviceId.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesStatus = _statusFilter == null || device.status == _statusFilter;
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyFilters();
  }

  void _onStatusFilterChanged(DeviceStatus? status) {
    setState(() {
      _statusFilter = status;
    });
    _applyFilters();
  }

  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedDevices.clear();
      }
    });
  }

  void _toggleDeviceSelection(String deviceId) {
    setState(() {
      if (_selectedDevices.contains(deviceId)) {
        _selectedDevices.remove(deviceId);
      } else {
        _selectedDevices.add(deviceId);
      }
    });
  }

  Future<void> _updateDeviceStatus(String deviceId, DeviceStatus status) async {
    final success = await _deviceService.updateDeviceStatus(deviceId, status);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device status updated to ${status.value}'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    }
  }

  Future<void> _deleteDevice(String deviceId, String deviceName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text('Delete "$deviceName"? This removes all data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _deviceService.deleteDevice(deviceId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device "$deviceName" deleted'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    }
  }

  Future<void> _bulkAction(DeviceStatus? status, {bool delete = false}) async {
    if (_selectedDevices.isEmpty) return;

    String actionText = delete ? 'delete' : 'update status for';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(delete ? 'Delete Devices' : 'Update Device Status'),
        content: Text('Are you sure you want to $actionText ${_selectedDevices.length} selected device(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: delete ? Colors.red : Colors.blue,
            ),
            child: Text(delete ? 'Delete' : 'Update'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      bool success;
      if (delete) {
        success = await _deviceService.bulkDeleteDevices(_selectedDevices.toList());
      } else {
        success = await _deviceService.bulkUpdateDeviceStatus(_selectedDevices.toList(), status!);
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(delete ? 'Devices deleted successfully' : 'Device statuses updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _selectedDevices.clear();
            _isMultiSelectMode = false;
          });
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(delete ? 'Failed to delete devices' : 'Failed to update device statuses'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildSearchAndFilter() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search bar
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search devices...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 16),
            
            // Filter row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<DeviceStatus?>(
                    decoration: const InputDecoration(
                      labelText: 'Filter by Status',
                      border: OutlineInputBorder(),
                    ),
                    value: _statusFilter,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Statuses')),
                      DropdownMenuItem(
                        value: DeviceStatus.active,
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: DeviceStatus.active.value == 'ACTIVE' ? Colors.green : null, size: 16),
                            const SizedBox(width: 8),
                            const Text('Allow'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: DeviceStatus.inactive,
                        child: Row(
                          children: [
                            Icon(Icons.pause_circle, color: DeviceStatus.inactive.value == 'INACTIVE' ? Colors.orange : null, size: 16),
                            const SizedBox(width: 8),
                            const Text('Inactive'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: DeviceStatus.blocked,
                        child: Row(
                          children: [
                            Icon(Icons.block, color: DeviceStatus.blocked.value == 'BLOCKED' ? Colors.red : null, size: 16),
                            const SizedBox(width: 8),
                            const Text('Block'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: _onStatusFilterChanged,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _toggleMultiSelectMode,
                  icon: Icon(_isMultiSelectMode ? Icons.close : Icons.checklist),
                  label: Text(_isMultiSelectMode ? 'Cancel' : 'Select'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isMultiSelectMode ? Colors.grey : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkActionBar() {
    if (!_isMultiSelectMode || _selectedDevices.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Row(
        children: [
          Text(
            '${_selectedDevices.length} selected',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _bulkAction(DeviceStatus.active),
            icon: const Icon(Icons.check_circle),
            label: const Text('Allow'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _bulkAction(DeviceStatus.blocked),
            icon: const Icon(Icons.block),
            label: const Text('Block'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _bulkAction(null, delete: true),
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    final isSelected = _selectedDevices.contains(device.deviceId);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: _isMultiSelectMode
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleDeviceSelection(device.deviceId),
              )
            : Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: device.statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  device.statusIcon,
                  color: device.statusColor,
                  size: 20,
                ),
              ),
        title: Text(
          device.deviceName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.deviceId),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: device.statusColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    device.displayStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${device.totalReadings} readings',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                Text(
                  device.lastSeenText,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: _isMultiSelectMode
            ? null
            : PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'allow':
                      _updateDeviceStatus(device.deviceId, DeviceStatus.active);
                      break;
                    case 'block':
                      _updateDeviceStatus(device.deviceId, DeviceStatus.blocked);
                      break;
                    case 'delete':
                      _deleteDevice(device.deviceId, device.deviceName);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'allow',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Allow'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(Icons.block, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Block'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
        onTap: _isMultiSelectMode
            ? () => _toggleDeviceSelection(device.deviceId)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device History'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          _buildBulkActionBar(),
          Expanded(
            child: _isLoading
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
                              onPressed: _loadData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredDevices.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.device_unknown,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty || _statusFilter != null
                                      ? 'No devices match your filter'
                                      : 'No devices found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isNotEmpty || _statusFilter != null
                                      ? 'Try adjusting your search or filter'
                                      : 'Devices will appear here once they connect',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.builder(
                              itemCount: _filteredDevices.length,
                              itemBuilder: (context, index) {
                                return _buildDeviceCard(_filteredDevices[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
} 