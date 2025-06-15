import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Standalone notification test that will FORCE a notification to appear
void main() async {
  print('🧪 STARTING STANDALONE NOTIFICATION TEST...');
  
  final notifications = FlutterLocalNotificationsPlugin();
  
  // Initialize with simple settings
  const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
  const settings = InitializationSettings(android: androidSettings);
  
  try {
    print('🔄 Initializing notification plugin...');
    final initialized = await notifications.initialize(settings);
    print('✅ Plugin initialized: $initialized');
    
    // Request permissions
    final androidPlugin = notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      print('📱 Requesting permissions...');
      final granted = await androidPlugin.requestNotificationsPermission();
      print('📱 Permission granted: $granted');
    }
    
    // Create channel
    if (androidPlugin != null) {
      print('🔔 Creating notification channel...');
      const channel = AndroidNotificationChannel(
        'test_gas_alerts',
        'Test Gas Alerts',
        description: 'Test notifications',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      );
      
      await androidPlugin.createNotificationChannel(channel);
      print('✅ Channel created');
    }
    
    // Send test notification
    print('🚨 SENDING TEST NOTIFICATION...');
    await notifications.show(
      12345,
      '🧪 TEST: Gas Alert!',
      '350 PPM detected at Test Kitchen - This is a test!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_gas_alerts',
          'Test Gas Alerts',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
          showWhen: true,
        ),
      ),
    );
    
    print('✅ TEST NOTIFICATION SENT! Check your notification panel!');
    
  } catch (e) {
    print('❌ Test failed: $e');
  }
} 