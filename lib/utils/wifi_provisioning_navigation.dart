// WiFi Provisioning Navigation Utility (2025 Flutter Best Practices)
import 'package:flutter/material.dart';
import '../screens/direct_wifi_setup_screen.dart';

class WiFiProvisioningNavigation {
  /// Navigate to WiFi provisioning screen
  static Future<T?> navigateToWiFiSetup<T extends Object?>(
    BuildContext context, {
    bool replaceCurrentRoute = false,
  }) {
    if (replaceCurrentRoute) {
      return Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const DirectWiFiSetupScreen(),
          settings: const RouteSettings(name: '/wifi-setup'),
        ),
      );
    } else {
      return Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const DirectWiFiSetupScreen(),
          settings: const RouteSettings(name: '/wifi-setup'),
        ),
      );
    }
  }

  /// Show WiFi setup dialog with instructions
  static Future<bool?> showWiFiSetupDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.wifi_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 48,
        ),
        title: const Text('WiFi Setup Required'),
        content: const Text(
          'Your gas detector needs to be connected to WiFi for remote monitoring. '
          'Would you like to set up WiFi now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              navigateToWiFiSetup(context);
            },
            child: const Text('Setup WiFi'),
          ),
        ],
      ),
    );
  }

  /// Create a WiFi setup card for dashboard or settings
  static Widget buildWiFiSetupCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wifi_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'WiFi Setup',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Configure your gas detector\'s WiFi connection for remote monitoring and alerts.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => navigateToWiFiSetup(context),
                icon: const Icon(Icons.settings_rounded),
                label: const Text('Setup WiFi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Create a floating action button for WiFi setup
  static Widget buildWiFiSetupFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => navigateToWiFiSetup(context),
      icon: const Icon(Icons.wifi_rounded),
      label: const Text('WiFi Setup'),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
    );
  }

  /// Create an app bar action for WiFi setup
  static Widget buildWiFiSetupAction(BuildContext context) {
    return IconButton(
      onPressed: () => navigateToWiFiSetup(context),
      icon: const Icon(Icons.wifi_rounded),
      tooltip: 'WiFi Setup',
    );
  }
} 