// WiFi Provisioning Screen (2025 Flutter Best Practices)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wifi_access_point.dart';
import '../providers/wifi_provisioning_providers.dart';
import '../services/esp_communication_service.dart';

class WiFiProvisioningScreen extends ConsumerStatefulWidget {
  const WiFiProvisioningScreen({super.key});

  @override
  ConsumerState<WiFiProvisioningScreen> createState() => _WiFiProvisioningScreenState();
}

class _WiFiProvisioningScreenState extends ConsumerState<WiFiProvisioningScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Initialize WiFi scanning
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWiFiScanning();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    
    // Stop scanning when leaving screen
    ref.read(wifiProvisioningStateProvider.notifier).stopScanning();
    super.dispose();
  }

  Future<void> _initializeWiFiScanning() async {
    final notifier = ref.read(wifiProvisioningStateProvider.notifier);
    final initialized = await notifier.initialize();
    
    if (initialized) {
      await notifier.startScanning();
      _animationController.forward();
    } else {
      _showPermissionDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'WiFi Setup',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
      actions: [
        Consumer(
          builder: (context, ref, child) {
            final isScanning = ref.watch(wifiScanningProvider).value ?? false;
            
            return IconButton(
              onPressed: isScanning ? null : _refreshNetworks,
              icon: AnimatedRotation(
                turns: isScanning ? 1 : 0,
                duration: const Duration(seconds: 1),
                child: const Icon(Icons.refresh_rounded),
              ),
              tooltip: 'Refresh networks',
            );
          },
        ),
        IconButton(
          onPressed: _showInstructions,
          icon: const Icon(Icons.help_outline_rounded),
          tooltip: 'Connection instructions',
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Consumer(
      builder: (context, ref, child) {
        // Watch for errors
        ref.listen(wifiScanErrorProvider, (previous, next) {
          final error = next.value;
          if (error != null && mounted) {
            _showErrorSnackBar(error);
          }
        });

        // Watch for provisioning state changes
        ref.listen(wifiProvisioningStateProvider, (previous, next) {
          if (next == WiFiProvisioningState.success) {
            _showSuccessDialog();
          } else if (next == WiFiProvisioningState.error) {
            final result = ref.read(provisioningResultProvider);
            _showErrorDialog(result?.error ?? 'Unknown error occurred');
          }
        });

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildConnectionStatus(),
              _buildSearchBar(),
              Expanded(child: _buildNetworkList()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionStatus() {
    return Consumer(
      builder: (context, ref, child) {
        final espConnectionAsync = ref.watch(espConnectionStatusProvider);
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              espConnectionAsync.when(
                data: (connected) => Icon(
                  connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: connected 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
                loading: () => SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                error: (_, __) => Icon(
                  Icons.error_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      espConnectionAsync.when(
                        data: (connected) => connected
                            ? 'Connected to Gas Detector'
                            : 'Connect to Gas Detector WiFi',
                        loading: () => 'Checking connection...',
                        error: (_, __) => 'Connection failed',
                      ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      espConnectionAsync.when(
                        data: (connected) => connected
                            ? 'Ready to configure WiFi settings'
                            : 'Follow the instructions to connect',
                        loading: () => 'Testing device connection...',
                        error: (_, __) => 'Unable to reach device',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SearchBar(
        controller: _searchController,
        hintText: 'Search WiFi networks...',
        leading: const Icon(Icons.search_rounded),
        trailing: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
                ref.read(wifiNetworkSearchProvider.notifier).state = '';
              },
              icon: const Icon(Icons.clear_rounded),
            ),
        ],
        onChanged: (value) {
          ref.read(wifiNetworkSearchProvider.notifier).state = value;
        },
        elevation: MaterialStateProperty.all(0),
        backgroundColor: MaterialStateProperty.all(
          Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        ),
        side: MaterialStateProperty.all(
          BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkList() {
    return Consumer(
      builder: (context, ref, child) {
        final networksAsync = ref.watch(searchedWifiNetworksProvider);
        final isScanning = ref.watch(wifiScanningProvider).value ?? false;
        
        return networksAsync.when(
          data: (networks) => _buildNetworkListView(networks, isScanning),
          loading: () => _buildLoadingView(),
          error: (error, _) => _buildErrorView(error.toString()),
        );
      },
    );
  }

  Widget _buildNetworkListView(List<WiFiAccessPoint> networks, bool isScanning) {
    if (networks.isEmpty) {
      return _buildEmptyView(isScanning);
    }

    return RefreshIndicator(
      onRefresh: _refreshNetworks,
      color: Theme.of(context).colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 16, bottom: 100),
        itemCount: networks.length,
        itemBuilder: (context, index) {
          final network = networks[index];
          return _buildNetworkTile(network);
        },
      ),
    );
  }

  Widget _buildNetworkTile(WiFiAccessPoint network) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: _buildSignalIcon(network),
          title: Text(
            network.ssid,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    network.isSecure ? Icons.lock_rounded : Icons.lock_open_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    network.securityType.displayName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    network.band,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${network.signalQuality} • ${network.signalStrengthPercentage}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onTap: () => _selectNetwork(network),
        ),
      ),
    );
  }

  Widget _buildSignalIcon(WiFiAccessPoint network) {
    final strength = network.signalStrengthPercentage;
    IconData icon;
    Color color;

    if (strength >= 75) {
      icon = Icons.wifi;
      color = Theme.of(context).colorScheme.primary;
    } else if (strength >= 50) {
      icon = Icons.wifi;
      color = Theme.of(context).colorScheme.primary;
    } else if (strength >= 25) {
      icon = Icons.wifi;
      color = Colors.orange;
    } else {
      icon = Icons.wifi_off;
      color = Theme.of(context).colorScheme.error;
    }

    return Icon(icon, color: color, size: 24);
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Scanning for WiFi networks...',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few moments',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(bool isScanning) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isScanning ? Icons.wifi_find : Icons.wifi_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            isScanning ? 'Scanning...' : 'No WiFi networks found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            isScanning
                ? 'Looking for available networks'
                : 'Try refreshing or check your location permissions',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (!isScanning) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _refreshNetworks,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'WiFi Scanning Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _showPermissionDialog,
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Settings'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _refreshNetworks,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    return Consumer(
      builder: (context, ref, child) {
        final espConnectionAsync = ref.watch(espConnectionStatusProvider);
        final connected = espConnectionAsync.value ?? false;
        
        if (!connected) {
          return FloatingActionButton.extended(
            onPressed: _showInstructions,
            icon: const Icon(Icons.help_rounded),
            label: const Text('Instructions'),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }

  Future<void> _refreshNetworks() async {
    try {
      // Show feedback to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Refreshing WiFi networks...'),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      final notifier = ref.read(wifiProvisioningStateProvider.notifier);
      await notifier.refresh();
      
      // Clear the snackbar and show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('WiFi networks refreshed'),
              ],
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Refresh failed: $e')),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _selectNetwork(WiFiAccessPoint network) {
    if (network.isSecure) {
      _showPasswordDialog(network);
    } else {
      _provisionNetwork(network, '');
    }
  }

  void _showPasswordDialog(WiFiAccessPoint network) {
    _passwordController.clear();
    _isPasswordVisible = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Connect to ${network.ssid}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This network requires a password',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter WiFi password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (_passwordController.text.isNotEmpty) {
                    Navigator.of(context).pop();
                    _provisionNetwork(network, _passwordController.text);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _passwordController.text.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _provisionNetwork(network, _passwordController.text);
                    },
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _provisionNetwork(WiFiAccessPoint network, String password) async {
    final notifier = ref.read(wifiProvisioningStateProvider.notifier);
    await notifier.provisionWiFi(
      network: network,
      password: password,
      deviceName: 'Gas Detector',
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.check_circle_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 48,
        ),
        title: const Text('WiFi Setup Complete!'),
        content: const Text(
          'Your gas detector has been successfully configured and will now connect to your WiFi network. '
          'The device will restart automatically.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Return to previous screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.error_rounded,
          color: Theme.of(context).colorScheme.error,
          size: 48,
        ),
        title: const Text('Setup Failed'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(wifiProvisioningStateProvider.notifier).reset();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.location_on_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 48,
        ),
        title: const Text('Permissions Required'),
        content: const Text(
          'WiFi scanning requires location and nearby devices permissions. '
          'Please enable these permissions in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(wifiScanServiceProvider).openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showInstructions() {
    final instructions = ESPCommunicationService().getConnectionInstructions();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.info_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 48,
        ),
        title: const Text('Connection Instructions'),
        content: SingleChildScrollView(
          child: Text(instructions),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String error) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Theme.of(context).colorScheme.onError,
          onPressed: _refreshNetworks,
        ),
      ),
    );
  }
} 