import 'package:flutter/material.dart';
import '../utils/wifi_provisioning_navigation.dart';

class SettingsScreen extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            
            // Appearance Section
            Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Switch between light and dark themes'),
                value: isDarkMode,
                onChanged: onDarkModeChanged,
                secondary: Icon(
                  isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: Colors.teal,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Device Setup Section
            Text(
              'Device Setup',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.wifi_rounded, color: Colors.teal),
                title: const Text('WiFi Setup'),
                subtitle: const Text('Configure gas detector WiFi connection'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => WiFiProvisioningNavigation.navigateToWiFiSetup(context),
              ),
            ),
            const SizedBox(height: 24),
            
            // About Section
            Text(
              'About',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info, color: Colors.teal),
                title: const Text('App Version'),
                subtitle: const Text('1.0.0'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 