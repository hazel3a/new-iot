# WiFi Provisioning Feature (2025 Flutter Implementation)

## Overview
This feature implements modern WiFi provisioning for ESP32 gas detector devices using 2025 Flutter best practices. The implementation includes stream-based WiFi scanning, Material 3 UI, Android 13+ permissions, error resilience, and secure communication.

## Architecture

### Core Components

1. **WiFiScanService** (`lib/services/wifi_scan_service.dart`)
   - Stream-based WiFi scanning with 3-second intervals
   - Smart filtering (signal strength > -80dBm, non-empty SSID)
   - Automatic permission handling for Android 13+ and iOS
   - Duplicate removal and signal strength sorting

2. **ESPCommunicationService** (`lib/services/esp_communication_service.dart`)
   - Secure HTTP communication with ESP32 access point
   - Exponential backoff retry logic (1s, 2s, 4s)
   - Input validation and URL encoding
   - Timeout handling (10 seconds)

3. **WiFiAccessPoint Model** (`lib/models/wifi_access_point.dart`)
   - Comprehensive WiFi network representation
   - Signal strength percentage calculation
   - Security type detection (WPA3, WPA2, WPA, WEP, Open)
   - WiFi band identification (2.4GHz, 5GHz)

4. **Riverpod Providers** (`lib/providers/wifi_provisioning_providers.dart`)
   - Stream-based state management
   - Automatic state synchronization
   - Error handling and recovery
   - Search functionality

5. **WiFiProvisioningScreen** (`lib/screens/wifi_provisioning_screen.dart`)
   - Material 3 UI with modern design
   - Accessibility compliance
   - Smooth animations and transitions
   - Real-time status updates

## Key Features

### 🔒 Security
- URL encoding of credentials to prevent injection attacks
- Secure headers with device identification
- Timestamp-based request validation
- Input sanitization and validation

### 📱 Modern UI/UX
- Material 3 design system
- Dark/light theme support
- Smooth animations and transitions
- Accessibility compliance
- Responsive layout

### 🔄 Real-time Updates
- Stream-based WiFi scanning
- Live signal strength monitoring
- Automatic network list updates
- Connection status indicators

### 🛡️ Error Handling
- Comprehensive error messages
- Retry mechanisms with exponential backoff
- Permission request handling
- Network connectivity validation

### 🌐 Cross-platform
- Android 13+ permission support
- iOS location permission handling
- Adaptive UI for different screen sizes
- Platform-specific optimizations

## Usage

### Basic Integration

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'lib/screens/wifi_provisioning_screen.dart';
import 'lib/utils/wifi_provisioning_navigation.dart';

// Navigate to WiFi setup
WiFiProvisioningNavigation.navigateToWiFiSetup(context);

// Show setup dialog
WiFiProvisioningNavigation.showWiFiSetupDialog(context);

// Add to dashboard
WiFiProvisioningNavigation.buildWiFiSetupCard(context);
```

### State Management

```dart
// Watch WiFi networks
final networks = ref.watch(wifiNetworksProvider);

// Watch scanning state
final isScanning = ref.watch(wifiScanningProvider);

// Watch errors
final error = ref.watch(wifiScanErrorProvider);

// Control provisioning
final notifier = ref.read(wifiProvisioningStateProvider.notifier);
await notifier.provisionWiFi(
  network: selectedNetwork,
  password: password,
);
```

## Dependencies

### Required Packages
```yaml
dependencies:
  wifi_scan: ^0.4.1               # Active WiFi scanning
  permission_handler: ^11.0.0     # Android 13+ permissions
  http: ^1.1.0                    # HTTP communication
  network_info_plus: ^5.0.0       # Network information
  flutter_riverpod: ^2.4.10      # State management
```

### Permissions

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<!-- WiFi Provisioning permissions (Android 13+ / 2025 best practices) -->
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.INTERNET" />
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<!-- WiFi Provisioning permissions (iOS) -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to scan for WiFi networks when setting up your gas detector device.</string>
```

## ESP32 Integration

### Expected ESP32 Endpoints
- **Setup Page**: `GET http://192.168.4.1/`
- **Save Credentials**: `POST http://192.168.4.1/save`
- **Device Status**: `GET http://192.168.4.1/status`

### POST Request Format
```
Content-Type: application/x-www-form-urlencoded
X-Device-ID: FLUTTER_MOBILE_APP
X-Timestamp: 1704067200000

ssid=MyWiFiNetwork&pass=MyPassword&timestamp=1704067200000
```

### Expected Response
```html
<!-- Success Response -->
<html>
<body>
  <h1>Settings Saved!</h1>
  <p>WiFi credentials saved successfully.</p>
</body>
</html>
```

## Testing

### Unit Tests
```bash
flutter test test/services/wifi_scan_service_test.dart
flutter test test/services/esp_communication_service_test.dart
flutter test test/models/wifi_access_point_test.dart
```

### Integration Tests
```bash
flutter test integration_test/wifi_provisioning_test.dart
```

### Manual Testing Checklist

#### Permissions
- [ ] Android 13+ permission request works
- [ ] iOS location permission request works
- [ ] Permission denial handling works
- [ ] Settings redirect works

#### WiFi Scanning
- [ ] Networks are discovered and listed
- [ ] Signal strength is displayed correctly
- [ ] Secure/open networks are identified
- [ ] Duplicate networks are filtered
- [ ] Search functionality works

#### ESP32 Communication
- [ ] Connection to ESP32 AP works
- [ ] Credential transmission succeeds
- [ ] Error handling works for timeouts
- [ ] Retry logic functions correctly

#### UI/UX
- [ ] Material 3 design is consistent
- [ ] Animations are smooth
- [ ] Dark/light theme works
- [ ] Accessibility features work
- [ ] Error messages are clear

## Troubleshooting

### Common Issues

1. **No WiFi networks found**
   - Check location permissions
   - Verify NEARBY_WIFI_DEVICES permission (Android 13+)
   - Ensure WiFi is enabled on device

2. **ESP32 connection fails**
   - Verify connection to "GasDetector_Setup" network
   - Check ESP32 is in AP mode
   - Ensure correct IP address (192.168.4.1)

3. **Permission errors**
   - Update target SDK to 33+ for Android
   - Add location usage description for iOS
   - Handle permission denial gracefully

4. **UI issues**
   - Ensure Material 3 theme is configured
   - Check Flutter version compatibility
   - Verify responsive design works

### Debug Commands
```bash
# Check WiFi scan capability
flutter run --debug
# Enable verbose logging
flutter logs --verbose
# Check permissions
adb shell dumpsys package com.example.breadwinners_mobile | grep permission
```

## Performance Optimization

### Scanning Optimization
- 3-second scan intervals balance responsiveness and battery
- Smart filtering reduces UI load
- Automatic disposal prevents memory leaks

### Network Optimization
- 10-second timeout prevents hanging
- Exponential backoff reduces server load
- Connection pooling for HTTP requests

### UI Optimization
- Stream-based updates prevent unnecessary rebuilds
- Lazy loading for large network lists
- Efficient state management with Riverpod

## Future Enhancements

### Planned Features
- [ ] QR code scanning for credentials
- [ ] Bluetooth provisioning fallback
- [ ] Batch device setup
- [ ] Advanced network diagnostics
- [ ] Custom ESP32 firmware updates

### Potential Improvements
- [ ] Machine learning for network quality prediction
- [ ] Offline credential storage
- [ ] Multi-language support
- [ ] Advanced security options

## License
This implementation follows Flutter's standard licensing and is compatible with the overall project license.

## Support
For issues and questions, please refer to the main project documentation or create an issue in the project repository. 