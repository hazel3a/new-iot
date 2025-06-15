import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_service.dart';
import 'auth_service.dart';

class RealTimeGasNotificationService {
  static RealTimeGasNotificationService? _instance;
  static RealTimeGasNotificationService get instance => _instance ??= RealTimeGasNotificationService._();
  
  RealTimeGasNotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final SupabaseService _supabase = SupabaseService.instance;
  
  bool _isInitialized = false;
  bool _isMonitoring = false;
  StreamSubscription? _gasLevelSubscription;
  int? _lastNotifiedLevel; // Track last notification level to prevent duplicates

  // Gas level thresholds in PPM
  static const int safeThreshold = 100;
  static const int warningThreshold = 300;
  static const int dangerThreshold = 600;
  static const int criticalThreshold = 1000;

  /// Initialize notifications
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      final initialized = await _notifications.initialize(settings);
      if (initialized != null && initialized) {
        await _createNotificationChannel();
        _isInitialized = true;
        if (kDebugMode) print('✅ Real-time gas notifications initialized');
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('❌ Notification initialization failed: $e');
    }
    return false;
  }

  /// Create notification channel
  Future<void> _createNotificationChannel() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      const channel = AndroidNotificationChannel(
        'gas_alerts',
        'Gas Level Alerts',
        description: 'Real-time gas level notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );

      await androidPlugin.createNotificationChannel(channel);
      if (kDebugMode) print('🔔 Notification channel created');
    }
  }

  /// Start monitoring gas levels
  Future<bool> startMonitoring() async {
    // 🔐 AUTHENTICATION CHECK: Only start monitoring if user is authenticated
    if (!AuthService.instance.isLoggedIn) {
      if (kDebugMode) print('🔒 MONITORING BLOCKED: User not authenticated - notifications will wait for login');
      return false;
    }
    
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_isMonitoring) return true;

    try {
      // Set up real-time stream monitoring
      _gasLevelSubscription = _createGasLevelStream().listen((gasValue) {
        if (kDebugMode) print('📊 Real-time gas level: $gasValue PPM');
        handleGasLevel(gasValue);
      });

      _isMonitoring = true;
      if (kDebugMode) print('⚡ Real-time gas monitoring started');
      
      // Check current level immediately
      _checkCurrentGasLevel();
      
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to start monitoring: $e');
      return false;
    }
  }

  /// Stop monitoring
  void stopMonitoring() {
    _gasLevelSubscription?.cancel();
    _gasLevelSubscription = null;
    _isMonitoring = false;
    _lastNotifiedLevel = null;
    if (kDebugMode) print('🛑 Gas monitoring stopped');
  }

  /// Create gas level stream from Supabase
  Stream<int> _createGasLevelStream() {
    return Stream.periodic(const Duration(seconds: 2), (_) async {
      try {
        final reading = await _supabase.getLatestReadingFiltered();
        if (reading != null && !_isTestDevice(reading.deviceName)) {
          return reading.gasValue;
        }
        return null;
      } catch (e) {
        if (kDebugMode) print('Error getting gas reading: $e');
        return null;
      }
    }).asyncMap((future) => future).where((value) => value != null).cast<int>();
  }

  /// Check current gas level immediatelyS
  Future<void> _checkCurrentGasLevel() async {
    try {
      final reading = await _supabase.getLatestReadingFiltered();
      if (reading != null && !_isTestDevice(reading.deviceName)) {
        if (kDebugMode) print('🔍 Current gas level: ${reading.gasValue} PPM from ${reading.deviceName}');
        handleGasLevel(reading.gasValue);
      }
    } catch (e) {
      if (kDebugMode) print('Error checking current level: $e');
    }
  }

  /// CORE LOGIC: Handle gas level changes and trigger notifications
  void handleGasLevel(int gasValue) {
    if (kDebugMode) print('🔄 Processing gas value: $gasValue PPM');
    
    // 🔐 AUTHENTICATION GATE: Block notifications if user is not logged in
    if (!AuthService.instance.isLoggedIn) {
      if (kDebugMode) print('🔒 BLOCKED: User not authenticated - no notifications until login');
      return;
    }
    
    // Determine notification level
    int notificationLevel;
    String message;
    
    if (gasValue >= criticalThreshold) {
      notificationLevel = 4;
      message = "CRITICAL: Evacuate immediately!";
    } else if (gasValue >= dangerThreshold) {
      notificationLevel = 3;
      message = "DANGER: High gas concentration detected!";
    } else if (gasValue >= warningThreshold) {
      notificationLevel = 2;
      message = "WARNING: Check gas nearby!";
    } else {
      // Safe level - no notification
      if (kDebugMode) print('✅ Safe level: $gasValue PPM - no notification');
      _lastNotifiedLevel = null; // Reset so next dangerous level triggers
      return;
    }

    // Only send notification if level changed
    if (_lastNotifiedLevel != notificationLevel) {
      if (kDebugMode) print('🚨 TRIGGERING NOTIFICATION: $message (Level $notificationLevel)');
      sendNotification(message, gasValue);
      _lastNotifiedLevel = notificationLevel;
    } else {
      if (kDebugMode) print('⏭️ Same notification level ($notificationLevel) - skipping duplicate');
    }
  }

  /// Send notification with sound
  Future<void> sendNotification(String message, int gasValue) async {
    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
        '🚨 Gas Alert',
        'Gas concentration: $gasValue PPM detected\n$message',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'gas_alerts',
            'Gas Level Alerts',
            channelDescription: 'Real-time gas level notifications',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
            ticker: 'Gas Alert',
            autoCancel: false,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            badgeNumber: 1,
          ),
        ),
      );
      
      if (kDebugMode) print('🔔 NOTIFICATION SENT: $message');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to send notification: $e');
    }
  }

  /// Check if device is test device
  bool _isTestDevice(String deviceName) {
    final lowercaseName = deviceName.toLowerCase().trim();
    return lowercaseName.contains('test') ||
           lowercaseName.contains('demo') ||
           lowercaseName.contains('mock') ||
           lowercaseName.contains('fake') ||
           deviceName.trim().isEmpty;
  }

  /// Get monitoring status
  bool get isMonitoring => _isMonitoring;
  bool get isInitialized => _isInitialized;
} 