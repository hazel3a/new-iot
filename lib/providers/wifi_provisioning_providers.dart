// WiFi Provisioning Providers (2025 Flutter Best Practices)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wifi_access_point.dart';
import '../services/wifi_scan_service.dart';
import '../services/esp_communication_service.dart';

/// WiFi Scan Service Provider
final wifiScanServiceProvider = Provider<WiFiScanService>((ref) {
  return WiFiScanService();
});

/// ESP Communication Service Provider
final espCommunicationServiceProvider = Provider<ESPCommunicationService>((ref) {
  return ESPCommunicationService();
});

/// WiFi Networks Stream Provider
final wifiNetworksProvider = StreamProvider<List<WiFiAccessPoint>>((ref) {
  final service = ref.watch(wifiScanServiceProvider);
  return service.networkStream;
});

/// WiFi Scanning State Provider
final wifiScanningProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(wifiScanServiceProvider);
  return service.scanningStream;
});

/// WiFi Scan Error Provider
final wifiScanErrorProvider = StreamProvider<String?>((ref) {
  final service = ref.watch(wifiScanServiceProvider);
  return service.errorStream;
});

/// WiFi Provisioning State Provider
final wifiProvisioningStateProvider = StateNotifierProvider<WiFiProvisioningNotifier, WiFiProvisioningState>((ref) {
  return WiFiProvisioningNotifier(ref);
});

/// Selected WiFi Network Provider
final selectedWifiNetworkProvider = StateProvider<WiFiAccessPoint?>((ref) => null);

/// WiFi Password Provider
final wifiPasswordProvider = StateProvider<String>((ref) => '');

/// Provisioning Result Provider
final provisioningResultProvider = StateProvider<WiFiProvisioningResult?>((ref) => null);

/// ESP Connection Status Provider
final espConnectionStatusProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(espCommunicationServiceProvider);
  return service.testConnection();
});

/// ESP Device Status Provider
final espDeviceStatusProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final service = ref.watch(espCommunicationServiceProvider);
  return service.getDeviceStatus();
});

/// WiFi Provisioning State Notifier
class WiFiProvisioningNotifier extends StateNotifier<WiFiProvisioningState> {
  final Ref _ref;
  
  WiFiProvisioningNotifier(this._ref) : super(WiFiProvisioningState.idle);

  /// Start WiFi scanning
  Future<void> startScanning() async {
    final service = _ref.read(wifiScanServiceProvider);
    
    state = WiFiProvisioningState.scanning;
    await service.startScanning();
  }

  /// Stop WiFi scanning
  void stopScanning() {
    final service = _ref.read(wifiScanServiceProvider);
    service.stopScanning();
    
    if (state == WiFiProvisioningState.scanning) {
      state = WiFiProvisioningState.idle;
    }
  }

  /// Initialize WiFi scanning
  Future<bool> initialize() async {
    final service = _ref.read(wifiScanServiceProvider);
    return service.initialize();
  }

  /// Provision WiFi credentials to ESP32
  Future<void> provisionWiFi({
    required WiFiAccessPoint network,
    required String password,
    String? deviceName,
  }) async {
    if (state == WiFiProvisioningState.sendingCredentials) return;

    state = WiFiProvisioningState.connecting;
    
    try {
      // Set selected network and password
      _ref.read(selectedWifiNetworkProvider.notifier).state = network;
      _ref.read(wifiPasswordProvider.notifier).state = password;
      
      state = WiFiProvisioningState.sendingCredentials;
      
      // Send credentials to ESP32
      final service = _ref.read(espCommunicationServiceProvider);
      final result = await service.sendWiFiCredentials(
        ssid: network.ssid,
        password: password,
        deviceName: deviceName,
      );
      
      // Store result
      _ref.read(provisioningResultProvider.notifier).state = result;
      
      if (result.success) {
        state = WiFiProvisioningState.success;
      } else {
        state = WiFiProvisioningState.error;
      }
    } catch (e) {
      _ref.read(provisioningResultProvider.notifier).state = 
          WiFiProvisioningResult.error('Provisioning failed: $e');
      state = WiFiProvisioningState.error;
    }
  }

  /// Reset provisioning state
  void reset() {
    state = WiFiProvisioningState.idle;
    _ref.read(selectedWifiNetworkProvider.notifier).state = null;
    _ref.read(wifiPasswordProvider.notifier).state = '';
    _ref.read(provisioningResultProvider.notifier).state = null;
  }

  /// Refresh WiFi scan
  Future<void> refresh() async {
    final service = _ref.read(wifiScanServiceProvider);
    await service.refresh();
  }
}

/// Filtered WiFi Networks Provider (remove weak signals, duplicates)
final filteredWifiNetworksProvider = Provider<AsyncValue<List<WiFiAccessPoint>>>((ref) {
  final networksAsync = ref.watch(wifiNetworksProvider);
  
  return networksAsync.when(
    data: (networks) {
      // Additional filtering for UI (already filtered in service)
      final filtered = networks
          .where((network) => network.ssid.isNotEmpty)
          .where((network) => network.level > -85) // Very weak signal threshold
          .toList();
      
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
  );
});

/// WiFi Network Search Provider
final wifiNetworkSearchProvider = StateProvider<String>((ref) => '');

/// Searched WiFi Networks Provider
final searchedWifiNetworksProvider = Provider<AsyncValue<List<WiFiAccessPoint>>>((ref) {
  final networksAsync = ref.watch(filteredWifiNetworksProvider);
  final searchQuery = ref.watch(wifiNetworkSearchProvider).toLowerCase();
  
  return networksAsync.when(
    data: (networks) {
      if (searchQuery.isEmpty) {
        return AsyncValue.data(networks);
      }
      
      final searched = networks
          .where((network) =>
              network.ssid.toLowerCase().contains(searchQuery) ||
              network.bssid.toLowerCase().contains(searchQuery))
          .toList();
      
      return AsyncValue.data(searched);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
  );
});

/// Permission Status Provider
final wifiPermissionStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(wifiScanServiceProvider);
  final statuses = await service.getPermissionStatuses();
  
  return {
    'permissions': statuses,
    'hasPermissions': service.hasPermissions,
  };
});

/// Auto-refresh Provider (for keeping scan results fresh)
final autoRefreshProvider = Provider<void>((ref) {
  // Auto-refresh logic can be implemented here if needed
  // For now, manual refresh via UI is sufficient
});

/// Dispose provider for cleanup
final wifiProvisioningDisposeProvider = Provider<void>((ref) {
  ref.onDispose(() {
    final scanService = ref.read(wifiScanServiceProvider);
    scanService.dispose();
  });
}); 